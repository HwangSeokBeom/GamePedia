protocol UserSessionStore {
    func saveUser(_ user: AuthUser)
    func fetchUser() -> AuthUser?
    func clear()
}

final class InMemoryUserSessionStore: UserSessionStore {

    static let shared = InMemoryUserSessionStore()

    private var currentUser: AuthUser?

    private init() {}

    func saveUser(_ user: AuthUser) {
        currentUser = user
    }

    func fetchUser() -> AuthUser? {
        currentUser
    }

    func clear() {
        currentUser = nil
    }
}
