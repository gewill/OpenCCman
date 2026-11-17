import Foundation

/// Character offsets are deliberately distinct from TextKit's UTF-16 offsets.
/// Equality is byte-exact: Swift's canonical-equivalence equality would hide
/// changes such as a decomposed accent becoming a precomposed character.
enum ConversionDiff {
  struct Limits: Sendable {
    static let workspace = Limits(characters: 50_000, cells: 4_000_000, hunks: 5_000)
    let characters: Int
    let cells: Int
    let hunks: Int
  }

  struct Hunk: Equatable, Sendable {
    enum Kind: String, Sendable { case replacement, insertion, deletion }
    let source: Range<Int>
    let result: Range<Int>
    var kind: Kind { source.isEmpty ? .insertion : result.isEmpty ? .deletion : .replacement }
  }

  enum Outcome: Equatable, Sendable {
    case computed([Hunk])
    case notComputed
    case cancelled
  }

  static func compute(source: String, result: String, limits: Limits,
                      cancelled: () -> Bool = { false }) -> Outcome {
    guard limits.characters >= 0, limits.cells >= 0, limits.hunks >= 0 else { return .notComputed }
    // Iterate with a bound; do not allocate an unbounded Character array first.
    func bounded(_ text: String) -> [String]? {
      var values: [String] = []
      for character in text {
        if cancelled() || values.count == limits.characters { return nil }
        values.append(String(character))
      }
      return values
    }
    guard let a = bounded(source), let b = bounded(result) else {
      return cancelled() ? .cancelled : .notComputed
    }
    func equal(_ x: String, _ y: String) -> Bool { x.utf8.elementsEqual(y.utf8) }
    func separator(_ x: String) -> Bool {
      x.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) || $0.value == 0 || $0.value == 0xFEFF }
    }
    // OpenCC preserves separators. When their complete sequence matches, use
    // them as hard anchors. Otherwise use the general alignment, not guessed
    // line offsets. Neither path normalizes CRLF or Unicode scalars.
    let sa = a.indices.filter { separator(a[$0]) }
    let sb = b.indices.filter { separator(b[$0]) }
    let anchored = sa.count == sb.count && zip(sa, sb).allSatisfy { equal(a[$0], b[$1]) }
    let anchors = anchored ? Array(zip(sa, sb)) : []
    var output: [Hunk] = []
    var spent = 0
    var exceeded = false
    var stopped = false

    func align(_ ar: Range<Int>, _ br: Range<Int>) {
      guard !exceeded, !stopped else { return }
      var lo = ar.lowerBound, ro = br.lowerBound
      var hi = ar.upperBound, rh = br.upperBound
      while lo < hi, ro < rh, equal(a[lo], b[ro]) { lo += 1; ro += 1 }
      while lo < hi, ro < rh, equal(a[hi - 1], b[rh - 1]) { hi -= 1; rh -= 1 }
      if lo == hi || ro == rh {
        if lo != hi || ro != rh { output.append(Hunk(source: lo..<hi, result: ro..<rh)) }
        return
      }
      let n = hi - lo, m = rh - ro
      let (cells, overflow) = (n + 1).multipliedReportingOverflow(by: m + 1)
      guard !overflow, cells <= limits.cells - spent else { exceeded = true; return }
      spent += cells
      var table = [Int32](repeating: 0, count: cells)
      let width = m + 1
      for i in stride(from: n - 1, through: 0, by: -1) {
        if cancelled() { stopped = true; return }
        for j in stride(from: m - 1, through: 0, by: -1) {
          table[i * width + j] = equal(a[lo + i], b[ro + j])
            ? table[(i + 1) * width + j + 1] + 1
            : max(table[(i + 1) * width + j], table[i * width + j + 1])
        }
      }
      var i = 0, j = 0
      var start: (Int, Int)?
      func flush() {
        if let s = start { output.append(Hunk(source: (lo + s.0)..<(lo + i), result: (ro + s.1)..<(ro + j))) }
        start = nil
      }
      while i < n || j < m {
        if cancelled() { stopped = true; return }
        if i < n, j < m, equal(a[lo + i], b[ro + j]) { flush(); i += 1; j += 1 }
        else {
          if start == nil { start = (i, j) }
          if j < m, i == n || table[i * width + j + 1] > table[(i + 1) * width + j] { j += 1 }
          else { i += 1 }
        }
      }
      flush()
    }
    var l = 0, r = 0
    for (x, y) in anchors {
      if cancelled() { return .cancelled }
      align(l..<x, r..<y)
      if exceeded { return .notComputed }
      if stopped { return .cancelled }
      l = x + 1; r = y + 1
    }
    align(l..<a.count, r..<b.count)
    if cancelled() || stopped { return .cancelled }
    if exceeded { return .notComputed }
    // Keep a short unchanged Han bridge inside a phrase (硅[二]极管,
    // [鼠]标 -> 滑[鼠]); never bridge whitespace, punctuation or emoji.
    func han(_ value: String) -> Bool {
      value.unicodeScalars.count == 1 && value.unicodeScalars.allSatisfy {
        (0x3400...0x9FFF).contains($0.value) || (0x20000...0x323AF).contains($0.value)
      }
    }
    var merged: [Hunk] = []
    for h in output {
      if let last = merged.last {
        let ag = last.source.upperBound..<h.source.lowerBound
        let bg = last.result.upperBound..<h.result.lowerBound
        if ag.count == bg.count, ag.count <= 1,
           zip(ag, bg).allSatisfy({ han(a[$0]) && equal(a[$0], b[$1]) }) {
          merged[merged.count - 1] = Hunk(source: last.source.lowerBound..<h.source.upperBound,
                                        result: last.result.lowerBound..<h.result.upperBound)
          continue
        }
      }
      merged.append(h)
    }
    return merged.count > limits.hunks ? .notComputed : .computed(merged)
  }
}
