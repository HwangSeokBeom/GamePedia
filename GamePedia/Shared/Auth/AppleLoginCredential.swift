struct AppleLoginCredential: Equatable {
    let userIdentifier: String
    let identityToken: String
    let authorizationCode: String?
    let email: String?
    let givenName: String?
    let familyName: String?
}
