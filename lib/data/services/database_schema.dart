/// Shared database schema for PandaVerse
/// This file contains the SQL schema definitions used by both the app
/// and the add_song.dart script to ensure consistency.
library;

class DatabaseSchema {
  static const int version = 1;

  /// Creates all tables in the database
  static Future<void> createTables(dynamic db) async {
    await db.execute(songsTableSql);
    await db.execute(lyricsTableSql);
    await db.execute(playHistoryTableSql);
    await db.execute(highlightedWordsTableSql);
  }

  static const String songsTableSql = '''
    CREATE TABLE songs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      added_date TEXT NOT NULL,
      last_activity TEXT NOT NULL
    )
  ''';

  static const String lyricsTableSql = '''
    CREATE TABLE lyrics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      song_id TEXT NOT NULL,
      lyrics_data TEXT NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
    )
  ''';

  static const String playHistoryTableSql = '''
    CREATE TABLE play_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      song_id TEXT NOT NULL,
      played_at TEXT NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
    )
  ''';

  static const String highlightedWordsTableSql = '''
    CREATE TABLE highlighted_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      song_id TEXT NOT NULL,
      line_index INTEGER NOT NULL,
      start_position INTEGER NOT NULL,
      end_position INTEGER NOT NULL,
      word_text TEXT NOT NULL,
      word_pinyin TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
      UNIQUE(song_id, line_index, start_position, end_position)
    )
  ''';
}
