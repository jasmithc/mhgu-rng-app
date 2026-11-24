// Small helpers over the Win32 API. Constants are declared here with explicit types rather than
// taken from the WinSDK module, where macros import with mixed Int32/UInt32 types.
import WinSDK

// MARK: - Messages and styles

enum WM {
  static let create: UINT = 0x0001, destroy: UINT = 0x0002, size: UINT = 0x0005
  static let setFocus: UINT = 0x0007, close: UINT = 0x0010, setText: UINT = 0x000C
  static let getMinMaxInfo: UINT = 0x0024, setFont: UINT = 0x0030
  static let keyDown: UINT = 0x0100, command: UINT = 0x0111, timer: UINT = 0x0113
  static let vScroll: UINT = 0x0115, ctlColorEdit: UINT = 0x0133, ctlColorStatic: UINT = 0x0138
  static let mouseWheel: UINT = 0x020A, copy: UINT = 0x0301
  static let user: UINT = 0x0400, app: UINT = 0x8000
}

enum WS {
  static let overlapped: DWORD = 0, popup: DWORD = 0x8000_0000, child: DWORD = 0x4000_0000
  static let visible: DWORD = 0x1000_0000, disabled: DWORD = 0x0800_0000
  static let clipSiblings: DWORD = 0x0400_0000, clipChildren: DWORD = 0x0200_0000
  static let caption: DWORD = 0x00C0_0000, border: DWORD = 0x0080_0000
  static let vScroll: DWORD = 0x0020_0000, sysMenu: DWORD = 0x0008_0000
  static let thickFrame: DWORD = 0x0004_0000, group: DWORD = 0x0002_0000, tabStop: DWORD = 0x0001_0000
  static let minimizeBox: DWORD = 0x0002_0000, maximizeBox: DWORD = 0x0001_0000
  static let overlappedWindow: DWORD = caption | sysMenu | thickFrame | minimizeBox | maximizeBox
  // Extended styles
  static let exDlgModalFrame: DWORD = 0x0000_0001, exClientEdge: DWORD = 0x0000_0200
  static let exControlParent: DWORD = 0x0001_0000
}

enum BS {
  static let pushButton: DWORD = 0, defPushButton: DWORD = 1, autoCheckBox: DWORD = 3
  static let getCheck: UINT = 0x00F0, setCheck: UINT = 0x00F1
  static let clicked: Int = 0
}

enum ES {
  static let left: DWORD = 0, right: DWORD = 2, multiline: DWORD = 4, autoVScroll: DWORD = 0x40
  static let autoHScroll: DWORD = 0x80, readOnly: DWORD = 0x800, wantReturn: DWORD = 0x1000
  static let setSel: UINT = 0x00B1, setMargins: UINT = 0x00D3
  static let enChange: Int = 0x0300, enKillFocus: Int = 0x0200
}

enum SS {
  static let left: DWORD = 0, center: DWORD = 1, right: DWORD = 2, noPrefix: DWORD = 0x80
  static let etchedHorz: DWORD = 0x10, centerImage: DWORD = 0x200, endEllipsis: DWORD = 0x4000
}

enum CB {
  static let dropDownList: DWORD = 3
  static let addString: UINT = 0x0143, getCurSel: UINT = 0x0147, resetContent: UINT = 0x014B
  static let setCurSel: UINT = 0x014E, getItemData: UINT = 0x0150, setItemData: UINT = 0x0151
  static let getCount: UINT = 0x0146, getDroppedState: UINT = 0x0157
  static let selChange: Int = 1
}

enum LB {
  static let notify: DWORD = 0x0001, noIntegralHeight: DWORD = 0x0100
  static let addString: UINT = 0x0180, setCurSel: UINT = 0x0186, getCurSel: UINT = 0x0188
  static let setItemHeight: UINT = 0x01A0
  static let selChange: Int = 1
}

enum RE {
  static let exLimitText: UINT = WM.user + 53, setBkgndColor: UINT = WM.user + 67
  static let setTargetDevice: UINT = WM.user + 72, setTextEx: UINT = WM.user + 97
}

enum MF {
  static let string: UINT = 0, grayed: UINT = 1, disabled: UINT = 2, checked: UINT = 8
  static let popup: UINT = 0x10, separator: UINT = 0x800, unchecked: UINT = 0
}

enum VK {
  static let back: UInt16 = 0x08, `return`: UInt16 = 0x0D, escape: UInt16 = 0x1B
}

