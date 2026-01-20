//
//  WatchBookCoverView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 20/01/2026.
//

import SwiftUI

private final class WatchImageCache {
    static let shared = WatchImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct WatchBookCoverView: View {
    let imageURL: URL?
    let size: CGSize
    @State private var image: UIImage?

    init(imageURL: URL?, size: CGSize = CGSize(width: 28, height: 40)) {
        self.imageURL = imageURL
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if imageURL != nil {
                placeholder
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .task(id: imageURL?.absoluteString) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        Image(systemName: "book.closed")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func loadImage() async {
        guard let imageURL else {
            image = nil
            return
        }

        if let cached = WatchImageCache.shared.image(for: imageURL) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let loaded = UIImage(data: data) {
                WatchImageCache.shared.insert(loaded, for: imageURL)
                image = loaded
            }
        } catch {
            image = nil
        }
    }
}
