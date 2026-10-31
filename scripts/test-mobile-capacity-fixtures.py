#!/usr/bin/env python3
"""Regression checks for exact, bounded, lossless fixture generation."""
import codecs
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("fixtures", Path(__file__).with_name("generate-mobile-capacity-fixtures.py"))
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


class FixtureTests(unittest.TestCase):
    def test_exact_size_hash_and_utf8_at_boundaries(self):
        with tempfile.TemporaryDirectory() as directory:
            for corpus, value in fixtures.CORPORA.items():
                seed = value.encode()
                for size in (1, len(seed) - 1, len(seed), len(seed) + 1, 65535, 65536, 65537, 1024 * 1024):
                    path = Path(directory) / f"{corpus}-{size}"
                    result = fixtures.generate(path, size, corpus)
                    data = path.read_bytes()
                    self.assertEqual(len(data), size)
                    self.assertEqual(hashlib.sha256(data).hexdigest(), result["sha256"])
                    # Incremental strict decoder deliberately splits multibyte sequences.
                    decoder = codecs.getincrementaldecoder("utf-8")("strict")
                    for offset in range(0, len(data), 127):
                        decoder.decode(data[offset:offset + 127])
                    decoder.decode(b"", final=True)
                    self.assertEqual(data, seed * (size // len(seed)) + b"x" * (size % len(seed)))

    def test_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "existing.txt"
            path.write_bytes(b"preserve")
            with self.assertRaises(FileExistsError):
                fixtures.generate(path, 100, "unicode")
            self.assertEqual(path.read_bytes(), b"preserve")

    def test_required_content(self):
        unicode_seed = fixtures.CORPORA["unicode"]
        for token in ("\x00", "\r\n", "\r\n\r\n", "e\u0301", "🙂", "\ufeff"):
            self.assertIn(token, unicode_seed)
        self.assertNotIn("\n", fixtures.CORPORA["no-newline"])
        self.assertTrue(fixtures.CORPORA["ascii"].isascii())


if __name__ == "__main__":
    unittest.main()
