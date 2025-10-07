import Foundation
import TerminalInput

/// Coordinates menu state, overlays and keyboard routing for menu bars. The controller owns the
/// currently visible scaffold and swaps overlays as menus open or close so the scene always reflects
/// the latest interaction state.
public final class MenuController {
  public private(set) var scene              : Scene
  public private(set) var activeOverlayBounds: BoxBounds?

  private var menuBarState      : MenuBar
  private let contentWidget     : AnyWidget
  private let statusBar         : StatusBar?
  private var storedOverlays    : [AnyWidget]?
  private var activeMenuIndex   : Int?
  private var activeEntryIndex  : Int?
  private var previousFocus     : FocusIdentifier?
  private var viewportBounds    : BoxBounds

  public init ( scene: Scene, menuBar: MenuBar, content: AnyWidget, statusBar: StatusBar? = nil, viewportBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24) ) {
    self.scene             = scene
    self.menuBarState      = menuBar
    self.contentWidget     = content
    self.statusBar         = statusBar
    self.viewportBounds    = viewportBounds
    self.storedOverlays    = nil
    self.activeMenuIndex   = nil
    self.activeEntryIndex  = nil
    self.previousFocus     = nil
    self.activeOverlayBounds = nil
    refreshScene()
  }

  public var menuBar : MenuBar {
    get { menuBarState }
    set {
      menuBarState = newValue
      closeMenu()
      refreshScene()
    }
  }

  public var isMenuOpen : Bool {
    return activeMenuIndex != nil
  }

  public func update ( viewportBounds: BoxBounds ) {
    self.viewportBounds = viewportBounds
    if isMenuOpen {
      presentMenuOverlay()
    }
  }

  public func handle ( token: TerminalInput.Token ) -> Bool {
    if let index = menuBarState.items.firstIndex(where: { $0.matches(token: token) }) {
      return openMenu(at: index)
    }

    guard let activeIndex = activeMenuIndex else { return false }

    switch token {
      case .escape :
        closeMenu()
        return true

      case .cursor(let key) :
        switch key {
          case .down : return moveSelection(by: 1)
          case .up   : return moveSelection(by: -1)
          case .left : return moveMenuHorizontally(by: -1)
          case .right: return moveMenuHorizontally(by: 1)
          default    : return false
        }

      case .control(let key) :
        switch key {
          case .TAB    : return moveSelection(by: 1)
          case .RETURN : return activateSelection()
          default      : return false
        }

      case .meta :
        // Allow alt key chords to switch menus while open.
        if let index = menuBarState.items.firstIndex(where: { $0.matches(token: token) }) {
          return openMenu(at: index)
        }
        return false

      default :
        break
    }

    // Tokens that reach this point should not be delivered to other widgets.
    return activeIndex == activeMenuIndex
  }

  public func closeMenu () {
    guard let _ = activeMenuIndex else { return }

    activeMenuIndex      = nil
    activeEntryIndex     = nil
    activeOverlayBounds  = nil

    if let baseOverlays = storedOverlays {
      scene.overlays = baseOverlays
    }

    storedOverlays = nil

    if let focus = previousFocus {
      scene.focusChain.focus(identifier: focus)
    }

    previousFocus = nil
    updateOpenFlags(activeIndex: nil)
  }

  private func openMenu ( at index: Int ) -> Bool {
    guard menuBarState.items.indices.contains(index) else { return false }
    let entries = menuBarState.items[index].entries
    guard entries.isEmpty == false else { return false }

    if activeMenuIndex == nil {
      previousFocus  = scene.focusChain.active
      storedOverlays = scene.overlays
    }

    let previousIndex = activeMenuIndex
    activeMenuIndex   = index

    if previousIndex != index {
      activeEntryIndex = 0
    } else {
      let current = activeEntryIndex ?? 0
      activeEntryIndex = max(0, min(current, entries.count - 1))
    }

    updateOpenFlags(activeIndex: index)
    presentMenuOverlay()
    return true
  }

  private func moveSelection ( by offset: Int ) -> Bool {
    guard let menuIndex = activeMenuIndex else { return false }
    let entries = menuBarState.items[menuIndex].entries
    guard entries.isEmpty == false else { return false }

    let count   = entries.count
    let current = activeEntryIndex ?? 0
    let next    = (current + offset + count) % count
    activeEntryIndex = next
    presentMenuOverlay()
    return true
  }

  private func moveMenuHorizontally ( by offset: Int ) -> Bool {
    guard menuBarState.items.isEmpty == false else { return false }
    guard let currentIndex = activeMenuIndex else { return false }

    var nextIndex = currentIndex
    for _ in 0..<menuBarState.items.count {
      nextIndex = (nextIndex + offset + menuBarState.items.count) % menuBarState.items.count
      if menuBarState.items[nextIndex].entries.isEmpty == false {
        return openMenu(at: nextIndex)
      }
    }

    return false
  }

  private func activateSelection () -> Bool {
    guard let menuIndex = activeMenuIndex else { return false }
    guard let entryIndex = activeEntryIndex else { return false }
    let entries = menuBarState.items[menuIndex].entries
    guard entries.indices.contains(entryIndex) else { return false }

    let action = entries[entryIndex].action
    closeMenu()
    action?()
    return true
  }

  private func updateOpenFlags ( activeIndex: Int? ) {
    for index in menuBarState.items.indices {
      menuBarState.items[index].isOpen = (index == activeIndex)
    }

    refreshScene()
  }

  private func presentMenuOverlay () {
    guard let menuIndex = activeMenuIndex else { return }
    let entries = menuBarState.items[menuIndex].entries
    guard entries.isEmpty == false else { return }

    if storedOverlays == nil {
      storedOverlays = scene.overlays
    }

    let itemBounds    = menuItemBounds(at: menuIndex)
    let dropDownBounds = DropDownMenu.anchoredBounds(for: entries, anchoredTo: itemBounds, in: viewportBounds)
    activeOverlayBounds = dropDownBounds

    let dropDown = DropDownMenu(
      entries        : entries,
      selectionIndex : activeEntryIndex ?? 0,
      style          : scene.configuration.theme.contentDefault,
      highlightStyle : scene.configuration.theme.highlight,
      borderStyle    : scene.configuration.theme.windowChrome
    )

    let overlay = Overlay(
      bounds  : dropDownBounds,
      content : AnyWidget(dropDown)
    )

    let base = storedOverlays ?? []
    scene.overlays = base + [AnyWidget(overlay)]
  }

  private func menuItemBounds ( at index: Int ) -> BoxBounds {
    let menuRowBounds = BoxBounds(row: viewportBounds.row, column: viewportBounds.column, width: viewportBounds.width, height: 1)
    var leftColumn    = menuRowBounds.column
    var rightColumn   = menuRowBounds.maxCol + 1

    for (offset, item) in menuBarState.items.enumerated() where item.alignment == .leading {
      let start = leftColumn
      if offset == index {
        return BoxBounds(row: menuRowBounds.row, column: start, width: item.title.count, height: 1)
      }
      leftColumn += item.title.count + 2
    }

    for element in menuBarState.items.enumerated().reversed() where element.element.alignment == .trailing {
      let start = rightColumn - element.element.title.count
      if element.offset == index {
        return BoxBounds(row: menuRowBounds.row, column: start, width: element.element.title.count, height: 1)
      }
      rightColumn = start - 2
    }

    return BoxBounds(row: menuRowBounds.row, column: menuRowBounds.column, width: 0, height: 1)
  }

  private func refreshScene () {
    let visibleMenu   = scene.configuration.showMenuBar ? menuBarState : nil
    let visibleStatus = scene.configuration.showStatusBar ? statusBar : nil
    let scaffold      = Scaffold(menuBar: visibleMenu, content: contentWidget, statusBar: visibleStatus)
    scene.rootWidget  = AnyWidget(scaffold)
  }
}
