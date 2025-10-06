import Foundation
import TerminalInput
import TerminalOutput

public enum CodexTUI {
  public static func makeDriver ( scene: Scene, configuration: RuntimeConfiguration = RuntimeConfiguration() ) -> TerminalDriver {
    let connection = TerminalOutput.FileHandleTerminalConnection()
    let terminal   = TerminalOutput.Terminal(connection: connection)
    let input      = TerminalInput()

    return TerminalDriver(scene: scene, terminal: terminal, input: input, configuration: configuration)
  }
}
