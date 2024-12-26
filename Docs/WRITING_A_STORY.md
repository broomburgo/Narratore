#  Writing a story

> All the code examples in this document are taken from the `SimpleStory` module of the [companion package](https://github.com/broomburgo/SimpleGame). The structure of the story written in that module is purposely contrived, in order to show several features of `Narratore`.

The defining feature of `Narratore` is that a story is Swift Package. A key design choice in `Narratore` was to avoid representing stories in loosely typed formats, and take advantage of the full power of the Swift compiler to produce stories with state, choices, branching paths et cetera. To be able to write stories in a "natural" format, that doesn't look too much like code, `Narratore` makes heavy use of `@resultBuilder` to define a simple DSL that can help focusing on the narration itself. This documents provides a summary of the main features of `Narratore` when it comes to writing stories, and to do that the document follows an actual story that was written to showcase some of these features. You can check the story yourself: it's fully contained in the `SimpleStory` module of the companion package.

## The basics

A `Story` in `Narratore` is a protocol that derives from `Setting` (described in [Defining a game setting](DEFINING_A_GAME_SETTING.md)) and adds a `static var scenes: [RawScene<Self>] { get }` property. This is required for decoding reasons: when a story file is deserialized, `Narratore` looks for the scenes defined in the property in order to deserialize each scene. We'll see later what a `RawScene` is, but for now let's take a look a the basic building blocks of a `Story`, that is, `Scene`s, `Scene`es and `SceneStep`s.

### `Scene`

A `Scene` is a type conforming to the `protocol SceneType`. Essentially, a `Scene` is an actual piece of the story, it might be associated to a location, an episode, or even a simple character, and it must be `Codable`, and `Identifiable`, because it's associated to some state that will be serialized and deserialized, and each instance of it will be uniquely identified. For example, `SimpleStory` declares the following scene:

```swift
struct Car: SceneType {
  var id = Game.Generate.uniqueString()

  init() {}
  ...
}
```

Normally, `SceneType` would require a `typealias Game = ...` declaration, but within a single `Story` is simply possible to automatically add it to all `Scene`s:

```swift
public extension SceneType {
  typealias Game = SimpleStory
}
```

In order to easily conform to `Identifiable`, we can simply add a `var id = Game.Generate.uniqueString()` property, so each instance of if will be uniquely identified: this is important because `Narratore` keeps track of the stack of scene instances because it assumes that they are uniquely identified; in case of collisions, `Narratore` will not work properly, so the mere `Hashable` conformance, that doesn't guarantee no collision, would be risky.

Please note that the property is `var` and not `let` because of the `Codable` conformance.

In some cases, it might be convenient to group multiple scenes into a single namespace, because they're all related, and the namespace could include some convenient declarations that are related to all scenes:

```swift
public enum Bookshop {
  ...
  public enum Status: Codable {
    case regular
    case trashed
  }
  ...
  public struct Main: SceneType {
    public enum Anchor: Codable & Hashable {
      case askQuestions
    }

    public var status: Status = .regular
    ...
  }
  ...
}
```

This `Bookshop.Main` scene has a `status` property that defines the state of the bookshop: `regular` when it's in its normal state, and `trashed` when it was messed up by someone. The scene is the same, but it has 2 possible states, which will work almost as separate scenes, as we will see, thanks to the fact that the scene is `Hashable` (it's uniquely identified based on its state), and `Codable` (deserialization will have a different effect when restoring it from storage).

The `Scene` is the fundamental building block of a `Narratore` story: it's its "Lego piece", so to speak. One could define a `Story` with a single `Scene` and a (very) long list of steps, but it's often convenient to split the story in `Scene`s that have their own separate state.

A `Scene` provides a __linear list of steps__, whose actual content depends on the current state of the `Scene`. This can be easily seen by just looking at the definition of the `Scene` protocol:

```swift
public protocol SceneType: Codable & Hashable {
  associatedtype Game: Story
  associatedtype Anchor: Codable & Hashable = NoAnchor

  @SceneBuilder<Self>
  var steps: Steps { get }
}
```

A `Scene` is associated to a `Game: Story` and an `Anchor: Codable & Hashable` that defaults to `NoAnchor` (it's essentially "optional" then, because if it's not defined for a `Scene`, it will be assumed as non-existent). Also, `Scene` must define a `var steps: Steps { get }`, that returns a list of `SceneStep` and depends on the state of the scene (`Steps` is a `typealias`).

