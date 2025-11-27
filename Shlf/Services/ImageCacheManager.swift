//
//  ImageCacheManager.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import CryptoKit

actor ImageCacheManager {
    static let shared = ImageCacheManager()

    private var memoryCache = NSCache<NSString, UIImage>()
    private var diskCacheURL: URL
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days in seconds

    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100 // Max 100 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDir.appendingPathComponent("BookCovers", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Clean up old cache on init
        Task {
            await cleanupOldCache()
        }
    }

    // MARK: - Public Methods

    func getImage(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        // 1. Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key) {
            return cachedImage
        }

        // 2. Check disk cache
        if let diskImage = await loadFromDisk(url: url) {
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }

        // 3. Download from network
        if let downloadedImage = await downloadImage(from: url) {
            memoryCache.setObject(downloadedImage, forKey: key)
            await saveToDisk(image: downloadedImage, url: url)
            return downloadedImage
        }

        return nil
    }

    func clearCache() async {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Private Methods

    private func loadFromDisk(url: URL) async -> UIImage? {
        let filename = cacheFilename(for: url)
        let fileURL = diskCacheURL.appendingPathComponent(filename)

        // Check if file exists and is not too old
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        let fileAge = Date().timeIntervalSince(modificationDate)
        if fileAge > maxCacheAge {
            // File is too old, delete it
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func saveToDisk(image: UIImage, url: URL) async {
        let filename = cacheFilename(for: url)
        let fileURL = diskCacheURL.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        try? data.write(to: fileURL)
    }

    private func cacheFilename(for url: URL) -> String {
        // Use SHA256 hash of full URL to avoid collisions
        let urlString = url.absoluteString
        let data = Data(urlString.utf8)
        let hash = sha256(data: data)
        return hash + ".jpg"
    }

    private func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02hhx", $0) }.joined()
    }

    private func cleanupOldCache() async {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let now = Date()

        for fileURL in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }

            let fileAge = now.timeIntervalSince(modificationDate)
            if fileAge > maxCacheAge {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Cached AsyncImage View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true

        if let cachedImage = await ImageCacheManager.shared.getImage(for: url) {
            image = cachedImage
        }

        isLoading = false
    }
}
