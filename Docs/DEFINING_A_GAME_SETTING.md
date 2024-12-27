#  Defining a game setting

> All the code examples in this document are taken from the `SimpleSetting` module of the [companion package](https://github.com/broomburgo/SimpleGame).

A game `Setting` declares the types used to a make a specific story unique. In order to define a `Game` in `Narratore`, we need to declare a game type, and make it conform to `Setting`:

```swift
public enum SimpleSetting: Setting {
  ...
}
```

The game type can be an `enum`, because it's only expected to declare some associated types, and no state.

`Setting` requires the definition of 4 associated types:

- `Generate`: a type designed to generate values, for example random numbers;
- `Message`: the fundamental communication mechanism between `Narratore` and the player;
- `Tag`: additional metadata that can be attached to each step in the narration;
- `World`: use this type to define the state of your game; for example, it could contain the character's attributes, the inventory, experience points, but also the state of the world, events that happened, cases solved, other characters et cetera.

Each associated type has additional requirements, let's see them in detail.

## Generate

The purpose of the `Generate` type is to provide a game `Setting` with an integrated system to generate values (for example, random numbers). The type must conform to the `Generate` protocol, that currently only requires a static function to produce a random ratio between 0 and 1, and a static function to produce a unique string: the protocol could be expanded in the future with extra requirements, like a function to generate progressive integers, or a function to hash a string.

For testing purposes, it can be useful to give a `Generate` type some way to fix the values that are going to be produced, for example to control randomness.

Here's possible `Generate` definition for our `SimpleSetting`:

```swift
public enum SimpleSetting: Setting {
  ...
  public enum Generate: Generating {
    public static var getFixedRandomRatio: (() -> Double)? = nil
    public static var getFixedUniqueString: (() -> String)? = nil

    public static func randomRatio() -> Double {
      getFixedRandomRatio?() ?? Double((0...1000).randomElement()!)/1000
    }
    
    public static func uniqueString() -> String {
      getFixedUniqueString?() ?? UUID().uuidString
    }
  }  
}
```

## Message

A message can be as simple as a `String`, but thanks to the fact that in `Narratore` a `Message` is a generic type, it's possible to obtain more sophisticated results, for example attaching the message to a character, or handling story localization in a convenient way.

The `Message` associated type is expected to conform to the `Messaging` protocol, that declares some requirements:
- it must be `Codable` and `CustomStringConvertible`;
- it must define an `ID` associated type;
- it must have 2 properties, `text: String` and `id: ID?`;
- it must be constructible with a specific initializer.

Thanks to these requirements, any `Message` type will support the DSL utilities described in [Writing a story](WRITING_A_STORY.md). Also, `Narratore` provides a default implementation for `description` that simply returns the value of the `text` property.

In order to continue defining our `SimpleSetting`, let's define a `SimpleMessage` as the minimal type that can conform to `Messaging`

```swift
public enum SimpleSetting: Setting {
  ...  
  public struct Message: Messaging {
    public var id: ID?
    public var text: String
    
    public init(id: ID?, text: String) {
      self.id = id
      self.text = text
    }
    
    public struct ID: Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
      public var description: String
      
      public init(stringLiteral value: String) {
        self.description = value
      }
    }
  }
  ...
}
```

Instead of simply using `String` for the `associatedtype ID`, we defined a basic `ID` type that can essentially be created from and transformed to a `String`. The advantage of specifying a type is that we'll be able to extend this and give it more power if it's needed. Defining a specific type for something instead of using a `typealias` is the more flexible option, but it requires a small amount of boilerplate (`ID` in fact is essentially wrapping of `String` not much more).

## Tag

Each narration step in `Narratore` can be assigned zero or more `Tag`s, that represents additional metadata to take into account when that narration step is received by the `Handler` (see [Running the game](RUNNING_THE_GAME.md) for more details). For example, a `Tag` can be associated with showing some image in the game, or playing a sound, or modifying the font or the message text, or can be used to start a timer or attach some additional information that's relevant to the state of the game in general, but doesn't affect the way some particular narration step is communicated to the player.

The `Tag` type must conform to the `Tagging` protocol, that makes it `Hashable` and `Codable`, and requires a `shouldObserve: Bool` property: if `shouldObserve` is `true` the tag will recorded in the global state of the game, and the count of observations for that tag can always be accessed from the `Script` type.

Let's add a simple `Tag` definition to `SimpleSetting`:

```swift
public enum SimpleSetting: Setting {
  ...
  public struct Tag: Tagging, CustomStringConvertible {
    public var value: String
    public var shouldObserve: Bool
    
    public init(_ value: String, shouldObserve: Bool = false) {
      self.value = value
      self.shouldObserve = shouldObserve
    }
    
    public var description: String {
      value
    }
  }
  ...  
}

```

## World

The `World` type should represent the state of the game world. A game in `Narratore` must be started with an initial value for `World`, and it can be easily changed and manipulated during the course of the story, or even by the game engine itself, in case we need to make changes when running a game: for example, if a game has an inventory, and the player can interact with it outside of the story, we can reflect this change to the game world in the `Handler` (see [Running the game](RUNNING_THE_GAME.md)).

The only requirement for `World` is to be `Codable`, because `Narratore` expects the full state of the game (including `World`) to be serialized when running the game, so that after exiting and entering it again, such state can be restored.

`World` is an important part of `Narratore`, but there's no need to record everything in it: in fact, `Narratore` already records many aspects of the story, for example the messages a player has read, or the observed tags: in order to see how to keep track of the game state outside of `World`, please check [Writing a story](WRITING_A_STORY.md).

Ideally, a `World` is very specific to a certain type of game setting: for example, in a role playing game we would expect to have the player's attributes, experience and health defined in the world, while in a visual novel we would probably care more about the kind of relationships the main character has with other characters. But for now, let's define a `World` for our `SimpleSetting` that's sufficiently generic to be able to contain all sorts of information:

```swift
public enum SimpleSetting: Setting {
  public struct World: Codable {
    public var value: [Key: Value] = [:]
    public var list: [Key: [Value]] = [:]
    
    public init() {}

    public struct Key: ExpressibleByStringLiteral, CustomStringConvertible, Codable, Equatable, Hashable {
      public var description: String
      public init(stringLiteral value: String) {
        description = value
      }
    }

    public struct Value: ExpressibleByStringLiteral, CustomStringConvertible, Codable, Equatable {
      public var description: String
      public init(stringLiteral value: String) {
        description = value
      }
    }
  }
  ...
}
```

Like we did with the `Message.ID`, we defined specific types for the `Key`s and the `Value`s recorded in the `World` dictionaries – even if they're simple wrappers for a `String` – in order to achieve more flexibility in later usage.

## Scenes

To be runnable, a game in `Narratore` must conform to the `Story` protocol. `Story` inherits from `Setting` and adds a requirement for a `scenes` property.

There is one fundamental grouping mechanism for a story in `Narratore`: the `Scene`, which is represented via the `SceneType` protocol. A `Scene` is a linear portion of the story, defined via a series of narration steps, and a story is made by a set of `Scene`s. More details can be found in [Writing a story](WRITING_A_STORY.md), but the relevant part here is that `Narratore` must be able to reference all scenes statically, for deserialization reasons: when restoring a previously started game, `Narratore` must be able to decode each `Scene` from the serialized `Data`, and to do that it must look into the catalog of scenes declared in the `scenes` property of the game `Story`. 

The type of the required `scenes` property is `[RawScene<Self>]`: a `RawScene<Game>` is a "raw" representation of a `Codable` scene, and encapsulates the decoding mechanism for a specific scene. When writing a story in `Narratore`, it's expected that when a `Scene` is added, the `_Raw` version should also be added to the `scenes` property of the `Game`.

The separation between `Setting` and `Story` allows to create reusable `Setting`s, from which multiple `Story`es can be created (check [Extending Narratore](EXTENDING_NARRATORE.md) for more details) so, for now, the `SimpleSetting` definition is complete; now, let's see how to write a story in [Writing a story](WRITING_A_STORY.md).
