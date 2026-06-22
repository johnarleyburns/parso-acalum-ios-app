import SwiftUI
import os

@main
struct AcalumApp: App {
    let queueService: QueueServiceProtocol
    let syncManager: SyncManager
    let networkMonitor: NetworkMonitor
    let downloadManager: DownloadManager
    @State private var showSplash = true

    init() {
        let networkMonitor = NetworkMonitor()
        self.networkMonitor = networkMonitor
        downloadManager = DownloadManager(networkMonitor: networkMonitor)
        queueService = Self.makeQueueService()
        syncManager = SyncManager(networkMonitor: networkMonitor)
        syncManager.start()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                PlayerHomeView(viewModel: PlayerViewModel(
                    queueService: queueService,
                    networkMonitor: networkMonitor,
                    downloadManager: downloadManager
                ))

                if showSplash {
                    SplashView(isPresented: $showSplash)
                        .zIndex(10)
                }
            }
        }
    }

    private static func makeQueueService() -> QueueServiceProtocol {
        do {
            let db = try LocalDatabase()
            let catalog = try db.loadTracks()
            os_log(.info, "makeQueueService: loaded %d tracks from database", catalog.count)
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
            os_log(.error, "makeQueueService: database load failed — falling back to mock data. error=%@", error.localizedDescription)
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
