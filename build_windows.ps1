# Build "MHGU Charms RNG" for Windows into dist\ and zip it for a release.
# Requires the Swift toolchain for Windows (https://www.swift.org/install/windows/).
#
#   .\build_windows.ps1              build dist\MHGU Charms RNG\ and dist\MHGU-Charms-RNG-<version>-Windows.zip
#   .\build_windows.ps1 -SmokeTest   also run the packaged app once (every tool, then the timers) with
#                                    only Windows' own folders on PATH, to check nothing is missing
param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Name = 'MHGU Charms RNG'
$Version = (Select-String -Path 'Sources\MHGUCharmsRNGWin\App.swift' -Pattern 'let appVersion = "(.+)"').Matches[0].Groups[1].Value
$Work = Join-Path $PSScriptRoot '.build\windows-package'
New-Item -ItemType Directory -Force $Work | Out-Null

# --- Icon and version information for the .exe (needs rc.exe from the Windows SDK) -------------
$linkArgs = @()
$rc = Get-Command rc.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $rc) {
  $rc = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\rc.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName
}
if ($rc) {
  $numeric = ((($Version -split '\.') + @('0', '0', '0', '0'))[0..3]) -join ','
  $icon = (Join-Path $PSScriptRoot 'Resources\AppIcon.ico') -replace '\\', '\\'
  @"
1 ICON "$icon"
1 VERSIONINFO
FILEVERSION $numeric
PRODUCTVERSION $numeric
FILEOS 0x40004
FILETYPE 0x1
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904B0"
    BEGIN
      VALUE "CompanyName", "mhgu-rng-app"
      VALUE "FileDescription", "$Name"
      VALUE "FileVersion", "$Version"
      VALUE "InternalName", "$Name"
      VALUE "LegalCopyright", "MIT License"
      VALUE "OriginalFilename", "$Name.exe"
      VALUE "ProductName", "$Name"
      VALUE "ProductVersion", "$Version"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x409, 1200
  END
END
"@ | Set-Content -Encoding ASCII "$Work\app.rc"
  & $rc /nologo /fo "$Work\app.res" "$Work\app.rc"
  if ($LASTEXITCODE -ne 0) { throw 'rc.exe failed' }
  $linkArgs = @('-Xlinker', "$Work\app.res")
} else {
  Write-Warning 'rc.exe (Windows SDK) not found: the .exe will have no icon in Explorer.'
}

# --- Build --------------------------------------------------------------------------------------
swift build -c release --product MHGUCharmsRNGWin @linkArgs
if ($LASTEXITCODE -ne 0) { throw 'swift build failed' }
$bin = (swift build -c release --show-bin-path).Trim()

$dist = Join-Path $PSScriptRoot "dist\$Name"
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Force $dist | Out-Null
$exe = Join-Path $dist "$Name.exe"
Copy-Item "$bin\MHGUCharmsRNGWin.exe" $exe
Copy-Item 'Resources\AppIcon.ico' $dist
Copy-Item 'LICENSE' "$dist\LICENSE.txt"

# --- Bundle the DLLs it needs (Swift runtime, Visual C++ runtime) -------------------------------
# Reads each PE file's import and delay-import tables and copies every DLL found on PATH that
# isn't part of Windows, then does the same for those DLLs.
function Get-PEImports([string]$Path) {
  $b = [IO.File]::ReadAllBytes($Path)
  $pe = [BitConverter]::ToInt32($b, 0x3C)
  $sections = [BitConverter]::ToUInt16($b, $pe + 6)
  $optSize = [BitConverter]::ToUInt16($b, $pe + 20)
  $opt = $pe + 24
  $dirs = $opt + $(if ([BitConverter]::ToUInt16($b, $opt) -eq 0x20B) { 112 } else { 96 })
  $secTable = $opt + $optSize
  function RvaToOffset([uint32]$rva) {
    for ($i = 0; $i -lt $sections; $i++) {
      $s = $secTable + 40 * $i
      $va = [BitConverter]::ToUInt32($b, $s + 12); $size = [BitConverter]::ToUInt32($b, $s + 8)
      if ($size -eq 0) { $size = [BitConverter]::ToUInt32($b, $s + 16) }
      if ($rva -ge $va -and $rva -lt $va + $size) { return $rva - $va + [BitConverter]::ToUInt32($b, $s + 20) }
    }
    return $null
  }
  function ReadName([uint32]$rva) {
    $o = RvaToOffset $rva; $e = $o
    while ($b[$e] -ne 0) { $e++ }
    return [Text.Encoding]::ASCII.GetString($b, $o, $e - $o)
  }
  $names = @()
  foreach ($d in @(@{ Index = 1; Size = 20; NameAt = 12 }, @{ Index = 13; Size = 32; NameAt = 4 })) {
    $rva = [BitConverter]::ToUInt32($b, $dirs + 8 * $d.Index)
    if ($rva -eq 0) { continue }
    $o = RvaToOffset $rva
    while ($o -ne $null) {
      $nameRva = [BitConverter]::ToUInt32($b, $o + $d.NameAt)
      if ($nameRva -eq 0) { break }
      $names += ReadName $nameRva
      $o += $d.Size
    }
  }
  return $names
}

