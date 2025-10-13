import CodexTUI
import Foundation
import TerminalInput

struct DSLShowcaseView : ComposableWidget {
  var theme               : Theme
  var featureDescriptions : [String]
  var instructionsBuffer  : TextBuffer

  init ( theme: Theme, featureDescriptions: [String], environmentNotes: [String] ) {
    self.theme               = theme
    self.featureDescriptions = featureDescriptions

    let buffer = TextBuffer(
      identifier    : FocusIdentifier("dsl.notes"),
      lines         : environmentNotes,
      style         : theme.contentDefault,
      highlightStyle: theme.highlight,
      isInteractive : false
    )

    self.instructionsBuffer = buffer
  }

  var body : some Widget {
    OverlayStack {
      Box(style: theme.windowChrome)
      Padding(
        top      : 1,
        leading  : 2,
        bottom   : 1,
        trailing : 2
      ) {
        VStack(spacing: 1) {
          Label(
            "CodexTUI Declarative Layout DSL",
            style     : theme.highlight,
            alignment : .center
          )
          Label(
            "Compose adaptive terminal layouts with expressive containers.",
            style     : theme.contentDefault,
            alignment : .center
          )
          Split(
            axis      : .horizontal,
            firstSize : .proportion(0.45),
            secondSize: .flexible,
            first     : {
              VStack(spacing: 1) {
                Label("Layout building blocks", style: theme.highlight)
                for description in featureDescriptions {
                  Label("• \(description)", style: theme.contentDefault)
                }
                HStack(spacing: 1) {
                  Label("Spacer keeps trailing callouts anchored right.", style: theme.contentDefault)
                  Spacer()
                  Label("⇢", style: theme.dimHighlight)
                }
              }
            },
            second    : {
              Split(
                axis      : .vertical,
                firstSize : .fixed(8),
                secondSize: .flexible,
                first     : {
                  OverlayStack {
                    Box(style: theme.windowChrome)
                    Padding(
                      top      : 1,
                      leading  : 2,
                      bottom   : 1,
                      trailing : 2
                    ) {
                      VStack(spacing: 1) {
                        Label("OverlayStack", style: theme.highlight)
                        Label("Layers backgrounds and content without manual bounds math.", style: theme.contentDefault)
                      }
                    }
                  }
                },
                second    : {
                  VStack(spacing: 1) {
                    Label("Environment-aware buffer", style: theme.highlight)
                    Label("EnvironmentScope customises contentInsets before layout.", style: theme.contentDefault)
                    EnvironmentScope(applying: { values in
                      values.contentInsets = EdgeInsets(
                        top      : 0,
                        leading  : 2,
                        bottom   : 0,
                        trailing : 2
                      )
                    }) {
                      instructionsBuffer
                    }
                  }
                }
              )
            }
          )
          Spacer(minLength: 1)
          Label(
            "Press ESC to exit the demo.",
            style     : theme.dimHighlight,
            alignment : .center
          )
        }
      }
    }
  }
}

final class DSLDemoApplication {
  private let scene  : Scene
  private let driver : TerminalDriver
  private let theme  : Theme

  init () {
    theme = Theme.codex

    let features         = [
      "VStack arranges children vertically and respects spacing.",
      "HStack positions views horizontally while sharing remaining width.",
      "Split divides space using flexible, fixed, and proportional sizing.",
      "Padding adds insets without touching child coordinate math.",
      "OverlayStack layers chrome such as Box behind interactive content."
    ]

    let environmentNotes = [
      "EnvironmentScope modifies inherited layout metadata at any depth.",
      "contentInsets flow to widgets like TextBuffer to produce internal padding.",
      "Resize the terminal to watch the buffer clamp and wrap content."
    ]

    let showcase = DSLShowcaseView(theme: theme, featureDescriptions: features, environmentNotes: environmentNotes)

    let configuration = SceneConfiguration(
      theme        : theme,
      environment  : EnvironmentValues(contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2)),
      showMenuBar  : false,
      showStatusBar: false
    )

    scene = Scene.standard(
      content      : AnyWidget(showcase),
      configuration: configuration,
      focusChain   : FocusChain()
    )

    driver = CodexTUI.makeDriver(scene: scene)

    driver.onKeyEvent = { [weak self] token in
      self?.handle(token: token)
    }
  }

  func run () {
    driver.start()

    let runLoop = RunLoop.current

    while driver.state != .stopped {
      _ = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }
  }

  private func handle ( token: TerminalInput.Token ) {
    if case .escape = token {
      driver.stop()
    }
  }
}

DSLDemoApplication().run()
