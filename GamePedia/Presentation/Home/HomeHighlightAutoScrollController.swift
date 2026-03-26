import Foundation

final class HomeHighlightAutoScrollController {

    private let interval: TimeInterval
    private var timer: Timer?
    private var tickHandler: (() -> Void)?

    init(interval: TimeInterval = 4.0) {
        self.interval = interval
    }

    deinit {
        stop()
    }

    func start(tickHandler: @escaping () -> Void) {
        self.tickHandler = tickHandler
        resume()
    }

    func resume() {
        guard timer == nil, let tickHandler else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            tickHandler()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func pause() {
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        pause()
        tickHandler = nil
    }
}
