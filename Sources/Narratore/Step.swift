/// The fundamental building block of a Narratore story.
///
/// A `Step` in Narratore is a flexible concept; it really just is a type wrapping a function with the following properties:
/// - the first input is an `inout Info<Game>`, that represents the full state of the game, and can be easily updated;
/// - the second input is a `Handling<Game>` instance, that allows to interact the game `Handler`, thus the player;
/// - the output is an instance of `Outcome<Game>`, used to decide what to do after processing a particular step.
///
/// The wrapped function is naturally `async`, in order to properly interact with the `Handler`.
public struct Step<Game: Setting> {
  private var _apply: (inout Info<Game>, Handling<Game>) async -> Outcome<Game>

  public init(apply: @escaping (inout Info<Game>, Handling<Game>) async -> Outcome<Game>) {
    self._apply = apply
  }

  public func apply(info: inout Info<Game>, handling: Handling<Game>) async -> Outcome<Game> {
    await _apply(&info, handling)
  }

  func apply(info: Info<Game>, handling: Handling<Game>) async -> (newInfo: Info<Game>, next: Outcome<Game>) {
    var newInfo = info
    let outcome = await apply(info: &newInfo, handling: handling)
    return (newInfo, outcome)
  }
}

/// The possible outcome of a `Step`, represented via the `Action` type of `Next`, where the value associated to the `.advance` case is an optional `BranchChange`.
public typealias Outcome<Game: Setting> = Next<Game, BranchChange<Game>?>.Action

extension Step {
  public static var skip: Self {
    .init { _, _ in .advance(nil) }
  }

  public init(choice: Choice<Game>) {
    guard !choice.options.isEmpty else {
      self = .skip
      return
    }
    
    self.init { info, handling in
      let playerOptions = choice.options.map {
        Player<Game>.Option.init(
          id: Game.Generate.uniqueString(),
          message: $0.message,
          tags: $0.tags
        )
      }
      
      let next = await handling.make(choice: .init(
        options: playerOptions,
        tags: choice.tags
      ))
      
      switch next.action {
      case .advance(let playerOption):
        guard
          let optionIndex = playerOptions.firstIndex(where: { $0.id == playerOption.id }),
          choice.options.indices.contains(optionIndex)
        else {
          handling.handle(event: .errorProduced(.invalidOptionId(expected: playerOptions.map(\.id), received: playerOption.id)))
          return .replay
        }
        
        info.script.append(choice: choice)
        next.update?(&info.world)

        return await choice.options[optionIndex].step.apply(info: &info, handling: handling)

      case .replay:
        next.update?(&info.world)
        return .replay

      case .stop:
        next.update?(&info.world)
        return .stop
      }
    }
  }

  public init(narration: Narration<Game>) {
    self.init { info, handling in
      let next: Next<Game, Void>
      if !narration.messages.isEmpty || !narration.tags.isEmpty {
        next = await handling.acknowledge(narration: .init(
          messages: narration.messages,
          tags: narration.tags
        ))
      } else {
        next = .advance
      }
      
      defer { next.update?(&info.world) }
      
      switch next.action {
      case .advance:
        info.script.append(narration: narration)
        narration.update?(&info.world)

        return .advance(nil)

      case .replay:
        return .replay

      case .stop:
        return .stop
      }
    }
  }

  public init(jump: Jump<Game>) {
    self.init { info, handling in
      let next: Next<Game, Void>
      if !jump.narration.messages.isEmpty || !jump.narration.tags.isEmpty {
        next = await handling.acknowledge(narration: .init(
          messages: jump.narration.messages,
          tags: jump.narration.tags
        ))
      } else {
        next = .advance
      }

      defer { next.update?(&info.world) }
      
      switch next.action {
      case .advance:
        info.script.append(narration: jump.narration)
        jump.narration.update?(&info.world)

        return .advance(jump.branchChange)

      case .replay:
        return .replay

      case .stop:
        return .stop
      }
    }
  }

  public init(update: @escaping Update<Game>) {
    self.init { info, _ in
      update(&info.world)

      return .advance(nil)
    }
  }
}

/// Wraps a function that allows to create a `Step` conditionally, given the game `Context`.
public struct GetStep<Game: Setting> {
  private var run: (Context<Game>) -> Step<Game>

  public init(_ run: @escaping (Context<Game>) -> Step<Game>) {
    self.run = run
  }

  public func callAsFunction(context: Context<Game>) -> Step<Game> {
    run(context)
  }
}
