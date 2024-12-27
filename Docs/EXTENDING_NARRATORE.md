# Extending `Narratore`

> Most code examples in this document are taken from the `AdvancedSetting` module of the [companion package](https://github.com/broomburgo/SimpleGame).

`Narratore` is designed to be extendable in ways that are easy to achieve but sufficiently sophisticated to be able to build complex game systems form a simple foundation. Because everything is based on types, protocols and constrains, and because basically all types in `Narratore` are parametrized with the generic `Game: Setting`, including result builders, it's possible to build libraries that incrementally add more features to a game setting.

Let's see a couple of examples of possible extensions.

## A parametrized reusable `Setting`

Suppose we want to build a reusable `Setting` that includes some features, possibly in common with `SimpleSetting`, but includes a more sophisticated `World`, which can be partially parametrized.

We could start by defining an `AdvancedSetting` that reuses some of the concepts of `SimpleSetting`

```swift
import Narratore
import SimpleSetting

public enum AdvancedSetting: Setting {
  public typealias Generate = SimpleSetting.Generate
  public typealias Message = SimpleSetting.Message
  public typealias Tag = SimpleSetting.Tag
  ...
}
``` 

but then add a new `World` definition that includes:

- some specific character attributes;
- an inventory, where the inventory item type is parametrized;
- a `custom` property that refers to a completely custom, parametrized world.

A good starting point is to declare in a protocol all the extra type parameters that we need:

```swift
public protocol SettingExtra {
  associatedtype CustomWorld: Codable
  associatedtype InventoryItem: Codable, Hashable
}
```

Then, we can add a type parameter to `AdvancedSetting`, and ask it to conform to this protocol:

```swift
public enum AdvancedSetting<Extra: SettingExtra>: Setting {
  ...
}
```

Finally, we can add a new `World` definition that takes advantage of this `Extra` parameter;

```swift
public enum AdvancedSetting<Extra: SettingExtra>: Setting {
  public typealias Generate = SimpleSetting.Generate
  public typealias Message = SimpleSetting.Message
  public typealias Tag = SimpleSetting.Tag

  public struct World: Codable {
    public var attributes: Attributes
    public var custom: Extra.CustomWorld
    public var inventory: [Extra.InventoryItem: Int]

    public init(
      attributes: Attributes,
      custom: Extra.CustomWorld,
      inventory: [Extra.InventoryItem: Int]
    ) {
      self.attributes = attributes
      self.custom = custom
      self.inventory = inventory
    }

    public struct Attributes: Codable {
      public var impact: Int
      public var dexterity: Int
      public var intelligence: Int
      public var perception: Int
      public var charisma: Int
      public var empathy: Int

      public init(
        impact: Int,
        dexterity: Int,
        intelligence: Int,
        perception: Int,
        charisma: Int,
        empathy: Int
      ) {
        self.impact = impact
        self.dexterity = dexterity
        self.intelligence = intelligence
        self.perception = perception
        self.charisma = charisma
        self.empathy = empathy
      }
    }
  }
}
```

When using this `AdvancedSetting` in practice, we'll define a concrete `AdvancedExtra` type, that conforms to `SettingExtra`, and use it in our particular story definition, which should be, ultimately, non-parametrized:

```swift
public enum AdvancedExtra: SettingExtra {
  public typealias CustomWorld = SimpleSetting.World

  public enum InventoryItem: Codable, Hashable {
    case apple
    case cloak
    case hat
  }
}

public typealias AdvancedStory = AdvancedSetting<AdvancedExtra>
```

Notice that as `CustomWorld` we're reusing `SimpleSetting.World`

## A localized `Message` with templating

Another possible extension consists in defining a more complex type for `Message`, that can be incorporated in other `Setting`s. Suppose, for example, that we wan to define a `Message` type that can be localized in multiple languages. We would need 3 things:

- a way to define the possible languages, the current language used in the game (mutable) and the base language (for example, english);
- a templating strategy, so we can define a dictionary of values that can be reused between translations;
- an extension to the DSL, in order to be able to simply add translated messages to a story.

We can start again by collecting the type and value requirements in a protocol:

```swift
public protocol Localizing {
  associatedtype Language: Hashable, Codable
  static var base: Language { get }
  static var current: Language { get set }
}
```

Then we can define out actual `LocalizedMessage` type:

```swift
public struct LocalizedMessage<Localization: Localizing>: Messaging {  
  public var text: String {
    let templated: String
    if Localization.current != Localization.base,
       let translated = translations[Localization.current]
    {
      templated = translated
    } else {
      templated = baseText
    }

    return values.reduce(templated) {
      $0.replacingOccurrences(of: $1.key, with: $1.value)
    }
  }
  
  public var id: ID?
  public var baseText: String
  public var translations: [Localization.Language: String]
  public var values: [String: String]

  public init(
    id: ID?,
    baseText: String,
    translations: [Localization.Language: String],
    values: [String: String]
  ) {
    self.id = id
    self.baseText = baseText
    self.translations = translations
    self.values = values
  }

  public init(id: ID?, text: String) {
    self.init(id: id, baseText: text, translations: [:], values: [:])
  }

  public struct ID: Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public var description: String

    public init(stringLiteral value: String) {
      description = value
    }
  }
}

```

Notice that:

- this type is completely self contained, it only requires importing `Narratore` due to the `Messaging` protocol conformance, so it's not tied to a specific `Setting`;
- the `var text: String { get }` requirement is satisfied, in this case, via a computed property, that considers `Localization.current`, `Localization.base`, the `translations` with which the message is constructed, and the `values` template dictionary;
- the `init(id: ID?, text: String)` requirement is still satisfied, so this message can be built with a simple `String`.

In order to be able to use this in the `Narratore` DSL in an ergonomic way, we need a simple function that can be called in the context of a `@SceneBuilder`. One option is to extend `String` with a particular function that returns a `SceneStep`:

```swift
extension String {
  public func localized<Scene: SceneType, Localization: Localizing>(
    anchor: Scene.Anchor? = nil,
    id: Scene.Game.Message.ID? = nil,
    values: [String: String] = [:],
    translations: [Localization.Language: String] = [:]
  ) -> SceneStep<Scene> where Scene.Game.Message == LocalizedMessage<Localization> {
    .init(
      anchor: anchor,
      getStep: .init { _ in
        .init(
          narration: .init(
            messages: [
              .init(
                id: id,
                baseText: self,
                translations: translations,
                values: values
              ),
            ],
            tags: [],
            update: nil
          )
        )
      }
    )
  }
}
```

Notice that this function is completely generic:

- it doesn't depend on a concrete specific `Game: Setting`, it only requires that the `Message` of the `Game` (reachable through `B.Game` where `B` is the `Scene`) is in fact a `LocalizedMessage`;
- it doesn't depend on a concrete specific `Localization` type, it only requires that it conforms to the `Localizing` protocol.

As you can see, the `LocalizedMessage` could be added to any `Game: Setting`, and the `localized` DSL function would then become "magically" available. For example, we can add this new `Localization` parameter to our `AdvancedSetting`, and thus be able to use `LocalizedMessage` in it:

```swift
public enum AdvancedSetting<Extra: SettingExtra, Localization: Localizing>: Setting {
  ...
  public typealias Message = LocalizedMessage<Localization>
  ...
}
```

Finally, here's a very basic example of a concrete `AdvancedStory`, that uses the `AdvancedSetting` and shows how the `localized` function can be used in the context of a `@SceneBuilder`:

```swift
public enum AdvancedExtra: SettingExtra {
  public typealias CustomWorld = SimpleSetting.World

  public enum InventoryItem: Codable, Hashable {
    case apple
    case cloak
    case hat
  }
}

public enum AdvancedLocalization: Localizing {
  public enum Language: Hashable, Codable {
    case english
    case italian
  }

  public static let base: Language = .english
  public static var current: Language = .italian
}

public typealias AdvancedStory = AdvancedSetting<AdvancedExtra, AdvancedLocalization>

extension AdvancedStory: Story {
  public static let scenes: [RawScene<Self>] = [
    AdvancedScene.raw,
  ]
}

struct AdvancedScene: SceneType {
  typealias Game = AdvancedStory

  var steps: [SceneStep<Self>] {
    "Hello!".localized(translations: [
      .italian: "Ciao!",
    ])

    "This is a story in english created with GAME_ENGINE_NAME".localized(
      values: ["GAME_ENGINE_NAME": "Narratore"],
      translations: [
        .italian: "Questa è una storia in italiano creata con GAME_ENGINE_NAME",
      ]
    )
  }
}
```
