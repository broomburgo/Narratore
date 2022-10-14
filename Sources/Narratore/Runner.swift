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

  private var getStepsCache: [AnyGetSection<Game>: [GetStep<Game>]] = [:]

  private func runNext() async {
    guard let positionIndex = status.branchStack.indices.last else {
      handling.handle(event: .gameEnded)
      return
    }

    var branchStatus: BranchStatus<Game> {
      get {
        status.branchStack[positionIndex]
      }
      set {
        status.branchStack[positionIndex] = newValue
      }
    }

    let getSteps: [GetStep<Game>]
    if let fromCache = getStepsCache[branchStatus.getSection] {
      getSteps = fromCache
    } else {
      getSteps = branchStatus.getSection().steps
      getStepsCache[branchStatus.getSection] = getSteps
    }

    let getStep = getSteps[branchStatus.currentStepIndex]
    let step = getStep(context: .init(
      generate: .init(),
      script: status.info.script,
      world: status.info.world
    ))
    let (newInfo, next) = await step.apply(info: status.info, handling: handling)
    status.info = newInfo

    switch next {
    case .advance(nil):
      branchStatus.currentStepIndex += 1
      if !getSteps.indices.contains(branchStatus.currentStepIndex) {
        status.branchStack.removeLast()
      }

    case .advance(let branchChange?):
      let getSection = branchChange.section
      let section = getSection()

      getStepsCache[getSection] = section.steps

      switch branchChange.action {
      case .replaceWith:
        if !status.branchStack.isEmpty {
          status.branchStack.removeLast()
        }

      case .runThrough:
        if let lastBranchIndex = status.branchStack.indices.last {
          status.branchStack[lastBranchIndex].currentStepIndex += 1
        }

      case .transitionTo:
        status.branchStack = []
      }

      status.branchStack.append(.init(
        currentStepIndex: section.startingIndex,
        getSection: getSection
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
public struct Status<Game: Setting>: Encodable {
  public internal(set) var info: Info<Game>
  public internal(set) var branchStack: [BranchStatus<Game>]

  /// Create a initial `Status` for a certain `World` instance and `Scene`.
  public init<S>(world: Game.World, scene: S) where S: Scene, S.Game == Game {
    info = .init(
      script: .init(),
      world: world
    )
    branchStack = [
      .init(
        currentStepIndex: 0,
        getSection: .init(GetSection<S.Main>.init(scene: scene))
      ),
    ]
  }
}

extension Status: Decodable where Game: Story {}

/// Contains the public readable info about a `Game`, that is, the `Script` and the state of the `World`.
public struct Info<Game: Setting>: Codable {
  public internal(set) var script: Script<Game>
  public internal(set) var world: Game.World
}

/// The state of a specific branch in the stack.
public struct BranchStatus<Game: Setting>: Encodable {
  public internal(set) var currentStepIndex: Int
  public internal(set) var getSection: AnyGetSection<Game>
}

extension BranchStatus: Decodable where Game: Story {}

/// Passed to the `GetStep` function, to create a `Step`.
public struct Context<Game: Setting> {
  public let generate: Generate<Game>
  public let script: Script<Game>
  public let world: Game.World
}

/// A convenience `struct` that wraps to functionality of `Generate`.
public struct Generate<Game: Setting> {
  public let randomRatio: () -> Double

  init() {
    randomRatio = { Game.Generate.randomRatio() }
  }
}
