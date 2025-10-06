import CodexTUI
import Foundation

final class DemoController {
  private let app       : Application
  private let logBuffer : ScrollBuffer

  init () {
    logBuffer = ScrollBuffer()
    app       = Application(
      menuBar : MenuBar(
        items: [
          MenuItem(
            key      : "F",
            title    : "File",
            alignment: .leading
          ) {
            MessageBox(
              title  : "File",
              message: ["New", "Open", "Save"],
              buttons: ["Close"]
            )
          }
        ]
      ),
      statusBar: StatusBar(
        items: [
          StatusItem(
            text      : "Press Ctrl+Q to quit",
            alignment : .leading
          ),
          StatusItem(
            text      : DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short),
            alignment : .trailing
          )
        ]
      ),
      content  : SplitView(
        orientation: .vertical,
        leading    : TextView(
          title : "Activity",
          buffer: logBuffer
        ),
        trailing   : TextView(
          title : "Details",
          buffer: ScrollBuffer()
        )
      )
    )

    app.bind(key: .control("q")) { [weak self] in self?.app.stop() }
    app.bind(key: .function(2)) { [weak self] in self?.showInfoBox() }
  }

  func run () {
    logBuffer.append("CodexTUI demo started")
    app.run()
  }

  private func showInfoBox () {
    app.present(
      MessageBox(
        title  : "CodexTUI",
        message: ["Build expressive TUIs in Swift."],
        buttons: ["OK"]
      )
    )
  }
}

DemoController().run()
