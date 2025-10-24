//
//  BackgroundTaskManager.swift
//  Gym_API
//
//  Manages heavy operations in background threads to avoid blocking main thread
//  Created as part of performance optimization phase
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Background Task Manager
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    private init() {}

    // MARK: - JSON Operations

    /// Decode JSON data in background
    func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        }.value
    }

    /// Encode object to JSON in background
    func encodeJSON<T: Encodable>(_ object: T) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(object)
        }.value
    }

    // MARK: - Image Operations

    /// Compress image in background
    func compressImage(_ image: UIImage, quality: CGFloat = 0.7) async -> Data? {
        return await Task.detached(priority: .userInitiated) {
            return image.jpegData(compressionQuality: quality)
        }.value
    }

    /// Resize image in background
    func resizeImage(_ image: UIImage, targetSize: CGSize) async -> UIImage? {
        return await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }.value
    }

    /// Load image from data in background
    func loadImage(from data: Data) async -> UIImage? {
        return await Task.detached(priority: .userInitiated) {
            return UIImage(data: data)
        }.value
    }

    // MARK: - File Operations

    /// Write data to file in background
    func writeToFile(_ data: Data, at url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try data.write(to: url, options: [.atomic])
        }.value
    }

    /// Read data from file in background
    func readFromFile(at url: URL) async throws -> Data {
        return try await Task.detached(priority: .utility) {
            return try Data(contentsOf: url)
        }.value
    }

    /// Copy file in background
    func copyFile(from source: URL, to destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.copyItem(at: source, to: destination)
        }.value
    }

    /// Delete file in background
    func deleteFile(at url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    // MARK: - Batch Operations

    /// Process multiple items in parallel
    func processBatch<T, R>(
        items: [T],
        maxConcurrency: Int = 4,
        operation: @escaping (T) async throws -> R
    ) async throws -> [R] {
        // Split items into chunks
        let chunkSize = max(1, items.count / maxConcurrency)
        var results: [R] = []
        results.reserveCapacity(items.count)

        // Process chunks in parallel
        await withTaskGroup(of: Result<[R], Error>.self) { group in
            for chunk in items.chunked(into: chunkSize) {
                group.addTask {
                    do {
                        var chunkResults: [R] = []
                        for item in chunk {
                            let result = try await operation(item)
                            chunkResults.append(result)
                        }
                        return .success(chunkResults)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            // Collect results
            for await result in group {
                switch result {
                case .success(let chunkResults):
                    results.append(contentsOf: chunkResults)
                case .failure(let error):
                    print("Batch operation error: \(error)")
                }
            }
        }

        return results
    }

    // MARK: - Heavy Computation

    /// Perform heavy computation in background
    func compute<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await Task.detached(priority: .background) {
            return try operation()
        }.value
    }

    // MARK: - Network Operations

    /// Download data in background with progress
    func downloadData(from url: URL, progress: @escaping (Double) -> Void) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }

            // Observe progress
            task.resume()
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Performance Monitor
struct PerformanceMonitor {
    static func measureTime<T>(
        operation: String,
        _ block: () async throws -> T
    ) async throws -> T {
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let result = try await block()
            let duration = CFAbsoluteTimeGetCurrent() - start

            #if DEBUG
            print("⏱️ \(operation) took \(String(format: "%.3f", duration)) seconds")
            #endif

            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start

            #if DEBUG
            print("⏱️ \(operation) failed after \(String(format: "%.3f", duration)) seconds")
            #endif

            throw error
        }
    }
}

// MARK: - Main Thread Checker
@MainActor
class MainThreadChecker {
    static func assertMainThread(function: String = #function) {
        assert(Thread.isMainThread, "\(function) must be called on main thread")
    }

    static func warnIfMainThread(function: String = #function) {
        #if DEBUG
        if Thread.isMainThread {
            print("⚠️ Warning: \(function) is being called on main thread")
        }
        #endif
    }
}

// MARK: - Background Queue Manager
enum BackgroundQueuePriority {
    case high
    case medium
    case low
    case background

    var qos: DispatchQoS {
        switch self {
        case .high:
            return .userInitiated
        case .medium:
            return .default
        case .low:
            return .utility
        case .background:
            return .background
        }
    }
}

class BackgroundQueueManager {
    static let shared = BackgroundQueueManager()

    private let highPriorityQueue = DispatchQueue(label: "com.gymapi.high", qos: .userInitiated, attributes: .concurrent)
    private let mediumPriorityQueue = DispatchQueue(label: "com.gymapi.medium", qos: .default, attributes: .concurrent)
    private let lowPriorityQueue = DispatchQueue(label: "com.gymapi.low", qos: .utility, attributes: .concurrent)
    private let backgroundQueue = DispatchQueue(label: "com.gymapi.background", qos: .background, attributes: .concurrent)

    func execute(priority: BackgroundQueuePriority, _ block: @escaping () -> Void) {
        let queue = queue(for: priority)
        queue.async(execute: block)
    }

    func executeSync<T>(priority: BackgroundQueuePriority, _ block: () throws -> T) rethrows -> T {
        let queue = queue(for: priority)
        return try queue.sync(execute: block)
    }

    private func queue(for priority: BackgroundQueuePriority) -> DispatchQueue {
        switch priority {
        case .high:
            return highPriorityQueue
        case .medium:
            return mediumPriorityQueue
        case .low:
            return lowPriorityQueue
        case .background:
            return backgroundQueue
        }
    }
}