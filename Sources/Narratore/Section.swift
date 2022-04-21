/// The "compiled" representation of a `Branch`.
///
/// While the purpose of a `Branch` is to wrap a function that returns the steps for the story, a `Section` is produced by running that function: in fact, `Section` is initialized via an array of `BranchStep`, and contains a list of `GetStep` instances, plus a mapping between the branch `Anchor`s and the step indices.
///
/// `Section` depends on the specific branch type, represented by the `B` generic parameter.
struct Section<B: Branch> {
  let steps: [GetStep<B.Parent.Game>]
  let anchorIndices: [B.Anchor: Int]

  init(branchSteps: [BranchStep<B>]) {
    var steps: [GetStep<B.Parent.Game>] = []
    var anchorIndices: [B.Anchor: Int] = [:]

    for index in branchSteps.indices {
      let branchStep = branchSteps[index]
      steps.append(branchStep.getStep)

      if let anchor = branchStep.anchor {
        anchorIndices[anchor] = index
      }
    }

    self.steps = steps
    self.anchorIndices = anchorIndices
  }
}

/// A "type-erased" `Section`, where the specific `Branch` from which the section depends is "forgot".
struct AnySection<Game: Setting> {
  let steps: [GetStep<Game>]
  let startingIndex: Int

  init<B: Branch>(section: Section<B>, anchor: B.Anchor? = nil) where B.Parent.Game == Game {
    self.steps = section.steps
    self.startingIndex = anchor.flatMap {
      section.anchorIndices[$0]
    } ?? 0
  }
}

/// Wraps a `() -> Section<B>` function, and can be encoded.
struct GetSection<B: Branch>: Codable & Hashable {
  let id: String

  private let run: () -> Section<B>
  private let scene: B.Parent

  init(scene: B.Parent) {
    self.run = { .init(branchSteps: B.getSteps(for: scene)) }
    self.id = B.id
    self.scene = scene
  }
  
  func callAsFunction() -> Section<B> {
    run()
  }

  func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
    scene.hash(into: &hasher)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.scene == rhs.scene
  }

  enum CodingKeys: CodingKey {
    case id
    case scene
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(String.self, forKey: .id)

    guard id == B.id else {
      throw Failure<B.Game>.invalidBranchId(expected: B.id, received: id)
    }

    self.init(scene: try container.decode(B.Parent.self, forKey: .scene))
  }
}

/// Wraps a `() -> AnySection<B>` function, and can be encoded.
///
/// `AnyGetSection` represents the fundamental mechanism through which the state of the story is encoded and decoded in Narratore.
///
/// When loading a previous game, the stack of branches will be reconstructed becase each element if it contains a `AnyGetSection`, which is turn is decoded by iterating through the `RawBranch` instances declared by the `RawScene` instances of the game, and then finding the right one based on the encoded `Scene` and the branch `id`.
public struct AnyGetSection<Game: Setting>: Hashable & Encodable {
  let id: String

  private let run: () -> AnySection<Game>

  init<B: Branch>(_ getSection: GetSection<B>, at anchor: B.Anchor? = nil) where B.Parent.Game == Game {
    self.run = {
      .init(section: getSection(), anchor: anchor)
    }
    id = getSection.id

    hashableSource = AnyHashable(getSection)
    encoding = getSection.encode(to:)
  }
  
  func callAsFunction() -> AnySection<Game>{
    run()
  }

  public func hash(into hasher: inout Hasher) {
    hashableSource.hash(into: &hasher)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.hashableSource == rhs.hashableSource
  }

  public func encode(to encoder: Encoder) throws {
    try encoding(encoder)
  }

  private let hashableSource: AnyHashable
  private let encoding: (Encoder) throws -> Void
}

extension AnyGetSection: Decodable where Game: Story {
  public init(from decoder: Decoder) throws {
    let sequence = Game.scenes.lazy
      .flatMap { $0.branches }
      .map { rawBranch in Result { try rawBranch.decodeSection(decoder) } }

    var errors: [Swift.Error] = []

    for result in sequence {
      switch result {
      case .success(let value):
        self = value
        return

      case .failure(let error):
        errors.append(error)
      }
    }

    throw Failure<Game>.notFound(errors: errors)
  }
}
