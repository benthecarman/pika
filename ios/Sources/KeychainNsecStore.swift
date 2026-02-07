import Foundation
import Security

final class KeychainNsecStore {
    private let service = "com.pika.app"
    private let account = "nsec"

    func getNsec() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setNsec(_ nsec: String) {
        let data = Data(nsec.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let addQuery = baseQuery.merging([kSecValueData as String: data]) { $1 }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            return
        }
        if status == errSecDuplicateItem {
            let attrs: [String: Any] = [kSecValueData as String: data]
            _ = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        }
    }

    func clearNsec() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}

