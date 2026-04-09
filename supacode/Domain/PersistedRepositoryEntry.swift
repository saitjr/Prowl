import Foundation

nonisolated struct PersistedRepositoryEntry: Codable, Equatable, Sendable {
  let path: String
  let kind: Repository.Kind
  let bookmarkData: Data?

  init(
    path: String,
    kind: Repository.Kind,
    bookmarkData: Data? = nil
  ) {
    self.path = path
    self.kind = kind
    self.bookmarkData = bookmarkData
  }
}
