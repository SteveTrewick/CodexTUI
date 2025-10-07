import Foundation
import TerminalOutput

// Represents a single cell in the terminal buffer and the styling required to display it.
public struct SurfaceTile : Equatable {
  public var character  : Character
  public var attributes : ColorPair

  public init ( character: Character, attributes: ColorPair ) {
    self.character  = character
    self.attributes = attributes
  }
}

public extension SurfaceTile {
  static let blank : SurfaceTile = SurfaceTile(character: " ", attributes: ColorPair())
}

// Lightweight framebuffer used to track differences between frames for efficient redraws.
public struct Surface {
  public private(set) var width             : Int
  public private(set) var height            : Int
  private var tiles                         : [SurfaceTile]
  private var previousFrameTiles            : [SurfaceTile]
  private var needsFullRefresh              : Bool

  public init ( width: Int, height: Int ) {
    let count  = max(0, width * height)
    let filler = SurfaceTile.blank

    self.width              = width
    self.height             = height
    self.tiles              = Array(repeating: filler, count: count)
    self.previousFrameTiles = Array(repeating: filler, count: count)
    self.needsFullRefresh   = false
  }

  public mutating func resize ( width: Int, height: Int ) {
    guard self.width != width || self.height != height else { return }

    self.width  = width
    self.height = height

    let count = max(0, width * height)
    tiles            = Array(repeating: .blank, count: count)
    needsFullRefresh = true
  }

  public mutating func clear ( with tile: SurfaceTile = .blank ) {
    tiles = Array(repeating: tile, count: tiles.count)
  }

  public func tile ( atRow row: Int, column: Int ) -> SurfaceTile? {
    guard isValid(row: row, column: column) else { return nil }
    let index = indexFor(row: row, column: column)
    return tiles[index]
  }

  public mutating func set ( tile: SurfaceTile, atRow row: Int, column: Int ) {
    guard isValid(row: row, column: column) else { return }
    tiles[indexFor(row: row, column: column)] = tile
  }

  // Snapshot the current frame so the diff can be computed after widgets finish rendering.
  public mutating func beginFrame () {
    previousFrameTiles = tiles
  }

  // Produces a minimal list of changed tiles. When the surface dimensions change we fall back to a full refresh.
  public mutating func diff () -> [SurfaceChange] {
    guard needsFullRefresh == false else {
      needsFullRefresh = false
      return fullRefreshChanges()
    }

    guard tiles.count == previousFrameTiles.count else {
      needsFullRefresh = false
      return fullRefreshChanges()
    }

    var changes = [SurfaceChange]()
    changes.reserveCapacity(tiles.count / 2)

    // Translate flat array indices back into 1-based terminal coordinates as required by TerminalOutput.
    for index in tiles.indices where tiles[index] != previousFrameTiles[index] {
      let row    = index / width
      let column = index % width
      changes.append(SurfaceChange(row: row + 1, column: column + 1, tile: tiles[index]))
    }

    return changes
  }

  private func fullRefreshChanges () -> [SurfaceChange] {
    var changes = [SurfaceChange]()
    changes.reserveCapacity(tiles.count)

    for index in tiles.indices {
      let row    = index / width
      let column = index % width
      changes.append(SurfaceChange(row: row + 1, column: column + 1, tile: tiles[index]))
    }

    return changes
  }

  private func isValid ( row: Int, column: Int ) -> Bool {
    return row >= 1 && column >= 1 && row <= height && column <= width
  }

  private func indexFor ( row: Int, column: Int ) -> Int {
    return (row - 1) * width + (column - 1)
  }
}

public struct SurfaceChange : Equatable {
  public let row    : Int
  public let column : Int
  public let tile   : SurfaceTile
}

// Converts surface mutations into terminal escape sequences.
public enum SurfaceRenderer {
  public static func sequences ( for changes: [SurfaceChange] ) -> [AnsiSequence] {
    guard changes.isEmpty == false else { return [] }

    var sequences = [AnsiSequence]()
    sequences.reserveCapacity(changes.count * 3)

    // Each change requires a cursor move, optional style change and the character itself.
    for change in changes {
      sequences.append(TerminalOutput.TerminalCommands.moveCursor(row: change.row, column: change.column))

      let attributes          = change.tile.attributes
      let isDefaultAppearance = attributes.foreground == nil && attributes.background == nil && attributes.style == .none

      if isDefaultAppearance {
        sequences.append(TerminalOutput.TextStyle.resetSequence())
        sequences.append(AnsiSequence(rawValue: String(change.tile.character)))
        continue
      }

      if let sequence = attributes.style.openingSequence(foreground: attributes.foreground, background: attributes.background) {
        sequences.append(sequence)
      }

      sequences.append(AnsiSequence(rawValue: String(change.tile.character)))

      if attributes.style.requiresReset {
        sequences.append(TerminalOutput.TextStyle.resetSequence())
      }
    }

    return sequences
  }
}
