import 'dart:convert';
import 'package:flutter/services.dart';

class DictionaryEntry {
  final String traditional;
  final String simplified;
  final String pinyin;
  final List<String> definitions;
  final int? frequency;

  DictionaryEntry({
    required this.traditional,
    required this.simplified,
    required this.pinyin,
    required this.definitions,
    this.frequency,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      traditional: json['traditional'] as String,
      simplified: json['simplified'] as String,
      pinyin: json['pinyin'] as String,
      definitions: List<String>.from(json['definitions'] as List),
      frequency: json['frequency'] as int?,
    );
  }
}

class WordMatch {
  final DictionaryEntry entry;
  final int startIndex;
  final int endIndex;

  WordMatch({
    required this.entry,
    required this.startIndex,
    required this.endIndex,
  });
}

class DictionaryService {
  static Map<String, DictionaryEntry>? _dictionary;
  static bool _isLoaded = false;

  /// Load the CC-CEDICT dictionary from assets
  /// This should be called once at app startup
  static Future<void> loadDictionary() async {
    if (_isLoaded) return;

    try {
      // Load the JSON dictionary from assets
      final String jsonString = await rootBundle.loadString('assets/dictionary/cedict.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      _dictionary = {};
      jsonData.forEach((key, value) {
        _dictionary![key] = DictionaryEntry.fromJson(value as Map<String, dynamic>);
      });

      _isLoaded = true;
    } catch (e) {
      // Initialize empty dictionary so app doesn't crash
      _dictionary = {};
      _isLoaded = true;
    }
  }

  /// Translate a Chinese word/phrase to English
  /// Uses greedy longest-match word segmentation
  static DictionaryEntry? translate(String word) {
    if (_dictionary == null || word.isEmpty) return null;

    // Try exact match first
    if (_dictionary!.containsKey(word)) {
      return _dictionary![word];
    }

    // Try finding in simplified form
    // (Some entries may be indexed by simplified)
    for (final entry in _dictionary!.values) {
      if (entry.simplified == word || entry.traditional == word) {
        return entry;
      }
    }

    return null;
  }

  /// Find the word at a given tap position in a line of text
  /// Uses greedy longest-match algorithm
  /// The line can be in either simplified or traditional Chinese
  static DictionaryEntry? findWordAtPosition(String line, int tapIndex) {
    final match = findWordMatchAtPosition(line, tapIndex);
    return match?.entry;
  }

  /// Find the word and its position at a given tap position in a line of text
  /// Uses greedy longest-match algorithm
  /// Returns a WordMatch with the entry and start/end positions
  static WordMatch? findWordMatchAtPosition(String line, int tapIndex) {
    if (_dictionary == null || line.isEmpty || tapIndex < 0 || tapIndex >= line.length) {
      return null;
    }

    // Try matching from length 4 down to 1 (greedy longest match)
    for (int length = 4; length >= 1; length--) {
      // Try different starting positions around the tap
      for (int offset = 0; offset < length; offset++) {
        final start = tapIndex - offset;
        if (start < 0 || start + length > line.length) continue;

        final candidate = line.substring(start, start + length);

        // Try direct lookup first (works for traditional text)
        if (_dictionary!.containsKey(candidate)) {
          return WordMatch(
            entry: _dictionary![candidate]!,
            startIndex: start,
            endIndex: start + length,
          );
        }

        // If not found, try looking up by simplified form
        // This is slower but necessary for simplified text
        for (final entry in _dictionary!.values) {
          if (entry.simplified == candidate || entry.traditional == candidate) {
            return WordMatch(
              entry: entry,
              startIndex: start,
              endIndex: start + length,
            );
          }
        }
      }
    }

    // Fallback: single character
    final char = line[tapIndex];
    final entry = translate(char);
    if (entry != null) {
      return WordMatch(
        entry: entry,
        startIndex: tapIndex,
        endIndex: tapIndex + 1,
      );
    }

    return null;
  }

  /// Check if dictionary is loaded
  static bool get isLoaded => _isLoaded;

  /// Get dictionary size
  static int get size => _dictionary?.length ?? 0;

  /// Get the dictionary (for internal use by other services)
  static Map<String, DictionaryEntry>? getDictionary() => _dictionary;
}