$windir = $env:SystemRoot.ToLower()
$pathDirs = $env:Path -split ';' | Where-Object { $_ -and (Test-Path $_) }
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue($exe)
$seen = @{}
while ($queue.Count -gt 0) {
  foreach ($dll in Get-PEImports $queue.Dequeue()) {
    $key = $dll.ToLower()
    if ($seen.ContainsKey($key) -or $key.StartsWith('api-ms-') -or $key.StartsWith('ext-ms-')) { continue }
    $seen[$key] = $true
    $found = $pathDirs | ForEach-Object { Join-Path $_ $dll } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) { continue }
    # Windows' own DLLs stay where they are, except the Visual C++ runtime, which is bundled.
    $isVCRuntime = $key -match '^(vcruntime|msvcp|concrt)\d'
    if ($found.ToLower().StartsWith($windir) -and -not $isVCRuntime) { continue }
    Copy-Item $found $dist
    Write-Host "  bundled $dll"
    $queue.Enqueue((Join-Path $dist $dll))
  }
}

$zip = Join-Path $PSScriptRoot "dist\MHGU-Charms-RNG-$Version-Windows.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $dist -DestinationPath $zip
Write-Host "Built: $exe"
Write-Host "Zipped: $zip"

# --- Smoke test ---------------------------------------------------------------------------------
if ($SmokeTest) {
  $out = Join-Path $Work 'smoke'
  if (Test-Path $out) { Remove-Item -Recurse -Force $out }
  New-Item -ItemType Directory -Force $out | Out-Null
  $savedPath = $env:Path
  $env:Path = "$env:SystemRoot\System32;$env:SystemRoot"   # only what every Windows PC has
  try {
    $p = Start-Process -FilePath $exe -ArgumentList '--smoke-test', "`"$out`"" -PassThru `
      -RedirectStandardError "$Work\smoke-stderr.txt" -RedirectStandardOutput "$Work\smoke-stdout.txt"
    $null = $p.Handle   # keeps the exit code available after the process ends
    if (-not $p.WaitForExit(600000)) { $p.Kill(); throw 'Smoke test timed out (a missing DLL shows a dialog and waits).' }
    if ($p.ExitCode -ne 0) { throw ('Smoke test exited with code 0x{0:X8}' -f $p.ExitCode) }
  } catch {
    foreach ($f in "$out\trace.txt", "$Work\smoke-stderr.txt", "$Work\smoke-stdout.txt") {
      if (Test-Path $f) { Write-Host "--- $f"; Get-Content $f -Encoding UTF8 | Select-Object -Last 60 | Write-Host }
    }
    throw
  } finally {
    $env:Path = $savedPath
  }
  $log = Join-Path $out 'smoke.txt'
  if (-not (Test-Path $log)) { throw 'Smoke test wrote no output' }
  Get-Content $log -Encoding UTF8 | Select-Object -First 400 | Write-Host
  $text = Get-Content $log -Raw -Encoding UTF8
  # One section per tool (9) plus the timer panel.
  $sections = ([regex]::Matches($text, '(?m)^== ')).Count
  if ($sections -ne 10) { throw "Smoke test: expected 10 sections of output, got $sections" }
  if ($text -match '-- Error') { throw 'Smoke test: a tool reported an error' }
  Write-Host "Smoke test passed. Output and screenshots: $out"
}
