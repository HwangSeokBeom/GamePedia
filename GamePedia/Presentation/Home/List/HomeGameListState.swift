import Foundation

struct HomeGameListState {
    let section: HomeSection
    let games: [Game]
    let wishlistedGameIDs: Set<Int>
}
