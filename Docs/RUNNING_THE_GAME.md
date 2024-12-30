#  Running the game

> All the code examples in this document are taken from the `SimpleHandler` and `SimpleGame` modules of the [companion package](https://github.com/broomburgo/SimpleGame).

The essential tool for running a game built with `Narratore` is the `Runner` actor. In turn, `Runner` uses an instance of some type that conforms to the `Handler` protocol in order to communicate with the game engine (thus, with the player) and send to it the various game events, like new narration steps, or choices to make. Before diving into `Runner`, let's see what's required from a `Handler` type.

`Handler` is a protocol that has the following definition:

```swift
public protocol Handler: Sendable {
  associatedtype Game: Setting

  func acknowledge(narration: Player<Game>.Narration) async -> Next<Game, Void>
  func make(choice: Player<Game>.Choice) async -> Next<Game, Player<Game>.Option>
  func answer(request: Player<Game>.TextRequest) async -> Next<Game, Player<Game>.ValidatedText>
  func handle(event: Player<Game>.Event)
}
```

Each callback function declared by `Handler` has a specific meaning, and a signature that's specific to the requirements of the particular functionality that the function expresses. The value that are expected as input or output are typically included in the `Player<Game>` namespace, that defines types that represent internal concepts of `Narratore` (like `Narration` and `Choice`) but in a "player-facing" fashion, that hides private details and restricts the options. Let's see each function in detail.

While exploring in detail the `Handler` protocol and the `Runner` APIs, let's define a `SimpleHandler` class that can be used to run a game on the command line:

```swift
public struct SimpleHandler<Game: Story> {
  ...
}
```

We want `Game` to conform to `Story` because `SimpleHandler` will also take care of game data serialization.

## `acknowledge(narration:)`

This will be called each time a new narration step must be presented to the user. A `Player.Narration` value is passed to the function, with the following structure:

```swift
public enum Player<Game: Setting> {
  public struct Narration {
    public let messages: [Game.Message]
    public let tags: [Game.Tag]
  }
  ...
}
```

The `Narration` will contain a list of `Message`s and a list of `Tag`s (both possibly empty), of the types declared in the game `Setting` definition: `Runner` will actually skip the call to `acknowledge(narration:)` if both `messages` and `tags` are empty, because there would actually be nothing to acknowledge. This function is `async`, so it can be suspended, in order, for example, to wait for the user to acknowledge the message. The function must return an instance of type `Next` with the following structure:

```swift
public struct Next<Game: Setting, Advancement: Sendable>: Sendable {
  public var action: Action
  public var update: Update<Game>?
  
  ...
  
  public enum Action {
    case advance(Advancement)
    case replay
    case stop
  }
  ...
}
```

`Next` describes the request that the game `Runner` will need to satisfy right after the narration step. `Next` defines several convenient constructors, and defines 2 properties:

- `action`: what the `Runner` should do next;
- `update`: an optional update to the game `World` that should be handled by the `Runner` before passing the next step to the player.

The `action` could be one of the following:

- `advance`: advance to the next step, passing a generic `Advancement` value to the `Runner` (in the case of `Narration`, `Advancement` is simply `Void`);
- `replay`: replay the last step (the `update` to the game `World` will be executed before replaying it);
- `stop`: stop the game.

Here's a possible implementation of `acknowledge(narration:)` in our `SimpleHandler` struct:

```swift
extension SimpleHandler: Handler {
  public func acknowledge(narration: Player<Game>.Narration) async -> Next<Game, Void> {
    if !narration.tags.isEmpty {
      print("[\(narration.tags.map { "\($0)" }.joined(separator: "|"))]")
    }

    for message in narration.messages {
      print(message)

      _ = readLine()
    }

    return .advance
  }
  ...
}
```

`SimpleHandler` will simply print the `Tag`s in a single line, then the messages one by one, using `readLine` after each message in order for the player to acknowledge the latter.

## `make(choice:)`

This will be called each time the player is expected to make a choice. The `Player.Choice` type that's passed in will contain a (possibly empty) list of `Tag`s, and a list of `Player.Option`s that's guaranteed to not be empty.

`Player.Option` has the following structure:

```swift
public enum Player<Game: Setting> {
  ...
  public struct Option: Sendable {
    let id: String
    public let message: Game.Message
    public let tags: [Game.Tag]
  }
  ...
}
```

The `message` is the one to be shown to present the option to the player, and there is a (possibly empty) list of `Tag`s associated with the `Option`. This function is also `async`, so it can be suspended while waiting for the player's selection. The return type is, again, `Next`, but the `A` type is now `Player.Option`: if `.advance` is retuned, it must associated with one of the `Option`s from the `Choice` itself. The structure of the `Player.Option` type will guarantee that only an `Option` from the list defined in `Player.Choice` can be passed, and this will be done via a internal `id` that will be generated via the `uniqueString` function from the `Generate` type defined in `Setting`. Nevertheless, in case an invalid `Player.Option` is returned, the `Handler` will receive an error event, and the same choice step will be sent again, without affecting the story and the game `World`.

Here's a possible implementation of `make(choice:)` in our `SimpleHandler` class:

```swift
public struct SimpleHandler<Game: Story> {
  ...
  private func input(accepted: [String]) -> String {
    while true {
      guard let captured = readLine(), accepted.contains(captured) else {
        print("[Invalid input. Valid inputs: \(accepted.joined(separator: ", "))]")
        continue
      }
      return captured
    }
  }
}

extension SimpleHandler: Handler {
  ...
  public func make(choice: Player<Game>.Choice) async -> Next<Game, Player<Game>.Option> {
    for (index, option) in choice.options.enumerated() {
      print(index, "-", option.message)
    }

    let received = input(accepted: choice.options.indices.map { "\($0)" })

    guard
      let selected = Int(received),
      choice.options.indices.contains(selected)
    else {
      print("[Invalid option. Valid options: \(choice.options.indices)]")
      return .replay
    }

    return .advance(with: choice.options[selected])
  }
  ...
}
```

The function will `print` the possible options, together with their index (starting from `0`). Then, it will continuously `readLine` until the player enters an input that matches one of the possible ones, that is, the option indices. The logic is achieved through the `input(accepted:)` function, but in case something goes wrong, the `make(choice:)` function will return `.replay`.

## `handle(event:)`

`Event` is a flexible type that expresses various events that the `Runner` will communicate to the `Handler` in a "fire-and-forget" fashion: `Runner` will simply relay these events to the `Handler`, without expecting anything particular in return, and without suspending the function that's being executed. The possible events are the following:

```swift
public enum Player<Game: Setting>: Sendable {
  public enum Event: Sendable {
    case gameStarted(Status<Game>)
    case gameEnded
    case errorProduced(Failure<Game>)
    case statusUpdated(Status<Game>)
  }
}
```

In order:

- `gameStarted` will be sent when the game starts, and will pass over the initial `Status` (if the game is restored from persistence, this will be the restored `Status`);
- `gameEnded` will be sent when the game ends because the story is completed: it will not be sent if the the game ends "forcibly", either because the game process is terminated, or if the handler returns `.stop`;
- `errorProduced` will be sent in case of an error in the game engine;
- `statusUpdated` will be sent each time the `Status` is updated, so the game engine has the opportunity to log or persist it, if needed.

Here's a possible implementation of `handle(event:)` in our `SimpleHandler` class:

```Swift
private let directoryPath = "SimpleGameSupportingFiles"
private let filePath = "\(directoryPath)/Status.json"

public final class SimpleHandler<Game: Story> {
  ...
  private let encoder = JSONEncoder()
  private let fm = FileManager.default
  ...
}

extension SimpleHandler: Handler {
  ...

  public func handle(event: Player<Game>.Event) {
    switch event {
    case .statusUpdated(let status):
      guard let data = try? encoder.encode(status) else {
        break
      }
      let currentDirectory = FileManager.default.currentDirectoryPath
      try? FileManager.default.createDirectory(atPath: "\(currentDirectory)/\(directoryPath)", withIntermediateDirectories: true)
      try? FileManager.default.removeItem(atPath: "\(currentDirectory)/\(filePath)")
      try? data.write(to: URL(fileURLWithPath: "\(currentDirectory)/\(filePath)"))

    case .gameStarted(let status):
      print("""
      Welcome to Narratore!
      ...
      """)

      _ = readLine()

      for message in status.info.script.words.suffix(4) {
        print(message)
      }

    case .gameEnded:
      print("The story ended. Until next time.")
      try? FileManager.default.removeItem(atPath: filePath)

    case .errorProduced(let failure):
      print("ERROR: \(failure)")
    }
  }
}
```

By using `FileManager` and `JSONEncoder`, `SimpleHandler` is able to persist the state of the story (expressed by the `Status` type) each time it changes via the `statusUpdated` event, into a `.json` file at a certain path. Also, in `gameStarted`, it will show a simple welcome message, and print the last 4 messages from `status.info.script.words`, if available, for example when the game is restored from a previous `Status`. When the game ends, and `gameEnded` is received, `SimpleHandler` will delete the `.json` file with the game state. Finally, in case of `errorProduced`, the error will be simply printed.

## `answer(request:)`

Finally, an `Handler` must define a function to answer a `TestRequest` type, defined as

```swift
public enum Player<Game: Setting>: Sendable {
  ...
  public struct TextRequest: Sendable {
    public let message: Game.Message?
    public let validate: @Sendable (String) -> Validation
    public let tags: [Game.Tag]

    public enum Validation: Sendable {
      case valid(ValidatedText)
      case invalid(Game.Message?)
    }
  }

  public struct ValidatedText: Sendable {
    public let value: String
  }
  ...
}
```

This will be used by `Narratore` when the player must be asked to enter some text (for example, when naming a character).

## The `Runner`

In order to actually execute the game, the `Runner` actor must be used. `Runner` will simply require a `Handler` and a `Status`, to be initialized, and the only public function is `start()`. `Runner` also exposes a public `info: Info` property, that can be accessed at any time and will contain the latest game `Info` value, but given that `Runner` is an actor, the property access will be `async`.

As mentioned, `Runner` requires an `Handler` and a `Status`, to be initialized: the `Status` could be the one retrieved from a previously run and interrupted game, but can also be constructed with a starting value depending on a state of the game `World`, and a `Scene`:

```swift
public struct Status<Game: Setting>: Encodable, Sendable {
  public init(world: Game.World, scene: some SceneType<Game>) {
    ...
  }
  ...
}
```

Generally, when starting a fresh game, this `init` will be used. `Status` doesn't have any other public `init`, but it's `Encodable` in general, and `Decodable` if `Game` is a `Story`. So it can be serialized, and retrieved from a serialized state.

We want our `SimpleHandler` to also handle the serialization of `Status` so it makes sense to also equip it with a function to retrieve and decode a serialized `Status`, if available (and if the player wants to continue a previously interrupted game):

```swift
public struct SimpleHandler<Game: Story> {
  private let decoder = JSONDecoder()
  ...
  public func askToRestoreStatusIfPossible() -> Status<Game>? {
    let useFile: Bool
    if FileManager.default.fileExists(atPath: filePath) {
      print("""
      A Narratore status file was found at '\(filePath)': do you want to continue where you left?
      "[Valid inputs: y, n. Hit RETURN after entering a valid input.]"
      """)
      useFile = input(accepted: ["y", "n"]) == "y"
    } else {
      useFile = false
    }

    guard useFile else {
      return nil
    }

    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
      print("""
      Cannot read file, will start story from scratch.
      """)
      return nil
    }

    do {
      return try decoder.decode(Status<Game>.self, from: data)
    } catch {
      print("""
      Cannot read file, will start story from scratch.
      ERROR: \(error)
      """)
      return nil
    }
  }
  ...
}
```

The function `askToRestoreStatusIfPossible` will check for the existence of a `Status` file at a certain path and, if found, it will ask the player if they want to restore the story. If the file is not corrupted, a `Status` is returned, that can be passed to `Runner` in order to start the game where the player left it.

## Executing the game

Finally, to actually run the game we can define an `executableTarget` in which we call `Runner.start()` in the `@main` function:

```swift
import Narratore
import SimpleHandler
import SimpleSetting
import SimpleStory

@main
enum Main {
  static func main() async {
    let handler = SimpleHandler<SimpleStory>()
    
    let runner = Runner<SimpleStory>(
      handler: handler,
      status: handler.askToRestoreStatusIfPossible() ?? .init(
        world: .init(),
        scene: SimpleStory.initialScene()
      )
    )
    
    await runner.start()
  }
}
```

This code can be found in the `SimpleGame` target of the `SimpleGame` companion Swift package. Notice that this module imports all other modules (it's not strictly necessary, due to transitive dependencies, but it's useful for documentation purposes), because:

- to construct a `Runner` we need a `Handler` and a `Status`;
- to construct a `Status` we need a `World`, defined in the game `Setting`, and the `initialScene()`, defined in the game `Story`.
