import Foundation
import Security

final class KeychainTokenStore: TokenStore {

    private enum KeychainAccount {
        static let refreshToken = "refreshToken"
    }

    private let service: String
    private var cachedAccessToken: String?

    init(service: String = Bundle.main.bundleIdentifier ?? "GamePedia") {
        self.service = "\(service).auth"
    }

    func saveAccessToken(_ token: String) {
        cachedAccessToken = token
    }

    func saveRefreshToken(_ token: String) {
        setKeychainValue(token, forAccount: KeychainAccount.refreshToken)
    }

    func fetchAccessToken() -> String? {
        cachedAccessToken
    }

    func fetchRefreshToken() -> String? {
        fetchKeychainValue(forAccount: KeychainAccount.refreshToken)
    }

    func clear() {
        cachedAccessToken = nil
        deleteKeychainValue(forAccount: KeychainAccount.refreshToken)
    }

    private func setKeychainValue(_ value: String, forAccount account: String) {
        guard let encodedValue = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encodedValue
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = encodedValue
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func fetchKeychainValue(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychainValue(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
