import 'package:flutter_test/flutter_test.dart';
import 'package:pandaverse/data/services/pinyin_service.dart';
import 'package:pandaverse/data/services/dictionary_service.dart';

void main() {
  setUpAll(() async {
    // Initialize dictionary service for word segmentation
    await DictionaryService.loadDictionary();
  });

  group('PinyinService - convertToPinyin', () {
    test('converts simple Chinese to pinyin with tone marks', () {
      final pinyin = PinyinService.convertToPinyin('你好');
      expect(pinyin, contains('nǐ'));
      expect(pinyin, contains('hǎo'));
    });

    test('handles empty string', () {
      final pinyin = PinyinService.convertToPinyin('');
      expect(pinyin, '');
    });

    test('preserves spaces in output', () {
      final pinyin = PinyinService.convertToPinyin('你 好');
      expect(pinyin, contains(' '));
    });

    test('uses defPinyin fallback for non-Chinese characters - English letters', () {
      // English letters should be preserved as-is due to defPinyin defaulting to input
      final pinyin = PinyinService.convertToPinyin('A');
      expect(pinyin, 'A');
    });

    test('uses defPinyin fallback for non-Chinese characters - numbers', () {
      // Numbers should be preserved as-is
      final pinyin = PinyinService.convertToPinyin('5');
      expect(pinyin, '5');
    });

    test('uses defPinyin fallback for non-Chinese characters - symbols', () {
      // Symbols should be preserved as-is
      final pinyin = PinyinService.convertToPinyin('@');
      expect(pinyin, '@');
    });

    test('lpinyin automatically preserves non-Chinese characters', () {
      // lpinyin preserves non-Chinese characters regardless of defPinyin
      // The defPinyin parameter is only used for truly unrecognizable characters
      final pinyin = PinyinService.convertToPinyin('X', defPinyin: '?');
      expect(pinyin, 'X'); // lpinyin returns 'X' even though defPinyin is '?'
    });

    test('converts Chinese but uses defPinyin for mixed content', () {
      // Mixed content should convert Chinese and preserve non-Chinese
      final pinyin = PinyinService.convertToPinyin('你A好');
      expect(pinyin, contains('nǐ'));
      expect(pinyin, contains('A')); // English letter preserved
      expect(pinyin, contains('hǎo'));
    });
  });

  group('PinyinService - convertLine', () {
    test('converts line with 1:1 character correspondence', () {
      final pinyin = PinyinService.convertLine('你好');
      final parts = pinyin.split(' ');
      expect(parts.length, 2); // Two Chinese characters
    });

    test('handles spaces by adding empty strings', () {
      final pinyin = PinyinService.convertLine('你 好');
      final parts = pinyin.split(' ');
      expect(parts.length, 3); // char, space, char
      expect(parts[1], ''); // Space becomes empty string
    });

    test('preserves punctuation as-is', () {
      final pinyin = PinyinService.convertLine('你好，世界！');
      expect(pinyin, contains('，'));
      expect(pinyin, contains('！'));
    });

    test('handles mixed Chinese and English punctuation', () {
      final pinyin = PinyinService.convertLine('你好, 世界!');
      expect(pinyin, contains(','));
      expect(pinyin, contains('!'));
    });

    test('uses defPinyin for English letters in convertLine', () {
      // English letters should be preserved via defPinyin fallback
      final pinyin = PinyinService.convertLine('你A好');
      final parts = pinyin.split(' ');
      expect(parts.length, 3);
      expect(parts[1], 'A'); // English letter should be preserved
    });

    test('uses defPinyin for numbers in convertLine', () {
      // Numbers should be preserved via defPinyin fallback
      final pinyin = PinyinService.convertLine('你5好');
      final parts = pinyin.split(' ');
      expect(parts.length, 3);
      expect(parts[1], '5'); // Number should be preserved
    });

    test('handles empty line', () {
      final pinyin = PinyinService.convertLine('');
      expect(pinyin, '');
    });

    test('handles line with only spaces', () {
      final pinyin = PinyinService.convertLine('   ');
      final parts = pinyin.split(' ');
      expect(parts.every((p) => p.isEmpty), true);
    });

    test('handles line with only punctuation', () {
      final pinyin = PinyinService.convertLine('，。！？');
      final parts = pinyin.split(' ');
      expect(parts, contains('，'));
      expect(parts, contains('。'));
      expect(parts, contains('！'));
      expect(parts, contains('？'));
    });

    test('uses dictionary for word segmentation', () {
      // "世界" is a two-character word that should be segmented together
      final pinyin = PinyinService.convertLine('世界');
      final parts = pinyin.split(' ');
      // Should have pinyin for both characters
      expect(parts.length, 2);
    });

    test('handles multi-character words correctly', () {
      // Test that multi-character words get pinyin for each character
      final pinyin = PinyinService.convertLine('中国');
      final parts = pinyin.split(' ');
      expect(parts.length, 2); // Two characters in the word
      expect(parts.every((p) => p.isNotEmpty), true); // Both should have pinyin
    });
  });

  group('PinyinService - containsChinese', () {
    test('returns true for Chinese characters', () {
      expect(PinyinService.containsChinese('你好'), true);
      expect(PinyinService.containsChinese('世界'), true);
      expect(PinyinService.containsChinese('中国'), true);
    });

    test('returns false for English text', () {
      expect(PinyinService.containsChinese('Hello'), false);
      expect(PinyinService.containsChinese('World'), false);
    });

    test('returns false for numbers', () {
      expect(PinyinService.containsChinese('123'), false);
      expect(PinyinService.containsChinese('456'), false);
    });

    test('returns false for punctuation only', () {
      expect(PinyinService.containsChinese(',.!?'), false);
      expect(PinyinService.containsChinese('，。！？'), false);
    });

    test('returns true for mixed Chinese and English', () {
      expect(PinyinService.containsChinese('你好 Hello'), true);
      expect(PinyinService.containsChinese('Hello 世界'), true);
    });

    test('returns false for empty string', () {
      expect(PinyinService.containsChinese(''), false);
    });

    test('returns false for spaces only', () {
      expect(PinyinService.containsChinese('   '), false);
    });

    test('detects Chinese in CJK Unified Ideographs range', () {
      // Test characters in the main CJK range (U+4E00 to U+9FFF)
      expect(PinyinService.containsChinese('一'), true); // U+4E00
      expect(PinyinService.containsChinese('龥'), true); // U+9FA5
    });

    test('detects Chinese in CJK Extension A range', () {
      // Test characters in CJK Extension A (U+3400 to U+4DBF)
      expect(PinyinService.containsChinese('㐀'), true); // U+3400
    });
  });

  group('PinyinService - Integration Tests', () {
    test('converts full sentence correctly', () {
      final pinyin = PinyinService.convertLine('我爱中国。');
      final parts = pinyin.split(' ');

      // Should have 5 parts: 4 characters + 1 punctuation
      expect(parts.length, 5);
      expect(parts.last, '。'); // Last part should be punctuation
      expect(parts.take(4).every((p) => p.isNotEmpty), true); // First 4 should have pinyin
    });

    test('maintains alignment with original text', () {
      final text = '你好 世界';
      final pinyin = PinyinService.convertLine(text);
      final parts = pinyin.split(' ');

      // Should have 5 parts: char, char, space, char, char
      expect(parts.length, 5);
      expect(parts[2], ''); // Middle should be empty for space
    });

    test('handles complex mixed content', () {
      final text = '你好，World！';
      final pinyin = PinyinService.convertLine(text);

      // Should handle Chinese, punctuation, and potentially English
      expect(pinyin, isNotEmpty);
      expect(pinyin, contains('，'));
      expect(pinyin, contains('！'));
    });
  });
}
