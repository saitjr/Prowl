import Foundation

enum SettingsSection: Hashable {
  case general
  case notifications
  case shortcuts
  case hotkeyWindow
  case worktree
  case updates
  case advanced
  case github
  case repository(Repository.ID)
}
