import Foundation
import Dispatch
import TerminalInput
import TerminalOutput
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Controls how the driver initialises and interacts with the terminal.
public struct RuntimeConfiguration {
  public var initialBounds      : BoxBounds
  /// Controls whether the driver switches to the terminal's alternate buffer.
  /// When enabled the driver also clears the scrollback buffer so previous history is hidden before the first frame is rendered.
  public var usesAlternateBuffer: Bool
  public var hidesCursor        : Bool

  public init ( initialBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24), usesAlternateBuffer: Bool = true, hidesCursor: Bool = true ) {
    self.initialBounds       = initialBounds
    self.usesAlternateBuffer = usesAlternateBuffer
    self.hidesCursor         = hidesCursor
  }
}

/// Orchestrates input handling, scene rendering and terminal lifecycle management. The driver takes
/// ownership of the terminal while running and ensures the display is kept in sync with scene updates.
public final class TerminalDriver {
  /// Lifecycle states the driver can occupy.
  public enum State {
    case stopped
    case running
    case suspended
  }

  public var configuration         : RuntimeConfiguration
  public var scene                 : Scene
  public private(set) var state    : State

  public var onKeyEvent            : ( (TerminalInput.Token) -> Void )?
  public var onResize              : ( (BoxBounds) -> Void )?
  public var textEntryBoxController: TextEntryBoxController? {
    didSet {
      textEntryBoxController?.update(viewportBounds: currentBounds)
    }
  }
  public var messageBoxController  : MessageBoxController? {
    didSet {
      messageBoxController?.update(viewportBounds: currentBounds)
    }
  }
  public var selectionListController: SelectionListController? {
    didSet {
      selectionListController?.update(viewportBounds: currentBounds)
    }
  }
  public var menuController        : MenuController? {
    didSet {
      menuController?.update(viewportBounds: currentBounds)
    }
  }

  private let input               : TerminalInput
  private let terminal            : TerminalOutput.Terminal
  private let terminalMode        : TerminalModeController
  private let inputQueue          : DispatchQueue
  private var inputSource         : DispatchSourceRead?
  private var surface             : Surface
  private var signalObserver      : SignalObserver
  private var currentBounds       : BoxBounds

  public init ( scene: Scene, terminal: TerminalOutput.Terminal, input: TerminalInput, terminalMode: TerminalModeController = TerminalModeController(), configuration: RuntimeConfiguration = RuntimeConfiguration(), signalObserver: SignalObserver = SignalObserver() ) {
    self.scene           = scene
    self.terminal        = terminal
    self.input           = input
    self.terminalMode    = terminalMode
    self.configuration   = configuration
    self.signalObserver  = signalObserver
    self.currentBounds   = configuration.initialBounds
    self.surface         = Surface(width: configuration.initialBounds.width, height: configuration.initialBounds.height)
    self.state           = .stopped
    self.inputQueue      = DispatchQueue(label: "CodexTUI.TerminalDriver.Input")
  }

  // Boots the driver, taking ownership of terminal state and performing an initial render.
  public func start () {
    guard state == .stopped else { return }

    state = .running
    terminalMode.enterRawMode()
    configureInput()
    configureSignalObserver()
    enterScreen()
    if let size = measureTerminalSize() {
      handleResize(width: size.width, height: size.height)
    } else {
      redraw()
    }
  }

  // Releases terminal mutations while keeping the scene in memory.
  public func suspend () {
    guard state == .running else { return }

    state = .suspended
    terminalMode.restore()
    exitScreen()
    cancelInputSource()
  }

  // Re-acquires the terminal and refreshes the display after a suspension.
  public func resume () {
    guard state == .suspended else { return }

    state = .running
    terminalMode.enterRawMode()
    configureInput()
    enterScreen()
    if let size = measureTerminalSize() {
      handleResize(width: size.width, height: size.height)
    } else {
      redraw()
    }
  }

  // Stops all processing and restores the terminal to its original state.
  public func stop () {
    guard state != .stopped else { return }

    state = .stopped
    signalObserver.stop()
    terminalMode.restore()
    exitScreen()
    cancelInputSource()
    input.dispatch = nil
  }

