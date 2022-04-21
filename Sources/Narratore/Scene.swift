/// Identifies a specific part of the story, characterized by some state and a list or branches
///
/// A `Scene` is the fundamental grouping mechanism for the story: it  can have state and must be `Codable`.
///
/// Each `Scene` must declare a `Main` branch. Typically, all other branches contained within a `Scene` will be nested types, but it's not required.
public protocol Scene: Codable, Hashable {
  associatedtype Game: Story
  associatedtype Main: Branch where Main.Parent == Self

  static var branches: [RawBranch<Game>] { get }
}

extension Scene {
  /// Return the scene after applying an update function.
  public func updating(_ transform: (inout Self) -> Void) -> Self {
    var m_self = self
    transform(&m_self)
    return m_self
  }
}

extension Scene {
  func steps<B>(for _: B.Type, at anchor: B.Anchor? = nil) -> AnyGetSection<Game> where B: Branch, B.Parent == Self {
    .init(GetSection<B>.init(scene: self), at: anchor)
  }
}
