import SwiftUI

@main
struct AcalumApp: App {
    let queueService: QueueServiceProtocol
    let syncManager: SyncManager

    init() {
        let networkMonitor = NetworkMonitor()
        queueService = Self.makeQueueService()
        syncManager = SyncManager(networkMonitor: networkMonitor)
        syncManager.start()
    }

    var body: some Scene {
        WindowGroup {
            PlayerHomeView(viewModel: PlayerViewModel(queueService: queueService))
        }
    }

    private static func makeQueueService() -> QueueServiceProtocol {
        do {
            let db = try LocalDatabase()
            let catalog = try db.loadTracks()
            let searchService = ExactCosineVectorSearchService(catalog: catalog)
            let tasteBuilder = TasteVectorBuilder(catalog: catalog)
            let textEmbedding = Self.makeTextEmbeddingService()
            return LocalRecommendationEngine(
                catalog: catalog,
                searchService: searchService,
                tasteBuilder: tasteBuilder,
                textEmbedding: textEmbedding
            )
        } catch {
            return MockQueueService()
        }
    }

    private static func makeTextEmbeddingService() -> TextEmbeddingService? {
        do {
            return try CLAPTextEmbeddingService()
        } catch CLAPTextEmbeddingError.modelNotBundled {
            return nil
        } catch {
            return nil
        }
    }
}
