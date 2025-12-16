#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:characters/characters.dart';

// Import shared database schema
import '../lib/data/services/database_schema.dart';

// Simple models for the script
class Song {
  final String id;
  final String title;
  final String author;
  final DateTime addedDate;
  final DateTime lastActivity;

  Song({
    required this.id,
    required this.title,
    required this.author,
    required this.addedDate,
    required this.lastActivity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'added_date': addedDate.toIso8601String(),
      'last_activity': lastActivity.toIso8601String(),
    };
  }
}

class LyricLine {
  final int lineNumber;
  final String traditionalChinese;
  final String pinyin;

  LyricLine({
    required this.lineNumber,
    required this.traditionalChinese,
    required this.pinyin,
  });

  Map<String, dynamic> toJson() {
    return {
      'line_number': lineNumber,
      'traditional_chinese': traditionalChinese,
      'pinyin': pinyin,
    };
  }
}

// Simple dictionary entry for character conversion
class DictionaryEntry {
  final String traditional;
  final String simplified;
  final int? frequency;

  DictionaryEntry({
    required this.traditional,
    required this.simplified,
    this.frequency,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      traditional: json['traditional'] as String,
      simplified: json['simplified'] as String,
      frequency: json['frequency'] as int?,
    );
  }
}

// Character converter for simplified to traditional conversion
class CharacterConverter {
  static Map<String, String>? _simplifiedToTraditional;

  // Manual overrides for ambiguous characters (simplified -> preferred traditional)
  static const Map<String, String> _manualOverrides = {
    '别': '別',  // Not 彆
    '干': '幹',  // Not 乾 (when meaning "do/work")
    '复': '複',  // Not 復 (when meaning "complex")
    '于': '於',  // Not 于 (when meaning "at/in")
  };

  /// Initialize conversion maps from the dictionary
  static Future<void> initialize() async {
    if (_simplifiedToTraditional != null) return;

    _simplifiedToTraditional = {};

    try {
      // Load dictionary from assets
      final dictionaryPath = join(
        Directory.current.path,
        'assets',
        'dictionary',
        'cedict.json'
      );

      final file = File(dictionaryPath);
      if (!await file.exists()) {
        print('Warning: Dictionary file not found at $dictionaryPath');
        return;
      }

      final jsonString = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // Parse all entries and sort by frequency (highest first)
      final allEntries = jsonData.values
          .map((e) => DictionaryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final aFreq = a.frequency ?? 0;
          final bFreq = b.frequency ?? 0;
          return bFreq.compareTo(aFreq); // Descending
        });

      // First pass: collect characters that are the same in both forms
      // These are modern characters that don't need conversion
      final noConversionNeeded = <String>{};
      for (final dictEntry in allEntries) {

        if (dictEntry.traditional == dictEntry.simplified) {
          // Add all characters from this entry to the no-conversion set
          for (final char in dictEntry.traditional.characters) {
            noConversionNeeded.add(char);
          }
        }
      }

      // Second pass: build conversion map, skipping characters that don't need conversion
      // Process in frequency order (most common first)
      for (final dictEntry in allEntries) {

        if (dictEntry.traditional != dictEntry.simplified) {
          // Use characters to properly handle grapheme clusters
          final tradChars = dictEntry.traditional.characters.toList();
          final simpChars = dictEntry.simplified.characters.toList();

          for (int i = 0; i < tradChars.length && i < simpChars.length; i++) {
            final trad = tradChars[i];
            final simp = simpChars[i];

            // Skip if either character doesn't need conversion (i.e., already the same in modern usage)
            if (noConversionNeeded.contains(trad) || noConversionNeeded.contains(simp)) {
              continue;
            }

            if (trad != simp) {
              // Only set simplified->traditional mapping if not already set (prefer first/most common)
              _simplifiedToTraditional![simp] ??= trad;
            }
          }
        }
      }

      // Apply manual overrides for common ambiguous characters
      _manualOverrides.forEach((simp, trad) {
        _simplifiedToTraditional![simp] = trad;
      });

      print('✓ Character converter initialized with ${_simplifiedToTraditional!.length} mappings');
    } catch (e) {
      print('Warning: Failed to initialize character converter: $e');
    }
  }

  /// Convert simplified Chinese to traditional
  static String toTraditional(String text) {
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
}

