import SwiftUI
import UIKit

/// Memory + disk cached remote image loader so the artwork appears instantly on revisit.
final class ImageStore {
    static let shared = ImageStore()

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memory.countLimit = 80
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 40 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    func cached(_ url: String) -> UIImage? { memory.object(forKey: url as NSString) }

    func load(_ url: String) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let task = inflight[url] { return await task.value }
        let session = self.session
        let task = Task<UIImage?, Never> {
            guard let u = URL(string: url) else { return nil }
            do {
                let (data, _) = try await session.data(from: u)
                return await Self.decode(data)
            } catch {
                return nil
            }
        }
        inflight[url] = task
        let image = await task.value
        inflight[url] = nil
        if let image { memory.setObject(image, forKey: url as NSString) }
        return image
    }

    nonisolated private static func decode(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }

    func prefetch(_ urls: [String]) {
        for url in urls {
            Task { _ = await load(url) }
        }
    }
}

struct RemoteImage: View {
    let url: String
    @State private var image: UIImage?

    init(url: String) {
        self.url = url
        _image = State(initialValue: ImageStore.shared.cached(url))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x1A0A3E), Color(hex: 0x0C0520)],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
        }
        .task(id: url) {
            if image == nil {
                let loaded = await ImageStore.shared.load(url)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
        }
    }

    func scaledToFill() -> some View {
        Color.clear
            .overlay { self.aspectRatio(contentMode: .fill) }
            .clipped()
    }
}
