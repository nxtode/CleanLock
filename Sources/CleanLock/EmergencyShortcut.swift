import AppKit
import Foundation

struct EmergencyShortcut: Equatable {
    let keyCodes: Set<Int64>

    var displayName: String {
        displaySymbols.joined(separator: " ")
    }

    var displaySymbols: [String] {
        sortedDisplayKeyCodes
            .map(shortcutDisplaySymbol)
    }

    static let defaultShortcut = EmergencyShortcut(keyCodes: [55, 54])

    static func load() -> EmergencyShortcut {
        let savedCodes = UserDefaults.standard.array(forKey: PreferencesKeys.emergencyShortcutKeyCodes) as? [Int]
        let codes = Set((savedCodes ?? []).map(Int64.init))
        return codes.isEmpty ? .defaultShortcut : EmergencyShortcut(keyCodes: codes)
    }

    func save() {
        UserDefaults.standard.set(keyCodes.sorted().map(Int.init), forKey: PreferencesKeys.emergencyShortcutKeyCodes)
    }

    static func resetToDefault() {
        defaultShortcut.save()
    }

    var isReserved: Bool {
        if keyCodes.count < 2 {
            return true
        }

        if keyCodes == [53] {
            return true
        }

        guard containsCommand else { return false }

        let reservedWithCommand: Set<Int64> = [12, 13, 4, 46, 48, 49]
        return !keyCodes.intersection(reservedWithCommand).isEmpty
    }

    private var containsCommand: Bool {
        keyCodes.contains(54) || keyCodes.contains(55)
    }

    private var sortedDisplayKeyCodes: [Int64] {
        keyCodes.sorted { first, second in
            let firstPriority = displayPriority(first)
            let secondPriority = displayPriority(second)
            if firstPriority == secondPriority {
                return first < second
            }
            return firstPriority < secondPriority
        }
    }
}

func shortcutDisplaySymbol(_ keyCode: Int64) -> String {
    switch keyCode {
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 25: return "9"
    case 26: return "7"
    case 28: return "8"
    case 29: return "0"
    case 31: return "O"
    case 32: return "U"
    case 34: return "I"
    case 35: return "P"
    case 36: return "↩"
    case 37: return "L"
    case 38: return "J"
    case 40: return "K"
    case 45: return "N"
    case 46: return "M"
    case 48: return "Tab"
    case 49: return "Space"
    case 51: return "⌫"
    case 53: return "⎋"
    case 54, 55: return "⌘"
    case 56, 60: return "⇧"
    case 57: return "⇪"
    case 58, 61: return "⌥"
    case 59, 62: return "⌃"
    case 63: return "fn"
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    case 122: return "F1"
    case 120: return "F2"
    case 99: return "F3"
    case 118: return "F4"
    case 96: return "F5"
    case 97: return "F6"
    case 98: return "F7"
    case 100: return "F8"
    case 101: return "F9"
    case 109: return "F10"
    case 103: return "F11"
    case 111: return "F12"
    default:
        return "Key \(keyCode)"
    }
}

private func displayPriority(_ keyCode: Int64) -> Int {
    switch keyCode {
    case 54, 55: return 0
    case 56, 60: return 1
    case 58, 61: return 2
    case 59, 62: return 3
    case 57: return 4
    case 63: return 5
    default: return 10
    }
}
