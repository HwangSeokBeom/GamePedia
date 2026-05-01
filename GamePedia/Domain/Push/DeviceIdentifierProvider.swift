import Foundation
import Security

protocol DeviceIdentifierProvider {
    func stableDeviceIdentifier() -> String
}

final class KeychainDeviceIdentifierProvider: DeviceIdentifierProvider {
    private enum KeychainAccount {
        static let deviceIdentifier = "pushDeviceIdentifier"
    }

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "GamePedia") {
        self.service = "\(service).device"
    }

    func stableDeviceIdentifier() -> String {
        if let existingIdentifier = fetchKeychainValue(forAccount: KeychainAccount.deviceIdentifier),
           existingIdentifier.isEmpty == false {
            return existingIdentifier
        }

        let identifier = UUID().uuidString.lowercased()
        setKeychainValue(identifier, forAccount: KeychainAccount.deviceIdentifier)
        return identifier
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
}
