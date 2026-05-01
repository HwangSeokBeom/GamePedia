import Foundation

protocol PushTokenRegistrationStore {
    var lastRegisteredFingerprint: String? { get set }
    var lastRegisteredAt: Date? { get set }
}

final class UserDefaultsPushTokenRegistrationStore: PushTokenRegistrationStore {
    private enum Key {
        static let lastRegisteredFingerprint = "push.lastRegisteredFingerprint"
        static let lastRegisteredAt = "push.lastRegisteredAt"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastRegisteredFingerprint: String? {
        get { userDefaults.string(forKey: Key.lastRegisteredFingerprint) }
        set { userDefaults.set(newValue, forKey: Key.lastRegisteredFingerprint) }
    }

    var lastRegisteredAt: Date? {
        get { userDefaults.object(forKey: Key.lastRegisteredAt) as? Date }
        set { userDefaults.set(newValue, forKey: Key.lastRegisteredAt) }
    }
}

actor FCMTokenRegistrar {
    private enum Constants {
        static let duplicateRegistrationInterval: TimeInterval = 60 * 10
    }

    private let remoteDataSource: any PushTokenRemoteDataSource
    private let authTokenProvider: () -> String?
    private let deviceIdentifierProvider: any DeviceIdentifierProvider
    private var registrationStore: any PushTokenRegistrationStore
    private var pendingToken: String?
    private var isRegistering = false

    init(
        remoteDataSource: any PushTokenRemoteDataSource = DefaultPushTokenRemoteDataSource(),
        authTokenProvider: @escaping () -> String? = { APIClient.shared.userAuthToken },
        deviceIdentifierProvider: any DeviceIdentifierProvider = KeychainDeviceIdentifierProvider(),
        registrationStore: any PushTokenRegistrationStore = UserDefaultsPushTokenRegistrationStore()
    ) {
        self.remoteDataSource = remoteDataSource
        self.authTokenProvider = authTokenProvider
        self.deviceIdentifierProvider = deviceIdentifierProvider
        self.registrationStore = registrationStore
    }

    func register(token: String, source: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedToken.isEmpty == false else {
            print("[FCM] token save skipped reason=empty source=\(source)")
            return
        }

        pendingToken = trimmedToken

        guard authTokenProvider() != nil else {
            print("[FCM] token save pending reason=authUnavailable source=\(source)")
            return
        }

        if isRegistering {
            print("[FCM] token save joined source=\(source)")
            return
        }

        while let tokenToRegister = pendingToken {
            let deviceID = deviceIdentifierProvider.stableDeviceIdentifier()
            let fingerprint = Self.fingerprint(
                token: tokenToRegister,
                deviceID: deviceID,
                environment: AppConfig.apiEnvironment.rawValue
            )

            if shouldSkipRegistration(fingerprint: fingerprint) {
                print("[FCM] token save skipped reason=unchanged source=\(source)")
                pendingToken = nil
                return
            }

            isRegistering = true
            do {
                try await remoteDataSource.savePushToken(
                    PushTokenRequestDTO(
                        token: tokenToRegister,
                        platform: "ios",
                        deviceId: deviceID,
                        appVersion: AppConfig.appVersion,
                        buildNumber: AppConfig.buildNumber,
                        environment: AppConfig.apiEnvironment.rawValue
                    )
                )
                registrationStore.lastRegisteredFingerprint = fingerprint
                registrationStore.lastRegisteredAt = Date()
                if pendingToken == tokenToRegister {
                    pendingToken = nil
                }
                print("[FCM] token save completed")
            } catch let networkError as NetworkError {
                if networkError.isAuthFailure {
                    print("[FCM] token save pending reason=authUnavailable source=\(source)")
                } else {
                    print("[FCM] token save failed error=\(networkError.localizedDescription)")
                }
                isRegistering = false
                return
            } catch {
                print("[FCM] token save failed error=\(error.localizedDescription)")
                isRegistering = false
                return
            }
            isRegistering = false
        }
    }

    func registerPendingTokenIfPossible(source: String) async {
        guard let pendingToken else { return }
        await register(token: pendingToken, source: source)
    }

    func deleteRegisteredTokenOnLogout(accessToken: String?) async {
        guard let accessToken, accessToken.isEmpty == false else {
            print("[FCM] token delete skipped reason=authUnavailable")
            clearLocalRegistration()
            return
        }

        let deviceID = deviceIdentifierProvider.stableDeviceIdentifier()
        do {
            try await remoteDataSource.deletePushToken(deviceId: deviceID, accessToken: accessToken)
            print("[FCM] token delete completed")
        } catch {
            print("[FCM] token delete failed error=\(error.localizedDescription)")
        }
        clearLocalRegistration()
    }

    private func clearLocalRegistration() {
        registrationStore.lastRegisteredFingerprint = nil
        registrationStore.lastRegisteredAt = nil
    }

    private func shouldSkipRegistration(fingerprint: String) -> Bool {
        guard registrationStore.lastRegisteredFingerprint == fingerprint else {
            return false
        }

        guard let lastRegisteredAt = registrationStore.lastRegisteredAt else {
            return true
        }

        return Date().timeIntervalSince(lastRegisteredAt) < Constants.duplicateRegistrationInterval
    }

    private static func fingerprint(token: String, deviceID: String, environment: String) -> String {
        "\(token)|\(deviceID)|\(environment)"
    }
}

private extension NetworkError {
    var isAuthFailure: Bool {
        switch self {
        case .unauthorized:
            return true
        case .serverError(let statusCode, _, _):
            return statusCode == 401 || statusCode == 403 || statusCode == 419
        default:
            return false
        }
    }
}
