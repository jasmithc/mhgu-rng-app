// MHGU Charms RNG for Windows: a native Win32 front end for RNGCore.
//
//   "MHGU Charms RNG.exe"                    run the app
//   "MHGU Charms RNG.exe" --smoke-test DIR   run every tool once, save output and screenshots to DIR, quit
import RNGCore
import WinSDK

let mainClassName = "MHGUCharmsRNG.Main"
let panelClassName = "MHGUCharmsRNG.TimerPanel"
let settingsClassName = "MHGUCharmsRNG.Settings"

/// All windows share one window procedure, which hands messages to the app.
let windowProc: WNDPROC = { hwnd, msg, wp, lp in
  guard let hwnd else { return 0 }
  if let app = theApp { return app.handle(hwnd, msg, wp, lp) }
  return DefWindowProcW(hwnd, msg, wp, lp)
}

var theApp: App?

/// Load a function from a system DLL by name (for APIs newer than the WinSDK headers Swift sees).
func systemFunction(_ dll: String, _ name: String) -> FARPROC? {
  guard let module = withWide(dll, { LoadLibraryW($0) }) else { return nil }
  return GetProcAddress(module, name)
}

/// Use version 6 of the common controls (themed buttons, combo boxes and so on) by activating a
/// manifest, written to %TEMP%, that asks for them. This keeps the .exe free of build-time
/// resource steps.
func activateVisualStyles() {
  let manifest = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
      <dependency><dependentAssembly>
        <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0"
          processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>
      </dependentAssembly></dependency>
    </assembly>
    """
  let path = tempDirectory() + "MHGUCharmsRNG.manifest"
  guard writeFile(path, Array(manifest.utf8)) else { return }
  withWide(path) { source in
    var ctx = ACTCTXW()
    ctx.cbSize = ULONG(MemoryLayout<ACTCTXW>.size)
    ctx.lpSource = source
    let handle = CreateActCtxW(&ctx)
    guard let handle, handle != HANDLE(bitPattern: -1) else { return }
    var cookie: ULONG_PTR = 0
    _ = ActivateActCtx(handle, &cookie)
  }
}

func registerClass(_ name: String, icon: HICON?, smallIcon: HICON?) {
  withWide(name) { cls in
    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.lpfnWndProc = windowProc
    wc.hInstance = GetModuleHandleW(nil)
    wc.hCursor = LoadCursorW(nil, intResource(32512))   // IDC_ARROW
    wc.hbrBackground = HBRUSH(bitPattern: Int(COLOR_BTNFACE + 1))
    wc.hIcon = icon
    wc.hIconSm = smallIcon
    wc.lpszClassName = cls
    _ = RegisterClassExW(&wc)
  }
}

/// The app icon: from the .exe's resources if it has one, else AppIcon.ico next to the .exe.
func loadIcon(size: Int) -> HICON? {
  let IMAGE_ICON: UINT = 1, LR_LOADFROMFILE: UINT = 0x10
  if let h = LoadImageW(GetModuleHandleW(nil), intResource(1), IMAGE_ICON, Int32(size), Int32(size), 0) {
    return HICON(bitPattern: Int(bitPattern: h))
  }
  let h = withWide(exeDirectory() + "AppIcon.ico") { LoadImageW(nil, $0, IMAGE_ICON, Int32(size), Int32(size), LR_LOADFROMFILE) }
  return HICON(bitPattern: Int(bitPattern: h))
}

// MARK: - Start-up

// Sharp text on high-DPI displays: system DPI aware (falls back to the Vista API).
typealias SetDpiContextFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
if let f = systemFunction("user32.dll", "SetProcessDpiAwarenessContext") {
  _ = unsafeBitCast(f, to: SetDpiContextFn.self)(UnsafeMutableRawPointer(bitPattern: -2))   // SYSTEM_AWARE
} else {
  _ = SetProcessDPIAware()
}

activateVisualStyles()
if let f = systemFunction("comctl32.dll", "InitCommonControlsEx") {
  typealias InitFn = @convention(c) (UnsafeRawPointer?) -> Int32
  let icc: [UInt32] = [8, 0x4000 | 0xFF]   // dwSize, ICC_STANDARD_CLASSES | the classic set
  _ = icc.withUnsafeBytes { unsafeBitCast(f, to: InitFn.self)($0.baseAddress) }
}
_ = withWide("Msftedit.dll") { LoadLibraryW($0) }   // RICHEDIT50W, used for the output

let screen = GetDC(nil)
let dpi = GetDeviceCaps(screen, 90 /* LOGPIXELSY */)
_ = ReleaseDC(nil, screen)
UI.setup(dpi: UINT(max(dpi, 96)))

let bigIcon = loadIcon(size: Int(GetSystemMetrics(11 /* SM_CXICON */)))
let smallIcon = loadIcon(size: Int(GetSystemMetrics(49 /* SM_CXSMICON */)))
registerClass(mainClassName, icon: bigIcon, smallIcon: smallIcon)
registerClass(panelClassName, icon: nil, smallIcon: nil)
registerClass(settingsClassName, icon: nil, smallIcon: nil)

var smokeDir: String?
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--smoke-test"), i + 1 < args.count { smokeDir = args[i + 1] }

_ = BeepScheduler.shared   // open the audio output and start the scheduler thread now
let app = App()
theApp = app
app.start(smokeDir: smokeDir)

// MARK: - Message loop

var msg = MSG()
while ok(GetMessageW(&msg, nil, 0, 0)) {
  if let s = app.settings {
    if ok(IsDialogMessageW(s.hwnd, &msg)) { continue }
  } else if ok(TranslateAcceleratorW(app.main, app.accelerators, &msg)) {
    continue
  } else if ok(IsDialogMessageW(app.main, &msg)) {
    continue
  }
  _ = TranslateMessage(&msg)
  _ = DispatchMessageW(&msg)
}
