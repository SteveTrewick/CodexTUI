import Foundation
import TerminalInput

/// High level builder that assembles a fully wired CodexTUI runtime from declarative
/// menu, status bar and overlay definitions. The builder takes care of constructing the
/// scene, focus chain, controllers and terminal driver so applications only need to
/// describe their UI state and interactions.
public final class CodexApp {
  // MARK: Builder

  public final class Builder {
    public var configuration        : SceneConfiguration
    public var runtimeConfiguration : RuntimeConfiguration
    public var content              : AnyWidget?
    public var menuBar              : MenuBar?
    public var statusBar            : StatusBar?
    public var focusables           : [FocusableWidget]
    public var textBuffers          : [TextBuffer]
    public var initialOverlays      : [AnyWidget]
    public var textEntryStartWidth  : Int?
    public var initialFocus         : FocusIdentifier?
    public var onResize             : ( (BoxBounds) -> Void )?
    public var onUnhandledKey       : ( (TerminalInput.Token) -> Void )?

    public init ( configuration: SceneConfiguration = SceneConfiguration(), runtimeConfiguration: RuntimeConfiguration = RuntimeConfiguration() ) {
      self.configuration        = configuration
      self.runtimeConfiguration = runtimeConfiguration
      self.content              = nil
      self.menuBar              = nil
      self.statusBar            = nil
      self.focusables           = []
      self.textBuffers          = []
      self.initialOverlays      = []
      self.textEntryStartWidth  = nil
      self.initialFocus         = nil
      self.onResize             = nil
      self.onUnhandledKey       = nil
    }

    public func setContent <Content: Widget> ( _ content: Content ) {
      self.content = AnyWidget(content)
    }

    public func addTextBuffer ( _ buffer: TextBuffer ) {
      textBuffers.append(buffer)
      focusables.append(buffer)
    }

    public func addFocusable ( _ focusable: FocusableWidget ) {
      focusables.append(focusable)
    }

    public func build () -> CodexApp {
      let focusChain   = FocusChain()
      let rootContent  = content ?? AnyWidget(OverlayStack { })
      let scene        = Scene.standard(
        menuBar       : menuBar,
        content       : rootContent,
        statusBar     : statusBar,
        configuration : configuration,
        focusChain    : focusChain,
        overlays      : initialOverlays
      )
      let driver       = CodexTUI.makeDriver(scene: scene, configuration: runtimeConfiguration)
      let messageBoxes = MessageBoxController(scene: scene, viewportBounds: runtimeConfiguration.initialBounds)
      let selection    = SelectionListController(scene: scene, viewportBounds: runtimeConfiguration.initialBounds)
      let textEntry    = TextEntryBoxController(scene: scene, viewportBounds: runtimeConfiguration.initialBounds, startWidth: textEntryStartWidth)
      let textIO       = TextIOController(scene: scene)
      let menuCtrl     = menuBar.map {
        MenuController(
          scene          : scene,
          menuBar        : $0,
          content        : rootContent,
          statusBar      : statusBar,
          viewportBounds : runtimeConfiguration.initialBounds
        )
      }

      let app = CodexApp(
        scene                  : scene,
        driver                 : driver,
        menuController         : menuCtrl,
        messageBoxController   : messageBoxes,
        selectionListController: selection,
        textEntryBoxController : textEntry,
        textIOController       : textIO,
        runtimeConfiguration   : runtimeConfiguration
      )

      var registered = Set<FocusIdentifier>()

      for buffer in textBuffers {
        if registered.contains(buffer.focusIdentifier) == false {
          app.register(textBuffer: buffer)
          registered.insert(buffer.focusIdentifier)
        }
      }

      for focusable in focusables {
        if registered.contains(focusable.focusIdentifier) == false {
          app.register(focusable: focusable)
          registered.insert(focusable.focusIdentifier)
        }
      }

      if let focus = initialFocus {
        app.focusChain.focus(identifier: focus)
      }

      app.onResize       = onResize
      app.onUnhandledKey = onUnhandledKey

      return app
    }
  }

