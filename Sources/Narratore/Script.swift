/// The current state of the narrated story in a game.
///
/// `Script` is part of the `Context`, and thus it can be inspected in each story step.
public struct Script<Game: Setting>: Codable {
  /// The count of the narrated messages with an `id` that wasn't `nil`.
  public private(set) var narrated: [Game.Message.ID: Int] = [:]

  /// The count of observed `Tag`s, that is, tags that had the `shouldObserve` property equal to `true`.
  public private(set) var observed: [Game.Tag: Int] = [:]

  /// The list of text messages that constitute the story up to a certain point.
  public private(set) var words: [String] = []

  public init() {}

  public func didNarrate(_ id: Game.Message.ID) -> Bool {
    narrated[id, default: 0] > 0
  }

  /// Add a `Narration` step to the story.
  public mutating func append(narration: Narration<Game>) {
    for tag in narration.tags.filter(\.shouldObserve) {
      observed[tag, default: 0] += 1
    }

    for message in narration.messages {
      if let id = message.id {
        narrated[id, default: 0] += 1
      }

      words.append(message.text)
    }
  }

  /// Add a `Choice` step to the story.
  public mutating func append(choice: Choice<Game>) {
    for tag in (choice.tags + choice.options.flatMap(\.tags)).filter(\.shouldObserve) {
      observed[tag, default: 0] += 1
    }
  }

  /// Add a `TextRequest` step to the story.
  public mutating func append(textRequest: TextRequest<Game>) {
    for tag in textRequest.tags.filter(\.shouldObserve) {
      observed[tag, default: 0] += 1
    }

    if let message = textRequest.message {
      if let id = message.id {
        narrated[id, default: 0] += 1
      }

      words.append(message.text)
    }
  }
}

/// Describes a step in the narration of the story.
///
/// `Narration` includes the following properies:
/// - and list of `Message`s: this can be empty, because a narration step could just be deinfed by some `Tag`s;
/// - a list of `Tag`s, possibly empty;
/// - an optional `Update` to the game `World` associated with the `Narration` step.
public struct Narration<Game: Setting> {
  public var messages: [Game.Message]
  public var tags: [Game.Tag]
  public var update: Update<Game>?

  public init(messages: [Game.Message], tags: [Game.Tag], update: Update<Game>?) {
    self.messages = messages
    self.tags = tags
    self.update = update
  }
}

/// Describes a choice that must be made by the player.
///
/// `Choice` includes the following properties:
/// - a list if `Option`s, that __should not be empty__;
/// - a list of `Tag`s, possibly empty;
public struct Choice<Game: Setting> {
  public var options: [Option<Game>]
  public var tags: [Game.Tag]
  public var config: Config

  public init(options: [Option<Game>], tags: [Game.Tag], config: Config = .init()) {
    self.options = options
    self.tags = tags
    self.config = config
  }

  public struct Config {
    public var failIfNoOptions: Bool = false
    public var showIfSingleOption: Bool = false

    public init(failIfNoOptions: Bool = false, showIfSingleOption: Bool = false) {
      self.failIfNoOptions = failIfNoOptions
      self.showIfSingleOption = showIfSingleOption
    }
  }
}

/// Describes a possible option in a choice.
///
/// `Option` includes the following properties:
/// - the `Message` associated with that particular option;
/// - the scene `Step` that must be performed if the option is selected.
/// - a list of `Tag`s, possibly empty;
public struct Option<Game: Setting> {
  public let message: Game.Message
  public let step: Step<Game>
  public let tags: [Game.Tag]
}

public struct TextRequest<Game: Setting> {
  public let message: Game.Message?
  public let validate: (String) -> Validation
  public let getStep: (Validated) -> Step<Game>
  public let tags: [Game.Tag]

  public enum Validation {
    case valid(Validated)
    case invalid(Game.Message)
  }

  public struct Validated {
    public let text: String
  }
}

/// Describes a jump between scenes in the story.
///
/// `Jump` includes the following properties:
/// - the `Narration` step to present immediately before the scene change;
/// - the kind of jump between scenes.
public struct Jump<Game: Setting> {
  public var narration: Narration<Game>
  public var sceneChange: SceneChange<Game>

  public init(narration: Narration<Game>, sceneChange: SceneChange<Game>) {
    self.narration = narration
    self.sceneChange = sceneChange
  }
}

/// A function to update the game `World`.
public typealias Update<Game: Setting> = (inout Game.World) -> Void
