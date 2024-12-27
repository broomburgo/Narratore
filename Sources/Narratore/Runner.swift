/// Should be used to run a specific `Game`.
///
/// `Runner` is an `actor` that capable of managing the gameplay loop.
///
/// It can be constructed in 2 ways:
/// - with a `World` instance, a particular `Scene` and an `Handler`: use this to start a completely new game;
/// - with a `Status` and an `Handler`: use this to restore a previously run `Game`, thank to the codable `Status` instance.
///
/// To start the game, simply call `start()`. At any moment the latest `Info` can be read via the `info` property.
public actor Runner<Game: Setting> {
  public var info: Info<Game> {
    status.info
  }

  public init<H>(handler: H, status: Status<Game>) where H: Handler, H.Game == Game {
    handling = handler.handling
    self.status = status
  }

  public func start() async {
    handling.handle(event: .gameStarted(status))
    await runNext()
  }

  private let handling: Handling<Game>

  private var status: Status<Game> {
    didSet {
      handling.handle(event: .statusUpdated(status))
    }
  }

  private var getStepsCache: [Section<Game>: [GetStep<Game>]] = [:]

  private func runNext() async {
    guard let positionIndex = status.sceneStack.indices.last else {
      handling.handle(event: .gameEnded)
      return
    }

    var sceneStatus: SceneStatus<Game> {
      get {
        status.sceneStack[positionIndex]
      }
      set {
        status.sceneStack[positionIndex] = newValue
      }
    }

    let getSteps: [GetStep<Game>]
    if let fromCache = getStepsCache[sceneStatus.section] {
      getSteps = fromCache
    } else {
      getSteps = sceneStatus.section.steps
      getStepsCache[sceneStatus.section] = getSteps
    }

    let getStep = getSteps[sceneStatus.currentStepIndex]
    let step = await getStep(context: .init(
      generate: .init(),
      script: status.info.script,
      world: status.info.world
    ))
    let (newInfo, next) = await step.apply(info: status.info, handling: handling)
    status.info = newInfo

    switch next {
    case .advance(nil):
      sceneStatus.currentStepIndex += 1
      if !getSteps.indices.contains(sceneStatus.currentStepIndex) {
        status.sceneStack.removeLast()
      }

    case .advance(let sceneChange?):
      getStepsCache[sceneChange.section] = sceneChange.section.steps

      switch sceneChange.action {
      case .replaceWith:
        if !status.sceneStack.isEmpty {
          status.sceneStack.removeLast()
        }

      case .runThrough:
        if let lastSceneIndex = status.sceneStack.indices.last {
          status.sceneStack[lastSceneIndex].currentStepIndex += 1
        }

      case .transitionTo:
        status.sceneStack = []
      }

      status.sceneStack.append(.init(
        currentStepIndex: sceneChange.section.startingIndex,
        section: sceneChange.section
      ))

    case .replay:
      break

    case .stop:
      return
    }

    await runNext()
  }
}

/// Contains the full encodable status of the `Game`, that can be used to restore it when needed.
public struct Status<Game: Setting>: Encodable, Sendable {
  public internal(set) var info: Info<Game>
  public internal(set) var sceneStack: [SceneStatus<Game>]

  /// Create a initial `Status` for a certain `World` instance and `Scene`.
  public init<Scene>(world: Game.World, scene: Scene) where Scene: SceneType, Scene.Game == Game {
    info = .init(
      script: .init(),
      world: world
    )
    sceneStack = [
      .init(
        currentStepIndex: 0,
        section: .init(scene: scene)
      ),
    ]
  }
}

extension Status: Decodable where Game: Story {}

/// Contains the public readable info about a `Game`, that is, the `Script` and the state of the `World`.
public struct Info<Game: Setting>: Codable, Sendable {
  public internal(set) var script: Script<Game>
  public internal(set) var world: Game.World
}

/// The state of a specific scene in the stack.
public struct SceneStatus<Game: Setting>: Encodable, Sendable {
  public internal(set) var currentStepIndex: Int
  public internal(set) var section: Section<Game>
}

extension SceneStatus: Decodable where Game: Story {}

/// Passed to the `GetStep` function, to create a `Step`.
public struct Context<Game: Setting>: Sendable {
  public let generate: Generate<Game>
  public let script: Script<Game>
  public let world: Game.World
}

/// A convenience `struct` that wraps to functionality of `Generate`.
public struct Generate<Game: Setting>: Sendable {
  public let randomRatio: @Sendable () -> Double
  public let uniqueString: @Sendable () -> String

  init() {
    randomRatio = { Game.Generate.randomRatio() }
    uniqueString = { Game.Generate.uniqueString() }
  }
}
