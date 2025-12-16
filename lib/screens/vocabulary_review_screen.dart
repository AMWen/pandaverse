import 'package:flutter/material.dart';
import '../data/constants.dart';
import '../data/services/lyrics_db_service.dart';
import '../data/services/dictionary_service.dart';
import '../data/widgets/sort_chips_widget.dart';
import '../data/widgets/search_bar_widget.dart';
import 'lyrics_screen.dart';

class VocabularyReviewScreen extends StatefulWidget {
  const VocabularyReviewScreen({super.key});

  @override
  State<VocabularyReviewScreen> createState() => VocabularyReviewScreenState();
}

class VocabularyReviewScreenState extends State<VocabularyReviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allWords = [];
  List<Map<String, dynamic>> _filteredWords = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Set<String> _expandedSongs = {}; // Track which songs are expanded
  String _sortBy = 'date'; // 'title', 'author', or 'date'
  bool _isAscending = false; // false = descending (most recent first for date)

  @override
  void initState() {
    super.initState();
    loadHighlightedWords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadHighlightedWords() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final words = await LyricsDB.getAllHighlightedWords();
    if (mounted) {
      setState(() {
        _allWords = words;
        _filteredWords = words;
        _isLoading = false;
        // Start with all songs expanded
        _expandedSongs = words.map((w) => w['song_title'] as String).toSet();
      });
    }
  }

  void _toggleSongExpansion(String songTitle) {
    setState(() {
      if (_expandedSongs.contains(songTitle)) {
        _expandedSongs.remove(songTitle);
      } else {
        _expandedSongs.add(songTitle);
      }
    });
  }

  void _toggleExpandCollapseAll() {
    setState(() {
      // Get unique song titles from filtered words
      final allSongTitles = _filteredWords.map((w) => w['song_title'] as String).toSet();

      // If all are expanded, collapse all; otherwise expand all
      if (_expandedSongs.containsAll(allSongTitles) && allSongTitles.isNotEmpty) {
        _expandedSongs.clear();
      } else {
        _expandedSongs = allSongTitles;
      }
    });
  }

  bool _areAllSongsExpanded() {
    final allSongTitles = _filteredWords.map((w) => w['song_title'] as String).toSet();
    return allSongTitles.isNotEmpty && _expandedSongs.containsAll(allSongTitles);
  }

  /// Remove tone marks from pinyin for normalized searching
  String _removeToneMarks(String pinyin) {
    return pinyin
        // Tone 1 (flat)
        .replaceAll(RegExp(r'[āĀ]'), 'a')
        .replaceAll(RegExp(r'[ēĒ]'), 'e')
        .replaceAll(RegExp(r'[īĪ]'), 'i')
        .replaceAll(RegExp(r'[ōŌ]'), 'o')
        .replaceAll(RegExp(r'[ūŪ]'), 'u')
        .replaceAll(RegExp(r'[ǖǕ]'), 'ü')
        // Tone 2 (rising)
        .replaceAll(RegExp(r'[áÁ]'), 'a')
        .replaceAll(RegExp(r'[éÉ]'), 'e')
        .replaceAll(RegExp(r'[íÍ]'), 'i')
        .replaceAll(RegExp(r'[óÓ]'), 'o')
        .replaceAll(RegExp(r'[úÚ]'), 'u')
        .replaceAll(RegExp(r'[ǘǗ]'), 'ü')
        // Tone 3 (falling-rising)
        .replaceAll(RegExp(r'[ǎǍ]'), 'a')
        .replaceAll(RegExp(r'[ěĚ]'), 'e')
        .replaceAll(RegExp(r'[ǐǏ]'), 'i')
        .replaceAll(RegExp(r'[ǒǑ]'), 'o')
        .replaceAll(RegExp(r'[ǔǓ]'), 'u')
        .replaceAll(RegExp(r'[ǚǙ]'), 'ü')
        // Tone 4 (falling)
        .replaceAll(RegExp(r'[àÀ]'), 'a')
        .replaceAll(RegExp(r'[èÈ]'), 'e')
        .replaceAll(RegExp(r'[ìÌ]'), 'i')
        .replaceAll(RegExp(r'[òÒ]'), 'o')
        .replaceAll(RegExp(r'[ùÙ]'), 'u')
        .replaceAll(RegExp(r'[ǜǛ]'), 'ü');
  }

  void _filterWords(String query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredWords = _allWords;
      } else {
        final searchLower = query.toLowerCase();
        final searchNormalized = _removeToneMarks(searchLower);

        _filteredWords = _allWords.where((word) {
          final wordText = (word['word_text'] as String).toLowerCase();
          final wordPinyin = (word['word_pinyin'] as String).toLowerCase();
          final wordPinyinNormalized = _removeToneMarks(wordPinyin);
          final songTitle = (word['song_title'] as String).toLowerCase();
          final songAuthor = (word['song_author'] as String).toLowerCase();

          // Get definitions for this word
          final entry = DictionaryService.translate(word['word_text'] as String);
          final definitions = entry?.definitions ?? [];
          final definitionsMatch = definitions.any((def) => def.toLowerCase().contains(searchLower));

          // Check if search matches:
          // 1. Chinese text (exact)
          // 2. Pinyin with tones (exact)
          // 3. Pinyin without tones (normalized)
          // 4. Song title or author
          // 5. Definitions
          return wordText.contains(searchLower) ||
              wordPinyin.contains(searchLower) ||
              wordPinyinNormalized.contains(searchNormalized) ||
              songTitle.contains(searchLower) ||
              songAuthor.contains(searchLower) ||
              definitionsMatch;
        }).toList();
      }
      // Keep only expanded songs that are still in filtered results
      final filteredSongTitles = _filteredWords.map((w) => w['song_title'] as String).toSet();
      _expandedSongs = _expandedSongs.intersection(filteredSongTitles);
    });
  }

  Future<void> _deleteWord(Map<String, dynamic> word) async {
    await LyricsDB.deleteHighlightedWord(
      songId: word['song_id'] as String,
      lineIndex: word['line_index'] as int,
      startPosition: word['start_position'] as int,
      endPosition: word['end_position'] as int,
    );
    await loadHighlightedWords();
  }

  Future<void> _navigateToSong(Map<String, dynamic> word) async {
    final songId = word['song_id'] as String;
    final song = await LyricsDB.getSongById(songId);

    if (song != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LyricsScreen(song: song),
        ),
      );

      // Refresh vocabulary list when returning (words may have been added/removed)
      await loadHighlightedWords();
    }
  }

  Widget _buildWordCard(Map<String, dynamic> word) {
    final wordText = word['word_text'] as String;
    final wordPinyin = word['word_pinyin'] as String;

    // Get translation from dictionary
    final entry = DictionaryService.translate(wordText);
    final definitions = entry?.definitions ?? ['Translation not found'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Word with pinyin
            Row(
              children: [
                Text(
                  wordText,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.0,
                  ),
                  strutStyle: StrutStyle.disabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    wordPinyin,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteWord(word),
                  tooltip: 'Remove from vocabulary',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Definitions
            ...definitions.take(2).map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $def',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedView() {
    // Group words by song
    final wordsBySong = <String, List<Map<String, dynamic>>>{};
    for (final word in _filteredWords) {
      final songTitle = word['song_title'] as String;
      wordsBySong.putIfAbsent(songTitle, () => []).add(word);
    }

    // Sort songs based on selected sort option
    final sortedSongs = wordsBySong.keys.toList();
    if (_sortBy == 'title') {
      sortedSongs.sort((a, b) {
        final comparison = a.toLowerCase().compareTo(b.toLowerCase());
        return _isAscending ? comparison : -comparison;
      });
    } else if (_sortBy == 'author') {
      sortedSongs.sort((a, b) {
        final authorA = wordsBySong[a]!.first['song_author'] as String;
        final authorB = wordsBySong[b]!.first['song_author'] as String;
        final comparison = authorA.toLowerCase().compareTo(authorB.toLowerCase());
        return _isAscending ? comparison : -comparison;
      });
    } else if (_sortBy == 'date') {
      // Sort by highlight date
      sortedSongs.sort((a, b) {
        final wordsA = wordsBySong[a]!;
        final wordsB = wordsBySong[b]!;
        // Get most recent created_at for each song
        final recentA = wordsA.map((w) => DateTime.parse(w['created_at'] as String)).reduce((a, b) => a.isAfter(b) ? a : b);
        final recentB = wordsB.map((w) => DateTime.parse(w['created_at'] as String)).reduce((a, b) => a.isAfter(b) ? a : b);
        final comparison = recentB.compareTo(recentA);
        return _isAscending ? -comparison : comparison; // Default is most recent first (descending)
      });
    }

    return ListView.builder(
      itemCount: sortedSongs.length,
      itemBuilder: (context, index) {
        final songTitle = sortedSongs[index];
        final words = wordsBySong[songTitle]!;
        final songAuthor = words.first['song_author'] as String;

        final isExpanded = _expandedSongs.contains(songTitle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Song header
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  // Navigate to song area
                  Expanded(
                    child: InkWell(
                      onTap: () => _navigateToSong(words.first),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    songTitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    songAuthor,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${words.length} ${words.length == 1 ? 'word' : 'words'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Expand/collapse button
                  IconButton(
                    icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                    onPressed: () => _toggleSongExpansion(songTitle),
                    tooltip: isExpanded ? 'Collapse' : 'Expand',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            // Words for this song (only show if expanded)
            if (isExpanded) ...words.map((word) => _buildWordCard(word)),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Review'),
        backgroundColor: primaryColor,
      ),
      body: Column(
        children: [
          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hintText: 'Search by word, pinyin, or definition...',
            searchQuery: _searchQuery,
            onChanged: _filterWords,
          ),

          // Sort buttons
          SortChipsWidget(
            currentSortBy: _sortBy,
            isAscending: _isAscending,
            onSortChanged: (sortBy, isAscending) {
              setState(() {
                _sortBy = sortBy;
                _isAscending = isAscending;
              });
            },
          ),

          const Divider(),

          // Word count and expand/collapse all button
          if (!_isLoading && _filteredWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredWords.length} ${_filteredWords.length == 1 ? 'word' : 'words'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      ' (filtered from ${_allWords.length})',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  // Expand/collapse all button
                  TextButton.icon(
                    onPressed: _toggleExpandCollapseAll,
                    icon: Icon(
                      _areAllSongsExpanded() ? Icons.unfold_less : Icons.unfold_more,
                      size: 18,
                    ),
                    label: Text(_areAllSongsExpanded() ? 'Collapse all' : 'Expand all'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          // Words list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.bookmark_border,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No words found'
                                  : 'No highlighted words yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Highlight words in lyrics to add them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildGroupedView(),
          ),
        ],
      ),
    );
  }
}
