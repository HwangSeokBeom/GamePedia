import XCTest
@testable import GamePedia

// Pure state-machine coverage: single-flight, duplicate-page rejection,
// stale-completion rejection, reset/refresh generations, and phase flags.
final class PaginationStateMachineTests: XCTestCase {

    func test_initialLoad_happyPath() {
        var machine = PaginationStateMachine<String>()

        let load = machine.beginInitial()
        XCTAssertNotNil(load)
        XCTAssertEqual(load?.kind, .initial)
        XCTAssertNil(load?.token)
        XCTAssertTrue(machine.isLoadingInitial)
        XCTAssertTrue(machine.isLoadInFlight)
        XCTAssertFalse(machine.hasLoadedInitialPage)

        XCTAssertTrue(machine.completeLoad(load!, nextToken: "c1"))
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertTrue(machine.hasLoadedInitialPage)
        XCTAssertEqual(machine.nextPageToken, "c1")
        XCTAssertTrue(machine.hasMorePages)
    }

    func test_singleFlight_rejectsOverlappingBegins() {
        var machine = PaginationStateMachine<String>()
        let load = machine.beginInitial()
        XCTAssertNotNil(load)

        XCTAssertNil(machine.beginInitial(), "second initial while in flight must be rejected")
        XCTAssertNil(machine.beginRefresh(), "refresh while in flight must be rejected")
        XCTAssertNil(machine.beginNextPage(), "next page while in flight must be rejected")
    }

    func test_nextPage_requiresInitialAndToken() {
        var machine = PaginationStateMachine<String>()
        XCTAssertNil(machine.beginNextPage(), "next page before initial load must be rejected")

        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: nil)
        XCTAssertNil(machine.beginNextPage(), "next page without a token must be rejected")
    }

    func test_nextPage_loadsAndAdvancesCursor() {
        var machine = PaginationStateMachine<String>()
        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: "c1")

        let more = machine.beginNextPage()
        XCTAssertEqual(more?.kind, .nextPage)
        XCTAssertEqual(more?.token, "c1")
        XCTAssertTrue(machine.isLoadingMore)

        machine.completeLoad(more!, nextToken: "c2")
        XCTAssertEqual(machine.nextPageToken, "c2")
    }

    func test_duplicatePage_serverEchoesSameCursor_terminatesPagination() {
        var machine = PaginationStateMachine<String>()
        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: "c1")

        let more = machine.beginNextPage()!
        machine.completeLoad(more, nextToken: "c1")

        XCTAssertNil(machine.nextPageToken, "echoed cursor must terminate pagination, not loop")
        XCTAssertNil(machine.beginNextPage())
    }

    func test_duplicatePage_alreadyLoadedToken_terminatesPagination() {
        var machine = PaginationStateMachine<String>()
        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: "c1")

        let first = machine.beginNextPage()!
        machine.completeLoad(first, nextToken: "c2")
        let second = machine.beginNextPage()!
        // Server points back at an earlier page.
        machine.completeLoad(second, nextToken: "c1")

        XCTAssertNil(machine.nextPageToken, "a next token pointing at a loaded page must terminate pagination")
    }

    func test_refresh_startsNewDataset_allowsPreviouslyLoadedTokens() {
        var machine = PaginationStateMachine<String>()
        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: "c1")
        let more = machine.beginNextPage()!
        machine.completeLoad(more, nextToken: nil)

        let refresh = machine.beginRefresh()
        XCTAssertEqual(refresh?.kind, .refresh)
        XCTAssertTrue(machine.isRefreshing, "refresh after initial load must use the refreshing phase")
        machine.completeLoad(refresh!, nextToken: "c1")

        XCTAssertEqual(machine.nextPageToken, "c1", "a refreshed dataset may revisit old cursors")
        XCTAssertNotNil(machine.beginNextPage())
    }

    func test_refreshBeforeFirstSuccess_usesInitialPhase() {
        var machine = PaginationStateMachine<String>()
        let failedInitial = machine.beginInitial()!
        machine.failLoad(failedInitial)

        let retry = machine.beginRefresh()
        XCTAssertNotNil(retry)
        XCTAssertTrue(machine.isLoadingInitial, "retry before any success renders as initial loading, not refreshing")
    }

    func test_failure_preservesNextTokenForRetry() {
        var machine = PaginationStateMachine<String>()
        let initial = machine.beginInitial()!
        machine.completeLoad(initial, nextToken: "c1")

        let more = machine.beginNextPage()!
        XCTAssertTrue(machine.failLoad(more))
        XCTAssertEqual(machine.phase, .failed)
        XCTAssertEqual(machine.nextPageToken, "c1", "failed page load must keep the cursor for retry")

        let retried = machine.beginNextPage()
        XCTAssertEqual(retried?.token, "c1")
    }

    func test_staleCompletion_afterReset_isRejected() {
        var machine = PaginationStateMachine<String>()
        let load = machine.beginInitial()!
        machine.reset()

        XCTAssertFalse(machine.completeLoad(load, nextToken: "c1"), "completion from before reset must be rejected")
        XCTAssertFalse(machine.failLoad(load), "failure from before reset must be rejected")
        XCTAssertFalse(machine.hasLoadedInitialPage)
        XCTAssertNil(machine.nextPageToken)
        XCTAssertEqual(machine.phase, .idle)
    }

    func test_staleCompletion_doubleComplete_isRejected() {
        var machine = PaginationStateMachine<String>()
        let load = machine.beginInitial()!
        XCTAssertTrue(machine.completeLoad(load, nextToken: "c1"))
        XCTAssertFalse(machine.completeLoad(load, nextToken: "c9"), "double completion must be rejected")
        XCTAssertEqual(machine.nextPageToken, "c1")
    }

    func test_intTokens_pageNumberPagination() {
        var machine = PaginationStateMachine<Int>()
        let initial = machine.beginRefresh()
        XCTAssertNotNil(initial, "refresh doubles as first load for single-page consumers")
        machine.completeLoad(initial!, nextToken: nil)
        XCTAssertTrue(machine.hasLoadedInitialPage)
        XCTAssertFalse(machine.hasMorePages)
    }
}