let SW_HIDE: Int32 = 0, SW_SHOW: Int32 = 5, SW_SHOWNORMAL: Int32 = 1, SW_SHOWMAXIMIZED: Int32 = 3
let IDOK = 1, IDCANCEL = 2
let COLOR_BTNFACE: Int32 = 15, COLOR_WINDOW: Int32 = 5, COLOR_WINDOWTEXT: Int32 = 8, COLOR_GRAYTEXT: Int32 = 17

// MARK: - Conversions

func rgb(_ r: Int, _ g: Int, _ b: Int) -> COLORREF { COLORREF(r) | (COLORREF(g) << 8) | (COLORREF(b) << 16) }

func lo(_ v: WPARAM) -> Int { Int(v & 0xFFFF) }
func hi(_ v: WPARAM) -> Int { Int((v >> 16) & 0xFFFF) }
func lparam<P>(_ p: UnsafePointer<P>?) -> LPARAM { LPARAM(Int(bitPattern: p)) }
func lparam<P>(_ p: UnsafeMutablePointer<P>?) -> LPARAM { LPARAM(Int(bitPattern: p)) }
func wparam<P>(_ p: UnsafeMutablePointer<P>?) -> WPARAM { WPARAM(UInt(bitPattern: p)) }
func handleToLRESULT<P>(_ p: UnsafeMutablePointer<P>?) -> LRESULT { LRESULT(Int(bitPattern: p)) }
func idMenu(_ id: Int) -> HMENU? { HMENU(bitPattern: UInt(id)) }

/// MAKEINTRESOURCEW
func intResource(_ id: Int) -> UnsafePointer<WCHAR>? { UnsafePointer<WCHAR>(bitPattern: UInt(id)) }

/// Win32 BOOL results import as Bool (or WindowsBool in some contexts); these normalize them.
@inline(__always) func ok(_ b: Bool) -> Bool { b }
@inline(__always) func ok(_ b: WindowsBool) -> Bool { b.boolValue }
@inline(__always) func ok(_ b: Int32) -> Bool { b != 0 }

func withWide<R>(_ s: String, _ body: (UnsafePointer<WCHAR>) -> R) -> R {
  s.withCString(encodedAs: UTF16.self) { body($0) }
}

// MARK: - Windows and controls

@discardableResult
func send(_ h: HWND?, _ msg: UINT, _ wp: WPARAM = 0, _ lp: LPARAM = 0) -> LRESULT {
  SendMessageW(h, msg, wp, lp)
}

func createWindow(_ cls: String, _ text: String = "", style: DWORD, ex: DWORD = 0, parent: HWND?,
                  id: Int = 0, x: Int32 = 0, y: Int32 = 0, w: Int32 = 10, h: Int32 = 10) -> HWND {
  let hwnd = withWide(cls) { c in
    withWide(text) { t in
      CreateWindowExW(ex, c, t, style, x, y, w, h, parent,
                      parent == nil ? nil : idMenu(id), GetModuleHandleW(nil), nil)
    }
  }
  guard let hwnd else { fatalError("CreateWindowExW failed for \(cls) (error \(GetLastError()))") }
  return hwnd
}

func setText(_ h: HWND, _ s: String) {
  _ = withWide(s) { SetWindowTextW(h, $0) }
}

func getText(_ h: HWND) -> String {
  let n = GetWindowTextLengthW(h)
  var buf = [WCHAR](repeating: 0, count: Int(n) + 1)
  let got = GetWindowTextW(h, &buf, n + 1)
  return String(decoding: buf[0..<Int(max(got, 0))], as: UTF16.self)
}

func setFont(_ h: HWND, _ f: HFONT?) {
  send(h, WM.setFont, WPARAM(UInt(bitPattern: f)), 1)
}

func show(_ h: HWND, _ visible: Bool) {
  _ = ShowWindow(h, visible ? SW_SHOW : SW_HIDE)
}

func enable(_ h: HWND, _ on: Bool) {
  _ = EnableWindow(h, on ? true : false)
}

func isChecked(_ h: HWND) -> Bool { send(h, BS.getCheck) == 1 }
func setChecked(_ h: HWND, _ on: Bool) { send(h, BS.setCheck, on ? 1 : 0) }