In theory, one could extend their `World` type with the `SceneType` protocol, and have all scenes in the game depend on the state of the `World` itself: while this could be a good idea for a very simple and short story, it's probably better to still split the story in several `Scene`s, that could then be referenced from the `World` if needed (being `Codable`, they can be put in `World` properties).

### `SceneStep`

The key requirement for a `Scene` is to provide a computed property that returns an `Array<SceneStep>`, and the types involved are pretty simple, so let's describe them in some detail:

```swift
public struct SceneStep<Scene: SceneType> {
  public init(anchor: Scene.Anchor? = nil,  getStep: GetStep<Scene.Game>) {
    ...
  }
  ...
}

public struct GetStep<Game: Setting> {
  public init(_ run: @escaping (Context<Game>) -> Step<Game>) {
    ...
  }
  ...
}

public struct Context<Game: Setting> {
  public let generate: Generate<Game>
  public let script: Script<Game>
  public let world: Game.World
}

public struct Step<Game: Setting> {
  public init(apply: @escaping (inout Info<Game>, Handling<Game>) async -> Outcome<Game>) {
    ...
  }
  ...
}

public struct Info<Game: Setting>: Codable {
  public internal(set) var script: Script<Game>
  public internal(set) var world: Game.World
}

public struct Handling<Game: Setting> {
  public init(
    acknowledgeNarration: @escaping (Player<Game>.Narration) async -> Next<Game,Void>,
    makeChoice: @escaping (Player<Game>.Choice) async -> Next<Game, Player<Game>.Option>,
    handleEvent: @escaping (Player<Game>.Event) -> Void
  ) {
    ...
  }
  ...
}

public typealias Outcome<Game: Setting> = Next<Game, SceneChange<Game>?>.Action
```

Basically, `SceneStep` requires a `GetStep`, and `GetStep` requires a function from `Context` to `Step`. The `Context` contains a generator defined from the `Setting.Generate` type, plus an (immutable) value of the current script of the story, and the state of the game world. `Step` is created from a function that takes:

- a mutable value of the pair script+state (the `Info`);
- a `Handling` value, that captures the logic of the `Handler` defined for the game;

The `Step` function then, returns an `Outcome`, that describes the next action `Narratore` should take (check [Running the game](RUNNING_THE_GAME.md) for more details on `Outcome` and some of the other types described).

It's perfectly possible to create a full story just by creating values of the types defined above: this value-based approach makes the creation of a story in `Narratore` extremely flexible. But `Narratore` also defines a DSL to handle these values – and combine them into a full story – that allows to basically forget about the high-level specifics and focus on the narration itself.

The next section will describe the various components of this DSL.

### The state of the story

It's important to understand how narratore represents the state of the story. The current state of the story, as mentioned above, is represented via the `Context` type

```swift
public struct Context<Game: Setting> {
  public let generate: Generate<Game>
  public let script: Script<Game>
  public let world: Game.World
}
```

where:

- `generate` exposes all generation functions provided to the `Game: Setting`;
- `script` represents _the story so far_, so all messages sent to the player, plus all additional metadata, if available;
- `world` is the current value of the `Game.World`, as defined in the `Game: Setting`.

Due to the fact that it's possible to assign unique identifiers to the `Game.Message`, whose "seen count" is kept track of by `Script`, it's technically possible to structure a complex state of the game without even having a `world`: the full script plus the count of observed messages and metadata can potentially be enough to represent even a complex state of the game world. But in general it can be useful to define a specific `Game.World` type, that could contain information based on classic patterns (attributes of the player, items and inventory, found leads, discovered locations et cetera).

Every single `Step` in a story can be customized based on the `Context` and, as we'll see, a `Step` could actually simply be an action that updates the `Game.World`. The `Script`, on the other hand, __cannot be updated__ by a step in the story, and it's exclusively updated by `Narratore` itself. 

## The DSL

The `static func getSteps(for: Parent) -> [SceneStep<Self>]` function of a `Scene` can be augmented with the `@SceneBuilder` result builder, that allows for creating stories in a natural way. This result builder provides all the expected `build_` functions, like `buildOptional`, `buildEither` and `buildArray`, so the composition can be customized based on the `Parent` scene that's passed into the function.