void main() async {
  // Initialize FFI for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('=== PandaVerse Song Addition Script ===\n');

  // Initialize character converter
  print('Initializing character converter...');
  await CharacterConverter.initialize();

  // Get song details from user
  stdout.write('Enter song title (in Chinese): ');
  final title = stdin.readLineSync() ?? '';

  stdout.write('Enter artist name: ');
  final author = stdin.readLineSync() ?? '';

  if (title.isEmpty || author.isEmpty) {
    print('Error: Title and author cannot be empty');
    exit(1);
  }

  print('\nFetching lyrics from lrclib.net...');

  try {
    // Fetch lyrics from lrclib.net API
    final url = Uri.parse(
      'https://lrclib.net/api/search?q=${Uri.encodeComponent(title)} ${Uri.encodeComponent(author)}'
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      print('Error: Failed to fetch lyrics (HTTP ${response.statusCode})');
      exit(1);
    }

    final List<dynamic> results = jsonDecode(response.body);

    if (results.isEmpty) {
      print('Error: No lyrics found for "$title" by $author');
      print('\nYou can:');
      print('1. Try searching manually at https://lrclib.net/');
      print('2. Check the spelling of the title and artist');
      exit(1);
    }

    // Show results and let user choose
    print('\nFound ${results.length} result(s):');
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      print('${i + 1}. ${result['trackName']} by ${result['artistName']}');
      if (result['albumName'] != null) {
        print('   Album: ${result['albumName']}');
      }
    }

    int choice = 0;
    if (results.length > 1) {
      stdout.write('\nSelect result (1-${results.length}): ');
      final input = stdin.readLineSync() ?? '1';
      choice = int.tryParse(input) ?? 1;
      choice = choice - 1;

      if (choice < 0 || choice >= results.length) {
        print('Invalid choice');
        exit(1);
      }
    }

    final selectedResult = results[choice];
    final plainLyrics = selectedResult['plainLyrics'];

    if (plainLyrics == null || plainLyrics.toString().isEmpty) {
      print('Error: No plain lyrics found in the selected result');
      exit(1);
    }

    print('\n✓ Lyrics fetched successfully!');
    print('Lines: ${plainLyrics.toString().split('\n').length}');

    // Convert to traditional Chinese (in case fetched lyrics are simplified)
    final traditionalTitle = CharacterConverter.toTraditional(title);
    final traditionalAuthor = CharacterConverter.toTraditional(author);
    final traditionalLyrics = CharacterConverter.toTraditional(plainLyrics.toString());

    // Generate song ID
    final songId = '${traditionalTitle.toLowerCase().replaceAll(' ', '_')}_${traditionalAuthor.toLowerCase().replaceAll(' ', '_')}';

    // Create song
    final now = DateTime.now();
    final song = Song(
      id: songId,
      title: traditionalTitle,
      author: traditionalAuthor,
      addedDate: now,
      lastActivity: now,
    );

    // Process lyrics lines
    final lyricsLines = traditionalLyrics.split('\n');
    final lyricLinesList = <LyricLine>[];

    for (int i = 0; i < lyricsLines.length; i++) {
      final line = lyricsLines[i].trim();
      if (line.isEmpty) continue;

      lyricLinesList.add(LyricLine(
        lineNumber: i,
        traditionalChinese: line,
        pinyin: '', // Will be generated by the app using lpinyin
      ));
    }

    // Save to database
    print('\nSaving to database...');

    // Get database path (same as app)
    final dbPath = join(
      Directory.current.path,
      'sample_data',
      'pandaverse_lyrics.db'
    );

    // Create directory if it doesn't exist
    await Directory(dirname(dbPath)).create(recursive: true);

    final db = await openDatabase(
      dbPath,
      version: DatabaseSchema.version,
      onCreate: (db, version) async {
        await DatabaseSchema.createTables(db);
      },
    );

    // Insert song
    await db.insert(
      'songs',
      song.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert lyrics
    final lyricsData = jsonEncode({
      'song_id': songId,
      'lines': lyricLinesList.map((l) => l.toJson()).toList(),
    });

    await db.delete('lyrics', where: 'song_id = ?', whereArgs: [songId]);
    await db.insert('lyrics', {
      'song_id': songId,
      'lyrics_data': lyricsData,
    });

    await db.close();

    print('\n✓ Song added successfully!');
    print('Song ID: $songId');
    print('Title: $traditionalTitle');
    print('Author: $traditionalAuthor');
    print('Lyrics lines: ${lyricLinesList.length}');
    print('\nDatabase location: $dbPath');
    print('\nNote: Pinyin will be generated automatically when the app loads the lyrics.');

  } catch (e) {
    print('\nError: $e');
    exit(1);
  }
}
