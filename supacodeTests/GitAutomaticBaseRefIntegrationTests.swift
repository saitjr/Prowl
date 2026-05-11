import Foundation
import Testing

@testable import supacode

struct GitAutomaticBaseRefIntegrationTests {
  @Test func fallsBackToLocalHeadForBareRepo() async throws {
    let tempRoot = URL(filePath: "/tmp", directoryHint: .isDirectory)
    let id = UUID().uuidString
    let bareURL = tempRoot.appending(
      path: "supacode-bare-\(id).git",
      directoryHint: URL.DirectoryHint.isDirectory
    )
    let workURL = tempRoot.appending(
      path: "supacode-work-\(id)",
      directoryHint: URL.DirectoryHint.isDirectory
    )
    defer {
      try? FileManager.default.removeItem(at: bareURL)
      try? FileManager.default.removeItem(at: workURL)
    }

    try runGit(["init", workURL.path(percentEncoded: false)])
    try runGit(["-C", workURL.path(percentEncoded: false), "config", "user.email", "test@example.com"])
    try runGit(["-C", workURL.path(percentEncoded: false), "config", "user.name", "Test User"])

    let readmeURL = workURL.appending(path: "README.md")
    try "hello".write(to: readmeURL, atomically: true, encoding: .utf8)
    try runGit(["-C", workURL.path(percentEncoded: false), "add", "README.md"])
    try runGit(["-C", workURL.path(percentEncoded: false), "commit", "-m", "init"])
    try runGit(["-C", workURL.path(percentEncoded: false), "branch", "-M", "main"])

    try runGit(["init", "--bare", bareURL.path(percentEncoded: false)])
    try runGit([
      "-C", workURL.path(percentEncoded: false),
      "remote", "add", "origin", bareURL.path(percentEncoded: false),
    ])
    try runGit(["-C", workURL.path(percentEncoded: false), "push", "-u", "origin", "main"])
    try runGit(["--git-dir", bareURL.path(percentEncoded: false), "symbolic-ref", "HEAD", "refs/heads/main"])

    let baseRef = await GitClient().automaticWorktreeBaseRef(for: bareURL)
    #expect(baseRef == "main")
  }
}

private struct GitCommandError: Error {
  let output: String
}

@discardableResult
private func runGit(_ arguments: [String]) throws -> String {
  let process = Process()
  process.executableURL = try resolvedGitExecutableURL()
  process.arguments = arguments
  var environment = ProcessInfo.processInfo.environment
  environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
  environment["PATH"] = [
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ].joined(separator: ":")
  process.environment = environment
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = pipe
  try process.run()
  process.waitUntilExit()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8) ?? ""
  if process.terminationStatus != 0 {
    throw GitCommandError(output: output)
  }
  return output
}

private func resolvedGitExecutableURL() throws -> URL {
  let fileManager = FileManager.default
  let candidates = [
    "/opt/homebrew/bin/git",
    "/usr/local/bin/git",
    "/usr/bin/git",
  ]

  if let path = candidates.first(where: fileManager.isExecutableFile(atPath:)) {
    return URL(fileURLWithPath: path)
  }

  throw GitCommandError(output: "Could not locate an executable git binary")
}
