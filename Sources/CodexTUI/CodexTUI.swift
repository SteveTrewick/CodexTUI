import Foundation
import TerminalInput
import TerminalOutput

// The public namespace that wraps convenience factories for bootstrapping a CodexTUI runtime.
public enum CodexTUI {
  // Creates a ready-to-run driver hooked up to the process STDIN/STDOUT and configured using sane defaults.
  // The helper performs the low level TerminalInput/TerminalOutput wiring so the caller only needs to provide a Scene.
  public static func makeDriver ( scene: Scene, configuration: RuntimeConfiguration = RuntimeConfiguration() ) -> TerminalDriver {
    let connection = TerminalOutput.FileHandleTerminalConnection()
    let terminal   = TerminalOutput.Terminal(connection: connection)
    let input      = TerminalInput()

    return TerminalDriver(scene: scene, terminal: terminal, input: input, configuration: configuration)
  }
}
