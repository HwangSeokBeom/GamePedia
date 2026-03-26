import Foundation

// MARK: - IGDBGameDTO
//
// Maps the IGDB /games endpoint response.
// IGDB always returns a JSON array: [IGDBGameDTO]
//
// Sample Apicalypse query:
//   fields name, summary, cover.url, genres.name, platforms.name, rating;
//   where cover != null;
//   limit 20;
//
// Cover URL note: IGDB returns protocol-relative URLs like "//images.igdb.com/..."
// Use IGDBGameMapper to prepend "https:" and swap the image size slug.

struct IGDBGameDTO: Decodable {
    let id: Int
    let name: String
    let summary: String?
    let translatedTitle: String?
    let translatedSummary: String?
    let cover: IGDBCoverDTO?
    let genres: [IGDBNameDTO]?
    let platforms: [IGDBNameDTO]?
    let rating: Double?
    let ratingCount: Int?
    /// Unix timestamp (seconds) — convert to year in mapper
    let firstReleaseDate: Int?
    /// Hype count — used for recommended sorting
    let hypes: Int?
}

// MARK: - IGDBCoverDTO

struct IGDBCoverDTO: Decodable {
    /// Protocol-relative: "//images.igdb.com/igdb/image/upload/t_thumb/co5ptl.jpg"
    let url: String
}

// MARK: - IGDBNameDTO
// Shared shape for genres, platforms, companies, etc.

struct IGDBNameDTO: Decodable {
    let name: String
}

// MARK: - IGDBGameDetailDTO
//
// Extended fields for the Game Detail screen.
// Uses the same /games endpoint with a richer query.

struct IGDBGameDetailDTO: Decodable {
    let id: Int
    let name: String
    let summary: String?
    let translatedTitle: String?
    let translatedSummary: String?
    let translatedStoryline: String?
    let cover: IGDBCoverDTO?
    let genres: [IGDBNameDTO]?
    let platforms: [IGDBNameDTO]?
    let rating: Double?
    let ratingCount: Int?
    let totalRating: Double?
    let screenshots: [IGDBScreenshotDTO]?
    let firstReleaseDate: Int?
    let involvedCompanies: [IGDBInvolvedCompanyDTO]?
}

// MARK: - IGDBScreenshotDTO

struct IGDBScreenshotDTO: Decodable {
    /// Protocol-relative, same format as cover URL
    let url: String
}

// MARK: - IGDBInvolvedCompanyDTO

struct IGDBInvolvedCompanyDTO: Decodable {
    let company: IGDBNameDTO?
    let developer: Bool?
}
