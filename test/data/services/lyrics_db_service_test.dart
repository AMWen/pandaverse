import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pandaverse/data/services/lyrics_db_service.dart';
import 'package:pandaverse/data/models/song_model.dart';
import 'package:pandaverse/data/models/lyrics_model.dart';
import 'package:pandaverse/data/models/lyric_line_model.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    // Use in-memory database for tests to avoid persistence issues
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // Clean up after each test
  tearDown(() async {
    await LyricsDB.close();
    // Delete the database to ensure clean state for next test
    await databaseFactory.deleteDatabase('pandaverse_lyrics.db');
  });

  group('LyricsDB - Song Operations', () {
    test('insertSong and getSongById', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'test_song_1',
        title: 'Test Song',
        author: 'Test Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      final retrieved = await LyricsDB.getSongById('test_song_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test_song_1');
      expect(retrieved.title, 'Test Song');
      expect(retrieved.author, 'Test Author');
    });

    test('getAllSongs returns all songs', () async {
      final now = DateTime.now();
      final song1 = Song(
        id: 'song_1',
        title: 'Song A',
        author: 'Author A',
        addedDate: now,
        lastActivity: now,
      );
      final song2 = Song(
        id: 'song_2',
        title: 'Song B',
        author: 'Author B',
        addedDate: now.add(const Duration(hours: 1)),
        lastActivity: now.add(const Duration(hours: 1)),
      );

      await LyricsDB.insertSong(song1);
      await LyricsDB.insertSong(song2);

      final songs = await LyricsDB.getAllSongs();
      expect(songs.length, 2);
    });

    test('getAllSongs sorts by title ascending', () async {
      final now = DateTime.now();
      final songB = Song(
        id: 'song_b',
        title: 'Zebra',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );
      final songA = Song(
        id: 'song_a',
        title: 'Apple',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(songB);
      await LyricsDB.insertSong(songA);

      final songs = await LyricsDB.getAllSongs(sortBy: 'title', isAscending: true);
      expect(songs.first.title, 'Apple');
      expect(songs.last.title, 'Zebra');
    });

    test('getAllSongs sorts by title descending', () async {
      final now = DateTime.now();
      final songB = Song(
        id: 'song_b',
        title: 'Zebra',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );
      final songA = Song(
        id: 'song_a',
        title: 'Apple',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(songB);
      await LyricsDB.insertSong(songA);

      final songs = await LyricsDB.getAllSongs(sortBy: 'title', isAscending: false);
      expect(songs.first.title, 'Zebra');
      expect(songs.last.title, 'Apple');
    });

    test('getAllSongs sorts by date (most recent first by default)', () async {
      final now = DateTime.now();
      final oldSong = Song(
        id: 'old_song',
        title: 'Old Song',
        author: 'Author',
        addedDate: now.subtract(const Duration(days: 1)),
        lastActivity: now.subtract(const Duration(days: 1)),
      );
      final newSong = Song(
        id: 'new_song',
        title: 'New Song',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(oldSong);
      await LyricsDB.insertSong(newSong);

      final songs = await LyricsDB.getAllSongs(sortBy: 'date', isAscending: false);
      expect(songs.first.id, 'new_song');
      expect(songs.last.id, 'old_song');
    });

    test('searchSongs finds songs by title', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'searchable',
        title: 'Beautiful Day',
        author: 'Test Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      final results = await LyricsDB.searchSongs('Beautiful');

      expect(results.length, 1);
      expect(results.first.title, 'Beautiful Day');
    });

    test('searchSongs finds songs by author', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'searchable',
        title: 'Test Song',
        author: 'Amazing Artist',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      final results = await LyricsDB.searchSongs('Amazing');

      expect(results.length, 1);
      expect(results.first.author, 'Amazing Artist');
    });

    test('searchSongs is case insensitive', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'searchable',
        title: 'Test Song',
        author: 'Test Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      final results = await LyricsDB.searchSongs('test');

      expect(results.length, 1);
    });

    test('updateLastActivity updates song timestamp', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'update_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await Future.delayed(const Duration(milliseconds: 100));
      await LyricsDB.updateLastActivity('update_test');

      final updated = await LyricsDB.getSongById('update_test');
      expect(updated!.lastActivity.isAfter(now), true);
    });

    test('deleteSong removes song', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'delete_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.deleteSong('delete_test');
      final retrieved = await LyricsDB.getSongById('delete_test');

      expect(retrieved, isNull);
    });
  });

  group('LyricsDB - Lyrics Operations', () {
    test('insertLyrics and getLyricsBySongId', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'lyrics_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      final lyrics = Lyrics(
        songId: 'lyrics_test',
        lines: [
          LyricLine(lineNumber: 0, traditionalChinese: '你好', pinyin: 'nǐ hǎo'),
          LyricLine(lineNumber: 1, traditionalChinese: '世界', pinyin: 'shì jiè'),
        ],
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertLyrics(lyrics);

      final retrieved = await LyricsDB.getLyricsBySongId('lyrics_test');
      expect(retrieved, isNotNull);
      expect(retrieved!.lines.length, 2);
      expect(retrieved.lines[0].traditionalChinese, '你好');
      expect(retrieved.lines[1].traditionalChinese, '世界');
    });

    test('insertLyrics replaces existing lyrics', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'replace_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      final lyrics1 = Lyrics(
        songId: 'replace_test',
        lines: [
          LyricLine(lineNumber: 0, traditionalChinese: '你好', pinyin: 'nǐ hǎo'),
        ],
      );

      final lyrics2 = Lyrics(
        songId: 'replace_test',
        lines: [
          LyricLine(lineNumber: 0, traditionalChinese: '世界', pinyin: 'shì jiè'),
        ],
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertLyrics(lyrics1);
      await LyricsDB.insertLyrics(lyrics2);

      final retrieved = await LyricsDB.getLyricsBySongId('replace_test');
      expect(retrieved!.lines.length, 1);
      expect(retrieved.lines[0].traditionalChinese, '世界');
    });
  });

  group('LyricsDB - Highlighted Words Operations', () {
    test('insertHighlightedWord and getHighlightedWordsForSong', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'highlight_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'highlight_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );

      final words = await LyricsDB.getHighlightedWordsForSong('highlight_test');
      expect(words.length, 1);
      expect(words.first['word_text'], '你好');
      expect(words.first['word_pinyin'], 'nǐ hǎo');
    });

    test('insertHighlightedWord replaces duplicate', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'duplicate_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'duplicate_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );
      await LyricsDB.insertHighlightedWord(
        songId: 'duplicate_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );

      final words = await LyricsDB.getHighlightedWordsForSong('duplicate_test');
      expect(words.length, 1);
    });

    test('deleteHighlightedWord removes word', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'delete_word_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'delete_word_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );
      await LyricsDB.deleteHighlightedWord(
        songId: 'delete_word_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
      );

      final words = await LyricsDB.getHighlightedWordsForSong('delete_word_test');
      expect(words.length, 0);
    });

    test('isWordHighlighted returns correct status', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'check_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);

      bool isHighlighted = await LyricsDB.isWordHighlighted(
        songId: 'check_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
      );
      expect(isHighlighted, false);

      await LyricsDB.insertHighlightedWord(
        songId: 'check_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );

      isHighlighted = await LyricsDB.isWordHighlighted(
        songId: 'check_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
      );
      expect(isHighlighted, true);
    });

    test('getAllHighlightedWords returns all words with song info', () async {
      final now = DateTime.now();
      final song1 = Song(
        id: 'song1',
        title: 'Song One',
        author: 'Author One',
        addedDate: now,
        lastActivity: now,
      );
      final song2 = Song(
        id: 'song2',
        title: 'Song Two',
        author: 'Author Two',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song1);
      await LyricsDB.insertSong(song2);

      await LyricsDB.insertHighlightedWord(
        songId: 'song1',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );
      await LyricsDB.insertHighlightedWord(
        songId: 'song2',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '世界',
        wordPinyin: 'shì jiè',
      );

      final words = await LyricsDB.getAllHighlightedWords();
      expect(words.length, 2);
      expect(words.any((w) => w['song_title'] == 'Song One'), true);
      expect(words.any((w) => w['song_title'] == 'Song Two'), true);
    });

    test('getAllHighlightedWords searches by word text', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'search_test',
        title: 'Test Song',
        author: 'Test Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'search_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );
      await LyricsDB.insertHighlightedWord(
        songId: 'search_test',
        lineIndex: 1,
        startPosition: 0,
        endPosition: 2,
        wordText: '世界',
        wordPinyin: 'shì jiè',
      );

      final words = await LyricsDB.getAllHighlightedWords(searchQuery: '你好');
      expect(words.length, 1);
      expect(words.first['word_text'], '你好');
    });

    test('getAllHighlightedWords searches by pinyin', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'pinyin_search_test',
        title: 'Test Song',
        author: 'Test Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'pinyin_search_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );

      final words = await LyricsDB.getAllHighlightedWords(searchQuery: 'nǐ');
      expect(words.length, 1);
      expect(words.first['word_pinyin'], 'nǐ hǎo');
    });

    test('deleteSong cascades to highlighted words', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'cascade_test',
        title: 'Test',
        author: 'Author',
        addedDate: now,
        lastActivity: now,
      );

      await LyricsDB.insertSong(song);
      await LyricsDB.insertHighlightedWord(
        songId: 'cascade_test',
        lineIndex: 0,
        startPosition: 0,
        endPosition: 2,
        wordText: '你好',
        wordPinyin: 'nǐ hǎo',
      );

      await LyricsDB.deleteSong('cascade_test');
      final words = await LyricsDB.getHighlightedWordsForSong('cascade_test');
      expect(words.length, 0);
    });
  });
}
