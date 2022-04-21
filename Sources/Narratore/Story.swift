/// A concrete `Game` of `Narratore` must implement the `Story` protocol, in order to provide `scenes` when restoring an encoded game.
public protocol Story: Setting {  
  static var scenes: [RawScene<Self>] { get }
}

/// Used when restoring a saved game, in the decoding process.
public struct RawScene<Game: Story> {
  var branches: [RawBranch<Game>]
}

extension Scene {
  public static var raw: RawScene<Game> {
    .init(branches: Self.branches)
  }
}

/// Used when restoring a saved game, in the decoding process.
public struct RawBranch<Game: Story> {
  var decodeSection: (Decoder) throws -> AnyGetSection<Game>
}

extension Branch {
  /// Used when restoring a saved game, in the decoding process.
  public static var raw: RawBranch<Parent.Game> {
    .init { try AnyGetSection<Parent.Game>.init(GetSection<Self>.init(from: $0)) }
  }
}
