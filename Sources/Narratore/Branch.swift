/// A linear sequence of steps in a Narratore story.
///
/// A `Branch` in Narratore is a type that implements a static function `getSteps` to obtain a linear list of story steps, that depends on the branch `Parent`, which is in turn a certain `Scene`.
///
/// Typically, a `Branch` will be a caseless `enum`, because it doesn't hold any state and has only static members: in order to customize a branch, the `Parent` scene should be used.
///
/// Also typically, the `getSteps(for:)` will be implemented using a `@BranchBuilder` result builder.
///
/// A `Branch` can define an `Anchor` type, in order to clearly identify specific steps in it: `Anchor` must be hashable, and it defaults to `Never`, so it's not necessary to manually declare it for all branches.
public protocol Branch {
  associatedtype Parent: Scene
  associatedtype Anchor: Hashable = Never

  static func getSteps(for: Parent) -> [BranchStep<Self>]
}

extension Branch {
  public typealias Game = Parent.Game

  /// The unique identifier assigned to a `Branch`.
  ///
  /// The `id` is simply a string containing the name of the parent `Scene` and the name of the branch itself: for example, it could be something like `CaveScene.FirstCorridor`.
  ///
  /// Due to the fact that it describes types, it's guaranteed that it will be unique, and can be used in the `getSteps` function to uniquely reference the specific branch where the step takes place.
  public static var id: String { "\(Parent.self).\(Self.self)" }
}

/// The `getSteps(for:)` function in a branch must return a linear sequence of `BranchStep`.
///
/// A `BranchStep` is really just a pair of an optional `Anchor`, and an instance of `GetStep`, which wraps a function that will eventually provide a story `Step`.
public struct BranchStep<B: Branch> {
  public var anchor: B.Anchor?
  public var getStep: GetStep<B.Parent.Game>

  public init(anchor: B.Anchor? = nil, getStep: GetStep<B.Parent.Game>) {
    self.anchor = anchor
    self.getStep = getStep
  }
}

/// Represents a jump from a `Branch` to another.
///
/// There are 3 possible cases of "jumps" between branches, represented by the nested `Action` type:
/// - `replaceWith`: replaces the last branch in the stack with a new one; used when moving from one branch to another (or between anchors in the same branch) without affecting the stack of previous branches;
/// - `runThrough`: add a branch to the branch stack, that will be removed when it's completed; used when the story needs to temporarily "visit" another branch without affecting the current branch history;
/// - `transitionTo`: completely replaces the branch stack with a single branch; used when the story shifts from a situation to another, so the branch history must be cleared.
public struct BranchChange<Game: Setting>: Encodable {
  public var action: Action
  public var section: AnyGetSection<Game>

  public init(action: Action, section: AnyGetSection<Game>) {
    self.action = action
    self.section = section
  }

  public enum Action: Codable {
    case replaceWith
    case runThrough
    case transitionTo
  }
}

extension BranchChange: Decodable where Game: Story {}

extension BranchChange {
  public static func replaceWith<B: Branch>(
    _: B.Type,
    at anchor: B.Anchor? = nil,
    scene: B.Parent
  ) -> Self where B.Parent.Game == Game {
    .init(action: .replaceWith, section: scene.steps(for: B.self, at: anchor))
  }

  public static func replaceWith<S: Scene>(
    _ scene: S
  ) -> Self where S.Game == Game {
    .replaceWith(S.Main.self, at: nil, scene: scene)
  }

  public static func runThrough<B: Branch>(
    _: B.Type,
    at anchor: B.Anchor? = nil,
    scene: B.Parent
  ) -> Self where B.Parent.Game == Game {
    .init(action: .runThrough, section: scene.steps(for: B.self, at: anchor))
  }

  public static func runThrough<S: Scene>(
    _ scene: S
  ) -> Self where S.Game == Game {
    .runThrough(S.Main.self, at: nil, scene: scene)
  }

  public static func transitionTo<B: Branch>(
    _: B.Type,
    at anchor: B.Anchor? = nil,
    scene: B.Parent
  ) -> Self where B.Parent.Game == Game {
    .init(action: .transitionTo, section: scene.steps(for: B.self, at: anchor))
  }

  public static func transitionTo<S: Scene>(
    _ scene: S
  ) -> Self where S.Game == Game {
    .transitionTo(S.Main.self, at: nil, scene: scene)
  }
}