  // MARK: Overlay Requests

  public struct MessageBoxRequest {
    public var title                 : String
    public var messageLines          : [String]
    public var buttons               : [MessageBoxButton]
    public var titleStyleOverride    : ColorPair?
    public var messageStyleOverrides : [ColorPair?]?
    public var buttonStyleOverride   : ColorPair?

    public init ( title: String, messageLines: [String], buttons: [MessageBoxButton], titleStyleOverride: ColorPair? = nil, messageStyleOverrides: [ColorPair?]? = nil, buttonStyleOverride: ColorPair? = nil ) {
      self.title                 = title
      self.messageLines          = messageLines
      self.buttons               = buttons
      self.titleStyleOverride    = titleStyleOverride
      self.messageStyleOverrides = messageStyleOverrides
      self.buttonStyleOverride   = buttonStyleOverride
    }
  }

  public struct SelectionListRequest {
    public var title                 : String
    public var entries               : [SelectionListEntry]
    public var selectionIndex        : Int
    public var titleStyleOverride    : ColorPair?
    public var contentStyleOverride  : ColorPair?
    public var highlightStyleOverride: ColorPair?
    public var borderStyleOverride   : ColorPair?

    public init ( title: String, entries: [SelectionListEntry], selectionIndex: Int = 0, titleStyleOverride: ColorPair? = nil, contentStyleOverride: ColorPair? = nil, highlightStyleOverride: ColorPair? = nil, borderStyleOverride: ColorPair? = nil ) {
      self.title                  = title
      self.entries                = entries
      self.selectionIndex         = selectionIndex
      self.titleStyleOverride     = titleStyleOverride
      self.contentStyleOverride   = contentStyleOverride
      self.highlightStyleOverride = highlightStyleOverride
      self.borderStyleOverride    = borderStyleOverride
    }
  }

  public struct TextEntryBoxRequest {
    public var title               : String
    public var prompt              : String?
    public var text                : String
    public var buttons             : [TextEntryBoxButton]
    public var titleStyleOverride  : ColorPair?
    public var promptStyleOverride : ColorPair?
    public var buttonStyleOverride : ColorPair?

    public init ( title: String, prompt: String? = nil, text: String = "", buttons: [TextEntryBoxButton], titleStyleOverride: ColorPair? = nil, promptStyleOverride: ColorPair? = nil, buttonStyleOverride: ColorPair? = nil ) {
      self.title               = title
      self.prompt              = prompt
      self.text                = text
      self.buttons             = buttons
      self.titleStyleOverride  = titleStyleOverride
      self.promptStyleOverride = promptStyleOverride
      self.buttonStyleOverride = buttonStyleOverride
    }
  }

  public struct OverlayPresenter {
    private let driver                  : TerminalDriver
    private let messageBoxController    : MessageBoxController
    private let selectionListController : SelectionListController
    private let textEntryBoxController  : TextEntryBoxController

    fileprivate init ( driver: TerminalDriver, messageBoxController: MessageBoxController, selectionListController: SelectionListController, textEntryBoxController: TextEntryBoxController ) {
      self.driver                  = driver
      self.messageBoxController    = messageBoxController
      self.selectionListController = selectionListController
      self.textEntryBoxController  = textEntryBoxController
    }

    public func messageBox ( _ request: MessageBoxRequest ) {
      messageBoxController.present(
        title                : request.title,
        messageLines         : request.messageLines,
        buttons              : request.buttons,
        titleStyleOverride   : request.titleStyleOverride,
        messageStyleOverrides: request.messageStyleOverrides,
        buttonStyleOverride  : request.buttonStyleOverride
      )
      driver.redraw()
    }

    public func dismissMessageBox () {
      messageBoxController.dismiss()
      driver.redraw()
    }

