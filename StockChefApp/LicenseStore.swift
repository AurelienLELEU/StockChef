import Foundation
import Security

/// A Keychain record survives ordinary app reinstalls, preventing a reset of free scan credits.
final class LicenseStore {
    private let service = "fr.stockchef.license"
    private let account = "local-license"

    func load() -> AppLicense {
        guard let data = read(), let license = try? JSONDecoder().decode(AppLicense.self, from: data) else {
            let fresh = AppLicense()
            save(fresh)
            return fresh
        }
        return license
    }

    func save(_ license: AppLicense) {
        let data = try? JSONEncoder().encode(license)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let data else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }
}
