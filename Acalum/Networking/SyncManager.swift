import Combine
import Foundation

final class SyncManager {
    private let networkMonitor: NetworkMonitor
    private let apiClient: APIClientProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false
    private var retryWorkItem: DispatchWorkItem?

    init(networkMonitor: NetworkMonitor, apiClient: APIClientProtocol = APIClient()) {
        self.networkMonitor = networkMonitor
        self.apiClient = apiClient

        networkMonitor.$isConnected
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.syncPendingEvents()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .feedbackEventRecorded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notifyEventRecorded()
            }
            .store(in: &cancellables)
    }

    func start() {
        if networkMonitor.isConnected {
            syncPendingEvents()
        }
    }

    func notifyEventRecorded() {
        guard networkMonitor.isConnected, !isSyncing else { return }
        syncPendingEvents()
    }

    private func syncPendingEvents() {
        guard !isSyncing else { return }

        let events = FeedbackEventStore.loadPendingEvents()
        guard !events.isEmpty else { return }

        isSyncing = true

        Task {
            let result = await sendBatch(events)

            await MainActor.run {
                self.isSyncing = false

                switch result {
                case .success(let acceptedCount):
                    if acceptedCount > 0 {
                        let sentIDs = Set(events.prefix(acceptedCount).map(\.id))
                        FeedbackEventStore.removePendingEvents(sentIDs)
                    }
                case .failure:
                    self.scheduleRetry()
                }
            }
        }
    }

    private func sendBatch(_ events: [FeedbackEvent]) async -> Result<Int, Error> {
        let isoFormatter = ISO8601DateFormatter()

        let dtos = events.map { event in
            EventDTO(
                id: event.id.uuidString,
                trackID: event.trackID,
                type: event.type.rawValue,
                listenSeconds: event.listenSeconds,
                timestamp: isoFormatter.string(from: event.timestamp),
                prompt: event.prompt,
                selectedPills: event.selectedPillIDs
            )
        }

        let request = EventsRequest(
            sessionID: events.first?.sessionID ?? "",
            events: dtos
        )

        do {
            let response = try await apiClient.sendEvents(request: request)
            return .success(response.accepted)
        } catch {
            return .failure(error)
        }
    }

    private func scheduleRetry() {
        retryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.syncPendingEvents()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }
}
