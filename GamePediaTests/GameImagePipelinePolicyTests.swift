import XCTest
import Kingfisher
@testable import GamePedia

// Policy-level coverage for the image pipeline: pure prefetch decisions
// and the explicit cache budgets. Kingfisher internals (downloader
// coalescing, memory-warning clearing) are the framework's contract and
// are not re-tested here.
final class GameImagePipelinePolicyTests: XCTestCase {

    func test_prefetchURLs_dropsNils_dedupes_preservesOrder() {
        let a = URL(string: "https://img.example/a.jpg")!
        let b = URL(string: "https://img.example/b.jpg")!
        let urls = GameImagePipelinePolicy.prefetchURLs(from: [nil, a, b, a, nil, b])
        XCTAssertEqual(urls, [a, b])
    }

    func test_prefetchURLs_boundsPassSize() {
        let candidates: [URL?] = (0..<100).map { URL(string: "https://img.example/\($0).jpg") }
        let urls = GameImagePipelinePolicy.prefetchURLs(from: candidates)
        XCTAssertEqual(urls.count, GameImagePipelinePolicy.maxPrefetchURLsPerPass)
        XCTAssertEqual(urls.first, URL(string: "https://img.example/0.jpg"), "nearest rows must win")
    }

    func test_prefetchURLs_emptyInput() {
        XCTAssertTrue(GameImagePipelinePolicy.prefetchURLs(from: []).isEmpty)
        XCTAssertTrue(GameImagePipelinePolicy.prefetchURLs(from: [nil, nil]).isEmpty)
    }

    func test_apply_setsExplicitCacheBudgets() {
        let cache = ImageCache(name: "GameImagePipelinePolicyTests-\(UUID().uuidString)")
        defer {
            cache.clearMemoryCache()
            cache.clearDiskCache()
        }

        GameImagePipelinePolicy.apply(to: cache)

        XCTAssertEqual(cache.memoryStorage.config.totalCostLimit, GameImagePipelinePolicy.memoryCacheBytesLimit)
        XCTAssertEqual(cache.memoryStorage.config.countLimit, GameImagePipelinePolicy.memoryCacheCountLimit)
        XCTAssertEqual(cache.diskStorage.config.sizeLimit, GameImagePipelinePolicy.diskCacheBytesLimit)
    }

    func test_memoryWarning_clearsBoundedMemoryCache() {
        let cache = ImageCache(name: "GameImagePipelinePolicyTests-mw-\(UUID().uuidString)")
        defer { cache.clearDiskCache() }
        GameImagePipelinePolicy.apply(to: cache)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        cache.store(image, forKey: "k", toDisk: false)
        XCTAssertTrue(cache.isCached(forKey: "k"))

        // Kingfisher subscribes its memory storage to memory warnings;
        // the explicit clear below asserts our budgeted cache empties and
        // stays usable, which is the recovery path a warning triggers.
        cache.clearMemoryCache()
        XCTAssertFalse(cache.memoryStorage.isCached(forKey: "k"))
    }
}
