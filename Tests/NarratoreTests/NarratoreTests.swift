import Narratore
import XCTest

class NarratoreTest: XCTestCase {
  var testScene1_main = TestScene1(title: "testScene1_main")
  var testScene1_other = TestScene1(title: "testScene1_other")
  var testScene2_main = TestScene2(title: "testScene2_main")
  var testScene2_other = TestScene2(title: "testScene2_other")

  override func setUp() {
    super.setUp()
    testScene1_main.updateSteps { "Test" }
    testScene1_other.updateSteps { "Test" }
    testScene2_main.updateSteps { "Test" }
    testScene2_other.updateSteps { "Test" }
  }

  func testReadRunnerScript() async {
    testScene1_main.updateSteps {
      "a"

      check { _ in
        .init(narration: .init(messages: [], tags: [], update: nil))
      }

      "b".with(id: "1")

      check { _ in
        .init(narration: .init(messages: [], tags: [], update: nil))
      }

      "c".with(id: "2")
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.narrated["1", default: 0], 1)
    XCTAssertEqual(story.narrated["2", default: 0], 1)
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
  }

  func testReadRunnerScriptWithTell() async {
    testScene1_main.updateSteps {
      "a"

      check { context in
        tell {
          "b".with(id: "1")

          if context.world.counter == 1 {
            "bb".with(id: "1")
          }

          "c"
        } update: {
          $0.counter += 1
        }
      }

      "d"

      check { context in
        tell(tags: ["a"]) {
          "e".with(id: "2")

          if context.world.counter == 1 {
            "ee".with(id: "2")
          }

          "f"
        }
      }

      "g"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.world.counter, 1)
    XCTAssertEqual(info.script.narrated["1", default: 0], 1)
    XCTAssertEqual(info.script.narrated["2", default: 0], 2)
    XCTAssertEqual(info.script.words, ["a", "b", "c", "d", "e", "ee", "f", "g"])
  }

