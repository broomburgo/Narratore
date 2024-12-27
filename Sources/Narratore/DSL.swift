// MARK: - SceneStep

/// The namespace for all functions that can be used in a `SceneBuilder` function.
///
/// To add more DSL functions, it should be extended by constraining the `Scene.Game` to the specific `Game` type one is writing.
public enum DO<Scene: SceneType> {
  /// Build a `SceneStep` out of a series of `Message`s.
  public static func tell(
    anchor: Scene.Anchor? = nil,
    tags: [Scene.Game.Tag] = [],
    @MessagesBuilder<Scene.Game> getMessages: @escaping @Sendable (Context<Scene.Game>) -> [Scene.Game.Message],
    update: Update<Scene.Game>? = nil
  ) -> SceneStep<Scene> {
    .init(anchor: anchor, getStep: .init {
      let messages = getMessages($0)

      return .tell(tags: tags, getMessages: {
        for message in messages {
          message
        }
      }, update: update)
    })
  }

  /// Create a `SceneStep` conditionally, based on the current `Context`.
  public static func check(
    anchor: Scene.Anchor? = nil,
    _ getStep: @escaping @Sendable (Context<Scene.Game>) -> Step<Scene.Game>
  ) -> SceneStep<Scene> {
    .init(anchor: anchor, getStep: .init(getStep))
  }

  /// Update the current `World`.
  public static func update(
    anchor: Scene.Anchor? = nil,
    _ update: @escaping @Sendable (inout Scene.Game.World) -> Void
  ) -> SceneStep<Scene> {
    .init(anchor: anchor, getStep: .init { _ in .init(update: update) })
  }

  /// Make the player choose between options.
  public static func choose(
    anchor: Scene.Anchor? = nil,
    tags: [Scene.Game.Tag] = [],
    @OptionsBuilder<Scene.Game> getOptions: @escaping @Sendable (Context<Scene.Game>) -> [Option<Scene.Game>]
  ) -> SceneStep<Scene> {
    .init(
      anchor: anchor,
      getStep: .init {
        .init(choice: .init(options: getOptions($0), tags: tags))
      }
    )
  }

  /// Ask the player to enter some text.
  public static func requestText(
    anchor: Scene.Anchor? = nil,
    tags: [Scene.Game.Tag] = [],
    @OptionalMessageBuilder<Scene.Game> getMessage: @escaping @Sendable () -> Scene.Game.Message?,
    validate: @escaping @Sendable (String) -> TextRequest<Scene.Game>.Validation,
    ifValid: @escaping @Sendable (Context<Scene.Game>, TextRequest<Scene.Game>.Validated) -> Step<Scene.Game>
  ) -> SceneStep<Scene> {
    .init(
      anchor: anchor,
      getStep: .init { context in
          .init(textRequest: .init(
            message: getMessage(),
            validate: validate,
            getStep: { ifValid(context, $0) },
            tags: tags
          ))
      }
    )
  }

  /// Create a `SceneStep` with a jump `Step` and empty `Narration`.
  public static func then(
    _ getSceneChange: @escaping @Sendable () -> SceneChange<Scene.Game>
  ) -> SceneStep<Scene> {
    .init(
      anchor: nil,
      getStep: .init { _ in
          .init(
            jump: .init(
              narration: .init(
                messages: [],
                tags: [],
                update: nil
              ),
              sceneChange: getSceneChange()
            )
          )
      }
    )
  }

  /// Creates a step that will be skipped; useful to establish a simple anchor that will not make the player acknowledge a narration or make a choice.
  public static func skip(anchor: Scene.Anchor? = nil) -> SceneStep<Scene> {
    .init(anchor: anchor, getStep: .init { _ in .skip })
  }

  /// Groups scene steps together.
  public static func group(@SceneBuilder<Scene> _ getSteps: () -> [SceneStep<Scene>]) -> [SceneStep<Scene>] {
    getSteps()
  }
}

extension String {
  /// Create a `SceneStep` with a narration `Step` created from the root `String`.
  public func with<Scene: SceneType>(
    anchor: Scene.Anchor? = nil,
    id: Scene.Game.Message.ID? = nil,
    tags: [Scene.Game.Tag] = [],
    update: Update<Scene.Game>? = nil
  ) -> SceneStep<Scene> {
    .init(
      anchor: anchor,
      getStep: .init { _ in
        .tell(
          tags: tags,
          getMessages: { [.init(id: id, text: self)] },
          update: update,
          then: nil
        )
      }
    )
  }
}

// MARK: - Step

extension Step {
  /// Build a `narration` step out of a series of `Message`s.
  public static func tell(
    tags: [Game.Tag] = [],
    @MessagesBuilder<Game> getMessages: () -> [Game.Message],
    update: Update<Game>? = nil,
    then getSceneChange: (() -> SceneChange<Game>)? = nil
  ) -> Self {
    let narration = Narration<Game>(messages: getMessages(), tags: tags, update: update)

    return if let sceneChange = getSceneChange?() {
      .init(jump: .init(
        narration: narration,
        sceneChange: sceneChange
      ))
    } else {
      .init(narration: narration)
    }
  }

  /// Build a `choice` step out of a series of `Option`s.
  public static func choose(
    tags: [Game.Tag] = [],
    @OptionsBuilder<Game> getOptions: @escaping () -> [Option<Game>]
  ) -> Self {
    .init(choice: .init(options: getOptions(), tags: tags))
  }

  /// Quick version of `if { someStep } else { .skip }`, useful for simple conditions and no particular `Step` in the `else` branch.
  public static func inCase(_ condition: Bool, getStep: () -> Self) -> Self {
    if condition {
      getStep()
    } else {
      .skip
    }
  }
}

// MARK: - Option

extension String {
  /// Create an `Option` with root the `String` as message text.
  public func onSelect<Game: Setting>(
    tags: [Game.Tag] = [],
    getStep: () -> Step<Game>
  ) -> Option<Game> {
    .init(
      message: .init(id: nil, text: self),
      step: getStep(),
      tags: tags
    )
  }
}

// MARK: - Message

/// No messages.
///
/// This function is useful in `tell` blocks, in order to avoid returning `Message`s for certain code paths.
///
/// Essentially, this is just returning an empty `Array<Message>`, so skipping messages can actually be done simply with `[]`, but a named function is probably clearer.
public func skip<Message: Messaging>() -> [Message] {
  []
}

extension String {
  /// Create a `Message` with the root `String` as text.
  public func with<Message: Messaging>(
    id: Message.ID? = nil
  ) -> Message {
    .init(id: id, text: self)
  }
}
