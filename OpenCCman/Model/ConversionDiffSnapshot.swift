import Foundation

/// Immutable provenance reusable by future result annotations. A generation is
/// replaced on invalidation, including when the same text is imported again.
struct ConversionDiffSnapshot<Configuration: Equatable & Sendable>: Sendable {
  let id: UUID
  let source: String
  let result: String
  let configuration: Configuration

  init(source: String, result: String, configuration: Configuration) {
    id = UUID()
    self.source = source
    self.result = result
    self.configuration = configuration
  }
}

struct ConversionDiffGeneration: Sendable {
  private(set) var id = UUID()
  mutating func invalidate() { id = UUID() }
  func accepts(_ candidate: UUID) -> Bool { candidate == id }
}

/// UTF-16 mapping is prepared by the worker, never rebuilt by a SwiftUI body.
struct ConversionDiffDisplay: Sendable {
  let id: UUID
  let sourceRanges: [NSRange]
  let resultRanges: [NSRange]

  init(id: UUID, source: String, result: String, hunks: [ConversionDiff.Hunk]) {
    self.id = id
    func offsets(_ text: String) -> [Int] {
      var values = [0]
      for character in text { values.append(values.last! + String(character).utf16.count) }
      return values
    }
    let a = offsets(source), b = offsets(result)
    sourceRanges = hunks.map { NSRange(location: a[$0.source.lowerBound], length: a[$0.source.upperBound] - a[$0.source.lowerBound]) }
    resultRanges = hunks.map { NSRange(location: b[$0.result.lowerBound], length: b[$0.result.upperBound] - b[$0.result.lowerBound]) }
  }
}

/// Drawing-only decoration: never stored in the document or pasteboard.
struct WorkspaceDiffDecoration {
  let id: UUID
  let text: String
  let ranges: [NSRange]
  let currentIndex: Int?
  let navigationID: UUID?
  var selectedRange: NSRange? { currentIndex.map { ranges[$0] } }
}
