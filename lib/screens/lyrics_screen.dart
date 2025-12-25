import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/constants.dart';
import '../data/models/song_model.dart';
import '../data/models/lyrics_model.dart';
import '../data/models/lyric_line_model.dart';
import '../data/services/lyrics_db_service.dart';
import '../data/services/dictionary_service.dart';
import '../data/services/character_converter.dart';
import '../data/services/pinyin_service.dart';
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
  bool _isEditMode = false;
  final Set<int> _selectedLineNumbers = {}; // Track selected lines for bulk delete
  OverlayEntry? _overlayEntry;
  OverlayEntry? _secondaryOverlayEntry;
  bool _overlayActive = false;
  double? _mainOverlayTop; // Track main overlay vertical position
  int? _currentLineIndex;
  int? _currentStart;
  int? _currentEnd;
  Set<String> _highlightedWords = {}; // Set of "lineIndex:start:end" strings
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _removeSecondaryOverlay();
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
    _mainOverlayTop = null;
  }

  void _removeSecondaryOverlay() {
    if (_secondaryOverlayEntry != null) {
      _secondaryOverlayEntry!.remove();
      _secondaryOverlayEntry = null;
    }
  }

  /// Build a tappable text widget for app bar (title/author)
  Widget _buildTappableAppBarText(String text, TextStyle style) {
    int charIndex = 0;
    return RichText(
      text: TextSpan(
        children: text.characters.map((char) {
          final currentIndex = charIndex;
          charIndex++;
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTapDown: (details) {
                _showTranslation(
                  context,
                  text,
                  currentIndex,
                  details.globalPosition,
                  null, // No character box available for app bar
                  -1, // Not a lyric line
                );
              },
              child: Text(
                char,
                style: style,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build a TextSpan with tappable Chinese characters in definitions
  TextSpan _buildTappableDefinition(String definition, BuildContext context, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'[\u4e00-\u9fff]+'); // Matches Chinese characters
    int lastIndex = 0;

    for (final match in regex.allMatches(definition)) {
      // Add text before the Chinese characters
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: definition.substring(lastIndex, match.start)));
      }

      // Add tappable Chinese characters
      final chineseText = match.group(0)!;
      spans.add(TextSpan(
        text: chineseText,
        style: baseStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        ),
        recognizer: TapGestureRecognizer()
          ..onTapDown = (details) {
            _showCharacterTranslation(context, chineseText, details.globalPosition);
          },
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < definition.length) {
      spans.add(TextSpan(text: definition.substring(lastIndex)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  void _showCharacterTranslation(BuildContext context, String character, Offset globalPosition) {
    // Remove any existing secondary overlay
    _removeSecondaryOverlay();

    // Look up the character in the dictionary
    final wordMatch = DictionaryService.findWordMatchAtPosition(character, 0);
    if (wordMatch == null) {
      return; // No translation found for this character
    }

    final entry = wordMatch.entry;
    final screenSize = MediaQuery.of(context).size;
    const tooltipWidth = 240.0;
    const maxHeight = 250.0;
    const padding = 16.0;
    const mainOverlayWidth = 280.0; // Width of main overlay

    // Try to position to the right of the main overlay
    // Estimate main overlay center position from screen center
    final mainOverlayLeft = (screenSize.width - mainOverlayWidth) / 2;
    final mainOverlayRight = mainOverlayLeft + mainOverlayWidth;

    double left;
    // Align vertically with main overlay if we know its position, otherwise center
    double top = _mainOverlayTop ?? (screenSize.height / 2 - maxHeight / 2);

    // Try right side first
    if (mainOverlayRight + padding + tooltipWidth < screenSize.width - padding) {
      left = mainOverlayRight + padding;
    }
    // Try left side if no space on right
    else if (mainOverlayLeft - padding - tooltipWidth > padding) {
      left = mainOverlayLeft - tooltipWidth - padding;
    }
    // Fallback: center horizontally, offset vertically from main
    else {
      left = (screenSize.width - tooltipWidth) / 2;
      // If main overlay position known, offset below it; otherwise position lower
      if (_mainOverlayTop != null) {
        top = _mainOverlayTop! + 50; // Position below main overlay
      } else {
        top = screenSize.height * 0.65;
      }
    }

    // Keep on screen
    if (top < padding) top = padding;
    if (top + maxHeight > screenSize.height - padding) {
      top = screenSize.height - maxHeight - padding;
    }

    // Create secondary overlay
    _secondaryOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _removeSecondaryOverlay,
            child: Container(
              width: tooltipWidth,
              constraints: const BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
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
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _useSimplified
                              ? CharacterConverter.toSimplified(entry.traditional)
                              : entry.traditional,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            entry.pinyin,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondary.withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Definitions
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entry.definitions.asMap().entries.map((e) {
                          final baseStyle = TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: RichText(
                              text: _buildTappableDefinition(
                                '${e.key + 1}. ${e.value}',
                                context,
                                baseStyle,
                              ),
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
    );

    Overlay.of(context).insert(_secondaryOverlayEntry!);
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

  void _toggleEditMode() {
    // Remove overlay when entering edit mode
    if (!_isEditMode) {
      _removeOverlay();
    }

    setState(() {
      _isEditMode = !_isEditMode;
      // Clear selections when exiting edit mode
      if (!_isEditMode) {
        _selectedLineNumbers.clear();
      }
    });
  }

  void _toggleLineSelection(int lineNumber) {
    setState(() {
      if (_selectedLineNumbers.contains(lineNumber)) {
        _selectedLineNumbers.remove(lineNumber);
      } else {
        _selectedLineNumbers.add(lineNumber);
      }
    });
  }

  Future<void> _bulkDeleteLines() async {
    if (_selectedLineNumbers.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lines', style: TextStyles.dialogTitle),
        content: Text('Are you sure you want to delete ${_selectedLineNumbers.length} line(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Sort line numbers in descending order to delete from bottom to top
      // This prevents issues with renumbering
      final sortedLines = _selectedLineNumbers.toList()..sort((a, b) => b.compareTo(a));

      for (final lineNumber in sortedLines) {
        await LyricsDB.deleteLyricLine(
          songId: widget.song.id,
          lineNumber: lineNumber,
        );
      }

      setState(() {
        _selectedLineNumbers.clear();
      });

      // Reload lyrics and highlighted words
      await _loadLyrics();
      await _loadHighlightedWords();
    }
  }

  Future<void> _deleteLine(int lineNumber) async {
    await LyricsDB.deleteLyricLine(
      songId: widget.song.id,
      lineNumber: lineNumber,
    );

    // Reload lyrics and highlighted words
    await _loadLyrics();
    await _loadHighlightedWords();
  }

  Future<void> _showEditLineDialog(int lineNumber, String currentText) async {
    final textController = TextEditingController(text: currentText);

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Lyrics Line', style: TextStyles.dialogTitle),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Chinese Text',
              border: OutlineInputBorder(),
              helperText: 'Pinyin will be auto-generated',
            ),
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        final newText = textController.text;
        // Convert to traditional Chinese if needed
        final traditionalText = CharacterConverter.toTraditional(newText);
        // Generate pinyin from the traditional text
        final newPinyin = PinyinService.convertLine(traditionalText);

        await LyricsDB.updateLyricLine(
          songId: widget.song.id,
          lineNumber: lineNumber,
          traditionalChinese: traditionalText,
          pinyin: newPinyin,
        );

        // Reload lyrics and highlighted words
        await _loadLyrics();
        await _loadHighlightedWords();
      }
    } finally {
      // Schedule disposal after dialog animation completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        textController.dispose();
      });
    }
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
      // Fallback to tap position (for app bar or when character box not available)
      // Try to show below the tap first
      top = globalPosition.dy + 10;
      if (top + estimatedHeight > screenSize.height - padding) {
        // Not enough space below, show above
        top = globalPosition.dy - estimatedHeight - 8;
      }
      // Keep on screen
      if (top < padding) {
        top = padding;
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

    // Store the main overlay position for secondary overlay alignment
    _mainOverlayTop = top;

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
                  onTap: () {
                    // If secondary overlay exists, only remove that
                    // Otherwise remove both overlays
                    if (_secondaryOverlayEntry != null) {
                      _removeSecondaryOverlay();
                    } else {
                      _removeOverlay();
                    }
                  },
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
                                  // Make each character tappable for individual translation
                                  ...(_useSimplified
                                      ? CharacterConverter.toSimplified(entry.traditional)
                                      : entry.traditional).characters.map((char) => GestureDetector(
                                    onTapDown: (details) {
                                      _showCharacterTranslation(
                                        context,
                                        char,
                                        details.globalPosition,
                                      );
                                    },
                                    child: Text(
                                      char,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        decoration: TextDecoration.underline,
                                        decorationStyle: TextDecorationStyle.dotted,
                                        decorationColor: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  )),
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
                              final baseStyle = TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              );
                              return RichText(
                                text: _buildTappableDefinition(
                                  '${e.key + 1}. ${e.value}',
                                  context,
                                  baseStyle,
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
            _buildTappableAppBarText(
              _useSimplified
                  ? CharacterConverter.toSimplified(widget.song.title)
                  : widget.song.title,
              const TextStyle(fontSize: 20, color: Colors.white),
            ),
            _buildTappableAppBarText(
              _useSimplified
                  ? CharacterConverter.toSimplified(widget.song.author)
                  : widget.song.author,
              const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        actions: [
          // Toggle between simplified and traditional
          if (!_isEditMode || _selectedLineNumbers.isEmpty)
            TextButton(
              onPressed: _toggleCharacterScript,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _useSimplified ? '简' : '繁',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Bulk delete button (shown when items are selected in edit mode)
          if (_isEditMode && _selectedLineNumbers.isNotEmpty)
            IconButton(
              onPressed: _bulkDeleteLines,
              style: IconButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.white,
              ),
              tooltip: 'Delete ${_selectedLineNumbers.length} line(s)',
              icon: const Icon(
                Icons.delete,
                size: 20,
              ),
            ),
          // Toggle edit mode
          IconButton(
            onPressed: _toggleEditMode,
            style: IconButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.white,
            ),
            tooltip: _isEditMode ? 'Done editing' : 'Edit lyrics',
            icon: FaIcon(
              _isEditMode ? FontAwesomeIcons.check : FontAwesomeIcons.penToSquare,
              size: 18,
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
                    // If secondary overlay is showing, only remove that
                    // Otherwise remove the main overlay
                    if (_secondaryOverlayEntry != null) {
                      _removeSecondaryOverlay();
                    } else {
                      _removeOverlay();
                    }
                  },
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    thickness: 6.0,
                    radius: const Radius.circular(3),
                    child: ListView.builder(
                      controller: _scrollController,
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

                      final lyricWidget = LyricLineWidget(
                        line: displayLine,
                        onTap: _isEditMode
                            ? (_, __, ___) {} // Disable character tap in edit mode
                            : (tapIndex, globalPosition, characterBox) => _showTranslation(context, displayText, tapIndex, globalPosition, characterBox, index),
                        showDebugOverlay: false,  // param to adjust for debugging
                        highlightedRanges: lineHighlights,
                      );

                      // Wrap in edit mode UI (checkbox + dismissible)
                      if (_isEditMode) {
                        final isSelected = _selectedLineNumbers.contains(line.lineNumber);

                        return Dismissible(
                          key: Key('${widget.song.id}_${line.lineNumber}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Line', style: TextStyles.dialogTitle),
                                content: const Text('Are you sure you want to delete this line?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            await _deleteLine(line.lineNumber);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox for bulk selection
                              Container(
                                width: 18,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleLineSelection(line.lineNumber),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Lyric line (takes remaining space) - wrapped in GestureDetector for full card tap
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showEditLineDialog(line.lineNumber, line.traditionalChinese),
                                  child: lyricWidget,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return lyricWidget;
                    },
                    ),
                  ),
                ),
    );
  }
}
