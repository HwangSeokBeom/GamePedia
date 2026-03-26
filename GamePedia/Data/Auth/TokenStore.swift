protocol TokenStore {
    func saveAccessToken(_ token: String)
    func saveRefreshToken(_ token: String)
    func fetchAccessToken() -> String?
    func fetchRefreshToken() -> String?
    func clear()
}
