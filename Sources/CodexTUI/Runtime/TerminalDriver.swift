import Foundation
import Dispatch
import TerminalInput
import TerminalOutput

// Controls how the driver initialises and interacts with the terminal.
public struct RuntimeConfiguration {
  public var initialBounds      : BoxBounds
  public var usesAlternateBuffer: Bool
  public var hidesCursor        : Bool

  public init ( initialBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24), usesAlternateBuffer: Bool = true, hidesCursor: Bool = true ) {
    self.initialBounds       = initialBounds
    self.usesAlternateBuffer = usesAlternateBuffer
    self.hidesCursor         = hidesCursor
  }
}

// Orchestrates input handling, scene rendering and terminal lifecycle management.
public final class TerminalDriver {
  public enum State {
    case stopped
    case running
    case suspended
  }

  public var configuration       : RuntimeConfiguration
  public var scene                : Scene
  public private(set) var state   : State

  public var onKeyEvent : ( (KeyEvent) -> Void )?
  public var onResize   : ( (BoxBounds) -> Void )?

  private let input           : TerminalInput
  private let terminal        : TerminalOutput.Terminal
  private let terminalMode    : TerminalModeController
  private var surface         : Surface
  private var signalObserver  : SignalObserver
  private var currentBounds   : BoxBounds

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
  }

  // Boots the driver, taking ownership of terminal state and performing an initial render.
  public func start () {
    guard state == .stopped else { return }

    state = .running
    terminalMode.enterRawMode()
    configureInput()
    configureSignalObserver()
    enterScreen()
    redraw()
  }

  // Releases terminal mutations while keeping the scene in memory.
  public func suspend () {
    guard state == .running else { return }

    state = .suspended
    terminalMode.restore()
    exitScreen()
  }

  // Re-acquires the terminal and refreshes the display after a suspension.
  public func resume () {
    guard state == .suspended else { return }

    state = .running
    terminalMode.enterRawMode()
    enterScreen()
    redraw()
  }

  // Stops all processing and restores the terminal to its original state.
  public func stop () {
    guard state != .stopped else { return }

    state = .stopped
    signalObserver.stop()
    terminalMode.restore()
    exitScreen()
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
  }

  // Subscribe to SIGWINCH so we can redraw when the user resizes the terminal window.
  private func configureSignalObserver () {
    signalObserver.setHandler { [weak self] in
      guard let self = self else { return }
      self.handleResize(width: self.currentBounds.width, height: self.currentBounds.height)
    }
    signalObserver.start()
  }

  // Converts terminal tokens into semantic events and emits them to the driver callbacks.
  private func route ( token: TerminalInput.Token ) {
    guard state == .running else { return }

    guard let event = KeyEvent.from(token: token) else { return }
    onKeyEvent?(event)
  }

  // Applies configuration specific terminal commands such as switching buffers or hiding the cursor.
  private func enterScreen () {
    do {
      if configuration.usesAlternateBuffer {
        try terminal.perform([TerminalOutput.TerminalCommands.useAlternateBuffer()])
      }
      if configuration.hidesCursor {
        try terminal.perform([TerminalOutput.TerminalCommands.hideCursor()])
      }
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
}
