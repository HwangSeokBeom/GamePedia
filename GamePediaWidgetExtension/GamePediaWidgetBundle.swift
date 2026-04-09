import WidgetKit
import SwiftUI

@main
struct GamePediaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentViewedGamesWidget()
        TrendingGamesWidget()
        MyActivityWidget()
        ReviewPromptWidget()
    }
}
