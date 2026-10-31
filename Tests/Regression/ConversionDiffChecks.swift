import Foundation

@main
struct ConversionDiffChecks {
  static func main() {
    let limits = ConversionDiff.Limits(characters: 20_000, cells: 4_000_000, hunks: 2_000)
    func check(_ source: String, _ result: String, count: Int? = nil) {
      guard case let .computed(hunks) = ConversionDiff.compute(source: source, result: result, limits: limits) else {
        fatalError("Expected complete diff")
      }
      let a = Array(source), b = Array(result)
      var rebuilt: [Character] = []
      var cursor = 0
      for h in hunks {
        precondition(h.source.lowerBound >= cursor)
        rebuilt += a[cursor..<h.source.lowerBound]
        rebuilt += b[h.result]
        cursor = h.source.upperBound
      }
      rebuilt += a[cursor...]
      precondition(String(rebuilt).utf8.elementsEqual(result.utf8), "Literal restoration")
      if let count { precondition(hunks.count == count, "Hunk count: \(source) -> \(result): \(hunks)") }
    }
    check("相同👩🏽‍💻e\u{301}", "相同👩🏽‍💻e\u{301}", count: 0)
    check("汉", "漢", count: 1)
    check("鼠标", "滑鼠", count: 1)
    check("硅二极管", "矽二極體", count: 1)
    check("互联网", "網際網路", count: 1)
    // Oracle verified using the project's pinned SwiftyOpenCC revision and
    // [.traditionalize, .twStandard, .twIdiom]; also checked live in CoreChecks.
    check("鼠标里面的硅二极管坏了，导致光标分辨率降低。", "滑鼠裡面的矽二極體壞了，導致游標解析度降低。")
    check("abc", "abXc", count: 1)
    check("abXc", "abc", count: 1)
    check("", "👩🏽‍💻", count: 1)
    check("👩🏽‍💻", "", count: 1)
    for (source, result, kind) in [("汉", "漢", ConversionDiff.Hunk.Kind.replacement),
                                    ("", "字", .insertion), ("字", "", .deletion)] {
      guard case let .computed(hunks) = ConversionDiff.compute(source: source, result: result, limits: limits) else {
        fatalError("Expected a typed hunk")
      }
      precondition(hunks.count == 1 && hunks[0].kind == kind)
    }
    check("e\u{301}", "é", count: 1)
    check("a👩🏽‍💻e\u{301}汉", "a👨‍👩‍👧‍👦e\u{301}漢")
    for separator in ["\0", "\r\n", "\r", "\u{2028}", "\u{2029}", "\u{FEFF}", " ", "\t"] {
      check(separator + "汉" + separator, separator + "漢" + separator, count: 1)
      check("a" + separator + "b", "ab", count: 1)
    }
    check("a\r\nb", "a\nb", count: 1)
    check("a b", "a\nb", count: 1)
    // Deterministic exhaustive small inputs exercise insertion/deletion alignment.
    let alphabet = ["a", "汉", "\r\n", "👩🏽‍💻"]
    var strings = [""]
    for x in alphabet { strings.append(x); for y in alphabet { strings.append(x + y) } }
    for a in strings { for b in strings { check(a, b) } }
    var generation = ConversionDiffGeneration()
    let old = generation.id
    precondition(generation.accepts(old))
    generation.invalidate()
    precondition(!generation.accepts(old))
    precondition(generation.accepts(generation.id))
    let snapshot = ConversionDiffSnapshot(source: "汉", result: "漢", configuration: "TW")
    precondition(snapshot.source == "汉" && snapshot.configuration == "TW")
    precondition(ConversionDiff.compute(source: "ab", result: "cd", limits: .init(characters: 1, cells: 100, hunks: 10)) == .notComputed)
    precondition(ConversionDiff.compute(source: "a", result: "abcd", limits: .init(characters: 2, cells: 100, hunks: 10)) == .notComputed)
    precondition(ConversionDiff.compute(source: "ab", result: "cd", limits: .init(characters: 10, cells: 1, hunks: 10)) == .notComputed)
    precondition(ConversionDiff.compute(source: "a b", result: "x y", limits: .init(characters: 10, cells: 100, hunks: 1)) == .notComputed)
    precondition(ConversionDiff.compute(source: "abc", result: "xyz", limits: limits, cancelled: { true }) == .cancelled)
    var cancellationChecks = 0
    let cancelledDuringAlignment = ConversionDiff.compute(
      source: String(repeating: "汉", count: 100), result: String(repeating: "漢", count: 100), limits: limits,
      cancelled: { cancellationChecks += 1; return cancellationChecks > 220 })
    precondition(cancelledDuringAlignment == .cancelled && cancellationChecks > 220)
    print("PASS: Character boundaries, literal restoration, phrase grouping, separators, generation rejection, cancellation and complete-or-not-computed limits")
  }
}
