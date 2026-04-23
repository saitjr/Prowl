import ComposableArchitecture
import Foundation

struct GitClientDependency: Sendable {
  var repoRoot: @Sendable (URL) async throws -> URL
  var worktrees: @Sendable (URL) async throws -> [Worktree]
  var pruneWorktrees: @Sendable (URL) async throws -> Void
  var localBranchNames: @Sendable (URL) async throws -> Set<String>
  var isValidBranchName: @Sendable (String, URL) async -> Bool
  var branchRefs: @Sendable (URL) async throws -> [String]
  var defaultRemoteBranchRef: @Sendable (URL) async throws -> String?
  var automaticWorktreeBaseRef: @Sendable (URL) async -> String?
  var ignoredFileCount: @Sendable (URL) async throws -> Int
  var untrackedFileCount: @Sendable (URL) async throws -> Int
  var createWorktree:
    @Sendable (
      _ name: String,
      _ repoRoot: URL,
      _ baseDirectory: URL,
      _ copyIgnored: Bool,
      _ copyUntracked: Bool,
      _ baseRef: String
    ) async throws
      -> Worktree
  var createWorktreeStream:
    @Sendable (
      _ name: String,
      _ repoRoot: URL,
      _ baseDirectory: URL,
      _ copyIgnored: Bool,
      _ copyUntracked: Bool,
      _ baseRef: String
    ) -> AsyncThrowingStream<GitWorktreeCreateEvent, Error>
  var removeWorktree: @Sendable (_ worktree: Worktree, _ deleteBranch: Bool) async throws -> URL
  var isBareRepository: @Sendable (_ repoRoot: URL) async throws -> Bool
  var branchName: @Sendable (URL) async -> String?
  var lineChanges: @Sendable (URL) async -> (added: Int, removed: Int)?
  var renameBranch: @Sendable (_ worktreeURL: URL, _ branchName: String) async throws -> Void
  var repositoryWebURL: @Sendable (_ repositoryRoot: URL) async -> URL?
  var remoteInfo: @Sendable (_ repositoryRoot: URL) async -> GithubRemoteInfo?
  var remoteNames: @Sendable (_ repoRoot: URL) async throws -> [String]
  var fetchRemote: @Sendable (_ remote: String, _ repoRoot: URL) async throws -> Void
}

extension GitClientDependency: DependencyKey {
  static let liveValue = GitClientDependency(
    repoRoot: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().repoRoot(for: accessibleURL)
      }
    },
    worktrees: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().worktrees(for: accessibleURL)
      }
    },
    pruneWorktrees: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().pruneWorktrees(for: accessibleURL)
      }
    },
    localBranchNames: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().localBranchNames(for: accessibleURL)
      }
    },
    isValidBranchName: { branchName, repoRoot in
      await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleURL in
        await GitClient().isValidBranchName(branchName, for: accessibleURL)
      }
    },
    branchRefs: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().branchRefs(for: accessibleURL)
      }
    },
    defaultRemoteBranchRef: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().defaultRemoteBranchRef(for: accessibleURL)
      }
    },
    automaticWorktreeBaseRef: { url in
      await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        await GitClient().automaticWorktreeBaseRef(for: accessibleURL)
      }
    },
    ignoredFileCount: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().ignoredFileCount(for: accessibleURL)
      }
    },
    untrackedFileCount: { url in
      try await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        try await GitClient().untrackedFileCount(for: accessibleURL)
      }
    },
    createWorktree: { name, repoRoot, baseDirectory, copyIgnored, copyUntracked, baseRef in
      try await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleRepoRoot in
        try await RepositorySecurityScopedAccess.withAccess(to: baseDirectory) { accessibleBaseDirectory in
          try await GitClient().createWorktree(
            named: name,
            in: accessibleRepoRoot,
            baseDirectory: accessibleBaseDirectory,
            copyFiles: (ignored: copyIgnored, untracked: copyUntracked),
            baseRef: baseRef
          )
        }
      }
    },
    createWorktreeStream: { name, repoRoot, baseDirectory, copyIgnored, copyUntracked, baseRef in
      AsyncThrowingStream { continuation in
        let task = Task {
          do {
            try await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleRepoRoot in
              try await RepositorySecurityScopedAccess.withAccess(to: baseDirectory) { accessibleBaseDirectory in
                let stream = GitClient().createWorktreeStream(
                  named: name,
                  in: accessibleRepoRoot,
                  baseDirectory: accessibleBaseDirectory,
                  copyFiles: (ignored: copyIgnored, untracked: copyUntracked),
                  baseRef: baseRef
                )
                for try await event in stream {
                  continuation.yield(event)
                }
              }
            }
            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
          }
        }
        continuation.onTermination = { _ in
          task.cancel()
        }
      }
    },
    removeWorktree: { worktree, deleteBranch in
      try await RepositorySecurityScopedAccess.withAccess(to: worktree.workingDirectory) { accessibleWorktreeURL in
        let accessibleWorktree = Worktree(
          id: worktree.id,
          name: worktree.name,
          detail: worktree.detail,
          workingDirectory: accessibleWorktreeURL,
          repositoryRootURL: worktree.repositoryRootURL,
          createdAt: worktree.createdAt
        )
        return try await GitClient().removeWorktree(accessibleWorktree, deleteBranch: deleteBranch)
      }
    },
    isBareRepository: { repoRoot in
      try await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleURL in
        try await GitClient().isBareRepository(for: accessibleURL)
      }
    },
    branchName: { url in
      await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        await GitClient().branchName(for: accessibleURL)
      }
    },
    lineChanges: { url in
      await RepositorySecurityScopedAccess.withAccess(to: url) { accessibleURL in
        await GitClient().lineChanges(at: accessibleURL)
      }
    },
    renameBranch: { worktreeURL, branchName in
      try await RepositorySecurityScopedAccess.withAccess(to: worktreeURL) { accessibleURL in
        try await GitClient().renameBranch(in: accessibleURL, to: branchName)
      }
    },
    repositoryWebURL: { repositoryRoot in
      await GitClient().repositoryWebURL(for: repositoryRoot)
    },
    remoteInfo: { repositoryRoot in
      await RepositorySecurityScopedAccess.withAccess(to: repositoryRoot) { accessibleURL in
        await GitClient().remoteInfo(for: accessibleURL)
      }
    },
    remoteNames: { repoRoot in
      try await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleURL in
        try await GitClient().remoteNames(for: accessibleURL)
      }
    },
    fetchRemote: { remote, repoRoot in
      try await RepositorySecurityScopedAccess.withAccess(to: repoRoot) { accessibleURL in
        try await GitClient().fetchRemote(remote, for: accessibleURL)
      }
    }
  )
  static let testValue = liveValue
}

extension DependencyValues {
  var gitClient: GitClientDependency {
    get { self[GitClientDependency.self] }
    set { self[GitClientDependency.self] = newValue }
  }
}
