import AppKit
import ComposableArchitecture
import SwiftUI

struct HotkeyWindowSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  @State private var isRecordingShortcut = false
  @State private var recorderMonitor: Any?
  @State private var invalidMessage: String?

  private let keyTokenResolver = ShortcutKeyTokenResolver()

  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section("Activation") {
          Toggle(
            "Enable hotkey window",
            isOn: $store.hotkeyWindow.isEnabled
          )
          .help("Register the configured global hotkey and let it toggle the main Prowl window")

          LabeledContent("Shortcut") {
            shortcutRecorder
          }

          if let invalidMessage {
            Text(invalidMessage)
              .font(.callout)
              .foregroundStyle(.red)
          } else if store.hotkeyWindow.isEnabled, store.hotkeyWindow.hotkey == nil {
            Text("Choose a shortcut before enabling the hotkey window.")
              .font(.callout)
              .foregroundStyle(.secondary)
          } else {
            Text("The hotkey toggles the existing main window instead of opening a separate utility window.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }

        Section("Window Layout") {
          ratioRow(
            title: "Width",
            value: $store.hotkeyWindow.widthRatio,
            range: HotkeyWindowSettings.widthRatioRange
          )
          .help("Set the hotkey window width as a percentage of the active display")

          ratioRow(
            title: "Height",
            value: $store.hotkeyWindow.heightRatio,
            range: HotkeyWindowSettings.heightRatioRange
          )
          .help("Set the hotkey window height as a percentage of the active display")

          minimumSizeRow(
            title: "Minimum Width",
            value: $store.hotkeyWindow.minimumWidth,
            range: HotkeyWindowSettings.minimumWidthRange
          )
          .help("When display metrics look wrong, Prowl will not size the hotkey window narrower than this fallback width")

          minimumSizeRow(
            title: "Minimum Height",
            value: $store.hotkeyWindow.minimumHeight,
            range: HotkeyWindowSettings.minimumHeightRange
          )
          .help("When display metrics look wrong, Prowl will not size the hotkey window shorter than this fallback height")

          LabeledContent("Alignment") {
            Text("Centered horizontally, bottom aligned")
              .foregroundStyle(.secondary)
          }

          Text(layoutSummary)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
    }
    .onChange(of: isRecordingShortcut) { _, newValue in
      if newValue {
        startRecorderMonitor()
      } else {
        stopRecorderMonitor()
      }
    }
    .onDisappear {
      stopRecorderMonitor()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var shortcutRecorder: some View {
    HStack(spacing: 8) {
      Button {
        isRecordingShortcut.toggle()
        if isRecordingShortcut {
          invalidMessage = nil
        }
      } label: {
        HStack(spacing: 6) {
          if isRecordingShortcut {
            Image(systemName: "record.circle.fill")
              .font(.caption)
              .foregroundStyle(Color.accentColor)
              .accessibilityHidden(true)
          }
          Text(shortcutTitle)
            .font(.body.monospaced())
            .frame(minWidth: 120, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
        )
      }
      .buttonStyle(.plain)
      .help(isRecordingShortcut ? "Press a shortcut to record it, or Esc to cancel" : "Record hotkey window shortcut")

      if store.hotkeyWindow.hotkey != nil {
        Button("Reset") {
          store.send(.setHotkeyWindowHotkey(HotkeyWindowSettings.default.hotkey))
          invalidMessage = nil
          isRecordingShortcut = false
        }
        .buttonStyle(.link)
        .help("Reset the hotkey window shortcut to the default value")
      }
    }
  }

  private var shortcutTitle: String {
    if isRecordingShortcut {
      return "Recording..."
    }
    if let binding = store.hotkeyWindow.hotkey {
      return binding.display
    }
    return "Not Set"
  }

  private var layoutSummary: String {
    let width = Int((store.hotkeyWindow.widthRatio * 100).rounded())
    let height = Int((store.hotkeyWindow.heightRatio * 100).rounded())
    let minimumWidth = Int(store.hotkeyWindow.minimumWidth.rounded())
    let minimumHeight = Int(store.hotkeyWindow.minimumHeight.rounded())
    return
      "On show, Prowl will resize to \(width)% width and \(height)% height of the active display, "
      + "with a fallback minimum size of \(minimumWidth) × \(minimumHeight)."
  }

  private func ratioRow(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    LabeledContent(title) {
      HStack(spacing: 12) {
        Slider(
          value: value,
          in: range,
          step: 0.05
        )
        .frame(width: 220)
        Text("\(Int((value.wrappedValue * 100).rounded()))%")
          .font(.body.monospaced())
          .foregroundStyle(.secondary)
          .frame(width: 48, alignment: .trailing)
      }
    }
  }

  private func minimumSizeRow(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    LabeledContent(title) {
      HStack(spacing: 12) {
        Stepper(
          value: value,
          in: range,
          step: 20
        ) {
          Text("\(Int(value.wrappedValue.rounded())) pt")
            .font(.body.monospaced())
            .frame(minWidth: 88, alignment: .trailing)
        }
      }
    }
  }

  private func startRecorderMonitor() {
    stopRecorderMonitor()
    recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      guard isRecordingShortcut else {
        return event
      }
      handleRecorderEvent(event)
      return nil
    }
  }

  private func stopRecorderMonitor() {
    if let recorderMonitor {
      NSEvent.removeMonitor(recorderMonitor)
      self.recorderMonitor = nil
    }
  }

  private func handleRecorderEvent(_ event: NSEvent) {
    if event.keyCode == 53 {
      isRecordingShortcut = false
      return
    }

    guard let keyToken = keyTokenResolver.resolveKeyToken(
      keyCode: event.keyCode,
      charactersIgnoringModifiers: event.charactersIgnoringModifiers
    ) else {
      invalidMessage =
        "That key isn't supported for hotkey window shortcuts yet. "
        + "Try letters, numbers, punctuation, Space, Return, or arrow keys."
      return
    }

    let modifiers = KeybindingModifiers(
      command: event.modifierFlags.contains(.command),
      shift: event.modifierFlags.contains(.shift),
      option: event.modifierFlags.contains(.option),
      control: event.modifierFlags.contains(.control)
    )

    guard !modifiers.isEmpty else {
      invalidMessage = "Shortcut must include at least one modifier key."
      return
    }

    store.send(.setHotkeyWindowHotkey(Keybinding(key: keyToken, modifiers: modifiers)))
    invalidMessage = nil
    isRecordingShortcut = false
  }
}
