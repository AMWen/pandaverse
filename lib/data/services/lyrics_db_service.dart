import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song_model.dart';
import '../models/lyrics_model.dart';
import '../models/lyric_line_model.dart';
import 'database_schema.dart';

class LyricsDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pandaverse_lyrics.db');

    // Copy sample lyrics from assets on first run
    if (!await File(path).exists()) {
      try {
        final data = await rootBundle.load('sample_data/pandaverse_lyrics.db');
        final bytes = data.buffer.asUint8List();
        await Directory(dirname(path)).create(recursive: true);
        await File(path).writeAsBytes(bytes);
      } catch (e) {
        // If asset doesn't exist, database will be created fresh
      }
    }

    _db = await openDatabase(
      path,
      version: DatabaseSchema.version,
      onCreate: (db, version) async {
        await DatabaseSchema.createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migrate from version 1 to 2: lyrics table -> lyric_lines table
          await _migrateToVersion2(db);
        }
      },
      onOpen: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  /// Migrate from version 1 to version 2
  static Future<void> _migrateToVersion2(Database db) async {
    // Create the new lyric_lines table
    await db.execute(DatabaseSchema.lyricLinesTableSql);

    // Check if old lyrics table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='lyrics'",
    );

    if (tables.isNotEmpty) {
      // Migrate data from old lyrics table to new lyric_lines table
      final oldLyrics = await db.query('lyrics');

      // Use batch for much faster inserts
      final batch = db.batch();

      for (final row in oldLyrics) {
        final songId = row['song_id'] as String;
        final lyricsData = row['lyrics_data'] as String;

        try {
          // Parse the old JSON format
          final lyrics = Lyrics.fromJsonString(lyricsData);

          // Add each line to the batch
          for (final line in lyrics.lines) {
            batch.insert('lyric_lines', {
              'song_id': songId,
              'line_number': line.lineNumber,
              'traditional_chinese': line.traditionalChinese,
              'pinyin': line.pinyin,
            });
          }
        } catch (e) {
          // If parsing fails, skip this song's lyrics
        }
      }

      // Commit all inserts at once
      await batch.commit(noResult: true);

      // Drop the old lyrics table
      await db.execute('DROP TABLE IF EXISTS lyrics');
    }
  }

  // Insert a song
  static Future<void> insertSong(Song song) async {
    final db = await database;
    await db.insert(
      'songs',
      song.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update last activity timestamp for a song
  static Future<void> updateLastActivity(String songId) async {
    final db = await database;
    await db.update(
      'songs',
      {'last_activity': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  // Insert lyrics for a song
  static Future<void> insertLyrics(Lyrics lyrics) async {
    final db = await database;

    // First delete existing lyrics for this song
    await db.delete('lyric_lines', where: 'song_id = ?', whereArgs: [lyrics.songId]);

    // Then insert each line as a separate row
    final batch = db.batch();
    for (final line in lyrics.lines) {
      batch.insert('lyric_lines', {
        'song_id': lyrics.songId,
        'line_number': line.lineNumber,
        'traditional_chinese': line.traditionalChinese,
        'pinyin': line.pinyin,
      });
    }
    await batch.commit(noResult: true);
  }

  // Get all songs
  static Future<List<Song>> getAllSongs({String? sortBy, bool isAscending = true}) async {
    final db = await database;

    String orderBy;
    final direction = isAscending ? 'ASC' : 'DESC';

    switch (sortBy) {
      case 'title':
        orderBy = 'title COLLATE NOCASE $direction';
        break;
      case 'author':
        orderBy = 'author COLLATE NOCASE $direction';
        break;
      case 'date':
        orderBy = 'last_activity $direction';
        break;
      default:
        orderBy = 'last_activity DESC';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) => Song.fromJson(maps[i]));
  }

  // Search songs by title or author
  static Future<List<Song>> searchSongs(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      where: 'title LIKE ? OR author LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return List.generate(maps.length, (i) => Song.fromJson(maps[i]));
  }

  // Get song by ID
  static Future<Song?> getSongById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Song.fromJson(maps.first);
  }

  // Get lyrics for a song
  static Future<Lyrics?> getLyricsBySongId(String songId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lyric_lines',
      where: 'song_id = ?',
      whereArgs: [songId],
      orderBy: 'line_number ASC',
    );

    if (maps.isEmpty) return null;

    final lines = maps.map((map) => LyricLine(
      lineNumber: map['line_number'] as int,
      traditionalChinese: map['traditional_chinese'] as String,
      pinyin: map['pinyin'] as String,
    )).toList();

    return Lyrics(songId: songId, lines: lines);
  }

  // Delete a song and its lyrics
  static Future<void> deleteSong(String songId) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [songId]);
    // Lyrics and highlighted words will be deleted automatically due to CASCADE
  }

  // Insert or update a highlighted word
  static Future<void> insertHighlightedWord({
    required String songId,
    required int lineIndex,
    required int startPosition,
    required int endPosition,
    required String wordText,
    required String wordPinyin,
  }) async {
    final db = await database;
    await db.insert(
      'highlighted_words',
      {
        'song_id': songId,
        'line_index': lineIndex,
        'start_position': startPosition,
        'end_position': endPosition,
        'word_text': wordText,
        'word_pinyin': wordPinyin,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Update last activity for the song
    await updateLastActivity(songId);
  }

  // Delete a highlighted word
  static Future<void> deleteHighlightedWord({
    required String songId,
    required int lineIndex,
    required int startPosition,
    required int endPosition,
  }) async {
    final db = await database;
    await db.delete(
      'highlighted_words',
      where: 'song_id = ? AND line_index = ? AND start_position = ? AND end_position = ?',
      whereArgs: [songId, lineIndex, startPosition, endPosition],
    );
  }

  // Get all highlighted words for a song
  static Future<List<Map<String, dynamic>>> getHighlightedWordsForSong(String songId) async {
    final db = await database;
    return await db.query(
      'highlighted_words',
      where: 'song_id = ?',
      whereArgs: [songId],
      orderBy: 'line_index ASC, start_position ASC',
    );
  }

  // Get all highlighted words (across all songs) with song info
  static Future<List<Map<String, dynamic>>> getAllHighlightedWords({String? searchQuery}) async {
    final db = await database;

    if (searchQuery == null || searchQuery.isEmpty) {
      // Return all highlighted words with song info
      return await db.rawQuery('''
        SELECT
          hw.*,
          s.title as song_title,
          s.author as song_author
        FROM highlighted_words hw
        JOIN songs s ON hw.song_id = s.id
        ORDER BY s.title ASC, hw.line_index ASC, hw.start_position ASC
      ''');
    } else {
      // Search by word text, pinyin, song title, or author
      return await db.rawQuery('''
        SELECT
          hw.*,
          s.title as song_title,
          s.author as song_author
        FROM highlighted_words hw
        JOIN songs s ON hw.song_id = s.id
        WHERE hw.word_text LIKE ?
          OR hw.word_pinyin LIKE ?
          OR s.title LIKE ?
          OR s.author LIKE ?
        ORDER BY s.title ASC, hw.line_index ASC, hw.start_position ASC
      ''', ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
  }

  // Check if a word is highlighted
  static Future<bool> isWordHighlighted({
    required String songId,
    required int lineIndex,
    required int startPosition,
    required int endPosition,
  }) async {
    final db = await database;
    final result = await db.query(
      'highlighted_words',
      where: 'song_id = ? AND line_index = ? AND start_position = ? AND end_position = ?',
      whereArgs: [songId, lineIndex, startPosition, endPosition],
    );
    return result.isNotEmpty;
  }

  // Update a single lyric line
  static Future<void> updateLyricLine({
    required String songId,
    required int lineNumber,
    required String traditionalChinese,
    required String pinyin,
  }) async {
    final db = await database;
    await db.update(
      'lyric_lines',
      {
        'traditional_chinese': traditionalChinese,
        'pinyin': pinyin,
      },
      where: 'song_id = ? AND line_number = ?',
      whereArgs: [songId, lineNumber],
    );

    // Delete highlighted words for this line since positions may have changed
    await db.delete(
      'highlighted_words',
      where: 'song_id = ? AND line_index = ?',
      whereArgs: [songId, lineNumber],
    );

    // Update last activity for the song
    await updateLastActivity(songId);
  }

  // Insert a new lyric line at a specific position and renumber subsequent lines
  static Future<void> insertLyricLine({
    required String songId,
    required int lineNumber,
    required String traditionalChinese,
    required String pinyin,
  }) async {
    final db = await database;

    // Renumber all lines at and after the insertion point
    await db.rawUpdate('''
      UPDATE lyric_lines
      SET line_number = line_number + 1
      WHERE song_id = ? AND line_number >= ?
    ''', [songId, lineNumber]);

    // Renumber highlighted words for lines at and after the insertion point
    await db.rawUpdate('''
      UPDATE highlighted_words
      SET line_index = line_index + 1
      WHERE song_id = ? AND line_index >= ?
    ''', [songId, lineNumber]);

    // Insert the new line
    await db.insert('lyric_lines', {
      'song_id': songId,
      'line_number': lineNumber,
      'traditional_chinese': traditionalChinese,
      'pinyin': pinyin,
    });

    // Update last activity for the song
    await updateLastActivity(songId);
  }

  // Delete a single lyric line and renumber remaining lines
  static Future<void> deleteLyricLine({
    required String songId,
    required int lineNumber,
  }) async {
    final db = await database;

    // Delete the line
    await db.delete(
      'lyric_lines',
      where: 'song_id = ? AND line_number = ?',
      whereArgs: [songId, lineNumber],
    );

    // Renumber all lines after the deleted one
    await db.rawUpdate('''
      UPDATE lyric_lines
      SET line_number = line_number - 1
      WHERE song_id = ? AND line_number > ?
    ''', [songId, lineNumber]);

    // Delete highlighted words for this line
    await db.delete(
      'highlighted_words',
      where: 'song_id = ? AND line_index = ?',
      whereArgs: [songId, lineNumber],
    );

    // Renumber highlighted words for lines after the deleted one
    await db.rawUpdate('''
      UPDATE highlighted_words
      SET line_index = line_index - 1
      WHERE song_id = ? AND line_index > ?
    ''', [songId, lineNumber]);

    // Update last activity for the song
    await updateLastActivity(songId);
  }

  // Close database
  static Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
