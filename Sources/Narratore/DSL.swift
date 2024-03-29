/// Build a `SceneStep` out of a series of `Message`s.
public func tell<Scene: SceneType>(
  _ anchor: Scene.Anchor? = nil,
  tags: [Scene.Game.Tag] = [],
  @MessagesBuilder<Scene.Game> getMessages: @escaping (Context<Scene.Game>) -> [Scene.Game.Message],
  update: Update<Scene.Game>? = nil
) -> SceneStep<Scene> {
  .init(anchor: anchor, getStep: .init {
    let messages = getMessages($0)

    return tell(tags: tags, getMessages: {
      for message in messages {
        message
      }
    }, update: update)
  })
}

/// Create a `SceneStep` conditionally, based on the current `Context`.
public func check<Scene: SceneType>(
  _ anchor: Scene.Anchor? = nil,
  @StepBuilder<Scene.Game> _ getStep: @escaping (Context<Scene.Game>) -> Step<Scene.Game>
) -> SceneStep<Scene> {
  .init(anchor: anchor, getStep: .init(getStep))
}

/// Update the current `World`.
public func update<Scene: SceneType>(
  _ anchor: Scene.Anchor? = nil,
  _ update: @escaping (inout Scene.Game.World) -> Void
) -> SceneStep<Scene> {
  .init(anchor: anchor, getStep: .init { _ in .init(update: update) })
}

/// Make the player choose between options.
public func choose<Scene: SceneType>(
  _ anchor: Scene.Anchor? = nil,
  tags: [Scene.Game.Tag] = [],
  @OptionsBuilder<Scene.Game> getOptions: @escaping (Context<Scene.Game>) -> [Option<Scene.Game>]
) -> SceneStep<Scene> {
  .init(
    anchor: anchor,
    getStep: .init {
      .init(choice: .init(options: getOptions($0), tags: tags))
    }
  )
}

/// Ask the player to enter some text.
public func requestText<Scene: SceneType>(
  _ anchor: Scene.Anchor? = nil,
  tags: [Scene.Game.Tag] = [],
  @OptionalMessageBuilder<Scene.Game> getMessage: @escaping () -> Scene.Game.Message?,
  validate: @escaping (String) -> TextRequest<Scene.Game>.Validation,
  @StepBuilder<Scene.Game> ifValid: @escaping (Context<Scene.Game>, TextRequest<Scene.Game>.Validated) -> Step<Scene.Game>
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
public func then<Scene: SceneType>(
  _ getSceneChange: @escaping () -> SceneChange<Scene.Game>
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
public func skip<Scene: SceneType>(_ anchor: Scene.Anchor? = nil) -> SceneStep<Scene> {
  .init(anchor: anchor, getStep: .init { _ in .skip })
}

/// Groups scene steps together.
public func group<Scene: SceneType>(@SceneBuilder<Scene> _ getSteps: () -> [SceneStep<Scene>])
  -> [SceneStep<Scene>]
{
  getSteps()
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
        self.with(id: id, tags: tags, update: update)
      }
    )
  }
}

// MARK: - Step

/// Build a `narration` step out of a series of `Message`s.
public func tell<Game: Setting>(
  tags: [Game.Tag] = [],
  @MessagesBuilder<Game> getMessages: () -> [Game.Message],
  update: Update<Game>? = nil
) -> Step<Game> {
  .init(narration: .init(messages: getMessages(), tags: tags, update: update))
}

/// Build a `choice` step out of a series of `Option`s.
public func choose<Game: Setting>(
  tags: [Game.Tag] = [],
  @OptionsBuilder<Game> getOptions: @escaping () -> [Option<Game>]
) -> Step<Game> {
  .init(choice: .init(options: getOptions(), tags: tags))
}

/// Equivalent to calling `Step.init()`, which produces and empty step that will be skipped, but more ergonomic when used in `StepBuilder`.
public func skip<Game: Setting>() -> Step<Game> {
  .skip
}

extension String {
  /// Create a `Step` with the `Narration` created from the root `String`.
  public func with<Game: Setting>(
    id: Game.Message.ID? = nil,
    tags: [Game.Tag] = [],
    update: Update<Game>? = nil
  ) -> Step<Game> {
    .init(
      narration: with(id: id, tags: tags, update: update)
    )
  }

  /// Create a `Step` with a `Jump` containing the `Narration` created from the root `String`.
  public func then<Game: Setting>(
    _ getSceneChange: () -> SceneChange<Game>
  ) -> Step<Game> {
    .init(jump: .init(
      narration: .init(messages: [.init(id: nil, text: self)], tags: [], update: nil),
      sceneChange: getSceneChange()
    ))
  }
}

extension Narration {
  /// Create a `Step` with a `Jump` containing the root `Narration`.
  public func then(
    _ getSceneChange: () -> SceneChange<Game>
  ) -> Step<Game> {
    .init(jump: .init(
      narration: self,
      sceneChange: getSceneChange()
    ))
  }
}

// MARK: - Narration

/// Build a `narration` step out of a series of `Message`s.
public func tell<Game: Setting>(
  tags: [Game.Tag] = [],
  @MessagesBuilder<Game> getMessages: () -> [Game.Message],
  update: Update<Game>? = nil
) -> Narration<Game> {
  .init(messages: getMessages(), tags: tags, update: update)
}

extension String {
  /// Create a `Narration` with the root `String` as message text.
  public func with<Game: Setting>(
    id: Game.Message.ID? = nil,
    tags: [Game.Tag] = [],
    update: Update<Game>? = nil
  ) -> Narration<Game> {
    .init(
      messages: [.init(id: id, text: self)],
      tags: tags,
      update: update
    )
  }
}

// MARK: - Option

extension String {
  /// Create an `Option` with root the `String` as message text.
  public func onSelect<Game: Setting>(
    tags: [Game.Tag] = [],
    @StepBuilder<Game> getStep: () -> Step<Game>
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