    public func selectionList ( _ request: SelectionListRequest ) {
      selectionListController.present(
        title                 : request.title,
        entries               : request.entries,
        selectionIndex        : request.selectionIndex,
        titleStyleOverride    : request.titleStyleOverride,
        contentStyleOverride  : request.contentStyleOverride,
        highlightStyleOverride: request.highlightStyleOverride,
        borderStyleOverride   : request.borderStyleOverride
      )
      driver.redraw()
    }

    public func dismissSelectionList () {
      selectionListController.dismiss()
      driver.redraw()
    }

    public func textEntryBox ( _ request: TextEntryBoxRequest ) {
      textEntryBoxController.present(
        title               : request.title,
        prompt              : request.prompt,
        text                : request.text,
        buttons             : request.buttons,
        titleStyleOverride  : request.titleStyleOverride,
        promptStyleOverride : request.promptStyleOverride,
        buttonStyleOverride : request.buttonStyleOverride
      )
      driver.redraw()
    }

    public func dismissTextEntryBox () {
      textEntryBoxController.dismiss()
      driver.redraw()
    }
  }

  public private(set) var scene                    : Scene
  public private(set) var driver                   : TerminalDriver
  public private(set) var overlays                 : OverlayPresenter
  public private(set) var textIOController         : TextIOController
  public private(set) var menuController           : MenuController?
  public private(set) var messageBoxController     : MessageBoxController
  public private(set) var selectionListController  : SelectionListController
  public private(set) var textEntryBoxController   : TextEntryBoxController
  public private(set) var viewportBounds           : BoxBounds

  public var onResize       : ( (BoxBounds) -> Void )?
  public var onUnhandledKey : ( (TerminalInput.Token) -> Void )?

  public var focusChain : FocusChain {
    return scene.focusChain
  }

  public var state : TerminalDriver.State {
    return driver.state
  }

  private init ( scene: Scene, driver: TerminalDriver, menuController: MenuController?, messageBoxController: MessageBoxController, selectionListController: SelectionListController, textEntryBoxController: TextEntryBoxController, textIOController: TextIOController, runtimeConfiguration: RuntimeConfiguration ) {
    self.scene                   = scene
    self.driver                  = driver
    self.menuController          = menuController
    self.messageBoxController    = messageBoxController
    self.selectionListController = selectionListController
    self.textEntryBoxController  = textEntryBoxController
    self.textIOController        = textIOController
    self.overlays                = OverlayPresenter(
      driver                  : driver,
      messageBoxController    : messageBoxController,
      selectionListController : selectionListController,
      textEntryBoxController  : textEntryBoxController
    )
    self.viewportBounds         = runtimeConfiguration.initialBounds
    self.onResize               = nil
    self.onUnhandledKey         = nil

    driver.messageBoxController    = messageBoxController
    driver.selectionListController = selectionListController
    driver.textEntryBoxController  = textEntryBoxController
    driver.textIOController        = textIOController
    driver.menuController          = menuController

    driver.onResize = { [weak self] bounds in
      guard let self = self else { return }
      self.viewportBounds = bounds
      self.onResize?(bounds)
    }

    driver.onKeyEvent = { [weak self] token in
      self?.onUnhandledKey?(token)
    }
  }

  // MARK: Lifecycle Management

  public func start () {
    driver.start()
  }

  public func suspend () {
    driver.suspend()
  }

  public func resume () {
    driver.resume()
  }

  public func stop () {
    driver.stop()
  }

  public func redraw () {
    driver.redraw()
  }

  // MARK: Focus Registration

  public func register ( focusable: FocusableWidget ) {
    scene.registerFocusable(focusable)
  }

  public func register ( textBuffer: TextBuffer ) {
    scene.registerFocusable(textBuffer)
    textIOController.register(buffer: textBuffer)
  }

  public func focus ( identifier: FocusIdentifier ) {
    scene.focusChain.focus(identifier: identifier)
  }

  // MARK: Menu Utilities

  public func updateMenuBar ( _ menuBar: MenuBar ) {
    guard let controller = menuController else { return }
    controller.menuBar = menuBar
    driver.menuController = controller
    driver.redraw()
  }
}
