# Narratore

`Narratore` is a Swift library that can be used to create and run interactive stories and narrative games.

With `Narratore` you can create stories using a DSL that allows to focus on the narration, with very few lines of code. In `Narratore` __a story is a Swift Package__.

The library also makes it easy to run a story, with a callback-based handler.

Here's an example of a minimal definition for a game with `Narratore`:

```swift
import Foundation
import Narratore

// ------ Define a game setting ------ //

enum MyGame: Setting {
  enum Generate: Generating {
    static func randomRatio() -> Double {
      Double((0...1000).randomElement()!)/1000
    }
    
    static func uniqueString() -> String {
      UUID().uuidString
    }
  }
  
  struct Message: Messaging {
    var id: String?
    var text: String
  }

  struct Tag: Tagging {
    var value: String
    
    init(_ value: String) {
      self.value = value
    }
  }
  
  struct World: Codable {
    var isEnjoyable = true
  }
}

// ------ Write a story ------ //

extension SceneType {
  typealias Game = MyGame
}

extension MyGame: Story {
  static let scenes: [RawScene<MyGame>] = [
    MyFirstScene.raw,
    MySecondScene_Main.raw,
    MySecondScene_Other.raw,
  ]
}

struct MyFirstScene: SceneType {
  typealias Anchor = String

  var steps: Steps {
    "Welcome"
    
    "This is your new game, built with narratore".with(tags: [.init("Let's play some sound effect!")])
    
    DO.check {
      .inCase($0.world.isEnjoyable) {
        .tell { "Enjoy!" }
      }
    }
    
    "Now choose".with(anchor: "We could jump right here from anywhere")
    
    DO.choose { _ in
      "Go to second scene, main path".onSelect {
        .tell {
          "Let's go to the second scene!"
            .with(id: "We can keep track of this message")
        } then: {
          .transitionTo(MySecondScene_Main(magicNumber: 42))  
        }
      }

      "Go to second scene, alternate path".onSelect {
        .tell {
          "Going to the alternate path of the second scene"
        } then: {
          .transitionTo(MySecondScene_Other())
        }
      }
    }
  }
}

struct MySecondScene_Main: SceneType {
  var magicNumber: Int

  var steps: [SceneStep<Self>] {
    "Welcome to the second scene"
    
    if magicNumber == 42 {
      "The magic number is \(magicNumber)"
    } else {
      "The magic number doesn't look right..."
    }
    
    "Hope you'll find this useful!"
  }
}

struct MySecondScene_Other: SceneType {
  var steps: [SceneStep<Self>] {
    "I see you chose the alternate path"
    
    "Bad luck!"
  }
}

// ------ Run the game ------ //

final class MyHandler: Handler {
  typealias Game = MyGame

  func handle(event: Event<MyGame>) {
    if case .gameEnded = event {
      print("Thanks for playing!")
    }
  }
  
  func acknowledge(narration: Narration<MyGame>) async -> Next<MyGame, Void> {
    for message in narration.messages {
      print(message)
      _ = readLine()
    }
    return .advance
  }
  
  func make(choice: Choice<MyGame>) async -> Next<MyGame, Option<MyGame>> {
    for (index, option) in choice.options.enumerated() {
      print(index, option.message)
    }
    
    while true {
      guard
        let captured = readLine(),
        let selected = Int(captured),
        choice.options.indices.contains(selected)
      else {
        print("Invalid input")
        continue
      }
      
      return .advance(with: choice.options[selected])
    }
  }
  
  func answer(request: Player<MyGame>.TextRequest) async -> Next<MyGame, Player<MyGame>.ValidatedText> {
    if let message = request.message {
      print(message)
    }

    guard let text = readLine() else {
      return .replay
    }

    switch request.validate(text) {
    case .valid(let validatedText):
      return .advance(with: validatedText)

    case .invalid(let optionalMessage):
      if let optionalMessage {
        print(optionalMessage)
      }
      return .replay
    }
  }
}

@main
enum Main {
  static func main() async {
    await Runner<MyGame>(
      handler: MyHandler(),
      status: .init(
        world: .init(),
        scene: MyFirstScene()
      )
    ).start()
  }
}
```

![](example.gif)

To learn about the detail of each main component of `Narratore`, check the following docs:

- [Defining a game setting](Docs/DEFINING_A_GAME_SETTING.md)
- [Writing a story](Docs/WRITING_A_STORY.md)
- [Running the game](Docs/RUNNING_THE_GAME.md)

`Narratore` is designed to be modular and extensible. In fact, each main component can be defined and implemented in a separate Swift package. For example:

- a specific game setting could be defined in a library;
- several stories could be created for a certain game setting;
- a game handler for that setting could be created for each platform (command line, iOS, macOS, Linux...);
- the final game would mix the game handler with one or more stories.

To learn how to extend `Narratore` and define modular components, check out [Extending Narratore](Docs/EXTENDING_NARRATORE.md).

The linked docs progressively build a basic game setting, a short story, a simple command-line runner, and some extension, each of which can be found in a companion package called [SimpleGame](https://github.com/broomburgo/SimpleGame), whose purpose is to show the basics of `Narratore` in practice via the construction of an actual story that can be run from the command line.

The main purpose of the companion package is to document the features of `Narratore`; nevertheless, most of its code is generic and reusable, and can be used to create games: please refer to the companion package [README](https://github.com/broomburgo/SimpleGame) to learn how to use it in your projects.

Thanks for checking out `Narratore`, I hope you'll have fun with it!

## Requirements

`Narratore` requires `iOS 13` and `macOS 10.15`, and has no third-party dependencies.

## Acknowledgments

`Narratore` is heavily inspired by [Ink](https://www.inklestudios.com/ink/), and its initial purpose was to be a similar story creation engine, but with the possibility of defining stories in Swift, instead of using a markup language. Nevertheless, the Ink specification was a strong inspiration for the features of `Narratore`.