In addition to `@SceneBuilder` there are other result builders used in the DSL: I'll describe them in detail when needed. But everything starts with simple `String` literals.

### String literals

`@SceneBuilder` declares, among other things, the following function:

```swift
public static func buildExpression(_ expression: String) -> Component {
  ...
}
```

Thus, a `SceneStep` can be simply build from a `String`. You can take a look at the beginning of the `Main` scene of `Car` scene:

```swift
public struct Car: SceneType {
  public init() {}

  public var steps: Steps {
    "You wake up from an unusual dream"
    "You were under the sea, walking on the ground as if there was no pull to the surface, nor any resistance from the water itself"
    "But you were definitely under the sea, fishes and everything, and the light of the sun reflected on the shimmering water surface, creating a dream-like movement"
    ...
  }
  ...
}
```
 
 Simple string literals will be turned into `SceneStep` by the `SceneBuilder`. Now consider instead the beginning scene `Bookshop.Main`:
 
```swift
public struct Main: SceneType {
  ...
  public var steps: Steps {
    switch status {
    case .regular:
      "The bookshop is barely lit, with some fake candles on the top shelves projecting a faint, shimmering light"
      "There's lots of bookshelves, some full of books, some almost empty"
  ...
  }
  ...
}
```

Thanks to the powers of the `@resultBuilder`, we can `switch` over the state of the scene, and produce a sequence of steps that depends on it. Given a uniquely identified state of the scene (remember that `Scene` is `Hashable`), the sequence of steps must always be the same: but remember that `SceneStep` wraps a `GetStep` instance, that in turn wraps a function from the game `Context` to a `Step`, so the specific `Step` that is produced from a `SceneStep` can actually change, but only a single `Step` will eventually be produced (the `Step` can actually be a `skip` one, as we'll see in a moment).

Finally, you can usually add some properties to the message or narration step represented by a `String`, thanks to the `.with` extension function defined on it, for example:

```swift
"A corpse must be involved in this".with(id: .didSpeculatedAboutTheCorpse)
```

### `tell`

Internally, a `Step` can be constructed (among other things) from a `Narration`, which is type that holds an array of `Game.Message`, the basic way in which `Narratore` communicates some message to the player. This means that __a single step__ can be actually constituted from multiple messages, and the list or content of the messages can depend on the `Context` (that is, the state of the story).

The fact that a step can contain multiple message means that the story will be actually considered "advanced by a step" __only if__ all messages are acknowledged by the player: this also applies to state restoration, that is, if a game is restored from a `Status` value (check [Running the game](RUNNING_THE_GAME.md) for more details). This could actually be convenient, though: grouping messages that are thematically connected (like in a conversation or a description) can be useful because we might want to restore the state of the game a the beginning of that portion of story, in order to give the player the required context.

If you want to group some messages, and/or make them depend on the state of the story, you can use the `tell` function. For example, consider this portion of `Bookshop.Main`:

```swift
tell {
  if !$0.script.didNarrate(.didMeetTheOwner) {
    "You don't see people in the store"
    "You're quite sure, because you easily see through the empty shelves"
    ...
    "An old man emerges from the desk, behind a pile of books that might or might not be about botanics"
    "'Yes?'".with(id: .didMeetTheOwner)
  }
}
```

This uses a classic pattern: if a certain message was acknowledged (the message with `id == .didMeetTheOwner`) don't narrate that section again.

The `tell` function requires a closure of type `(Context<Game>) -> [Game.Message]`, so it takes the game `Context` as input, and must return a list of `Game.Message`. But `tell` uses `@MessagesBuilder` so we can define the messages with the regular DSL, with all the regular `build_` functions.

`Narratore` actually provides 3 separate `tell` function, depending on the context of the function where `tell` is called: this allows for a consistent experience, where it's almost always possible to use `tell` to group some messages. But the `Context` input to the closure is only present when `tell` is called at the first level of a `@SceneBuilder`: in any other case, a `Context` will already be present, so it's not repeated.

Within `tell` we can also use `skip()` to avoid sending messages in certain code paths, useful in case of a `switch`, for example in `Street.Main`:

```swift
"Or have weird thoughts"
"Or dreams"

switch theCreatureLookedLike {
case .anAlienBeing?:
  "For example, that alien being you dreamed about"
case .aFish?:
  "Like of weird fishes"
case .aDarkShadow?:
  "Dark dreams, of dark shadows"
default:
  skip()
}

"But you're still a well-rounded person"
"Easy to talk to"
```

You can attach an optional `update:` closure to a `tell` call, in order to strongly associate to that block of messages a change in the `Game.World`, for example:

```swift
tell {
  "You did notice an apartment block, next to the grocery store"
  "You should go take a look"
} update: {
  $0.didDiscover(.apartment7)
}
```

### `then`

The `then` function can be used to "jump" to another scene, or to a different place in the same scene, so that the narration continues from there. Jumping to other scenes can be done for several reasons:

- simple narration grouping;
- getting different outcomes from a choice;
- branching out in certain conditions;
- skipping ahead a section of a scene;
- "looping back" in the same scene or in a different one, previously encountered.

The `then` function is the basic mechanism with which you can build a story with several sceneing paths, that can also merge together. It's a DSL function, but it's also declared as an extension to `String` so it's possible to have a narration step alongside the scene jump.

Internally, `Narratore` will keep track of the current scene situation with a __stack of scenes__: it's possible, in fact, to define scene jumps in a way that allows for "running through" a scene, and then going back to the previous one, at the very next step after the jump. Also, when jumping from a scene to another, it's possible to jump to a specific point in the scene, thanks to the scene `Anchor` type.

The `then` function requires a `SceneChange` value, and there are 3 types of scene changes: let's take a look at them.

#### `runThrough`

This scene change will append a new scene on top of the scene stack, so the narration will continue from the start of the new scene, or from a certain step described by a specific `Anchor` value. When the scene ends, it will be removed from the stack, and the narration will continue in the previous scene, from the very next step after the one where the jump occurred.

`SceneChange.runThrough` can be used to narrate optional sections of the story, or to narrate a section right before a jump that you want to define in the starting scene.

#### `replaceWith`

Use this to replace the scene on top of the stack with another scene: when the new scene ends, it will be removed from the stack and the narration will continue from where it was sceneed from. You should consider `SceneChange.replaceWith` as the "default option", to be used in all cases where there is no specific need for particular types of sceneing.

#### `transitionTo`

This scene change completely replaces the scene stack with a new one that only contains the scene to which the narration is jumping: this will discard the entire stack, so all previous `runThrough` scene changes will be essentially ignored.

Use this for a hard narration changes, for example if the story should go to the ending scene, or for unrecoverable change in some condition in the story, for example if the main character is traveling to another place, or some major change in the world occurs, like a substantial shift in time that would make all previous narration jumps obsolete.

### `choose`

Other than advancing narration, the other main player interaction is making choices. The DSL allows for an expressive way to describe choices (and their consequences), including the possibility to make the available options depend on the script or state of the world.

It starts with the `choose` function, that takes a closure enhanced with the `@OptionsBuilder` result builder; also, if the `choose` function is called at the top level of a scene (thus, describing a `SceneStep`), the closure will take the `Context<Game>` as input.

Within the closure passed to `choose` we must describe the options that will be presented on the player, with the usual `@resultBuilder` features, that is, `if-else` scenes, `switch`, arrays and so on. In the end, the `@resultBuilder` will need to build an array of options (of type `Option<Game>`), which could depend on several conditions: please note that if the conditions produce __zero options__, the `Runner` will send an error to its `Handler` and the game will stop.

The DSL allows for building an option by simply writing a `String`, with the text that will be presented as option, and calling the `onSelect` function on it, for example:

```swift
"You look at the photograph"

choose { _ in
  "A man".onSelect {
    ...
  }

  "A woman".onSelect {
    ...
  }
}
``` 

Within the `onSelect` closure, __a single step` must be defined__: this will keep the narration linear, because the `choose` function will define a single step, that includes both the choice and the result of the choice. But thanks to the `tell` and `then` functions, it's actually possible to produce multiple messages within the context of an option, and also to jump to another scene, or within the same scene but in a different place. Here's some examples:

```swift
"You try to remember what the creature looked like.."

choose { _ in
  "Some kind of alien?".onSelect {
    tell {
      "...then it comes to your mind: it was some kind of alien being"
      "An alien 'entity' could describe it better"
      "Eerie, otherworldly"
      "You sure have a great imagination, and a great knowledge of eldritch words"
      "Including 'eldritch'"
    }
  }

  "Looked like a fish!".onSelect {
    tell {
      "...and, unsurprisingly, it looked like a large fish"
      "You don't know much about fish: you barely know that there's a distinction between saltwater and freshwater"
      "Maybe, in the future, if you see a picture of that particular fish, the dream will come back to your mind"
      "But for now, better not to linger"
    }
  }

  "I don't know..".onSelect {
    tell {
      "...but you really don't"
      "You think about some kind of formless dark shadow"
      "But you don't struggle that much: it was just a dream, no use in wasting mental energy in trying to remember what naturally fades away"
    }
  }
}
```

```swift
"The door is locked".with {
  $0.wasTheDoorClosed = true
}

choose(.atTheDoor) {
  if $0.world.wasTheKeyFound {
    "Open the door with the key".onSelect {
      tell {
        "You put the key in the locket and turn it counterclockwise"
        "The door unlocks"
        "You feel happy, and enter the apartment"
      }.then {
        .transitionTo(TheApartment())
      }
    }
  }

  switch scene.breakTheDoorCounter {
  case 0:
    "Try to break down the door".onSelect {
      tell {
        "You try break down the door with a push"
        "The door doesn't bulge"
      }.then {
        .replaceWith(self.updating { $0.breakTheDoorCounter = 1 }, at: .atTheDoor)
      }
    }

  case 1:
    "Try to break down the door again".onSelect {
      tell {
        "You try again"
        "You're pushing as hard as you can, but your \"build\" is not exactly one of a door-breaker"
      }.then { 
        .replaceWith(self.updating { $0.breakTheDoorCounter = 2 }, at: .atTheDoor)
      }
    }

  default:
    "Look for help".onSelect {
      tell {
        "You simply can't break the door down"
        "Maybe you should look for help"
        "It's going to be weird to ask someone to help you break into an apartment"
        "But you don't see many alternatives"
      }.then {
        .replaceWith(LookForHelp())
      }
    }
  }
}
```

```swift
"What will you do?".with(anchor: .whatToDo)

choose {
  let (they, _, _) = $0.world.targetPersonPronoun

  if scene.didLookAroundOnce {
    "Look around some more".onSelect {
      "You take another look around".then { 
        .replaceWith(LookAround())
      }
    }
  } else {
    "Look around".onSelect {
      "You take a look around".then {
        .replaceWith(LookAround())
      }
    }
  }
  
  if !scene.didAskAboutTheTarget {
    "Ask about the target".onSelect {
      "You ask the woman at the checkout about the person you're looking for".then {
        .replaceWith(AskAboutTheTarget())
      }
    }
  }
  
  if scene.didAskAboutTheTarget, scene.didNoticeMissingBeans {
    "Ask about the beans".onSelect {
      "'Did \(they) buy all the beans in the store?'".then {
        .replaceWith(AskAboutTheBeans())
      }
    }
  }
  
  "Get our of here".onSelect {
    tell {
      "You decide to leave the grocery store"
      "'Goodbye'"
    }
  }
}
```

Note that, in the last example, with the `"Get our of here"` option, after the `tell` the narration will simply proceed with the very next step after the `choose`.

Please also note that, as explained earlier, the `choose` function will describe a single step, that includes the choice and the effect of the choice: this means that, before updating the state of the story and the world, the full effect of the choice must take place. For example, if you're persisting the story `Status` with the callback `handle(event:)` with event `.statusUpdated` (see [Running the game](RUNNING_THE_GAME.md) for more details), the callback will actually be called only after the full effect of the choice has taken place. If you need to immediately persist the choice after it's made, simply return a "jump" step with the `then` function.

### `check`

Use can use the `check` function to create a `Step` that depends on the current `Context<Game>`. The closure passed to the `check` function is enhanced by the `@StepBuilder` result builder, that allows to return a step with the usual `@resultBuilder` function, but it's just for __a single step__: `Narratore` doesn't allows for sceneing paths within a single `Scene`, but you can use the `then` function (that requires a `SceneChange`) to "scene out" from a specific code path of a `check` function.

But even building a single `Step` can be good enough in several situations, in fact you can combine `check` with the `tell` function to generate a more complex set of conditions and outcomes, for example:

```swift
check {
  if $0.world.hasDiscovered(.apartment7) {
    "It's likely the key to the apartment in that apartment block"
  } else {
    tell {
      "You did notice an apartment block, next to the grocery store"
      "You should go take a look"
    } update: {
      $0.didDiscover(.apartment7)
    }
  }
}
```

Also, thanks to the fact that the `then` function is also an extension on `String`, it's possible to send a message with a `SceneChange` attached:

```swift
check {
  if $0.script.narrated[.didThinkAboutTheBookshopFeelings, default: 0] >= 3 {
    "...".then(.replaceWith(TheFeelingShop.self, scene: scene))
  } else {
    tell {
      "Let's discard this thought.."
      "..."
      "...for now"
    }
  }
}
```

You can create all types of `Step`s in the `check` function, including a choice step with `choose`:

```swift
check {
  if $0.world.theCreatureLookedLike == .aDarkShadow {
    choose {
      "It was just a dream".onSelect {
        "Yes, it was".with {
          $0.increaseMentalHealth()
        }
      }
      
      "Maybe... not?".onSelect {
        tell {
          "Maybe not"
          "These thoughts are not helping..."
        } update: {
          $0.decreaseMentalHealth()
        }
      }
    }
  }
}
```

In all uncovered code paths, internally, the `check` function will produce a `skip()` step, and it can also be used manually in case of `case` or `default` scenes in a `switch` that would ideally return with `break`.

### `update`

The `update` function can be used to update the state of the `Game.World`. The function can be called at various levels, that is:

- at the root level of a scene, as a free function;

```swift
"The rain is thin but persistent"

update {
  $0.didDiscover(.bookshop)
  $0.didDiscover(.groceryStore)
}

"You look around".with(anchor: .backInStreet)
```

- as an additional parameter of the `tell` function;

```swift
tell {
  "Yes you are, what was I thinking?"
  "Occasionally, you might have a weird dream or two"
  "But you like the normal world"
  "No alternate realities for you"
  "And that helps a lot with your line of work"
} update: {
  $0.areYouWeird = true
}
```

- as a parameter of the `.with` function, attached to a `String` (the `update` label is hidden because it's a trailing closure);

```swift
"The door is locked".with {
  $0.wasTheDoorClosed = true
}
```

### `skip`

In several contexts you'll be able to use the `skip` function to simply skip a narration step in specific conditions. You can also use `skip` at the root level of a scene to create a step that only acts as "marker", associating it to an `Anchor` to be able to jump to that point in the scene.

### `group`

Use the `group` function to create an array of scene steps – using usual `@SceneBuilder` – that can be reused between scenes: this is usually done via a generic function, declared outside a scene (thus, with a generic parameter constrained to be a `Scene`), that can be freely called inside scenes, in order to reuse steps.

`group` is a lightweight alternative to creating a whole scene and `runThrough` it in several other scenes, and here's an example of a generic function that uses `group` to create a check that's designed to be run in several scenes, several times during the story:

```swift
func checkMentalHealth<Scene: Scene>() -> [SceneStep<Scene>] where B.Parent.Game == SimpleStory {
  group {
    check {
      switch $0.world.mentalHealth {
      case 0:
        tell {
          "Suddenly, you feel agitated and paranoid"
          "You're senses are leaving you..."
          "It's like falling asleep..."
        }.then {
          .transitionTo(PassedOut())
        }
        
      case 1 where !$0.script.didNarrate(.gotToMentalHealth1):
        tell {
          "You feel confused"
          "It seems like you're sweating"
          "You're hands are shaking a bit".with(id: .gotToMentalHealth1)
        }
        
      case 2 where !$0.script.didNarrate(.gotToMentalHealth2):
        tell {
          "You feel a little disoriented"
          "It seems like someone is following you"
          "Or maybe you're being watched"
          "You can't say, but you better watch you back".with(id: .gotToMentalHealth2)
        }

      case 3 where !$0.script.didNarrate(.gotToMentalHealth3):
        tell {
          "You feel a little dizzy"
          "Maybe you're just tired"
          "Let's hope this case ends soon".with(id: .gotToMentalHealth3)
        }

      default:
        skip()
      }
    }
  }
}
```

This can be used as follows:

```swift
"It almost looks like someone did this on purpose"

check {
  if $0.world.didDepleteTheBatteryFaster {
    tell {
      "Your smartphone battery runs off"
      "You're left in the dark"
      "You can only feel the walls, while looking for the door"
    } update: {
      $0.decreaseMentalHealth()
    }
  }
}

checkMentalHealth()

"You keep going"
```
