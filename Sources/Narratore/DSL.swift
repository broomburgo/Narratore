// MARK: - BranchStep

/// Build a `BranchStep` out of a series of `Message`s.
public func tell<B: Branch>(_ anchor: B.Anchor? = nil, tags: [B.Game.Tag] = [], @MessagesBuilder<B.Game> getMessages: @escaping (Context<B.Game>) -> [B.Game.Message], update: Update<B.Game>? = nil) -> BranchStep<B> {
  .init(anchor: anchor, getStep: .init {
    let messages = getMessages($0)

    return tell(tags: tags, getMessages: {
      for message in messages {
        message
      }
    }, update: update)
  })
}

/// Create a `BranchStep` conditionally, based on the current `Context`.
public func check<B: Branch>(_ anchor: B.Anchor? = nil, @StepBuilder<B.Game> _ getStep: @escaping (Context<B.Game>) -> Step<B.Game>) -> BranchStep<B> {
  .init(anchor: anchor, getStep: .init(getStep))
}

/// Update the current `World`.
public func update<B: Branch>(_ anchor: B.Anchor? = nil, _ update: @escaping (inout B.Game.World) -> Void) -> BranchStep<B> {
  .init(anchor: anchor, getStep: .init { _ in .init(update: update) })
}

/// Make the player choose between options.
public func choose<B: Branch>(_ anchor: B.Anchor? = nil, tags: [B.Game.Tag] = [], @OptionsBuilder<B.Game> getOptions: @escaping (Context<B.Game>) -> [Option<B.Game>]) -> BranchStep<B> {
  .init(
    anchor: anchor,
    getStep: .init {
      .init(choice: .init(options: getOptions($0), tags: tags))
    }
  )
}

/// Create a `BranchStep` with a jump `Step` and empty `Narration`.
public func then<B: Branch>(
  _ branchChange: BranchChange<B.Game>
) -> BranchStep<B> {
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
          branchChange: branchChange
        )
      )
    }
  )
}

/// Creates a step that will be skipped; useful to establish a simple anchor that will not make the player acknowledge a narration or make a choice.
public func skip<B: Branch>(_ anchor: B.Anchor? = nil) -> BranchStep<B> {
  .init(anchor: anchor, getStep: .init { _ in .init() })
}

/// Groups branch steps together.
public func group<B: Branch>(@BranchBuilder<B> _ getSteps: () -> [BranchStep<B>]) -> [BranchStep<B>] {
  getSteps()
}

extension String {
  /// Create a `BranchStep` with a narration `Step` created from the root `String`.
  public func with<B: Branch>(
    anchor: B.Anchor? = nil,
    id: B.Game.Message.ID? = nil,
    tags: [B.Game.Tag] = [],
    update: Update<B.Game>? = nil
  ) -> BranchStep<B> {
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
public func tell<Game: Setting>(tags: [Game.Tag] = [], @MessagesBuilder<Game> getMessages: () -> [Game.Message], update: Update<Game>? = nil) -> Step<Game> {
  .init(narration: .init(messages: getMessages(), tags: tags, update: update))
}

/// Build a `choice` step out of a series of `Option`s.
public func choose<Game: Setting>(tags: [Game.Tag] = [], @OptionsBuilder<Game> getOptions: @escaping () -> [Option<Game>]) -> Step<Game> {
  .init(choice: .init(options: getOptions(), tags: tags))
}

/// Equivalent to calling `Step.init()`, which produces and empty step that will be skipped, but more ergonomic when used in `StepBuilder`.
public func skip<Game: Setting>() -> Step<Game> {
  .init()
}

extension String {
  /// Create a `Step` with the `Narration` created from the root `String`.
  public func with<Game: Setting>(
    id: Game.Message.ID? = nil,
    tags: [Game.Tag] = [],
    update: Update<Game>? = nil
  ) -> Step<Game> {
    .init(
      narration: self.with(id: id, tags: tags, update: update)
    )
  }

  /// Create a `Step` with a `Jump` containing the `Narration` created from the root `String`.
  public func then<Game: Setting>(
    _ branchChange: BranchChange<Game>
  ) -> Step<Game> {
    .init(jump: .init(
      narration: .init(messages: [.init(id: nil, text: self)], tags: [], update: nil),
      branchChange: branchChange
    ))
  }
}

extension Narration {
  /// Create a `Step` with a `Jump` containing the root `Narration`.
  public func then(
    _ branchChange: BranchChange<Game>
  ) -> Step<Game> {
    .init(jump: .init(
      narration: self,
      branchChange: branchChange
    ))
  }
}

// MARK: - Narration

/// Build a `narration` step out of a series of `Message`s.
public func tell<Game: Setting>(tags: [Game.Tag] = [], @MessagesBuilder<Game> getMessages: () -> [Game.Message], update: Update<Game>? = nil) -> Narration<Game> {
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
