import XCTest
@testable import GamePedia

final class FCMTokenRegistrarTests: XCTestCase {
    func testRegisterStoresPendingWhenAuthIsUnavailable() async {
        let remote = SpyPushTokenRemoteDataSource()
        let store = InMemoryPushTokenRegistrationStore()
        let registrar = FCMTokenRegistrar(
            remoteDataSource: remote,
            authTokenProvider: { nil },
            deviceIdentifierProvider: StubDeviceIdentifierProvider(),
            registrationStore: store
        )

        await registrar.register(token: "token-a", source: "test")

        let savedRequests = await remote.currentSavedRequests()
        XCTAssertEqual(savedRequests.count, 0)
        XCTAssertNil(store.lastRegisteredFingerprint)
    }

    func testRegisterSkipsUnchangedToken() async {
        let remote = SpyPushTokenRemoteDataSource()
        let store = InMemoryPushTokenRegistrationStore()
        let registrar = FCMTokenRegistrar(
            remoteDataSource: remote,
            authTokenProvider: { "access-token" },
            deviceIdentifierProvider: StubDeviceIdentifierProvider(),
            registrationStore: store
        )

        await registrar.register(token: "token-a", source: "test")
        await registrar.register(token: "token-a", source: "test")

        let savedRequests = await remote.currentSavedRequests()
        XCTAssertEqual(savedRequests.count, 1)
    }

    func testRegisterSavesAgainWhenTokenChanges() async {
        let remote = SpyPushTokenRemoteDataSource()
        let store = InMemoryPushTokenRegistrationStore()
        let registrar = FCMTokenRegistrar(
            remoteDataSource: remote,
            authTokenProvider: { "access-token" },
            deviceIdentifierProvider: StubDeviceIdentifierProvider(),
            registrationStore: store
        )

        await registrar.register(token: "token-a", source: "test")
        await registrar.register(token: "token-b", source: "test")

        let savedRequests = await remote.currentSavedRequests()
        XCTAssertEqual(savedRequests.map(\.token), ["token-a", "token-b"])
    }
}

private final class InMemoryPushTokenRegistrationStore: PushTokenRegistrationStore {
    var lastRegisteredFingerprint: String?
    var lastRegisteredAt: Date?
}

private struct StubDeviceIdentifierProvider: DeviceIdentifierProvider {
    func stableDeviceIdentifier() -> String {
        "device-id"
    }
}

private actor SpyPushTokenRemoteDataSource: PushTokenRemoteDataSource {
    private(set) var savedRequests: [PushTokenRequestDTO] = []
    private(set) var deletedDeviceIDs: [String] = []

    func savePushToken(_ requestDTO: PushTokenRequestDTO) async throws {
        savedRequests.append(requestDTO)
    }

    func deletePushToken(deviceId: String) async throws {
        deletedDeviceIDs.append(deviceId)
    }

    func deletePushToken(deviceId: String, accessToken: String) async throws {
        deletedDeviceIDs.append(deviceId)
    }

    func currentSavedRequests() -> [PushTokenRequestDTO] {
        savedRequests
    }
}
