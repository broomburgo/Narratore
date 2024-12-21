@resultBuilder
public enum StepBuilder<Game: Setting> {
  public typealias Component = Step<Game>

  public static func buildExpression(_ expression: String) -> Component {
    .init(narration: .init(messages: [.init(id: nil, text: expression)], tags: [], update: nil))
  }

  public static func buildExpression(_ expression: Component) -> Component {
    expression
  }

  public static func buildOptional(_ component: Component?) -> Component {
    component ?? .skip
  }

  public static func buildEither(first component: Component) -> Component {
    component
  }

  public static func buildEither(second component: Component) -> Component {
    component
  }

  public static func buildBlock(_ component: Component) -> Component {
    component
  }
}

@resultBuilder
public enum OptionalMessageBuilder<Game: Setting> {
  public typealias Component = Game.Message?

  public static func buildExpression(_ expression: String) -> Component {
    .init(id: nil, text: expression)
  }

  public static func buildExpression(_ expression: Game.Message?) -> Component {
    expression
  }

  public static func buildBlock(_ component: Component) -> Component {
    component
  }
}

@resultBuilder
public enum MessagesBuilder<Game: Setting> {
  public typealias Component = [Game.Message]

  public static func buildExpression(_ expression: String) -> Component {
    [.init(id: nil, text: expression)]
  }

  public static func buildExpression(_ expression: Game.Message) -> Component {
    [expression]
  }

  public static func buildExpression(_ expression: [Game.Message]) -> Component {
    expression
  }

  public static func buildOptional(_ component: Component?) -> Component {
    component ?? []
  }

  public static func buildEither(first component: Component) -> Component {
    component
  }

  public static func buildEither(second component: Component) -> Component {
    component
  }

  public static func buildArray(_ components: [Component]) -> Component {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: Component...) -> Component {
    components.flatMap { $0 }
  }
}

@resultBuilder
public enum OptionsBuilder<Game: Setting> {
  public typealias Component = [Option<Game>]

  public static func buildExpression(_ expression: Option<Game>) -> Component {
    [expression]
  }

  public static func buildExpression(_ expression: [Option<Game>]) -> Component {
    expression
  }

  public static func buildOptional(_ component: Component?) -> Component {
    component ?? []
  }

  public static func buildEither(first component: Component) -> Component {
    component
  }

  public static func buildEither(second component: Component) -> Component {
    component
  }

  public static func buildArray(_ components: [Component]) -> Component {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: Component...) -> Component {
    components.flatMap { $0 }
  }
}

@resultBuilder
public enum SceneBuilder<Scene: SceneType> {
  public typealias Component = [SceneStep<Scene>]

  public static func buildExpression(_ expression: String) -> Component {
    [
      .init(
        anchor: nil,
        getStep: .init { _ in
          .init(
            narration: .init(
              messages: [.init(id: nil, text: expression)],
              tags: [],
              update: nil
            )
          )
        }
      ),
    ]
  }

  public static func buildExpression(_ expression: SceneStep<Scene>) -> Component {
    [expression]
  }

  public static func buildExpression(_ expression: [SceneStep<Scene>]) -> Component {
    expression
  }

  public static func buildOptional(_ component: Component?) -> Component {
    component ?? []
  }

  public static func buildEither(first component: Component) -> Component {
    component
  }

  public static func buildEither(second component: Component) -> Component {
    component
  }

  public static func buildArray(_ components: [Component]) -> Component {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: Component...) -> Component {
    components.flatMap { $0 }
  }
}
