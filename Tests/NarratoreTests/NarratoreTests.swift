import Narratore
import XCTest

class NarratoreTest: XCTestCase {
  override func setUp() {
    super.setUp()
    TestScene1.Main.updateSteps { _ in "Test" }
    TestScene1.Other.updateSteps { _ in "Test" }
    TestScene2.Main.updateSteps { _ in "Test" }
    TestScene2.Other.updateSteps { _ in "Test" }
  }

  func testReadRunnerScript() async {
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.narrated["1", default: 0], 1)
    XCTAssertEqual(story.narrated["2", default: 0], 1)
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
  }

  func testReadRunnerScriptWithTell() async {
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
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
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let world = await runner.info.world
    XCTAssertEqual(world.counter, 1)
  }

  func testBasicHandledEvents() async {
    TestScene1.Main.updateSteps { _ in
      "a"
      "b".with(id: "1")
      "c".with(id: "2")
      "d"
    }

    var finalStatus: Status<TestGame>?
    var gameStartedCount = 0
    var gameEndedCount = 0

    await Runner<TestGame>.init(
      handler: .mock {
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
      },
      status: .init(
        world: .init(),
        scene: TestScene1()
      )
    ).start()

    XCTAssertEqual(gameStartedCount, 1)
    XCTAssertEqual(gameEndedCount, 1)
    XCTAssertNotNil(finalStatus)
    XCTAssertEqual(finalStatus!.info.world.counter, 0)
    XCTAssertEqual(finalStatus!.info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(finalStatus!.info.script.narrated, ["1": 1, "2": 1])
  }

  func testBasicBranchJump() async {
    TestScene1.Main.updateSteps { _ in
      "a"
      "b"
      then(.transitionTo(TestScene2()))
    }

    TestScene2.Main.updateSteps { _ in
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
  }

  func testBasicChoice() async {
    TestScene1.Main.updateSteps { _ in
      "a"
      choose { _ in
        "* 1".onSelect {
          "b"
            .with(id: "b is selected")
            .then(.transitionTo(TestScene2()))
        }

        "* 2".onSelect {
          "c"
            .with(id: "c is selected")
            .then(.transitionTo(TestScene2.Other.self, scene: .init()))
        }

        "* 3".onSelect {
          "d".then(.transitionTo(TestScene2.Other.self, scene: .init()))
        }
      }
    }

    TestScene2.Main.updateSteps { _ in
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
      )
    )
    await runner.start()

    let story = await runner.info.script
    XCTAssertEqual(story.words, ["a", "b", "c", "d"])
    XCTAssertEqual(story.narrated["b is selected", default: 0], 1)
    XCTAssertEqual(story.narrated["c is selected", default: 0], 0)
  }

  func testBasicCheck() async {
    TestScene1.Main.updateSteps { _ in
      "a"

      update {
        $0.counter = 10
      }

      check {
        if $0.world.counter == 10 {
          "b"
            .with { $0.counter -= 1 }
            .then(.transitionTo(TestScene2()))
        }
      }
    }

    TestScene2.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(info.world.counter, 8)
  }

  func testForcedUpdate() async {
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner!.start()

    let info = await runner!.info
    XCTAssertEqual(info.script.words, ["a", "b", "c", "d"])
    XCTAssertEqual(info.world.counter, 7)
  }

  func testReturnToChoiceWithUpdate() async {
    TestScene1.Main.updateSteps { scene in
      "a"
      "b"
      then(.transitionTo(TestScene1.Other.self, scene: scene))
    }

    TestScene1.Other.updateSteps { scene in
      "c"
      "d".with(anchor: "return")
      "e"

      choose {
        if $0.world.counter < 1 {
          "f".onSelect {
            "f"
              .with { $0.counter += 1 }
              .then(.replaceWith(TestScene1.Other.self, at: "return", scene: scene))
          }
        }

        if $0.world.counter < 2 {
          "g".onSelect {
            "g"
              .with { $0.counter += 1 }
              .then(.replaceWith(TestScene1.Other.self, at: "return", scene: scene))
          }
        }

        if $0.world.counter < 3 {
          "h".onSelect {
            "h"
              .with { $0.counter += 1 }
              .then(.replaceWith(TestScene1.Other.self, at: "return", scene: scene))
          }
        }

        if $0.world.counter < 4 {
          "i".onSelect {
            "i".then(.replaceWith(TestScene1.Other.self, at: "continue", scene: scene))
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
        scene: TestScene1()
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
    TestScene2.Main.updateSteps { scene in
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
          "h".then(.replaceWith(TestScene2.Main.self, at: "return", scene: scene))
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
        scene: TestScene2()
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
    TestScene1.Main.updateSteps { _ in
      "1_1"
      "1_2"
      "1_3"
    }

    TestScene1.Other.updateSteps { _ in
      "2_1"
      "2_2"
      "2_3"
    }

    TestScene2.Main.updateSteps { _ in
      "a"
      "b".with(anchor: "return")

      check {
        if $0.world.counter == 0 {
          "c"
            .with { $0.counter += 1 }
            .then(.runThrough(TestScene1.Main.self, scene: .init()))
        } else {
          "d"
            .with { $0.counter += 1 }
            .then(.runThrough(TestScene1.Other.self, scene: .init()))
        }
      }

      "e"

      check {
        if $0.world.counter < 2 {
          "f".then(.replaceWith(TestScene2.Main.self, at: "return", scene: .init()))
        }
      }

      "g"
      "h"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene2()
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
    TestScene1.Main.updateSteps { _ in
      "a"
      "b"

      "c"
      then(.runThrough(TestScene1.Other.self, scene: .init()))

      "d"
      "e"
    }

    TestScene1.Other.updateSteps { scene in
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then(.replaceWith(TestScene1.Other.self, at: "continue", scene: scene))
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
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
    TestScene1.Main.updateSteps { _ in
      "a"
      "b"

      "c"
      then(.runThrough(TestScene1.Other.self, scene: .init()))

      "d"
      "e"
    }

    TestScene1.Other.updateSteps { scene in
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then(.transitionTo(TestScene1.Other.self, at: "continue", scene: scene))
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
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
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "b", "c"])
  }

  func testReplayWithChange() async {
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a", "c", "d"])
  }

  func testStopNotAffectScript() async {
    TestScene1.Main.updateSteps { _ in
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
        scene: TestScene1()
      )
    )
    await runner.start()

    let info = await runner.info
    XCTAssertEqual(info.script.words, ["a"])
  }

  func testBranchChangeShorthand() async {
    TestScene1.Main.updateSteps { _ in
      "a"
      check {
        if $0.script.narrated["did see b", default: 0] == 0 {
          "b"
            .with(id: "did see b")
            .then(.replaceWith(TestScene2()))
        }
      }
      "c"
    }

    TestScene2.Main.updateSteps { _ in
      "d"
      "e"
      then(.runThrough(TestScene1()))
      "f"
      "g"
      then(.transitionTo(TestScene1()))
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
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
    TestScene1.Main.updateSteps { _ in
      "a"
      "b".with(tags: ["observe-1"])
      "c"
      "d".with(tags: ["not-observe-1"])
      "e"
      choose(tags: ["observe-choice"]) { _ in
        "* 1".onSelect(tags: ["not-observe-1"]) {
          "* 1".then(.transitionTo(TestScene2()))
        }

        "* 2".onSelect(tags: ["observe-1"]) {
          "* 2".then(.transitionTo(TestScene2()))
        }
      }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: TestScene1()
      )
    )
    await runner.start()

    let info = await runner.info

    XCTAssertEqual(info.script.observed["observe-1", default: 0], 2)
    XCTAssertEqual(info.script.observed["not-observe-1", default: 0], 0)
    XCTAssertEqual(info.script.observed["observe-choice", default: 0], 1)
  }

  func testEncodeDecode() async throws {
    TestScene1.Main.updateSteps { _ in
      "a"
      "b"
      "c"
      then(.runThrough(TestScene2()))
      "d"
      "e"
    }

    TestScene2.Main.updateSteps { _ in
      "1"
      "2"
      "3"
    }

    var status: Status<TestGame>!

    let runner1 = Runner<TestGame>.init(
      handler: .mock(
        handleEvent: {
          if case .statusUpdated(let newStatus) = $0 {
            status = newStatus
          }
        },
        acknowledgeNarration: {
          if $0.messages.map(\.text) == ["2"] {
            return .stop
          }
          return .advance
        }
      ),
      status: .init(
        world: .init(),
        scene: TestScene1()
      )
    )
    await runner1.start()

    let encoded = try JSONEncoder().encode(status)
    let decoded = try JSONDecoder().decode(Status<TestGame>.self, from: encoded)

    var narratedByRunner2: [String] = []

    let runner2 = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: {
        for text in $0.messages.map(\.text) {
          narratedByRunner2.append(text)
        }
        return .advance
      }),
      status: decoded
    )
    await runner2.start()

    let info1 = await runner1.info
    let info2 = await runner2.info

    XCTAssertEqual(info1.script.words, ["a", "b", "c", "1"])
    XCTAssertEqual(info2.script.words, ["a", "b", "c", "1", "2", "3", "d", "e"])
    XCTAssertEqual(narratedByRunner2, ["2", "3", "d", "e"])
  }
}
