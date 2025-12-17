import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/constants.dart';
import '../data/models/song_model.dart';
import '../data/models/lyrics_model.dart';
import '../data/models/lyric_line_model.dart';
import '../data/services/lyrics_db_service.dart';
import '../data/services/dictionary_service.dart';
import '../data/services/character_converter.dart';
import '../data/services/pinyin_service.dart';
import '../data/widgets/song_card_widget.dart';
import '../data/widgets/sort_chips_widget.dart';
import '../data/widgets/search_bar_widget.dart';
import 'lyrics_screen.dart';
import 'add_song_dialog.dart';

class SongListScreen extends StatefulWidget {
  const SongListScreen({super.key});

  @override
  State<SongListScreen> createState() => SongListScreenState();
}

class SongListScreenState extends State<SongListScreen> {
  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  String _sortBy = 'date'; // 'title', 'author', or 'date'
  bool _isAscending = false; // false = descending (most recent first for date)
  String _searchQuery = '';
  bool _isLoading = true;
  bool _useSimplified = false;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _songsGeneratingPinyin = {}; // Track which songs are generating pinyin
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    // Load dictionary
    await DictionaryService.loadDictionary();

    // Initialize character converter
    CharacterConverter.initialize();

    // Load character script preference
    final prefs = await SharedPreferences.getInstance();
    _useSimplified = prefs.getBool('useSimplified') ?? false;

    // Load songs from database
    await loadSongs();

    setState(() => _isLoading = false);
  }

  Future<void> _toggleCharacterScript() async {
    setState(() {
      _useSimplified = !_useSimplified;
    });

    // Save preference to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSimplified', _useSimplified);
  }

  Future<void> loadSongs() async {
    final songs = await LyricsDB.getAllSongs(sortBy: _sortBy, isAscending: _isAscending);

    // Check which songs are generating pinyin
    final generatingSongs = <String>{};
    for (final song in songs) {
      final lyrics = await LyricsDB.getLyricsBySongId(song.id);

      // Mark as generating if:
      // 1. Lyrics don't exist yet (still being saved)
      // 2. Lyrics exist but have empty pinyin
      if (lyrics == null || lyrics.lines.isEmpty) {
        // No lyrics yet - mark as generating
        generatingSongs.add(song.id);
      } else {
        // Check if any line has empty pinyin
        final hasEmptyPinyin = lyrics.lines.any((line) => line.pinyin.isEmpty);
        if (hasEmptyPinyin) {
          generatingSongs.add(song.id);
        }
      }
    }

    setState(() {
      _allSongs = songs;
      _filteredSongs = _filterSongs(songs);
      _songsGeneratingPinyin = generatingSongs;
    });

    // Trigger pinyin generation for songs that need it
    for (final songId in generatingSongs) {
      _generatePinyinForSong(songId);
    }

    // Start or stop refresh timer based on whether any songs are generating
    if (generatingSongs.isNotEmpty && _refreshTimer == null) {
      _startRefreshTimer();
    } else if (generatingSongs.isEmpty && _refreshTimer != null) {
      _stopRefreshTimer();
    }
  }

  /// Generate pinyin for a song in the background
  Future<void> _generatePinyinForSong(String songId) async {
    try {
      final lyrics = await LyricsDB.getLyricsBySongId(songId);
      if (lyrics == null) return;

      final updatedLines = <LyricLine>[];
      bool needsUpdate = false;

      for (int i = 0; i < lyrics.lines.length; i++) {
        final line = lyrics.lines[i];

        if (line.traditionalChinese.isNotEmpty && line.pinyin.isEmpty) {
          // Generate pinyin for this line
          final pinyin = PinyinService.convertLine(line.traditionalChinese);

          updatedLines.add(LyricLine(
            lineNumber: line.lineNumber,
            traditionalChinese: line.traditionalChinese,
            pinyin: pinyin,
          ));
          needsUpdate = true;
        } else {
          updatedLines.add(line);
        }

        // Yield to UI thread after every line to keep UI responsive
        await Future.delayed(Duration.zero);
      }

      if (needsUpdate) {
        // Update database with generated pinyin
        final updatedLyrics = Lyrics(songId: songId, lines: updatedLines);
        await LyricsDB.insertLyrics(updatedLyrics);
      }
    } catch (e) {
      // Silently fail - will retry on next refresh
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await loadSongs();
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  List<Song> _filterSongs(List<Song> songs) {
    if (_searchQuery.isEmpty) return songs;

    return songs.where((song) {
      final titleLower = song.title.toLowerCase();
      final authorLower = song.author.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return titleLower.contains(queryLower) || authorLower.contains(queryLower);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredSongs = _filterSongs(_allSongs);
    });
  }

  Future<void> _changeSortOrder(String sortBy, bool isAscending) async {
    setState(() {
      _sortBy = sortBy;
      _isAscending = isAscending;
      _isLoading = true;
    });

    await loadSongs();

    setState(() => _isLoading = false);
  }

  Future<void> _navigateToLyrics(Song song) async {
    // Don't allow opening songs that are still generating pinyin
    if (_songsGeneratingPinyin.contains(song.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for pinyin generation to complete'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricsScreen(song: song),
      ),
    );

    // Reload data and preference when coming back from lyrics screen
    final prefs = await SharedPreferences.getInstance();
    final newPreference = prefs.getBool('useSimplified') ?? false;
    if (newPreference != _useSimplified) {
      setState(() {
        _useSimplified = newPreference;
      });
    }

    // Refresh song list (last_activity may have changed)
    await loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        backgroundColor: primaryColor,
        actions: [
          // Toggle between simplified and traditional
          TextButton(
            onPressed: _toggleCharacterScript,
            child: Text(
              _useSimplified ? '简' : '繁',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSongDialog,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hintText: 'Search songs or artists...',
            searchQuery: _searchQuery,
            onChanged: _onSearchChanged,
          ),

          // Sort buttons
          SortChipsWidget(
            currentSortBy: _sortBy,
            isAscending: _isAscending,
            onSortChanged: _changeSortOrder,
          ),

          const Divider(),

          // Song list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSongs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No songs yet!\n\nUse the script to add songs.'
                                  : 'No songs found',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredSongs.length,
                        itemBuilder: (context, index) {
                          final song = _filteredSongs[index];
                          return Dismissible(
                            key: Key(song.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Song'),
                                  content: Text('Are you sure you want to delete "${song.title}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              await LyricsDB.deleteSong(song.id);
                              await loadSongs();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Deleted "${song.title}"'),
                                    duration: const Duration(milliseconds: 800),
                                  ),
                                );
                              }
                            },
                            child: SongCardWidget(
                              song: song,
                              displayTitle: _useSimplified
                                  ? CharacterConverter.toSimplified(song.title)
                                  : song.title,
                              displayAuthor: _useSimplified
                                  ? CharacterConverter.toSimplified(song.author)
                                  : song.author,
                              onTap: () => _navigateToLyrics(song),
                              isGeneratingPinyin: _songsGeneratingPinyin.contains(song.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSongDialog() async {
    final songId = await showDialog<String>(
      context: context,
      builder: (context) => const AddSongDialog(),
    );

    // If a song was added, start the refresh timer to detect it
    if (songId != null) {
      // Start refresh timer if not already running
      if (_refreshTimer == null) {
        _startRefreshTimer();
      }
      // Trigger one immediate reload after animation completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) loadSongs();
      });
    }
  }
}
