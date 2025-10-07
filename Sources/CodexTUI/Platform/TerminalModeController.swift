import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Captures terminal attributes and toggles the descriptor between cooked and raw modes. Exposed as
/// an open class so platform-specific subclasses can extend the behaviour if required.
open class TerminalModeController {
  private let descriptor       : Int32
  private var originalSettings : termios?
  private var isRawModeActive  : Bool

  public init ( fileDescriptor: Int32 = FileHandle.standardInput.fileDescriptor ) {
    self.descriptor       = fileDescriptor
    self.originalSettings = TerminalModeController.captureAttributes(of: fileDescriptor)
    self.isRawModeActive  = false
  }

  /// Applies raw mode so key presses are delivered immediately without buffering.
  open func enterRawMode () {
    guard isRawModeActive == false else { return }
    guard var attributes = TerminalModeController.captureAttributes(of: descriptor) else { return }

    cfmakeraw(&attributes)

    if tcsetattr(descriptor, TCSANOW, &attributes) == 0 {
      isRawModeActive = true
    }
  }

  /// Restores the descriptor to the previously captured cooked mode settings.
  open func restore () {
    guard isRawModeActive else { return }
    guard var attributes = originalSettings else { return }

    if tcsetattr(descriptor, TCSANOW, &attributes) == 0 {
      isRawModeActive = false
    }
  }

  private static func captureAttributes ( of descriptor: Int32 ) -> termios? {
    var attributes = termios()

    if tcgetattr(descriptor, &attributes) == 0 {
      return attributes
    }

    return nil
  }
}
