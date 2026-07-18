import Foundation
import Kingfisher

// MARK: - GameImagePipelinePolicy
//
// One explicit place for the app's image cache and prefetch policy.
// Kingfisher stays the pipeline (downloader-level coalescing of duplicate
// URL downloads and memory-warning cache clearing are built in); this
// policy makes the budgets explicit instead of relying on defaults, and
// keeps the decisions pure so they are unit-testable.

enum GameImagePipelinePolicy {

    /// Memory cache budget: bounded so list scrolling cannot grow the
    /// cache without limit. Kingfisher's default is 25% of physical RAM;
    /// covers/avatars are small, so a fixed budget is predictable across
    /// devices and keeps memory-warning recovery cheap.
    static let memoryCacheBytesLimit = 64 * 1024 * 1024
    static let memoryCacheCountLimit = 150

    /// Disk cache budget and retention for cover art.
    static let diskCacheBytesLimit: UInt = 256 * 1024 * 1024
    static let diskCacheExpirationDays = 14

    /// Cap on how many upcoming rows a single prefetch pass may request,
    /// so a fast scroll cannot fan out unbounded downloads.
    static let maxPrefetchURLsPerPass = 20

    /// Applies the cache budgets to the shared Kingfisher cache. Called
    /// once at launch; safe to call again (idempotent assignment).
    static func apply(to cache: ImageCache = .default) {
        cache.memoryStorage.config.totalCostLimit = memoryCacheBytesLimit
        cache.memoryStorage.config.countLimit = memoryCacheCountLimit
        cache.diskStorage.config.sizeLimit = diskCacheBytesLimit
        cache.diskStorage.config.expiration = .days(diskCacheExpirationDays)
    }

    /// Pure prefetch decision: ordered, de-duplicated, bounded list of
    /// URLs for the given upcoming-row candidates. Nils are dropped;
    /// order of first appearance is preserved so the nearest rows win.
    static func prefetchURLs(from candidates: [URL?]) -> [URL] {
        var seen = Set<URL>()
        var urls: [URL] = []
        for candidate in candidates {
            guard let url = candidate, seen.insert(url).inserted else { continue }
            urls.append(url)
            if urls.count == maxPrefetchURLsPerPass { break }
        }
        return urls
    }
}

// MARK: - GameImagePrefetcher
//
// Small per-screen wrapper over Kingfisher's ImagePrefetcher that applies
// the policy above. Each call replaces the previous pass, so stale
// prefetches from rows scrolled past are stopped instead of piling up.

final class GameImagePrefetcher {

    private var activePrefetcher: ImagePrefetcher?

    func prefetch(candidates: [URL?]) {
        let urls = GameImagePipelinePolicy.prefetchURLs(from: candidates)
        guard urls.isEmpty == false else { return }
        activePrefetcher?.stop()
        let prefetcher = ImagePrefetcher(urls: urls)
        activePrefetcher = prefetcher
        prefetcher.start()
    }

    func cancelAll() {
        activePrefetcher?.stop()
        activePrefetcher = nil
    }
}
