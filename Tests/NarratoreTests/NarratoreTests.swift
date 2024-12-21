import Narratore
import Testing
import Foundation

struct NarratoreTest {
  @Test
  func readRunnerScript() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
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
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    #expect(story.narrated["1", default: 0] == 1)
    #expect(story.narrated["2", default: 0] == 1)
    #expect(story.words == ["a", "b", "c", "d"])
  }

  @Test
  func readRunnerScriptWithTell() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
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
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.world.counter == 1)
    #expect(info.script.narrated["1", default: 0] == 1)
    #expect(info.script.narrated["2", default: 0] == 2)
    #expect(info.script.words == ["a", "b", "c", "d", "e", "ee", "f", "g"])
  }

  @Test
  func readRunnerWorld() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
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
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let world = await runner.info.world
    #expect(world.counter == 1)
  }

  @Test
  func basicHandledEvents() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b".with(id: "1")
      "c".with(id: "2")
      "d"
    }

    nonisolated(unsafe) var finalStatus: Status<TestGame>?
    nonisolated(unsafe) var gameStartedCount = 0
    nonisolated(unsafe) var gameEndedCount = 0

    await Runner<TestGame>.init(
      handler: .mock(
        handleEvent: { @Sendable in
          switch $0 {
          case .statusUpdated(let status):
            finalStatus = status

          case .errorProduced(let error):
            Issue.record(error)

          case .gameEnded:
            gameEndedCount += 1

          case .gameStarted:
            gameStartedCount += 1
          }
        }
      ),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    ).start()

    #expect(gameStartedCount == 1)
    #expect(gameEndedCount == 1)
    #expect(finalStatus != nil)
    #expect(finalStatus!.info.world.counter == 0)
    #expect(finalStatus!.info.script.words == ["a", "b", "c", "d"])
    #expect(finalStatus!.info.script.narrated == ["1": 1, "2": 1])
  }

  @Test
  func basicSceneJump() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"
      then { .transitionTo(values.testScene2_main) }
    }

    values.testScene2_main.updateSteps {
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    #expect(story.words == ["a", "b", "c", "d"])
  }

  @Test
  func basicChoice() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      choose { _ in
        "* 1".onSelect {
          "b"
            .with(id: "b is selected")
            .then { .transitionTo(values.testScene2_main) }
        }

        "* 2".onSelect {
          "c"
            .with(id: "c is selected")
            .then { .transitionTo(values.testScene2_other) }
        }

        "* 3".onSelect {
          "d".then { .transitionTo(values.testScene2_other) }
        }
      }
    }

    values.testScene2_main.updateSteps {
      "c"
      "d"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    #expect(story.words == ["a", "b", "c", "d"])
    #expect(story.narrated["b is selected", default: 0] == 1)
    #expect(story.narrated["c is selected", default: 0] == 0)
  }

  @Test
  func basicCheck() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"

      update {
        $0.counter = 10
      }

      check {
        if $0.world.counter == 10 {
          "b"
            .with { $0.counter -= 1 }
            .then { .transitionTo(values.testScene2_main) }
        }
      }
    }

    values.testScene2_main.updateSteps {
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
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == ["a", "b", "c", "d"])
    #expect(info.world.counter == 8)
  }

  @Test
  func forcedUpdate() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
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
      handler: .mock(acknowledgeNarration: { @Sendable in
        if $0.messages.map(\.text) == ["b"] {
          return .advance {
            $0.counter = 7
          }
        }
        return .advance
      }),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner!.start()

    let info = await runner!.info
    #expect(info.script.words == ["a", "b", "c", "d"])
    #expect(info.world.counter == 7)
  }

  @Test
  func returnToChoiceWithUpdate() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"
      then { .transitionTo(values.testScene1_other) }
    }

    values.testScene1_other.updateSteps {
      "c"
      "d".with(anchor: "return")
      "e"

      choose {
        if $0.world.counter < 1 {
          "f".onSelect {
            "f"
              .with { $0.counter += 1 }
              .then { .replaceWith(values.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 2 {
          "g".onSelect {
            "g"
              .with { $0.counter += 1 }
              .then { .replaceWith(values.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 3 {
          "h".onSelect {
            "h"
              .with { $0.counter += 1 }
              .then { .replaceWith(values.testScene1_other, at: "return") }
          }
        }

        if $0.world.counter < 4 {
          "i".onSelect {
            "i".then { .replaceWith(values.testScene1_other, at: "continue") }
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
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.world.counter == 3)
    #expect(info.script.words == [
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

  @Test
  func returnToChoiceWithUpdateAndSimpleStep() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene2_main.updateSteps {
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
          "h".then { .replaceWith(values.testScene2_main, at: "return") }
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
        scene: values.testScene2_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.world.counter == 4)
    #expect(info.script.words == [
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

  @Test
  func runThrough() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "1_1"
      "1_2"
      "1_3"
    }

    values.testScene1_other.updateSteps {
      "2_1"
      "2_2"
      "2_3"
    }

    values.testScene2_main.updateSteps {
      "a"
      "b".with(anchor: "return")

      check {
        if $0.world.counter == 0 {
          "c"
            .with { $0.counter += 1 }
            .then { .runThrough(values.testScene1_main) }
        } else {
          "d"
            .with { $0.counter += 1 }
            .then { .runThrough(values.testScene1_other) }
        }
      }

      "e"

      check {
        if $0.world.counter < 2 {
          "f".then { .replaceWith(values.testScene2_main, at: "return") }
        }
      }

      "g"
      "h"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene2_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.world.counter == 2)
    #expect(info.script.words == [
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

  @Test
  func runThroughAndReplaceWith() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"

      "c"
      then { .runThrough(values.testScene1_other) }

      "d"
      "e"
    }

    values.testScene1_other.updateSteps {
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then { .replaceWith(values.testScene1_other, at: "continue") }
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == [
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

  @Test
  func runThroughAndTransitionTo() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"

      "c"
      then { .runThrough(values.testScene1_other) }

      "d"
      "e"
    }

    values.testScene1_other.updateSteps {
      "f"
      "g".with(anchor: "continue")
      "h"
      check {
        if $0.script.narrated["did see i", default: 0] == 0 {
          "i"
            .with(id: "did see i")
            .then { .transitionTo(values.testScene1_other, at: "continue") }
        }
      }
      "j"
      "k"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == [
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

  @Test
  func replayNotAffectScript() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"
      "c"
    }

    nonisolated(unsafe) var didReplay = false

    let runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: { @Sendable in
        if !didReplay, $0.messages.map(\.text) == ["b"] {
          didReplay = true
          return .replay
        } else {
          return .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == ["a", "b", "c"])
  }

  @Test
  func replayWithChange() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
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
      handler: .mock(acknowledgeNarration: { @Sendable in
        if $0.messages.map(\.text) == ["b"] {
          .replay {
            $0.counter += 1
          }
        } else {
          .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == ["a", "c", "d"])
  }

  @Test
  func stopNotAffectScript() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b"
      "c"
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(acknowledgeNarration: { @Sendable in
        if $0.messages.map(\.text) == ["b"] {
          .stop
        } else {
          .advance
        }
      }),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == ["a"])
  }

  @Test
  func sceneChangeShorthand() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      check {
        if $0.script.narrated["did see b", default: 0] == 0 {
          "b"
            .with(id: "did see b")
            .then { .replaceWith(values.testScene2_main) }
        }
      }
      "c"
    }

    values.testScene2_main.updateSteps {
      "d"
      "e"
      then { .runThrough(values.testScene1_main) }
      "f"
      "g"
      then { .transitionTo(values.testScene1_main) }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info
    #expect(info.script.words == [
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

  @Test
  func observeTags() async {
    nonisolated(unsafe) var values = TestValues()

    values.testScene1_main.updateSteps {
      "a"
      "b".with(tags: ["observe-1"])
      "c"
      "d".with(tags: ["not-observe-1"])
      "e"
      choose(tags: ["observe-choice"]) { _ in
        "* 1".onSelect(tags: ["not-observe-1"]) {
          "* 1".then { .transitionTo(values.testScene2_main) }
        }

        "* 2".onSelect(tags: ["observe-1"]) {
          "* 2".then { .transitionTo(values.testScene2_main) }
        }
      }
    }

    let runner = Runner<TestGame>.init(
      handler: .mock(),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let info = await runner.info

    #expect(info.script.observed["observe-1", default: 0] == 2)
    #expect(info.script.observed["not-observe-1", default: 0] == 0)
    #expect(info.script.observed["observe-choice", default: 0] == 1)
  }

  @Test
  func encodeDecode() async throws {
    nonisolated(unsafe) var values = TestValues()

    enum LocalTestGame: Story {
      enum Generate: Generating {
        nonisolated(unsafe) static var expectedRandomRatio: Double = 0.5
        nonisolated(unsafe) static var expectedUniqueString: String = "expected"

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

      nonisolated(unsafe) static var scenes: [RawScene<LocalTestGame>] = [LocalTestScene1.raw, LocalTestScene2.raw]
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

    nonisolated(unsafe) var status: Status<LocalTestGame>!

    let runner1 = Runner<LocalTestGame>.init(
      handler: Handling<LocalTestGame>(
        acknowledgeNarration: {
          if $0.messages.map(\.text) == ["2"] {
            return .stop
          }
          return .advance
        },
        makeChoice: { $0.options.first.map { .advance(with: $0) } ?? .stop },
        answerRequest: { _ in Issue.record("shouldn't be here"); return .stop },
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

    nonisolated(unsafe) var narratedByRunner2: [String] = []

    let runner2 = Runner<LocalTestGame>.init(
      handler: Handling<LocalTestGame>(
        acknowledgeNarration: {
          for text in $0.messages.map(\.text) {
            narratedByRunner2.append(text)
          }
          return .advance
        },
        makeChoice: { $0.options.first.map { .advance(with: $0) } ?? .stop },
        answerRequest: { _ in Issue.record("shouldn't be here"); return .stop },
        handleEvent: { _ in }
      ),
      status: decoded
    )
    await runner2.start()

    let info1 = await runner1.info
    let info2 = await runner2.info

    #expect(info1.script.words == ["a", "b", "c", "1"])
    #expect(info2.script.words == ["a", "b", "c", "1", "2", "3", "d", "e"])
    #expect(narratedByRunner2 == ["2", "3", "d", "e"])
  }

  @Test
  func verifyRequestText() async {
    nonisolated(unsafe) var values = TestValues()

    nonisolated(unsafe) var receivedText: String?

    values.testScene1_main.updateSteps {
      "a"

      requestText {
        "b"
      } validate: {
        receivedText = $0
        return .valid(.init(text: $0))
      } ifValid: { _, _ in
        "d"
      }

      "e"
    }

    nonisolated(unsafe) var receivedRequest: TestPlayer.TextRequest?

    let runner = Runner<TestGame>.init(
      handler: .mock(answerRequest: { @Sendable in
        receivedRequest = $0
        switch $0.validate("c") {
        case .valid(let validated):
          return .advance(with: validated)

        case .invalid(let message):
          Issue.record("shouldn't fail (\(message ?? .init(text: "nil")))")
          return .stop
        }
      }),
      status: .init(
        world: .init(),
        scene: values.testScene1_main
      )
    )
    await runner.start()

    let story = await runner.info.script
    #expect(story.words == ["a", "b", "c", "d", "e"])
    #expect(receivedText == "c")
    #expect(receivedRequest?.message?.text == "b")
  }
}

private struct TestValues {
  var testScene1_main = TestScene1(title: "values.testScene1_main")
  var testScene1_other = TestScene1(title: "values.testScene1_other")
  var testScene2_main = TestScene2(title: "values.testScene2_main")
  var testScene2_other = TestScene2(title: "values.testScene2_other")

  init() {
    testScene1_main.updateSteps { "Test" }
    testScene1_other.updateSteps { "Test" }
    testScene2_main.updateSteps { "Test" }
    testScene2_other.updateSteps { "Test" }
  }
}
