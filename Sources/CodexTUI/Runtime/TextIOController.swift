import Foundation
import TerminalInput

/// Routes keyboard text tokens from the currently focused buffer to its bound text channel and
/// bridges asynchronous channel updates back into the render loop.
public final class TextIOController {
  public var scene         : Scene
  public var onNeedsRedraw : ( () -> Void )?

  private var buffers : [FocusIdentifier: TextBuffer]

  public init ( scene: Scene, buffers: [TextBuffer] = [] ) {
    self.scene   = scene
    self.buffers = [:]
    self.onNeedsRedraw = nil

    for buffer in buffers {
      register(buffer: buffer)
    }
  }

  public func register ( buffer: TextBuffer ) {
    guard buffer.isInteractive else { return }

    buffers[buffer.focusIdentifier] = buffer

    let existing = buffer.onNeedsDisplay
    buffer.onNeedsDisplay = { [weak self, weak buffer] in
      existing?()
      guard let self = self, let buffer = buffer else { return }
      guard let tracked = self.buffers[buffer.focusIdentifier], tracked === buffer else { return }
      self.onNeedsRedraw?()
    }
  }

  public func unregister ( identifier: FocusIdentifier ) {
    buffers.removeValue(forKey: identifier)
  }

  public func buffer ( for identifier: FocusIdentifier ) -> TextBuffer? {
    return buffers[identifier]
  }

  @discardableResult
  public func handle ( token: TerminalInput.Token ) -> Bool {
    guard case .text(let string) = token else { return false }
    guard string.isEmpty == false else { return true }
    guard let focus = scene.focusChain.active else { return false }
    guard let buffer = buffers[focus] else { return false }
    guard let channel = buffer.textIOChannel else { return false }

    channel.send(string)
    return true
  }
}