  func testReadRunnerWorld() async {
    testScene1_main.updateSteps {
      "a"
      update {
        $0.counter += 1
      }
      "b"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let world = await runner.info.world
    XCTAssertEqual(world.counter, 1)
  }

  func testBasicHandledEvents() async {
    testScene1_main.updateSteps {
      "a"
      "b".with(id: "1")
      "c".with(id: "2")
      "d"
    }

    var finalStatus: Status<TestGame>?
    var gameStartedCount = 0
    var gameEndedCount = 0

    await Runner<TestGame>.init(
      handler: .mock(
        handleEvent: {
          switch $0 {
          case .statusUpdated(let status):
            finalStatus = status

          case .errorProduced(let error):
            XCTFail("\(error)")

          case .gameEnded:
            gameEndedCount += 1

          case .gameStarted:
            gameStartedCount += 1
          }
        }
      ),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    ).start()

    XCTAssertEqual(gameStartedCount, 1)
    XCTAssertEqual(gameEndedCount, 1)
    XCTAssertNotNil(finalStatus)
    XCTAssertEqual(finalStatus!.info.world.counter, 0)
    XCTAssertEqual(finalStatus!.info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(finalStatus!.info.script.narrated, ["1": 1, "2": 1])
  }

  func testBasicSceneJump() async {
    testScene1_main.updateSteps {
      "a"
      "b"
      then { .transitionTo(self.testScene2_main) }
    }

    testScene2_main.updateSteps {
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
  }

  func testBasicChoice() async {
    testScene1_main.updateSteps {
      "a"
      choose { _ in
        "* 1".onSelect {
          "b"
            .with(id: "b is selected")
            .then { .transitionTo(self.testScene2_main) }
        }

        "* 2".onSelect {
          "c"
            .with(id: "c is selected")
            .then { .transitionTo(self.testScene2_other) }
        }

        "* 3".onSelect {
          "d".then { .transitionTo(self.testScene2_other) }
        }
      }
    }

    testScene2_main.updateSteps {
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
    XCTAssertEqual(story.narrated["b is selected", default: 0], 1)
    XCTAssertEqual(story.narrated["c is selected", default: 0], 0)
  }

  func testBasicCheck() async {
    testScene1_main.updateSteps {
      "a"

      update {
        $0.counter = 10
      }

      check {
        if $0.world.counter == 10 {
          "b"
            .with { $0.counter -= 1 }
            .then { .transitionTo(self.testScene2_main) }
        }
      }
    }

    testScene2_main.updateSteps {
      "c"

      check {
        if $0.world.counter == 9 {
          "d".with { $0.counter -= 1 }
        } else {
          "e"
        }
      }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(info.world.counter, 8)
  }

  func testForcedUpdate() async {
    testScene1_main.updateSteps {
      "a"
      "b"

      check {
        if $0.world.counter == 7 {
          "c"
        }
      }

      "d"
    }

    var runner: Runner<TestGame>?
    runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: {
        if $0.messages.map(\.text) == ["b"] {
          return .advance {
            $0.counter = 7
          }
        }
        return .advance
      }),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner!.start()

    let info = await runner!.info
    XCTAssertEqual(info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(info.world.counter, 7)
  }

  func testReturnToChoiceWithUpdate() async {
    testScene1_main.updateSteps {
      "a"
      "b"
      then { .transitionTo(self.testScene1_other) }
    }

    testScene1_other.updateSteps {
      "c"
      "d".with(anchor: "return")
      "e"

      choose {
        if $0.world.counter < 1 {
          "f".onSelect {
            "f"
              .with { $0.counter += 1 }
              .then { .replaceWith(self.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 2 {
          "g".onSelect {
            "g"
              .with { $0.counter += 1 }
              .then { .replaceWith(self.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 3 {
          "h".onSelect {
            "h"
              .with { $0.counter += 1 }
              .then { .replaceWith(self.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 4 {
          "i".onSelect {
            "i".then { .replaceWith(self.testScene1_other, at: "continue") }
          }
        }
      }

      "j".with(anchor: "continue")
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.world.counter, 3)
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "d",
      "e",
      "g",
      "d",
      "e",
      "h",
      "d",
      "e",
      "i",
      "j",
      "k",
    ])
  }

  func testReturnToChoiceWithUpdateAndSimpleStep() async {
    testScene2_main.updateSteps {
      "a"
      "b".with(anchor: "return")
      "c"

      choose {
        if $0.world.counter < 1 {
          "d".onSelect {
            "d".with { $0.counter += 1 }
          }
        }

        if $0.world.counter < 2 {
          "e".onSelect {
            "e".with { $0.counter += 1 }
          }
        }

        if $0.world.counter < 3 {
          "f".onSelect {
            "f".with { $0.counter += 1 }
          }
        }

        if $0.world.counter < 4 {
          "g".onSelect {
            "g".with { $0.counter += 1 }
          }
        }
      }

      check {
        if $0.world.counter < 4 {
          "h".then { .replaceWith(self.testScene2_main, at: "return") }
        } else {
          "h"
        }
      }

      "i"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene2_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.world.counter, 4)
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "c",
      "d",
      "h",
      "b",
      "c",
      "e",
      "h",
      "b",
      "c",
      "f",
      "h",
      "b",
      "c",
      "g",
      "h",
      "i",
    ])
  }

  func testRunThrough() async {
    testScene1_main.updateSteps {
      "1_1"
      "1_2"
      "1_3"
    }

    testScene1_other.updateSteps {
      "2_1"
      "2_2"
      "2_3"
    }

    testScene2_main.updateSteps {
      "a"
      "b".with(anchor: "return")

      check {
        if $0.world.counter == 0 {
          "c"
            .with { $0.counter += 1 }
            .then { .runThrough(self.testScene1_main) }
        } else {
          "d"
            .with { $0.counter += 1 }
            .then { .runThrough(self.testScene1_other) }
        }
      }

      "e"

      check {
        if $0.world.counter < 2 {
          "f".then { .replaceWith(self.testScene2_main, at: "return") }
        }
      }

      "g"
      "h"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene2_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.world.counter, 2)
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "c",
      "1_1",
      "1_2",
      "1_3",
      "e",
      "f",
      "b",
      "d",
      "2_1",
      "2_2",
      "2_3",
      "e",
      "g",
      "h",
    ])
  }

  func testRunThroughAndReplaceWith() async {
    testScene1_main.updateSteps {
      "a"
      "b"

      "c"
      then { .runThrough(self.testScene1_other) }

      "d"
      "e"
    }

    testScene1_other.updateSteps {
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then { .replaceWith(self.testScene1_other, at: "continue") }
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "c",
      "f",
      "g",
      "h",
      "i",
      "g",
      "h",
      "j",
      "k",
      "d",
      "e",
    ])
  }

  func testRunThroughAndTransitionTo() async {
    testScene1_main.updateSteps {
      "a"
      "b"

      "c"
      then { .runThrough(self.testScene1_other) }

      "d"
      "e"
    }

    testScene1_other.updateSteps {
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then { .transitionTo(self.testScene1_other, at: "continue") }
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "c",
      "f",
      "g",
      "h",
      "i",
      "g",
      "h",
      "j",
      "k",
    ])
  }

  func testReplayNotAffectScript() async {
    testScene1_main.updateSteps {
      "a"
      "b"
      "c"
    }

    var didReplay = false

    let runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: {
        if !didReplay, $0.messages.map(\.text) == ["b"] {
          didReplay = true
          return .replay
        } else {
          return .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "b", "c"])
  }

  func testReplayWithChange() async {
    testScene1_main.updateSteps {
      "a"
      check {
        if $0.world.counter == 0 {
          "b"
        } else {
          "c"
        }
      }
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: {
        if $0.messages.map(\.text) == ["b"] {
          return .replay {
            $0.counter += 1
          }
        } else {
          return .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "c", "d"])
  }

  func testStopNotAffectScript() async {
    testScene1_main.updateSteps {
      "a"
      "b"
      "c"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: {
        if $0.messages.map(\.text) == ["b"] {
          return .stop
        } else {
          return .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a"])
  }

  func testSceneChangeShorthand() async {
    testScene1_main.updateSteps {
      "a"
      check {
        if $0.script.narrated["did see b", default: 0] == 0 {
          "b"
            .with(id: "did see b")
            .then { .replaceWith(self.testScene2_main) }
        }
      }
      "c"
    }

    testScene2_main.updateSteps {
      "d"
      "e"
      then { .runThrough(self.testScene1_main) }
      "f"
      "g"
      then { .transitionTo(self.testScene1_main) }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, [
      "a",
      "b",
      "d",
      "e",
      "a",
      "c",
      "f",
      "g",
      "a",
      "c",
    ])
  }

  func testObserveTags() async {
    testScene1_main.updateSteps {
      "a"
      "b".with(tags: ["observe-1"])
      "c"
      "d".with(tags: ["not-observe-1"])
      "e"
      choose(tags: ["observe-choice"]) { _ in
        "* 1".onSelect(tags: ["not-observe-1"]) {
          "* 1".then { .transitionTo(self.testScene2_main) }
        }

        "* 2".onSelect(tags: ["observe-1"]) {
          "* 2".then { .transitionTo(self.testScene2_main) }
        }
      }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info

    XCTAssertEqual(info.script.observed["observe-1", default: 0], 2)
    XCTAssertEqual(info.script.observed["not-observe-1", default: 0], 0)
    XCTAssertEqual(info.script.observed["observe-choice", default: 0], 1)
  }

  func testEncodeDecode() async throws {
    enum LocalTestGame: Story {
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

      static var scenes: [RawScene<LocalTestGame>] = [LocalTestScene1.raw, LocalTestScene2.raw]
    }

    struct LocalTestScene1: SceneType {
      typealias Game = LocalTestGame

      var steps: [SceneStep<Self>] {
        "a"
        "b"
        "c"
        then { .runThrough(LocalTestScene2()) }
        "d"
        "e"
      }
    }

    struct LocalTestScene2: SceneType {
      typealias Game = LocalTestGame

      var steps: [SceneStep<Self>] {
        "1"
        "2"
        "3"
      }
    }

    var status: Status<LocalTestGame>!

    let runner1 = Runner<LocalTestGame>.init(
      handler: Handling<LocalTestGame>(
        acknowledgeNarration: {
          if $0.messages.map(\.text) == ["2"] {
            return .stop
          }
          return .advance
        },
        makeChoice: { $0.options.first.map { .advance(with: $0) } ?? .stop },
        answerRequest: { _ in XCTFail("shouldn't be here"); return .stop },
        handleEvent: {
          if case .statusUpdated(let newStatus) = $0 {
            status = newStatus
          }
        }
      ),
      status: .init(
        world: .init(),
        scene: LocalTestScene1()
      )
    )
    await runner1.start()

    let encoded = try JSONEncoder().encode(status)
    let decoded = try JSONDecoder().decode(Status<LocalTestGame>.self, from: encoded)

    var narratedByRunner2: [String] = []

    let runner2 = Runner<LocalTestGame>.init(
      handler: Handling<LocalTestGame>(
        acknowledgeNarration: {
          for text in $0.messages.map(\.text) {
            narratedByRunner2.append(text)
          }
          return .advance
        },
        makeChoice: { $0.options.first.map { .advance(with: $0) } ?? .stop },
        answerRequest: { _ in XCTFail("shouldn't be here"); return .stop },
        handleEvent: { _ in }
      ),
      status: decoded
    )
    await runner2.start()

    let info1 = await runner1.info
    let info2 = await runner2.info

    XCTAssertEqual(info1.script.words, ["a", "b", "c", "1"])
    XCTAssertEqual(info2.script.words, ["a", "b", "c", "1", "2", "3", "d", "e"])
    XCTAssertEqual(narratedByRunner2, ["2", "3", "d", "e"])
  }

  func testRequestText() async {
    var receivedText: String?

    testScene1_main.updateSteps {
      "a"

      requestText {
        "b"
      } validate: {
        receivedText = $0
        return .valid(.init(text: $0))
      } ifValid: { _, _ in
        "c"
      }

      "d"
    }

    var receivedRequest: TestPlayer.TextRequest?
    
    let runner = Runner<TestGame>.init(
      handler: .mock(answerRequest: {
        receivedRequest = $0
        switch $0.validate("valid") {
        case .valid(let validated):
          return .advance(with: validated)

        case .invalid(let message):
          XCTFail("shouldn't fail (\(message ?? .init(text: "nil")))")
          return .stop
        }
      }),
      status: .init(
        world: .init(),
        scene: testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
    XCTAssertEqual(receivedText, "valid")
    XCTAssertEqual(receivedRequest?.message?.text, "b")
  }
}
