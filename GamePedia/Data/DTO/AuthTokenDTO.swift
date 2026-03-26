import Foundation

// MARK: - AuthTokenDTO
// Maps the Twitch client_credentials token response.
// Endpoint: POST https://id.twitch.tv/oauth2/token
//
// Example response:
// {
//   "access_token": "cfabdegwdoklmawdzdo4v4386uct8b",
//   "expires_in": 5035365,
//   "token_type": "bearer"
// }

struct AuthTokenDTO: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
}
