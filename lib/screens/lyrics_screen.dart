import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/constants.dart';
import '../data/models/song_model.dart';
import '../data/models/lyrics_model.dart';
import '../data/models/lyric_line_model.dart';
import '../data/services/lyrics_db_service.dart';
import '../data/services/dictionary_service.dart';
import '../data/services/character_converter.dart';
import '../data/widgets/lyric_line_widget.dart';

class LyricsScreen extends StatefulWidget {
  final Song song;

  const LyricsScreen({
    super.key,
    required this.song,
  });

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  Lyrics? _lyrics;
  bool _isLoading = true;
  bool _useSimplified = false;
  OverlayEntry? _overlayEntry;
  bool _overlayActive = false;
  int? _currentLineIndex;
  int? _currentStart;
  int? _currentEnd;
  Set<String> _highlightedWords = {}; // Set of "lineIndex:start:end" strings

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    _loadHighlightedWords();
  }

  Future<void> _loadHighlightedWords() async {
    final highlights = await LyricsDB.getHighlightedWordsForSong(widget.song.id);
    if (mounted) {
      setState(() {
        _highlightedWords = highlights
            .map((h) => '${h['line_index']}:${h['start_position']}:${h['end_position']}')
            .toSet();
      });
    }
  }

  @override
  void dispose() {
    // Mark overlay as inactive first to prevent any pending updates
    _overlayActive = false;
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _overlayActive = false;
    // Clear tracking variables without setState - they'll be set again when needed
    // and we don't want to trigger rebuilds during disposal
    _currentLineIndex = null;
    _currentStart = null;
    _currentEnd = null;
  }

  Future<void> _loadLyrics() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    // Initialize character converter
    CharacterConverter.initialize();

    // Load character script preference
    final prefs = await SharedPreferences.getInstance();
    _useSimplified = prefs.getBool('useSimplified') ?? false;

    // Load lyrics from database
    final lyrics = await LyricsDB.getLyricsBySongId(widget.song.id);

    if (mounted) {
      setState(() {
        _lyrics = lyrics;
        _isLoading = false;
      });
    }

    // Update last activity timestamp for this song
    await LyricsDB.updateLastActivity(widget.song.id);
  }

  Future<void> _toggleCharacterScript() async {
    if (mounted) {
      setState(() {
        _useSimplified = !_useSimplified;
      });
    }

    // Save preference to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSimplified', _useSimplified);
  }

  String _makeWordKey(int lineIndex, int start, int end) {
    return '$lineIndex:$start:$end';
  }

  bool _isCurrentWordHighlighted() {
    if (_currentLineIndex == null || _currentStart == null || _currentEnd == null) {
      return false;
    }
    final key = _makeWordKey(_currentLineIndex!, _currentStart!, _currentEnd!);
    return _highlightedWords.contains(key);
  }

  Future<void> _toggleCurrentWordHighlight() async {
    if (_currentLineIndex == null || _currentStart == null || _currentEnd == null || _lyrics == null) {
      return;
    }

    final lineIndex = _currentLineIndex!;
    final start = _currentStart!;
    final end = _currentEnd!;
    final key = _makeWordKey(lineIndex, start, end);

    // Get the line text and extract word
    final line = _lyrics!.lines[lineIndex];
    final displayText = _useSimplified
        ? CharacterConverter.toSimplified(line.traditionalChinese)
        : line.traditionalChinese;
    final wordText = displayText.substring(start, end);

    // Get pinyin for this word
    final pinyinSyllables = line.pinyin.split(' ');
    final wordPinyin = pinyinSyllables.skip(start).take(end - start).join(' ');

    if (mounted) {
      setState(() {
        if (_highlightedWords.contains(key)) {
          _highlightedWords.remove(key);
        } else {
          _highlightedWords.add(key);
        }
      });
    }

    // Save to database
    if (_highlightedWords.contains(key)) {
      await LyricsDB.insertHighlightedWord(
        songId: widget.song.id,
        lineIndex: lineIndex,
        startPosition: start,
        endPosition: end,
        wordText: wordText,
        wordPinyin: wordPinyin,
      );
    } else {
      await LyricsDB.deleteHighlightedWord(
        songId: widget.song.id,
        lineIndex: lineIndex,
        startPosition: start,
        endPosition: end,
      );
    }
  }

  void _showTranslation(BuildContext context, String line, int tapIndex, Offset globalPosition, Rect? characterBox, int lineIndex) {
    // Remove existing overlay first
    _removeOverlay();

    final wordMatch = DictionaryService.findWordMatchAtPosition(line, tapIndex);

    if (wordMatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation not found'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    final entry = wordMatch.entry;

    // Update current word tracking
    if (mounted) {
      setState(() {
        _currentLineIndex = lineIndex;
        _currentStart = wordMatch.startIndex;
        _currentEnd = wordMatch.endIndex;
      });
    }

    // Get screen size for positioning
    final screenSize = MediaQuery.of(context).size;
    const tooltipWidth = 280.0;
    const tooltipMaxHeight = 350.0;
    const padding = 16.0;

    // Calculate actual tooltip height based on content
    const headerHeight = 52.0; // Header with padding (8px * 2 + ~24pt*1.5 content)
    const containerPadding = 20.0; // ScrollView padding (10px * 2)

    // Measure actual height of definitions with text wrapping
    double definitionsHeight = 0;
    const definitionSpacing = 4.0; // Spacing between definitions
    for (int i = 0; i < entry.definitions.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}. ${entry.definitions[i]}',
          style: const TextStyle(fontSize: 14, height: 1.3), // Add line height
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      textPainter.layout(maxWidth: tooltipWidth - 24); // Account for padding
      definitionsHeight += textPainter.height + definitionSpacing;
    }

    final estimatedHeight = (headerHeight + definitionsHeight + containerPadding)
        .clamp(0.0, tooltipMaxHeight);

    // Calculate position based on character box if available, otherwise use tap position
    double left = (characterBox?.center.dx ?? globalPosition.dx) - tooltipWidth / 2;
    double top;

    // Check if there's enough space below the character
    if (characterBox != null && characterBox.bottom + estimatedHeight + padding < screenSize.height) {
      // Show below: align top of tooltip with bottom of character
      top = characterBox.bottom + 4;
    } else if (characterBox != null) {
      // Show above: align bottom of tooltip with top of character
      top = characterBox.top - estimatedHeight - 4;
    } else {
      // Fallback to tap position
      top = globalPosition.dy + 20;
      if (top + estimatedHeight > screenSize.height - padding) {
        top = globalPosition.dy - estimatedHeight - 20;
      }
    }

    // Keep tooltip on screen horizontally
    if (left < padding) {
      left = padding;
    } else if (left + tooltipWidth > screenSize.width - padding) {
      left = screenSize.width - tooltipWidth - padding;
    }

    // Make sure it doesn't go off the top of the screen
    if (top < padding) {
      top = padding;
    }

    // Create overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setOverlayState) => Stack(
          children: [
            // Positioned tooltip near tap
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _removeOverlay, // Tap on tooltip to dismiss
                  child: Container(
                  width: tooltipWidth,
                  constraints: const BoxConstraints(maxHeight: tooltipMaxHeight),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    entry.traditional,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      entry.pinyin,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: FaIcon(
                                _isCurrentWordHighlighted() ? FontAwesomeIcons.eraser : FontAwesomeIcons.highlighter,
                                size: 18,
                              ),
                              onPressed: () {
                                // Save to database (fire-and-forget)
                                _toggleCurrentWordHighlight();

                                // Update overlay UI to reflect the change
                                if (_overlayActive && mounted) {
                                  try {
                                    setOverlayState(() {});
                                  } catch (e) {
                                    // Overlay may have been disposed, ignore
                                  }
                                }
                              },
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              tooltip: _isCurrentWordHighlighted() ? 'Remove highlight' : 'Highlight word',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Definitions
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: entry.definitions.asMap().entries.map((e) {
                              return Text(
                                '${e.key + 1}. ${e.value}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );

    // Show overlay
    _overlayActive = true;
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.song.title, style: const TextStyle(fontSize: 20)),
            Text(
              widget.song.author,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lyrics == null || _lyrics!.lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No lyrics found',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // Dismiss overlay when tapping empty space
                    // Character taps will be handled by their GestureDetectors before this
                    _removeOverlay();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lyrics!.lines.length,
                    itemBuilder: (context, index) {
                      final line = _lyrics!.lines[index];
                      // Convert to simplified if preference is set
                      final displayText = _useSimplified
                          ? CharacterConverter.toSimplified(line.traditionalChinese)
                          : line.traditionalChinese;

                      // Create a modified line for display
                      final displayLine = LyricLine(
                        lineNumber: line.lineNumber,
                        traditionalChinese: displayText,
                        pinyin: line.pinyin,
                      );

                      // Get all highlighted word ranges for this line
                      final lineHighlights = <Map<String, int>>[];
                      for (final key in _highlightedWords) {
                        final parts = key.split(':');
                        if (parts.length == 3) {
                          final lineIdx = int.tryParse(parts[0]);
                          final start = int.tryParse(parts[1]);
                          final end = int.tryParse(parts[2]);
                          if (lineIdx == index && start != null && end != null) {
                            lineHighlights.add({'start': start, 'end': end});
                          }
                        }
                      }

                      return LyricLineWidget(
                        line: displayLine,
                        onTap: (tapIndex, globalPosition, characterBox) => _showTranslation(context, displayText, tapIndex, globalPosition, characterBox, index),
                        showDebugOverlay: false,  // param to adjust for debugging
                        highlightedRanges: lineHighlights,
                      );
                    },
                  ),
                ),
    );
  }
}
