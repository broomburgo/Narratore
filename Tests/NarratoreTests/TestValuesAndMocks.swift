import Narratore

extension String: Tagging {
  public var shouldObserve: Bool {
    hasPrefix("observe")
  }
}

enum TestGame: Story {
  enum Generate: Generating {
    static var expectedRandomRatio: Double = 0.5
    static var expectedUniqueString: String = "expected"

    static func randomRatio() -> Double {
      expectedRandomRatio
    }

    static func uniqueString() -> String {
      expectedUniqueString
    }
  }

  struct Message: Messaging {
    var id: String?
    var text: String
  }

  typealias Tag = String

  struct World: Codable {
    var counter = 0
  }

  static var scenes: [RawScene<TestGame>] = [TestScene1.raw, TestScene2.raw]
}

typealias TestPlayer = Player<TestGame>

struct TestScene1: Scene {
  var title: String = "title"

  static let branches: [RawBranch<TestGame>] = [Main.raw, Other.raw]

  enum Main: Branch {
    private static var _getStepsFor: (TestScene1) -> [BranchStep<Self>] = { _ in [.init(
      anchor: nil,
      getStep: .init { _ in
        .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
      }
    )] }

    static func getSteps(for scene: TestScene1) -> [BranchStep<Self>] {
      _getStepsFor(scene)
    }

    static func updateSteps(
      @BranchBuilder<Self> _ update: @escaping (TestScene1)
        -> [BranchStep<Self>]
    ) {
      _getStepsFor = {
        update($0)
      }
    }
  }

  enum Other: Branch {
    typealias Anchor = String

    private static var _getStepsFor: (TestScene1) -> [BranchStep<Self>] = { _ in [.init(
      anchor: nil,
      getStep: .init { _ in
        .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
      }
    )] }

    static func getSteps(for scene: TestScene1) -> [BranchStep<Self>] {
      _getStepsFor(scene)
    }

    static func updateSteps(
      @BranchBuilder<Self> _ update: @escaping (TestScene1)
        -> [BranchStep<Self>]
    ) {
      _getStepsFor = {
        update($0)
      }
    }
  }
}

struct TestScene2: Scene {
  var title: String = "title"

  static let branches: [RawBranch<TestGame>] = [Main.raw, Other.raw]

  enum Main: Branch {
    typealias Anchor = String

    private static var _getStepsFor: (TestScene2) -> [BranchStep<Self>] = { _ in [.init(
      anchor: nil,
      getStep: .init { _ in
        .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
      }
    )] }

    static func getSteps(for scene: TestScene2) -> [BranchStep<Self>] {
      _getStepsFor(scene)
    }

    static func updateSteps(
      @BranchBuilder<Self> _ update: @escaping (TestScene2)
        -> [BranchStep<Self>]
    ) {
      _getStepsFor = {
        update($0)
      }
    }
  }

  enum Other: Branch {
    private static var _getStepsFor: (TestScene2) -> [BranchStep<Self>] = { _ in [.init(
      anchor: nil,
      getStep: .init { _ in
        .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
      }
    )] }

    static func getSteps(for scene: TestScene2) -> [BranchStep<Self>] {
      _getStepsFor(scene)
    }

    static func updateSteps(
      @BranchBuilder<Self> _ update: @escaping (TestScene2)
        -> [BranchStep<Self>]
    ) {
      _getStepsFor = {
        update($0)
      }
    }
  }
}

extension Handler where Self == Handling<TestGame> {
  static func mock(
    handleEvent: ((TestPlayer.Event) -> Void)? = nil,
    acknowledgeNarration: ((TestPlayer.Narration) async -> Next<TestGame, Void>)? = nil,
    makeChoice: ((TestPlayer.Choice) async -> Next<TestGame, TestPlayer.Option>)? = nil
  ) -> Handling<TestGame> {
    .init(
      acknowledgeNarration: acknowledgeNarration ?? { _ in .advance },
      makeChoice: makeChoice ?? { $0.options.first.map { .advance(with: $0) } ?? .stop },
      handleEvent: handleEvent ?? { _ in }
    )
  }
}
