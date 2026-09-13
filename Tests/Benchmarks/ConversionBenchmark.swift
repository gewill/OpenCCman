// Baseline chunking copied verbatim from cc8c7e8 for reproducible comparison.
// Both paths use the same warmed converter; this measures data processing, not UI.
import Foundation
import OpenCC
  // Chunking helper: split large text by paragraphs first, then by size
  func chunked(text: String, maxChunkLength: Int = 4000) -> [String] {
    guard !text.isEmpty else { return [] }

    // Prefer splitting by double newlines (paragraphs)
    let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }

    var chunks: [String] = []
    var current = ""

    func flushCurrent() {
      if !current.isEmpty { chunks.append(current); current.removeAll(keepingCapacity: true) }
    }

    if paragraphs.count > 1 {
      for para in paragraphs {
        if current.count + para.count + 2 <= maxChunkLength {
          if current.isEmpty { current = para } else { current += "\n\n" + para }
        } else if para.count <= maxChunkLength {
          flushCurrent()
          current = para
        } else {
          // Paragraph itself is too big, hard-split by size
          var start = para.startIndex
          while start < para.endIndex {
            let end = para.index(start, offsetBy: maxChunkLength, limitedBy: para.endIndex) ?? para.endIndex
            chunks.append(String(para[start ..< end]))
            start = end
          }
          current.removeAll(keepingCapacity: true)
        }
      }
      flushCurrent()
    } else {
      // No clear paragraph boundaries, split by size
      var start = text.startIndex
      while start < text.endIndex {
        let end = text.index(start, offsetBy: maxChunkLength, limitedBy: text.endIndex) ?? text.endIndex
        chunks.append(String(text[start ..< end]))
        start = end
      }
    }

    return chunks
  }
@main enum Benchmark {
  static func main() async throws {
    let options: ChineseConverter.Options = [.traditionalize, .twIdiom]
    let converter = try ChineseConversionService.converter(options: options)
    let fixtures = [
      ("lost-prefix", "前段\n\n" + String(repeating: "汉", count: 4001)),
      ("phrase-boundary", String(repeating: "a", count: 3999) + "鼠标"),
      ("edge-newlines", "\n\n前段\n\n后段\n\n")
    ]
    for (name, input) in fixtures {
      let old = chunked(text: input).map { converter.convert($0) }.joined(separator: "\n")
      let expected = converter.convert(input)
      let current = try await ChineseConversionService.shared.convert(input, options: options)
      precondition(old != expected && current == expected)
      print("REPRO \(name): old wrong; current matches OpenCC; old/output UTF8 bytes \(old.utf8.count)/\(current.utf8.count)")
    }
    let input = String(repeating: "鼠标里面的硅二极管坏了，导致光标分辨率降低。\n\n", count: 20000)
    let pieces = chunked(text: input)
    var oldTimes: [Double] = []
    var newTimes: [Double] = []
    for _ in 0..<5 {
      let start = DispatchTime.now().uptimeNanoseconds
      var old = ""
      for piece in chunked(text: input) {
        let converted = converter.convert(piece)
        old += old.isEmpty ? converted : "\n" + converted
      }
      oldTimes.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
      let next = DispatchTime.now().uptimeNanoseconds
      let current = try await ChineseConversionService.shared.convert(input, options: options)
      newTimes.append(Double(DispatchTime.now().uptimeNanoseconds - next) / 1e6)
      precondition(!old.isEmpty && current == converter.convert(input))
    }
    print("BENCH chars=\(input.count), bytes=\(input.utf8.count), chunks=\(pieces.count), result-publications=\(pieces.count)->1")
    print(String(format: "BENCH median processing (no UI; warmed converter; 5 runs): old %.2f ms, current %.2f ms", oldTimes.sorted()[2], newTimes.sorted()[2]))
  }
}
