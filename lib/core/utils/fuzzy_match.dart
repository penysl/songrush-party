import 'dart:math';

/// Fuzzy string matching utility for song title validation.
/// Uses Levenshtein distance to compute similarity.
class FuzzyMatch {
  /// Computes the Levenshtein distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Create matrix
    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    // Initialize first row and column
    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // Fill matrix
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,       // deletion
          matrix[i][j - 1] + 1,       // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Normalizes a string for comparison:
  /// - lowercase
  /// - strip parenthetical content: (feat. ...), (Radio Edit), [Remastered], etc.
  /// - strip bare feat./ft./with suffixes
  /// - remove remaining special characters (keep letters, digits, spaces)
  /// - trim and collapse whitespace
  static String _normalize(String input) {
    return input
        .toLowerCase()
        // Remove anything in brackets/parens: (feat. X), [Radio Edit], {Deluxe}
        .replaceAll(RegExp(r'\s*[\(\[\{][^\)\]\}]*[\)\]\}]'), '')
        // Remove bare "feat. X", "ft. X", "with X" at end of string
        .replaceAll(RegExp(r'\s+(feat\.|ft\.|with)\s+\S.*$'), '')
        // Remove special characters (keep letters, digits, spaces, umlauts)
        .replaceAll(RegExp(r'[^a-z0-9äöüß\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns similarity between 0.0 and 1.0.
  /// 1.0 = identical, 0.0 = completely different.
  static double similarity(String a, String b) {
    final normalA = _normalize(a);
    final normalB = _normalize(b);

    if (normalA.isEmpty && normalB.isEmpty) return 1.0;
    if (normalA.isEmpty || normalB.isEmpty) return 0.0;

    final maxLen = max(normalA.length, normalB.length);
    final distance = _levenshtein(normalA, normalB);

    return 1.0 - (distance / maxLen);
  }

  /// Returns true if the input is a fuzzy match for the target.
  /// Threshold 0.75 allows ~2 typos on a 10-char title, ~3 on a 15-char title.
  static bool isMatch(String input, String target, {double threshold = 0.75}) {
    return similarity(input, target) >= threshold;
  }
}
