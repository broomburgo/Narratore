/// The basic protocol that describes the main attributes of a `Game`.
///
/// This protocol declares the key associated types that will define the structure of the `Game`. These are the following:
/// - `Generate`: used to provide generating functions for values;
/// - `Message`: used to define the messages through which the story is narrated;
/// - `Tag`: additional metadata that can be associated to the stepts of the story;
/// - `World`: represents the state of the game world, and must be `Codable`.
public protocol Setting {
  associatedtype Generate: Generating
  associatedtype Message: Messaging
  associatedtype Tag: Tagging
  associatedtype World: Codable
}

/// Defines generating functions for values.
public protocol Generating {
  static func randomRatio() -> Double
  static func uniqueString() -> String
}

/// Represents the requirements for a game `Message`.
///
/// A `Message` in Narratore must declare an `ID` type, but each message instance is not actually required to have an id, thus the `id: ID?` property is optional.
///
/// Additionally, a message must be constructible with a text `String`, a feature used in the DSL functions, and must have a simple, human-readable `description`, that defaults to the `text` property.
public protocol Messaging: Codable & CustomStringConvertible {
  associatedtype ID: Hashable & Codable

  var id: ID? { get }
  var text: String { get }

  init(id: ID?, text: String)
}

extension Messaging {
  public var description: String { text }
}

/// Represents the requirements for a game `Tag`.
///
/// A tag must but `Hashable` and `Codable`. Additionally, a tag can be "observed", that is, the fact that it was received will be saved in the game `Script` state. To declare that a tag must be observed, implement the `shouldObserve` property and return `true`: the default implementation returns `false`.
public protocol Tagging: Hashable & Codable {
  var shouldObserve: Bool { get }
}

extension Tagging {
  public var shouldObserve: Bool { false }
}
