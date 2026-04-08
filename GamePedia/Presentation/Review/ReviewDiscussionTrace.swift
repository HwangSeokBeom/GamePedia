import Foundation

enum ReviewDiscussionTrace {
    static var sink: ((String) -> Void)?

    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        let resolved = message()
        print(resolved)
        sink?(resolved)
#endif
    }
}
