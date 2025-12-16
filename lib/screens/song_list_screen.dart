import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/constants.dart';
import '../data/models/song_model.dart';
import '../data/services/lyrics_db_service.dart';
import '../data/services/dictionary_service.dart';
import '../data/services/character_converter.dart';
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
    setState(() {
      _allSongs = songs;
      _filteredSongs = _filterSongs(songs);
    });
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
                                  SnackBar(content: Text('Deleted "${song.title}"')),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddSongDialog(),
    );

    // Reload songs if a song was added
    if (result == true) {
      await loadSongs();
    }
  }
}