func comboAdd(_ h: HWND, _ s: String, data: Int = 0) {
  let i = withWide(s) { send(h, CB.addString, 0, lparam($0)) }
  if i >= 0 { send(h, CB.setItemData, WPARAM(i), LPARAM(data)) }
}
func comboSelected(_ h: HWND) -> Int { Int(send(h, CB.getCurSel)) }
func comboSelect(_ h: HWND, _ i: Int) { send(h, CB.setCurSel, WPARAM(truncatingIfNeeded: i)) }
func comboData(_ h: HWND) -> Int? {
  let i = comboSelected(h)
  return i < 0 ? nil : Int(send(h, CB.getItemData, WPARAM(i)))
}
/// Select the item whose data is `data`; returns false if there is none.
@discardableResult
func comboSelectData(_ h: HWND, _ data: Int) -> Bool {
  let n = Int(send(h, CB.getCount))
  for i in 0..<n where Int(send(h, CB.getItemData, WPARAM(i))) == data {
    comboSelect(h, i); return true
  }
  return false
}

func moveWindow(_ h: HWND, _ x: Int, _ y: Int, _ w: Int, _ hgt: Int) {
  _ = MoveWindow(h, Int32(x), Int32(y), Int32(max(w, 0)), Int32(max(hgt, 0)), true)
}

func clientSize(_ h: HWND) -> (w: Int, h: Int) {
  var r = RECT()
  _ = GetClientRect(h, &r)
  return (Int(r.right - r.left), Int(r.bottom - r.top))
}

/// Height in pixels that `text` needs when wrapped to `width` in font `font`.
func textHeight(_ text: String, font: HFONT?, width: Int, reference h: HWND) -> Int {
  guard let dc = GetDC(h) else { return 16 }
  defer { _ = ReleaseDC(h, dc) }
  let old = SelectObject(dc, UnsafeMutableRawPointer(font))
  defer { _ = SelectObject(dc, old) }
  var r = RECT(left: 0, top: 0, right: LONG(max(width, 1)), bottom: 0)
  let s = text.isEmpty ? " " : text
  let DT_WORDBREAK: UINT = 0x10, DT_CALCRECT: UINT = 0x400, DT_NOPREFIX: UINT = 0x800
  _ = withWide(s) { DrawTextW(dc, $0, -1, &r, DT_WORDBREAK | DT_CALCRECT | DT_NOPREFIX) }
  return Int(r.bottom - r.top)
}

// MARK: - Fonts and DPI

enum UI {
  /// Pixels per 96-DPI unit. The process is system-DPI aware (see main.swift).
  static var scale: Double = 1
  static func px(_ v: Int) -> Int { Int((Double(v) * scale).rounded()) }

  static var font: HFONT?, bold: HFONT?, title: HFONT?, small: HFONT?, readout: HFONT?
  static var mono: HFONT?

  static func makeFont(_ face: String, points: Double, weight: Int32 = 400) -> HFONT? {
    let height = -Int32((points * 96 * scale / 72).rounded())
    return withWide(face) {
      CreateFontW(height, 0, 0, 0, weight, 0, 0, 0, 1 /* DEFAULT_CHARSET */, 0, 0,
                  5 /* CLEARTYPE_QUALITY */, 0, $0)
    }
  }

  static func setup(dpi: UINT) {
    scale = Double(dpi) / 96
    font = makeFont("Segoe UI", points: 9)
    small = makeFont("Segoe UI", points: 8)
    bold = makeFont("Segoe UI", points: 9, weight: 600)
    title = makeFont("Segoe UI", points: 14, weight: 600)
    readout = makeFont("Consolas", points: 22)
    mono = makeFont("Consolas", points: 10)
  }
}

// MARK: - Settings (HKEY_CURRENT_USER\Software\MHGU Charms RNG)

enum Prefs {
  static let subkey = "Software\\MHGU Charms RNG"
  static var hkcu: HKEY? { HKEY(bitPattern: Int(Int32(bitPattern: 0x8000_0001))) }

  static func string(_ name: String) -> String? {
    withWide(subkey) { key in
      withWide(name) { value -> String? in
        let RRF_RT_REG_SZ: DWORD = 0x2
        var size: DWORD = 0
        guard RegGetValueW(hkcu, key, value, RRF_RT_REG_SZ, nil, nil, &size) == 0, size > 0 else { return nil }
        var buf = [WCHAR](repeating: 0, count: Int(size) / 2 + 1)
        guard RegGetValueW(hkcu, key, value, RRF_RT_REG_SZ, nil, &buf, &size) == 0 else { return nil }
        let n = buf.firstIndex(of: 0) ?? buf.count
        return String(decoding: buf[0..<n], as: UTF16.self)
      }
    }
  }

