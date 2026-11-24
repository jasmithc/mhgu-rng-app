// File › Settings…: the same options as the macOS app's Settings window.
import WinSDK

final class SettingsWindow {
  let hwnd: HWND
  unowned let app: App
  private let showRare: HWND, showAllRank: HWND, count: HWND

  init(app: App) {
    self.app = app
    let w = UI.px(440), h = UI.px(220)
    // Centre over the main window.
    var r = RECT()
    _ = GetWindowRect(app.main, &r)
    let left = Int(r.left) + (Int(r.right - r.left) - w) / 2, top = Int(r.top) + (Int(r.bottom - r.top) - h) / 2
    hwnd = createWindow(settingsClassName, "Settings", style: WS.popup | WS.caption | WS.sysMenu,
                        ex: WS.exDlgModalFrame | WS.exControlParent, parent: app.main,
                        x: Int32(left), y: Int32(top), w: Int32(w), h: Int32(h))
    let (cw, ch) = clientSize(hwnd)
    let pad = UI.px(16)
    func make(_ cls: String, _ text: String, _ style: DWORD, id: Int = 0, ex: DWORD = 0) -> HWND {
      let c = createWindow(cls, text, style: WS.child | WS.visible | style, ex: ex, parent: hwnd, id: id)
      setFont(c, UI.font)
      return c
    }
    showRare = make("BUTTON", "Show rarity after each charm", WS.tabStop | BS.autoCheckBox)
    showAllRank = make("BUTTON", "Show Halcyon/Juju aim points for every rank", WS.tabStop | BS.autoCheckBox)
    let countLabel = make("STATIC", "Quest charm count (aim points)", SS.noPrefix)
    count = make("EDIT", String(app.numOfCharms), WS.tabStop | ES.right | ES.autoHScroll, ex: WS.exClientEdge)
    let okButton = make("BUTTON", "OK", WS.tabStop | BS.defPushButton, id: IDOK)
    let cancel = make("BUTTON", "Cancel", WS.tabStop, id: IDCANCEL)
    setChecked(showRare, app.showRare)
    setChecked(showAllRank, app.showAllRank)

    var y = pad
    moveWindow(showRare, pad, y, cw - 2 * pad, UI.px(22)); y += UI.px(28)
    moveWindow(showAllRank, pad, y, cw - 2 * pad, UI.px(22)); y += UI.px(34)
    moveWindow(countLabel, pad, y + UI.px(4), UI.px(220), UI.px(18))
    moveWindow(count, pad + UI.px(224), y, UI.px(80), UI.px(23))
    let bw = UI.px(84), bh = UI.px(27)
    moveWindow(okButton, cw - pad - 2 * bw - UI.px(8), ch - pad - bh, bw, bh)
    moveWindow(cancel, cw - pad - bw, ch - pad - bh, bw, bh)

    enable(app.main, false)
    _ = ShowWindow(hwnd, SW_SHOW)
    _ = SetFocus(showRare)
  }

  func command(_ id: Int, _ code: Int) {
    switch id {
    case IDOK:
      guard let n = parseInt(getText(count)), n > 0 else {
        _ = MessageBeep(0xFFFF_FFFF)
        _ = SetFocus(count)
        return
      }
      app.showRare = isChecked(showRare)
      app.showAllRank = isChecked(showAllRank)
      app.numOfCharms = n
      close()
    case IDCANCEL:
      close()
    default:
      break
    }
  }

  func close() {
    // Re-enable the main window first so it, not another app, gets activated.
    enable(app.main, true)
    _ = DestroyWindow(hwnd)
    app.settings = nil
    _ = SetForegroundWindow(app.main)
  }
}
