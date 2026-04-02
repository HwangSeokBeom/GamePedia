import Foundation

struct NotificationsState {
    var isLoading: Bool = false
    var notifications: [AppNotification] = []
    var errorMessage: String? = nil

    var isEmpty: Bool {
        !isLoading && notifications.isEmpty && errorMessage == nil
    }
}