  static func set(_ name: String, _ s: String) {
    let data = Array(s.utf16) + [0]
    _ = withWide(subkey) { key in
      withWide(name) { value in
        data.withUnsafeBytes { bytes in
          RegSetKeyValueW(hkcu, key, value, 1 /* REG_SZ */, bytes.baseAddress, DWORD(bytes.count))
        }
      }
    }
  }

  static func int(_ name: String) -> Int? { string(name).flatMap { Int($0) } }
  static func double(_ name: String) -> Double? { string(name).flatMap { Double($0) } }
  static func bool(_ name: String) -> Bool? { string(name).map { $0 == "1" } }
  static func set(_ name: String, _ v: Int) { set(name, String(v)) }
  static func set(_ name: String, _ v: Double) { set(name, String(v)) }
  static func set(_ name: String, _ v: Bool) { set(name, v ? "1" : "0") }
}

// MARK: - Time

private let qpcFrequency: Double = {
  var f = LARGE_INTEGER()
  _ = QueryPerformanceFrequency(&f)
  return Double(f.QuadPart)
}()

/// Seconds on a monotonic high-resolution clock.
func now() -> Double {
  var c = LARGE_INTEGER()
  _ = QueryPerformanceCounter(&c)
  return Double(c.QuadPart) / qpcFrequency
}

// MARK: - Formatting (RNGCore and this app avoid Foundation)

/// `value` with exactly `digits` decimals, like String(format: "%.Nf").
func fixed(_ value: Double, _ digits: Int) -> String {
  guard value.isFinite else { return "—" }
  var m = 1.0
  for _ in 0..<digits { m *= 10 }
  let scaled = (abs(value) * m).rounded()
  let whole = Int(scaled / m)
  var frac = Int(scaled - Double(whole) * m)
  if frac < 0 { frac = 0 }
  var s = String(whole)
  if digits > 0 {
    var f = String(frac)
    while f.count < digits { f = "0" + f }
    s += "." + f
  }
  return (value < 0 && scaled != 0 ? "-" : "") + s
}

/// Parse a whole number typed by the user (spaces, commas and underscores allowed).
func parseInt(_ s: String) -> Int? {
  Int(String(s.filter { !$0.isWhitespace && $0 != "," && $0 != "_" }))
}

/// Parse a decimal typed by the user (accepts "," as the decimal separator, and "−").
func parseDouble(_ s: String) -> Double? {
  var t = String(s.filter { !$0.isWhitespace })
  t = String(t.map { $0 == "," ? "." : ($0 == "−" ? "-" : $0) })
  if t.isEmpty { return 0 }
  return Double(t)
}

/// Directory holding the running .exe, with a trailing backslash.
func exeDirectory() -> String {
  var buf = [WCHAR](repeating: 0, count: 32768)
  let n = Int(GetModuleFileNameW(nil, &buf, DWORD(buf.count)))
  let path = String(decoding: buf[0..<n], as: UTF16.self)
  guard let i = path.lastIndex(of: "\\") else { return "" }
  return String(path[...i])
}

/// Write bytes to a file (used by the smoke test and the manifest).
@discardableResult
func writeFile(_ path: String, _ bytes: [UInt8]) -> Bool {
  let GENERIC_WRITE: DWORD = 0x4000_0000, CREATE_ALWAYS: DWORD = 2, FILE_ATTRIBUTE_NORMAL: DWORD = 0x80
  let h = withWide(path) { CreateFileW($0, GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nil) }
  guard let h, h != HANDLE(bitPattern: -1) else { return false }
  defer { _ = CloseHandle(h) }
  var written: DWORD = 0
  let okWrite = bytes.withUnsafeBytes { WriteFile(h, $0.baseAddress, DWORD($0.count), &written, nil) }
  return ok(okWrite) && Int(written) == bytes.count
}

/// The %TEMP% directory, with a trailing backslash.
func tempDirectory() -> String {
  var buf = [WCHAR](repeating: 0, count: 1024)
  let n = Int(GetTempPathW(DWORD(buf.count), &buf))
  return String(decoding: buf[0..<n], as: UTF16.self)
}
