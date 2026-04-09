import ComposableArchitecture
import Foundation
import Sharing

struct RepositoryBookmarkClient {
  var makeBookmarkData: @Sendable (URL) -> Data?
}

extension RepositoryBookmarkClient: DependencyKey {
  static let liveValue = RepositoryBookmarkClient { url in
    RepositorySecurityScopedAccess.makeBookmarkData(for: url)
  }

  static let testValue = RepositoryBookmarkClient { _ in nil }
}

extension DependencyValues {
  var repositoryBookmarkClient: RepositoryBookmarkClient {
    get { self[RepositoryBookmarkClient.self] }
    set { self[RepositoryBookmarkClient.self] = newValue }
  }
}

nonisolated enum RepositorySecurityScopedAccess {
  private struct StoredBookmark {
    let path: String
    let bookmarkData: Data
  }

  final class Session {
    let url: URL
    private var startedAccessing: Bool

    fileprivate init(requestedURL: URL, resolvedURL: URL) {
      url = resolvedURL
      startedAccessing = resolvedURL.startAccessingSecurityScopedResource()
      RepositorySecurityScopedAccess.persistBookmarkIfPossible(for: requestedURL)
    }

    deinit {
      stop()
    }

    func stop() {
      guard startedAccessing else { return }
      url.stopAccessingSecurityScopedResource()
      startedAccessing = false
    }
  }

  static func makeBookmarkData(for url: URL) -> Data? {
    let normalizedURL = url.standardizedFileURL
    do {
      return try normalizedURL.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    } catch {
      repositoryBookmarkLogger.warning(
        "Unable to create bookmark for \(normalizedURL.path(percentEncoded: false)): \(error.localizedDescription)"
      )
      return nil
    }
  }

  static func makeSession(for url: URL) -> Session {
    let normalizedURL = url.standardizedFileURL
    return Session(
      requestedURL: normalizedURL,
      resolvedURL: resolvedURL(for: normalizedURL)
    )
  }

  static func withAccess<T>(
    to url: URL,
    operation: @Sendable (URL) async -> T
  ) async -> T {
    let session = makeSession(for: url)
    return await operation(session.url)
  }

  static func withAccess<T>(
    to url: URL,
    operation: @Sendable (URL) async throws -> T
  ) async throws -> T {
    let session = makeSession(for: url)
    return try await operation(session.url)
  }

  private static func resolvedURL(for url: URL) -> URL {
    let normalizedURL = url.standardizedFileURL
    guard let bookmark = bookmark(matching: normalizedURL) else { return normalizedURL }
    return resolvedURL(for: bookmark.path, bookmarkData: bookmark.bookmarkData)
  }

  private static func bookmark(matching url: URL) -> StoredBookmark? {
    @Shared(.repositoryEntries) var entries: [PersistedRepositoryEntry]
    @Shared(.securityScopedBookmarks) var securityScopedBookmarks: [String: Data]
    let targetPath = url.path(percentEncoded: false)

    let persistedBookmarks = entries.compactMap { entry -> StoredBookmark? in
      guard let bookmarkData = entry.bookmarkData else { return nil }
      let normalizedPath = URL(fileURLWithPath: entry.path).standardizedFileURL.path(percentEncoded: false)
      return StoredBookmark(path: normalizedPath, bookmarkData: bookmarkData)
    }
    let dynamicBookmarks = securityScopedBookmarks.map { path, bookmarkData in
      let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path(percentEncoded: false)
      return StoredBookmark(path: normalizedPath, bookmarkData: bookmarkData)
    }
    let allBookmarks = persistedBookmarks + dynamicBookmarks

    return allBookmarks.reduce(into: StoredBookmark?.none) { current, bookmark in
      guard targetPath == bookmark.path || targetPath.hasPrefix("\(bookmark.path)/") else { return }
      guard let bestMatch = current else {
        current = bookmark
        return
      }
      if bookmark.path.count > bestMatch.path.count {
        current = bookmark
      }
    }
  }

  private static func resolvedURL(for path: String, bookmarkData: Data) -> URL {
    let fallbackURL = URL(fileURLWithPath: path).standardizedFileURL
    var isStale = false
    do {
      let resolvedURL = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ).standardizedFileURL
      if isStale {
        repositoryBookmarkLogger.warning(
          "Bookmark is stale for \(path); continuing with resolved URL"
        )
      }
      return resolvedURL
    } catch {
      repositoryBookmarkLogger.warning(
        "Unable to resolve bookmark for \(path): \(error.localizedDescription)"
      )
      return fallbackURL
    }
  }

  private static func persistBookmarkIfPossible(for url: URL) {
    let bookmarkTargetURL = bookmarkTargetURL(for: url)
    let bookmarkPath = bookmarkTargetURL.path(percentEncoded: false)
    @Shared(.securityScopedBookmarks) var securityScopedBookmarks: [String: Data]
    let normalizedBookmarks = SecurityScopedBookmarkNormalizer.normalize(securityScopedBookmarks)
    if normalizedBookmarks[bookmarkPath] != nil { return }
    guard let bookmarkData = makeBookmarkData(for: bookmarkTargetURL) else { return }
    $securityScopedBookmarks.withLock {
      var updated = SecurityScopedBookmarkNormalizer.normalize($0)
      updated[bookmarkPath] = bookmarkData
      $0 = updated
    }
  }

  private static func bookmarkTargetURL(for url: URL) -> URL {
    let normalizedURL = url.standardizedFileURL
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(
      atPath: normalizedURL.path(percentEncoded: false),
      isDirectory: &isDirectory
    ), !isDirectory.boolValue {
      return normalizedURL.deletingLastPathComponent()
    }
    return normalizedURL
  }
}

private nonisolated let repositoryBookmarkLogger = SupaLogger("RepositoryBookmarks")
