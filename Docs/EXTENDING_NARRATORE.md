# Extending `Narratore`

> Most code examples in this document are taken from the `AdvancedSetting` module of the [companion package](https://github.com/broomburgo/SimpleGame).

`Narratore` is designed to be extendable in ways that are easy to achieve but sufficiently sophisticated to be able to build complex game systems from a simple foundation. Because everything is based on types, protocols and constrains, and because basically all types in `Narratore` are parametrized with the generic `Game: Setting`, including result builders, it's possible to build libraries that incrementally add more features to a game setting.

Let's see a couple of examples of possible extensions.

## A parametrized reusable `Setting`

Suppose we want to build a reusable `Setting` that includes some features, possibly in common with `SimpleSetting`, but includes a more sophisticated `World`, which can be partially parametrized.

We're not trying to build a specific setting here, but a new, more advanced set of **requirements** for a setting, that can be used to create several stories, with potentially different settings. 

We can define our `AdvancedSetting` as a `protocol` deriving from `Setting`, that adds a few extra things, so we can use those in generic functions designed to work with a setting conforming to `AdvancedSetting`. In general, we can use protocol to define all generic requirements of our types.

### A more sophisticated `World`

For example, we can add a new `AdvancedWorld` definition that includes:

- some specific character attributes;
- an inventory, where the inventory item type is parametrized;
- a `custom` property that refers to a completely custom, parametrized world.

To parametrize our `AdvancedWorld`, we can define a protocol that includes all the extra type parameters that we need:

```swift
public protocol AdvancedWorldExtra: Sendable {
  associatedtype Attribute: AdvancedWorldAttribute
  associatedtype InventoryItem: AdvancedWorldInventoryItem
  associatedtype CustomWorld: Codable, Sendable
}

public protocol AdvancedWorldAttribute: Codable, Hashable, Sendable {
  associatedtype Value: Codable, Sendable
}

public protocol AdvancedWorldInventoryItem: Codable, Hashable, Sendable {
  associatedtype Count: Codable, Sendable
}
```

### A localized `Message` with templating

Another possible extension consists in defining a more complex type for `Message`, that can be incorporated in other `Setting`s. Suppose, for example, that we want to define a `Message` type that can be localized in multiple languages. We would need 3 things:

- a way to define the possible languages, the current language used in the game (mutable) and the base language (for example, english);
- a templating strategy, so we can define a dictionary of values that can be reused between translations;
- an extension to the DSL, in order to be able to simply add translated messages to a story.

We can start again by collecting the type and value requirements in a protocol:

```swift
public protocol Localizing {
  associatedtype Language: Hashable, Codable
  static var base: Language { get }
  static var current: Language { get set }
  static var translations: [String: [Language: String]] { get }
}
```

Then, we can define a new `LocalizedMessage` concrete type, parametrized over a `Localization` type that conforms to `Localizing`:

```swift
public struct LocalizedMessage<Localization: Localizing>: Messaging {
  public var text: String {
    guard !baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ""
    }

    let templated: String =
      if Localization.current != Localization.base,
      let translated = Localization.translations[baseText]?[Localization.current] {
        translated
      } else {
        baseText
      }

    return templateValues.reduce(templated) {
      $0.replacingOccurrences(of: $1.key, with: $1.value)
    }
  }

  public var id: ID?
  public var baseText: String
  public var templateValues: [String: String]

  public init(
    id: ID?,
    baseText: String,
    templateValues: [String: String]
  ) {
    self.id = id
    self.baseText = baseText
    self.templateValues = templateValues
  }

  public init(id: ID?, text: String) {
    self.init(id: id, baseText: text, templateValues: [:])
  }

  public struct ID: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
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


### Putting things together

Once we defined our new requirements, described by the `AdvancedWorldExtra` and `Localizing` protocols, the trick is to create a new setting requirement with `associatedtype`s that conform to those protocols, so a specific concrete setting can provide its own types for those requirements:

```swift
public protocol AdvancedSetting: Setting where
  World == AdvancedWorld<Extra>,
  Message == LocalizedMessage<Localization>
{
  associatedtype Extra: AdvancedWorldExtra
  associatedtype Localization: Localizing
}
```

The `AdvancedSetting` protocol contraints the `World` and `Message` to be the new, more powerful concrete types that we defined, in order to provide new features to settings, stories and games that use it.

Note that `Message` is `LocalizedMessage`, that has an extra property `templateValues: [String: String]` (in order to manage localizations of texts that contain dynamic values), but in the DSL a simple string literal for a message will use the basic `init(id: ID?, text: String)` initializer for the `Message` type, that doesn't provide any templating.

We could add templating to messages in several ways, but an easy way is to define 2 new `with` function in a `String` extension, one to create a `SceneStep` (to be used at the top level of the `step` computed property of a scene), and one to create a `Message`, to be used in a `$MessagesBuilder` function (for example the one passed to the `tell` functions):

```swift
extension String {
  public func with<Localization: Localizing>(
    templateValues: [String: String],
    id: LocalizedMessage<Localization>.ID? = nil
  ) -> LocalizedMessage<Localization> {
    .init(id: id, baseText: self, templateValues: templateValues)
  }

  public func with<Scene: SceneType>(
    templateValues: [String: String],
    anchor: Scene.Anchor? = nil,
    id: Scene.Game.Message.ID? = nil,
    tags: [Scene.Game.Tag] = [],
    update: Update<Scene.Game>? = nil
  ) -> SceneStep<Scene> where Scene.Game: AdvancedSetting {
    .init(
      anchor: anchor,
      getStep: .init { _ in
        .tell(
          tags: tags,
          getMessages: { [.init(id: id, baseText: self, templateValues: templateValues)] },
          update: update,
          then: nil
        )
      }
    )
  }
}
```

Note that in the second `with` function we are creating a `LocalizedMessage` in the `getMessages` closure, because `Scene.Game: AdvancedSetting` and in `AdvancedSetting` the `Message` is constrained to be `LocalizedMessage`.

Finally, to see an example of a concrete setting conforming to `AdvancedSetting`, check the `MyAdvancedSetting` type in the companion package.
