import Combine
import Foundation
import Network

final class NetworkMonitor: ObservableObject {
    @Published var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.parso.acalum.network-monitor")

    init(startMonitoring: Bool = true) {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        if startMonitoring {
            monitor.start(queue: queue)
        }
    }

    deinit {
        monitor.cancel()
    }
}
