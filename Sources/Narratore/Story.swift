/// A concrete `Game` of `Narratore` must implement the `Story` protocol, in order to provide `scenes` when restoring an encoded game.
public protocol Story: Setting {
  static var scenes: [RawScene<Self>] { get }
}

/// Used when restoring a saved game, in the decoding process.
public struct RawScene<Game: Story>: Sendable {
  var decodeSection: @Sendable (Decoder) throws -> Section<Game>
}

/// A linear sequence of steps in a Narratore story.
///
/// A `Scene` in Narratore is a type that implements a `steps` computed property to obtain a linear list of story steps, that depends on the scene `Parent`, which is in turn a certain `Scene`.
///
/// Typically, a `Scene` will be a caseless `enum`, because it doesn't hold any state and has only static members: in order to customize a scene, the `Parent` scene should be used.
///
/// The `steps` will be implemented using a `@SceneBuilder` result builder.
///
/// A `Scene` can define an `Anchor` type, in order to clearly identify specific steps in it: `Anchor` must be hashable, and it defaults to `Never`, so it's not necessary to manually declare it for all scenes.
public protocol SceneType<Game>: Codable, Hashable, Sendable {
  associatedtype Game: Story
  associatedtype Anchor: Codable, Hashable, Sendable = Never

  @SceneBuilder<Self>
  var steps: Steps { get }
}

extension SceneType {
  /// The type of the steps generated by the `Scene`.
  public typealias Steps = [SceneStep<Self>]

  /// The unique identifier assigned to a `Scene`.
  ///
  /// It must be unique, and it's used to decode a scene.
  ///
  /// It's value is `"\(Self.self)"`, simply representing the type of the scene.
  public static var identifier: String { "\(Self.self)" }

  /// Return the scene after applying an update function.
  public func updating(_ transform: (inout Self) -> Void) -> Self {
    var m_self = self
    transform(&m_self)
    return m_self
  }

  /// The "raw" representation of the `Scene`, used for decoding.
  public static var raw: RawScene<Game> {
    .init {
      let helper: SectionCodableHelper<Self> = try .init(from: $0)

      guard helper.identifier == Self.identifier else {
        throw Failure<Game>.invalidSceneIdentifier(expected: Self.identifier, received: helper.identifier)
      }

      return .init(scene: helper.scene, anchor: {
        if let anchor = helper.anchor, anchor is Never {
          nil
        } else {
          helper.anchor
        }
      }())
    }
  }
}

/// The `getSteps(for:)` function in a scene must return a linear sequence of `SceneStep`.
///
/// A `SceneStep` is really just a pair of an optional `Anchor`, and an instance of `GetStep`, which wraps a function that will eventually provide a story `Step`.
public struct SceneStep<Scene: SceneType>: Sendable {
  public var anchor: Scene.Anchor?
  public var getStep: GetStep<Scene.Game>

  public init(anchor: Scene.Anchor? = nil, getStep: GetStep<Scene.Game>) {
    self.anchor = anchor
    self.getStep = getStep
  }
}

/// Represents a jump from a `Scene` to another.
///
/// There are 3 possible cases of "jumps" between scenes, represented by the nested `Action` type:
/// - `replaceWith`: replaces the last scene in the stack with a new one; used when moving from one scene to another (or between anchors in the same scene) without affecting the stack of previous scenes;
/// - `runThrough`: add a scene to the scene stack, that will be removed when it's completed; used when the story needs to temporarily "visit" another scene without affecting the current scene history;
/// - `transitionTo`: completely replaces the scene stack with a single scene; used when the story shifts from a situation to another, so the scene history must be cleared.
public struct SceneChange<Game: Setting>: Encodable, Sendable {
  public var action: Action
  public var section: Section<Game>

  public init(action: Action, section: Section<Game>) {
    self.action = action
    self.section = section
  }

  public enum Action: Codable, Sendable {
    case replaceWith
    case runThrough
    case transitionTo
  }
}

extension SceneChange: Decodable where Game: Story {}

extension SceneChange {
  public static func replaceWith<Scene: SceneType>(
    _ scene: Scene,
    at anchor: Scene.Anchor? = nil
  ) -> Self where Scene.Game == Game {
    .init(action: .replaceWith, section: .init(scene: scene, anchor: anchor))
  }

  public static func runThrough<Scene: SceneType>(
    _ scene: Scene,
    at anchor: Scene.Anchor? = nil
  ) -> Self where Scene.Game == Game {
    .init(action: .runThrough, section: .init(scene: scene, anchor: anchor))
  }

  public static func transitionTo<Scene: SceneType>(
    _ scene: Scene,
    at anchor: Scene.Anchor? = nil
  ) -> Self where Scene.Game == Game {
    .init(action: .transitionTo, section: .init(scene: scene, anchor: anchor))
  }
}

/// The "compiled" representation of a `Scene`.
///
/// While the purpose of a `Scene` is to wrap a function that returns the steps for the story, a `Section` is produced by running that function, considering a certain starting `anchor`
///
/// `Section` depends on the specific scene type, represented by the `Scene` generic parameter.
public struct Section<Game: Setting>: Encodable, Hashable, Sendable {
  let steps: [GetStep<Game>]
  let startingIndex: Int

  private let encodeTo: @Sendable (Encoder) throws -> Void
  private let hashableSource: any (Hashable & Sendable)

  init<Scene: SceneType<Game>>(scene: Scene, anchor: Scene.Anchor? = nil) {
    encodeTo = SectionCodableHelper(scene: scene, anchor: anchor).encode(to:)
    hashableSource = scene

    let sceneSteps = scene.steps

    var steps: [GetStep<Scene.Game>] = []
    var anchorIndices: [Scene.Anchor: Int] = [:]

    for index in sceneSteps.indices {
      let sceneStep = sceneSteps[index]
      steps.append(sceneStep.getStep)

      if let anchor = sceneStep.anchor {
        anchorIndices[anchor] = index
      }
    }

    self.steps = steps

    startingIndex = anchor.flatMap {
      anchorIndices[$0]
    } ?? 0
  }

  public static func == (lhs: Section<Game>, rhs: Section<Game>) -> Bool {
    lhs.hashableSource.hashValue == rhs.hashableSource.hashValue
  }

  public func encode(to encoder: Encoder) throws {
    try encodeTo(encoder)
  }

  public func hash(into hasher: inout Hasher) {
    hashableSource.hash(into: &hasher)
  }
}

extension Section: Decodable where Game: Story {
  public init(from decoder: Decoder) throws {
    let results = Game.scenes.lazy.map { rawScene in
      Result { try rawScene.decodeSection(decoder) }
    }

    var errors: [Swift.Error] = []

    for result in results {
      switch result {
      case .success(let value):
        self = value
        return

      case .failure(let error):
        errors.append(error)
      }
    }

    throw Failure<Game>.cannotDecodeSection(errors: errors)
  }
}

// MARK: - Private

private struct SectionCodableHelper<Scene: SceneType>: Codable {
  var scene: Scene
  var anchor: Scene.Anchor?
  var identifier: String

  init(scene: Scene, anchor: Scene.Anchor?) {
    self.scene = scene
    self.anchor = anchor
    identifier = Scene.identifier
  }
}
