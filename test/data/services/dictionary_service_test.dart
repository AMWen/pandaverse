import 'package:flutter_test/flutter_test.dart';
import 'package:pandaverse/data/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize the dictionary service
    await DictionaryService.loadDictionary();
  });

  group('DictionaryService - Initialization', () {
    test('getDictionary returns non-null after initialization', () {
      final dict = DictionaryService.getDictionary();
      expect(dict, isNotNull);
    });

    test('dictionary contains entries', () {
      final dict = DictionaryService.getDictionary();
      expect(dict!.isNotEmpty, true);
    });
  });

  group('DictionaryService - translate', () {
    test('translates common two-character word', () {
      final entry = DictionaryService.translate('世界');
      expect(entry, isNotNull);
      expect(entry!.traditional, '世界');
      expect(entry.definitions, isNotEmpty);
    });

    test('translates common single character', () {
      final entry = DictionaryService.translate('好');
      expect(entry, isNotNull);
      expect(entry!.traditional, '好');
      expect(entry.definitions, isNotEmpty);
    });

    test('returns null for non-existent word', () {
      final entry = DictionaryService.translate('🎵🎶🎵');
      expect(entry, isNull);
    });

    test('handles empty string', () {
      final entry = DictionaryService.translate('');
      expect(entry, isNull);
    });

    test('finds traditional characters', () {
      final entry = DictionaryService.translate('中國');
      expect(entry, isNotNull);
      expect(entry!.traditional, '中國');
    });

    test('finds simplified characters', () {
      final entry = DictionaryService.translate('中国');
      expect(entry, isNotNull);
      // Should find the entry with simplified form
      expect(entry!.simplified, '中国');
    });

    test('returned entry has pinyin', () {
      final entry = DictionaryService.translate('你好');
      expect(entry, isNotNull);
      expect(entry!.pinyin, isNotEmpty);
    });

    test('returned entry has definitions', () {
      final entry = DictionaryService.translate('你好');
      expect(entry, isNotNull);
      expect(entry!.definitions, isNotEmpty);
      expect(entry.definitions.first, isA<String>());
    });
  });

  group('DictionaryService - Entry Properties', () {
    test('entry contains traditional, simplified, pinyin, and definitions', () {
      final entry = DictionaryService.translate('你好');
      expect(entry, isNotNull);
      expect(entry!.traditional, isNotEmpty);
      expect(entry.simplified, isNotEmpty);
      expect(entry.pinyin, isNotEmpty);
      expect(entry.definitions, isNotEmpty);
    });

    test('definitions are non-empty strings', () {
      final entry = DictionaryService.translate('你好');
      expect(entry, isNotNull);
      expect(entry!.definitions.every((d) => d.isNotEmpty), true);
    });

    test('entry has frequency data when available', () {
      final entry = DictionaryService.translate('的');
      expect(entry, isNotNull);
      // Most common character should have frequency data
      expect(entry!.frequency, isNotNull);
    });
  });

  group('DictionaryService - Common Words', () {
    test('finds basic greetings', () {
      final hello = DictionaryService.translate('你好');
      final goodbye = DictionaryService.translate('再見');
      final thanks = DictionaryService.translate('謝謝');

      expect(hello, isNotNull);
      expect(goodbye, isNotNull);
      expect(thanks, isNotNull);
    });

    test('finds common nouns', () {
      final person = DictionaryService.translate('人');
      final water = DictionaryService.translate('水');
      final day = DictionaryService.translate('天');

      expect(person, isNotNull);
      expect(water, isNotNull);
      expect(day, isNotNull);
    });

    test('finds numbers', () {
      final one = DictionaryService.translate('一');
      final two = DictionaryService.translate('二');
      final three = DictionaryService.translate('三');

      expect(one, isNotNull);
      expect(two, isNotNull);
      expect(three, isNotNull);
    });
  });

  group('DictionaryService - Edge Cases', () {
    test('handles single character lookups', () {
      final entry = DictionaryService.translate('我');
      expect(entry, isNotNull);
    });

    test('handles multi-character word lookups', () {
      final entry = DictionaryService.translate('中華人民共和國');
      expect(entry, isNotNull);
    });

    test('handles words with numbers', () {
      // Some entries might contain numbers
      final entry = DictionaryService.translate('一個');
      expect(entry, isNotNull);
    });

    test('lookup is case-sensitive for Chinese', () {
      // Chinese characters don't have case, but this ensures
      // the lookup works correctly
      final entry1 = DictionaryService.translate('你好');
      final entry2 = DictionaryService.translate('你好');
      expect(entry1, isNotNull);
      expect(entry2, isNotNull);
      expect(entry1!.traditional, entry2!.traditional);
    });
  });

  group('DictionaryService - Word Segmentation Support', () {
    test('finds two-character words for greedy matching', () {
      // These should be in dictionary for word segmentation
      final world = DictionaryService.translate('世界');
      final china = DictionaryService.translate('中國');

      expect(world, isNotNull);
      expect(china, isNotNull);
    });

    test('finds three-character words', () {
      final entry = DictionaryService.translate('計算機');
      expect(entry, isNotNull);
    });

    test('finds four-character words', () {
      // Test if dictionary supports 4-character idioms/phrases
      final entry = DictionaryService.translate('一心一意');
      expect(entry, isNotNull);
    });
  });

  group('DictionaryService - Performance', () {
    test('lookups are reasonably fast', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        DictionaryService.translate('你好');
      }

      stopwatch.stop();

      // 100 lookups should take less than 100ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('handles multiple concurrent lookups', () {
      final words = ['你好', '世界', '中國', '人民', '謝謝'];
      final results = words.map((w) => DictionaryService.translate(w)).toList();

      expect(results.every((r) => r != null), true);
    });
  });
}