  // Renders the scene hierarchy into terminal commands. Failures are intentionally swallowed to keep the UI responsive.
  public func redraw () {
    guard state == .running else { return }

    do {
      let sequences = scene.render(into: &surface, bounds: currentBounds)
      try terminal.perform(sequences)
      try terminal.flush()
    } catch {
      // Rendering failures should not crash the driver, but they can be surfaced via logging hooks in the future.
    }
  }

  // Updates the backing surface when the terminal reports a new size and informs listeners.
  public func handleResize ( width: Int, height: Int ) {
    currentBounds = BoxBounds(row: 1, column: 1, width: width, height: height)
    textEntryBoxController?.update(viewportBounds: currentBounds)
    messageBoxController?.update(viewportBounds: currentBounds)
    selectionListController?.update(viewportBounds: currentBounds)
    menuController?.update(viewportBounds: currentBounds)
    onResize?(currentBounds)
    redraw()
  }

  // Registers a dispatch closure that converts raw tokens into high level key events.
  private func configureInput () {
    input.dispatch = { [weak self] result in
      switch result {
        case .success(let token):
          self?.route(token: token)
        case .failure:
          break
      }
    }

    guard inputSource == nil else { return }

    let fileHandle     = FileHandle.standardInput
    let fileDescriptor = fileHandle.fileDescriptor
    let source         = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: inputQueue)

    source.setEventHandler { [weak self] in
      guard let self = self else { return }

      let available = Int(source.data)
      guard available > 0 else { return }

      let data = fileHandle.readData(ofLength: available)
      guard data.isEmpty == false else { return }

      self.input.enqueue(data)
    }

    source.setCancelHandler { [weak self] in
      self?.inputSource = nil
    }

    inputSource = source
    source.resume()
  }

  private func cancelInputSource () {
    inputSource?.cancel()
    inputSource = nil
  }

  // Subscribe to SIGWINCH so we can redraw when the user resizes the terminal window.
  private func configureSignalObserver () {
    signalObserver.setHandler { [weak self] in
      guard let self = self else { return }
      if let size = self.measureTerminalSize() {
        self.handleResize(width: size.width, height: size.height)
      } else {
        self.handleResize(width: self.currentBounds.width, height: self.currentBounds.height)
      }
    }
    signalObserver.start()
  }

  // Emits terminal tokens to the driver callbacks when active.
  private func route ( token: TerminalInput.Token ) {
    guard state == .running else { return }
    if let controller = textEntryBoxController, controller.handle(token: token) {
      redraw()
      return
    }
    if let controller = messageBoxController, controller.handle(token: token) {
      redraw()
      return
    }

    if let controller = selectionListController, controller.handle(token: token) {
      redraw()
      return
    }

    if let controller = menuController, controller.handle(token: token) {
      redraw()
      return
    }

    onKeyEvent?(token)
  }

  // Applies configuration specific terminal commands such as switching buffers or hiding the cursor.
  private func enterScreen () {
    do {
      var sequences : [AnsiSequence] = []

      if configuration.usesAlternateBuffer {
        sequences.append(TerminalOutput.TerminalCommands.useAlternateBuffer())
        sequences.append(TerminalOutput.TerminalCommand.clearScrollback.sequence)
      }

      if configuration.hidesCursor {
        sequences.append(TerminalOutput.TerminalCommands.hideCursor())
      }

      guard sequences.isEmpty == false else { return }

      try terminal.perform(sequences)
      try terminal.flush()
    } catch { }
  }

  // Restores the terminal to its original settings when leaving the UI.
  private func exitScreen () {
    do {
      if configuration.hidesCursor {
        try terminal.perform([TerminalOutput.TerminalCommands.showCursor()])
      }
      if configuration.usesAlternateBuffer {
        try terminal.perform([TerminalOutput.TerminalCommands.usePrimaryBuffer()])
      }
      try terminal.flush()
    } catch { }
  }

  private func measureTerminalSize () -> (width: Int, height: Int)? {
    var windowSize = winsize()
    let result     = withUnsafeMutablePointer(to: &windowSize) { pointer -> Int32 in
      return ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), pointer)
    }
    guard result == 0 else { return nil }

    let width  = Int(windowSize.ws_col)
    let height = Int(windowSize.ws_row)
    guard width > 0 && height > 0 else { return nil }

    return (width, height)
  }
}
