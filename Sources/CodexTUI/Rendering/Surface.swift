import Foundation
import TerminalOutput

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

public struct Surface {
  public private(set) var width    : Int
  public private(set) var height   : Int
  private var tiles                : [SurfaceTile]
  private var previousFrameTiles   : [SurfaceTile]

  public init ( width: Int, height: Int ) {
    let count  = max(0, width * height)
    let filler = SurfaceTile.blank

    self.width              = width
    self.height             = height
    self.tiles              = Array(repeating: filler, count: count)
    self.previousFrameTiles = Array(repeating: filler, count: count)
  }

  public mutating func resize ( width: Int, height: Int ) {
    guard self.width != width || self.height != height else { return }

    self.width  = width
    self.height = height

    let count = max(0, width * height)
    tiles              = Array(repeating: .blank, count: count)
    previousFrameTiles = Array(repeating: .blank, count: count)
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

  public mutating func beginFrame () {
    previousFrameTiles = tiles
  }

  public func diff () -> [SurfaceChange] {
    guard tiles.count == previousFrameTiles.count else { return fullRefreshChanges() }

    var changes = [SurfaceChange]()
    changes.reserveCapacity(tiles.count / 2)

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

public enum SurfaceRenderer {
  public static func sequences ( for changes: [SurfaceChange] ) -> [AnsiSequence] {
    guard changes.isEmpty == false else { return [] }

    var sequences = [AnsiSequence]()
    sequences.reserveCapacity(changes.count * 3)

    for change in changes {
      sequences.append(TerminalOutput.TerminalCommands.moveCursor(row: change.row, column: change.column))

      if let sequence = change.tile.attributes.style.openingSequence(foreground: change.tile.attributes.foreground, background: change.tile.attributes.background) {
        sequences.append(sequence)
      }

      sequences.append(AnsiSequence(rawValue: String(change.tile.character)))

      if change.tile.attributes.style.requiresReset {
        sequences.append(TerminalOutput.TextStyle.resetSequence())
      }
    }

    return sequences
  }
}
