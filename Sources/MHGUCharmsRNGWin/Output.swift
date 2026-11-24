// Turns the engine's Output into RTF for the rich edit control: rarity colours in bold, and
// wrapped continuation lines indented a little so each line's start stays clear.
import RNGCore

enum RTFRenderer {
  /// Monospaced font per skill-name language: CJK names need a font whose full-width
  /// characters are exactly two columns wide so the table columns line up.
  static func font(for language: Language) -> (face: String, charset: Int) {
    switch language {
    case .en: return ("Consolas", 0)
    case .ja: return ("MS Gothic", 128)
    case .zh: return ("NSimSun", 134)
    }
  }

  // Colour table: 1 = marker green, 2…11 = rarity 1…10.
  static let rareColors: [(Int, Int, Int)] = [
    (128, 128, 128), (96, 96, 230), (160, 150, 0), (170, 100, 170), (80, 160, 80),
    (64, 64, 192), (192, 64, 64), (60, 150, 160), (220, 130, 40), (170, 50, 170)]

  static func colorIndex(_ tint: Tint) -> Int {
    switch tint {
    case .marker: return 1
    case .rare(let r): return (1...10).contains(r) ? r + 1 : 2
    }
  }

  static func render(_ out: Output, language: Language) -> [UInt8] {
    let f = font(for: language)
    var s = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\fmodern\\fcharset\(f.charset) \(f.face);}}"
    s += "{\\colortbl ;\\red30\\green150\\blue60;"
    for c in rareColors { s += "\\red\(c.0)\\green\(c.1)\\blue\(c.2);" }
    s += "}\\uc1\\pard\\li440\\fi-440\\f0\\fs20 "
    var bytes = Array(s.utf8)
    bytes.reserveCapacity(bytes.count + out.lines.count * 64)
    for (i, line) in out.lines.enumerated() {
      if i > 0 { bytes.append(contentsOf: Array("\\par\n".utf8)) }
      for seg in line {
        if let t = seg.tint {
          bytes.append(contentsOf: Array("{\\b\\cf\(colorIndex(t)) ".utf8))
          escape(seg.text, into: &bytes)
          bytes.append(UInt8(ascii: "}"))
        } else {
          escape(seg.text, into: &bytes)
        }
      }
    }
    bytes.append(UInt8(ascii: "}"))
    return bytes
  }

  static func escape(_ text: String, into bytes: inout [UInt8]) {
    for unit in text.utf16 {
      switch unit {
      case 0x5C: bytes.append(contentsOf: [0x5C, 0x5C])                      // \
      case 0x7B: bytes.append(contentsOf: [0x5C, 0x7B])                      // {
      case 0x7D: bytes.append(contentsOf: [0x5C, 0x7D])                      // }
      case 0x09: bytes.append(contentsOf: Array("\\tab ".utf8))
      case 0x20..<0x80: bytes.append(UInt8(unit))
      default: bytes.append(contentsOf: Array("\\u\(Int16(bitPattern: unit))?".utf8))
      }
    }
  }
}
