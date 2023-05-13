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

struct TestScene1: SceneType {
  typealias Game = TestGame
  typealias Anchor = String

  var title: String

  init(title: String = "title") {
    self.title = title
  }

  private var _getSteps: () -> [SceneStep<Self>] = { [.init(
    anchor: nil,
    getStep: .init { _ in
      .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
    }
  )] }

  var steps: [SceneStep<Self>] {
    _getSteps()
  }

  mutating func updateSteps(@SceneBuilder<Self> _ update: @escaping () -> [SceneStep<Self>]) {
    _getSteps = {
      update()
    }
  }

  func encode(to encoder: Encoder) throws {
    try title.encode(to: encoder)
  }

  init(from decoder: Decoder) throws {
    try self.init(title: .init(from: decoder))
  }

  func hash(into hasher: inout Hasher) {
    title.hash(into: &hasher)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
  }
}

struct TestScene2: SceneType {
  typealias Game = TestGame
  typealias Anchor = String

  var title: String

  init(title: String = "title") {
    self.title = title
  }

  private var _getSteps: () -> [SceneStep<Self>] = { [.init(
    anchor: nil,
    getStep: .init { _ in
      .init(narration: .init(messages: [.init(id: nil, text: "Test")], tags: [], update: nil))
    }
  )] }

  var steps: [SceneStep<Self>] {
    _getSteps()
  }

  mutating func updateSteps(@SceneBuilder<Self> _ update: @escaping () -> [SceneStep<Self>]) {
    _getSteps = {
      update()
    }
  }

  func encode(to encoder: Encoder) throws {
    try title.encode(to: encoder)
  }

  init(from decoder: Decoder) throws {
    try self.init(title: .init(from: decoder))
  }

  func hash(into hasher: inout Hasher) {
    title.hash(into: &hasher)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
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
      answerRequest: { _ in fatalError() },
      handleEvent: handleEvent ?? { _ in }
    )
  }
}
