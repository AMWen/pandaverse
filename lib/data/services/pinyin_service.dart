import 'package:lpinyin/lpinyin.dart';
import 'dictionary_service.dart';

class PinyinService {
  /// Convert Chinese text to pinyin using lpinyin
  /// Example: "你好" -> "nǐ hǎo"
  static String convertToPinyin(String chinese, {String? defPinyin}) {
    if (chinese.isEmpty) return '';

    // Use lpinyin for pinyin generation
    return PinyinHelper.getPinyinE(
      chinese,
      defPinyin: defPinyin ?? chinese,
      separator: ' ',
      format: PinyinFormat.WITH_TONE_MARK,
    );
  }

  /// Convert a line of lyrics to pinyin with 1:1 character correspondence
  /// Uses dictionary service for word segmentation and lpinyin for pinyin generation
  /// For spaces and punctuation, an empty string is added to maintain alignment
  /// Example: "你好 世界" -> "nǐ hǎo  shì jiè"
  ///           (5 chars)     (5 entries when split: ["nǐ", "hǎo", "", "shì", "jiè"])
  static String convertLine(String line) {
    if (line.isEmpty) return '';

    final result = <String>[];
    final punctuationPattern = RegExp(r'[，。！？：；""''、…—·《》（）【】,.!?:;-]');
    final dictionary = DictionaryService.getDictionary();

    if (dictionary == null) {
      // Dictionary not loaded, use lpinyin for each character
      final result = <String>[];
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == ' ') {
          result.add('');
        } else if (punctuationPattern.hasMatch(char)) {
          result.add(char);
        } else {
          result.add(convertToPinyin(char));
        }
      }
      return result.join(' ');
    }

    int i = 0;
    while (i < line.length) {
      final char = line[i];

      if (char == ' ') {
        // For spaces, add empty string to maintain 1:1 correspondence
        result.add('');
        i++;
      } else if (punctuationPattern.hasMatch(char)) {
        // For punctuation, preserve the character
        result.add(char);
        i++;
      } else {
        // Try to match longest word from dictionary (greedy matching)
        bool matched = false;

        // Try lengths from 4 down to 1 (longest match first)
        for (int length = 4; length >= 1 && i + length <= line.length; length--) {
          final word = line.substring(i, i + length);

          // Try direct lookup first
          DictionaryEntry? entry = dictionary[word];

          // If not found, try searching by traditional or simplified
          if (entry == null) {
            for (final dictEntry in dictionary.values) {
              if (dictEntry.traditional == word || dictEntry.simplified == word) {
                entry = dictEntry;
                break;
              }
            }
          }

          if (entry != null) {
            // Found a match! Use lpinyin to get pinyin for each character in the word
            for (int j = 0; j < length; j++) {
              final char = line[i + j];
              final charPinyin = convertToPinyin(char);
              result.add(charPinyin);
            }

            i += length;
            matched = true;
            break;
          }
        }

        if (!matched) {
          // No dictionary match found, use lpinyin for single character
          final charPinyin = convertToPinyin(char);
          result.add(charPinyin);
          i++;
        }
      }
    }

    return result.join(' ');
  }

  /// Check if a string contains Chinese characters
  static bool containsChinese(String text) {
    if (text.isEmpty) return false;

    // Check if any character is in the CJK Unicode range
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      // CJK Unified Ideographs: 4E00-9FFF
      // CJK Extension A: 3400-4DBF
      if ((codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
          (codeUnit >= 0x3400 && codeUnit <= 0x4DBF)) {
        return true;
      }
    }
    return false;
  }
}
