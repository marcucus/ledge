import Foundation

extension UserDefaults {
    func shortcut(forKey key: String) -> GlobalKeyboardShortcut? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlobalKeyboardShortcut.self, from: data)
    }

    func setShortcut(_ shortcut: GlobalKeyboardShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        set(data, forKey: key)
    }

    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key)
    }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
