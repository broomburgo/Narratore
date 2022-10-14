/// The main mechanism with which a game engine can respond to the game loop.
///
/// A `Handler` for a game will likely be the type where most of the code to run the game is located.
///
/// For a type to be a `Handler`, it must implement 3 functions:
/// - `handle(event:)`, used to handle a static event related to the flow of the game;
/// - `acknowledge(narration:)`, used to handle a `Narration` step;
/// - `make(choice:)`, used to ask the player to make some choice.
///
/// `acknowledge(narration:)`, and `make(choice:)` are `async` functions, because they need to wait for a player's reaction, and they must return a `Next` instance, where the engine can tell the `Runner` what to do next after a certain step.
public protocol Handler {
  associatedtype Game: Setting

  func acknowledge(narration: Player<Game>.Narration) async -> Next<Game, Void>
  func make(choice: Player<Game>.Choice) async -> Next<Game, Player<Game>.Option>
  func handle(event: Player<Game>.Event)
}

/// The namespace for player-facing information and choices.
public enum Player<Game: Setting> {
  public struct Narration {
    public let messages: [Game.Message]
    public let tags: [Game.Tag]
  }

  public struct Choice {
    public let options: [Option]
    public let tags: [Game.Tag]
  }

  public struct Option {
    let id: String
    public let message: Game.Message
    public let tags: [Game.Tag]
  }

  public enum Event {
    case gameStarted(Status<Game>)
    case gameEnded
    case errorProduced(Failure<Game>)
    case statusUpdated(Status<Game>)
  }
}

/// Tells the `Runner` what to do next.
///
/// `Next` declares 2 properties:
/// - `action: Action`, that defines what to do next;
/// - `update: Change?`, and optional update to the state of the game `World`.
public struct Next<Game: Setting, A> {
  public var action: Action
  public var update: Update<Game>?

  public init(
    action: Action,
    update: Update<Game>?
  ) {
    self.action = action
    self.update = update
  }

  /// There are 3 possible actions after a step in the story:
  /// - `advance`: move on with the story, passing along a value of type `A`;
  /// - `replay`: play again the last step, without updating the state of the story;
  /// - `stop`: end the game.
  public enum Action {
    case advance(A)
    case replay
    case stop
  }
}

extension Next {
  public static func advance(with value: A, update: Update<Game>? = nil) -> Self {
    .init(
      action: .advance(value),
      update: update
    )
  }

  public static func replay(update: @escaping Update<Game>) -> Self {
    .init(
      action: .replay,
      update: update
    )
  }

  public static var replay: Self {
    .init(
      action: .replay,
      update: nil
    )
  }

  public static var stop: Self {
    .init(
      action: .stop,
      update: nil
    )
  }
}

extension Next where A == Void {
  public static func advance(update: @escaping Update<Game>) -> Self {
    .init(
      action: .advance(()),
      update: update
    )
  }

  public static var advance: Self {
    .init(
      action: .advance(()),
      update: nil
    )
  }
}

/// Some possible error statuses.
public enum Failure<Game: Setting>: Error {
  case invalidBranchId(expected: String, received: String)
  case invalidOptionId(expected: [String], received: String)
  case noBranch(option: Option<Game>)
  case noOptions(choice: Choice<Game>)
  case notFound(errors: [Error])
}

/// The "protocol witness" version of `Handler`, used internally to type-erase the `Handler` passed to `Runner`.
public struct Handling<Game: Setting> {
  var _acknowledgeNarration: (Player<Game>.Narration) async -> Next<Game, Void>
  var _makeChoice: (Player<Game>.Choice) async -> Next<Game, Player<Game>.Option>
  var _handleEvent: (Player<Game>.Event) -> Void

  public init(
    acknowledgeNarration: @escaping (Player<Game>.Narration) async -> Next<Game, Void>,
    makeChoice: @escaping (Player<Game>.Choice) async -> Next<Game, Player<Game>.Option>,
    handleEvent: @escaping (Player<Game>.Event) -> Void
  ) {
    _acknowledgeNarration = acknowledgeNarration
    _makeChoice = makeChoice
    _handleEvent = handleEvent
  }
}

extension Handler {
  var handling: Handling<Game> {
    .init(
      acknowledgeNarration: acknowledge(narration:),
      makeChoice: make(choice:),
      handleEvent: handle(event:)
    )
  }
}

extension Handling: Handler {
  public func acknowledge(narration: Player<Game>.Narration) async -> Next<Game, Void> {
    await _acknowledgeNarration(narration)
  }

  public func make(choice: Player<Game>.Choice) async -> Next<Game, Player<Game>.Option> {
    await _makeChoice(choice)
  }

  public func handle(event: Player<Game>.Event) {
    _handleEvent(event)
  }
}
