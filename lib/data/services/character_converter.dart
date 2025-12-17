import 'package:characters/characters.dart';
import 'dictionary_service.dart';

/// Service for converting between simplified and traditional Chinese characters
class CharacterConverter {
  static Map<String, String>? _traditionalToSimplified;
  static Map<String, String>? _simplifiedToTraditional;

  // Manual overrides for ambiguous characters (simplified -> preferred traditional)
  // These are applied after dictionary processing to ensure correct common forms
  static const Map<String, String> _manualOverrides = {
    '别': '別',  // Not s
    '干': '幹',  // Not 乾 (when meaning "do/work")
    '复': '複',  // Not 復 (when meaning "complex")
    '于': '於',  // Not 于 (when meaning "at/in")
    '却': '卻',  // Not 㕁
    '并': '並',  // Not 并
    '后': '後',  // Not 后
    '离': '離',  // Not 离
  };

  /// Validate if a string is valid UTF-16
  static bool _isValidUtf16(String text) {
    try {
      // Try to create a TextSpan to validate
      final runes = text.runes.toList();
      String.fromCharCodes(runes);
      return !text.contains('�');
    } catch (e) {
      return false;
    }
  }

  /// Initialize conversion maps from the dictionary
  static void initialize() {
    if (_traditionalToSimplified != null) return;

    _traditionalToSimplified = {};
    _simplifiedToTraditional = {};

    // Build conversion maps from dictionary entries
    final dictionary = DictionaryService.getDictionary();
    if (dictionary == null) return;

    // Sort entries by frequency (highest first, nulls last)
    final sortedEntries = dictionary.values.toList()
      ..sort((a, b) {
        // Get frequency, treating null as 0
        final aFreq = a.frequency ?? 0;
        final bFreq = b.frequency ?? 0;
        // Sort descending (highest frequency first)
        return bFreq.compareTo(aFreq);
      });

    // First pass: collect characters that are the same in both forms
    // These are modern characters that don't need conversion
    final noConversionNeeded = <String>{};
    for (final entry in sortedEntries) {
      if (!_isValidUtf16(entry.traditional) || !_isValidUtf16(entry.simplified)) {
        continue;
      }

      if (entry.traditional == entry.simplified) {
        // Add all characters from this entry to the no-conversion set
        for (final char in entry.traditional.characters) {
          if (_isValidUtf16(char)) {
            noConversionNeeded.add(char);
          }
        }
      }
    }

    // Second pass: build conversion maps, skipping characters that don't need conversion
    // Process in frequency order (most common first)
    for (final entry in sortedEntries) {
      // Validate entry strings
      if (!_isValidUtf16(entry.traditional) || !_isValidUtf16(entry.simplified)) {
        continue;
      }

      if (entry.traditional != entry.simplified) {
        // Use characters to properly handle grapheme clusters
        final tradChars = entry.traditional.characters.toList();
        final simpChars = entry.simplified.characters.toList();

        for (int i = 0; i < tradChars.length && i < simpChars.length; i++) {
          final trad = tradChars[i];
          final simp = simpChars[i];

          // Skip if either character doesn't need conversion (i.e., already the same in modern usage)
          if (noConversionNeeded.contains(trad) || noConversionNeeded.contains(simp)) {
            continue;
          }

          // Validate individual characters
          if (trad != simp && _isValidUtf16(trad) && _isValidUtf16(simp)) {
            _traditionalToSimplified![trad] = simp;
            // Only set simplified->traditional mapping if not already set (prefer first/most common)
            _simplifiedToTraditional![simp] ??= trad;
          }
        }
      }
    }

    // Apply manual overrides for common ambiguous characters
    _manualOverrides.forEach((simp, trad) {
      _simplifiedToTraditional![simp] = trad;
      _traditionalToSimplified![trad] = simp;
    });

    // Initialization complete
  }

  /// Convert traditional Chinese to simplified
  static String toSimplified(String text) {
    if (_traditionalToSimplified == null) initialize();
    if (_traditionalToSimplified == null || text.isEmpty) return text;

    try {
      final buffer = StringBuffer();
      // Process each character (handling multi-code-unit characters)
      for (final char in text.characters) {
        final converted = _traditionalToSimplified![char] ?? char;
        buffer.write(converted);
      }
      final result = buffer.toString();

      // Check if result is valid
      if (result.contains('�')) {
        return text; // Return original if conversion produced invalid output
      }

      return result;
    } catch (e) {
      // If conversion fails, return original text
      return text;
    }
  }

  /// Convert simplified Chinese to traditional
  static String toTraditional(String text) {
    if (_simplifiedToTraditional == null) initialize();
    if (_simplifiedToTraditional == null || text.isEmpty) return text;

    try {
      final buffer = StringBuffer();
      // Process each character (handling multi-code-unit characters)
      for (final char in text.characters) {
        buffer.write(_simplifiedToTraditional![char] ?? char);
      }
      return buffer.toString();
    } catch (e) {
      // If conversion fails, return original text
      return text;
    }
  }

  /// Convert text based on preference
  static String convert(String text, bool useSimplified) {
    return useSimplified ? toSimplified(text) : text;
  }
}
