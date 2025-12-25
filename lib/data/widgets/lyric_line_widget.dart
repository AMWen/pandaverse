import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/lyric_line_model.dart';
import '../constants.dart';

class LyricLineWidget extends StatefulWidget {
  final LyricLine line;
  final Function(int tapIndex, Offset globalPosition, Rect? characterBox) onTap;
  final bool showDebugOverlay;
  final List<Map<String, int>> highlightedRanges; // List of {start, end} maps
  final bool enableTap; // Whether to enable character-level tap handling

  const LyricLineWidget({
    super.key,
    required this.line,
    required this.onTap,
    this.showDebugOverlay = false,
    this.highlightedRanges = const [],
    this.enableTap = true,
  });

  @override
  State<LyricLineWidget> createState() => _LyricLineWidgetState();

  /// Detect the tone of a pinyin syllable and return the appropriate color
  static Color _getToneColor(String syllable) {
    // Tone 1: flat tone (ā, ē, ī, ō, ū, ǖ)
    if (syllable.contains(RegExp(r'[āēīōūǖĀĒĪŌŪǕ]'))) {
      return PinyinToneColors.tone1;
    }//
    // Tone 2: rising tone (á, é, í, ó, ú, ǘ)
    if (syllable.contains(RegExp(r'[áéíóúǘÁÉÍÓÚǗ]'))) {
      return PinyinToneColors.tone2;
    }
    // Tone 3: falling-rising tone (ǎ, ě, ǐ, ǒ, ǔ, ǚ)
    if (syllable.contains(RegExp(r'[ǎěǐǒǔǚǍĚǏǑǓǙ]'))) {
      return PinyinToneColors.tone3;
    }
    // Tone 4: falling tone (à, è, ì, ò, ù, ǜ)
    if (syllable.contains(RegExp(r'[àèìòùǜÀÈÌÒÙǛ]'))) {
      return PinyinToneColors.tone4;
    }
    // Neutral tone or no tone marker
    return PinyinToneColors.neutral;
  }

  /// Convert pinyin string to colored TextSpan
  static List<TextSpan> _colorPinyin(String pinyin) {
    final spans = <TextSpan>[];
    final syllables = pinyin.split(' ');

    for (int i = 0; i < syllables.length; i++) {
      final syllable = syllables[i];

      if (syllable.isEmpty) {
        // Empty syllable represents a space in the original text
        spans.add(const TextSpan(text: ' '));
      } else {
        spans.add(TextSpan(
          text: syllable,
          style: TextStyle(color: _getToneColor(syllable)),
        ));
      }

      // Add space after syllable (except last one)
      if (i < syllables.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return spans;
  }

}

class _LyricLineWidgetState extends State<LyricLineWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _SynchronizedPinyinText(
            text: widget.line.traditionalChinese,
            pinyin: widget.line.pinyin,
            maxWidth: constraints.maxWidth,  // padding should be accounted for
            showDebugOverlay: widget.showDebugOverlay,
            onTap: widget.onTap,
            highlightedRanges: widget.highlightedRanges,
            enableTap: widget.enableTap,
          );
        },
      ),
    );
  }
}

/// Widget that synchronizes pinyin and Chinese text wrapping
class _SynchronizedPinyinText extends StatefulWidget {
  final String text;
  final String pinyin;
  final double maxWidth;
  final bool showDebugOverlay;
  final Function(int tapIndex, Offset globalPosition, Rect? characterBox) onTap;
  final List<Map<String, int>> highlightedRanges;
  final bool enableTap;

  const _SynchronizedPinyinText({
    required this.text,
    required this.pinyin,
    required this.maxWidth,
    required this.showDebugOverlay,
    required this.onTap,
    required this.highlightedRanges,
    required this.enableTap,
  });

  @override
  State<_SynchronizedPinyinText> createState() => _SynchronizedPinyinTextState();
}

class _SynchronizedPinyinTextState extends State<_SynchronizedPinyinText> {

  /// Find wrap points for Chinese text that also work for pinyin
  List<int> _findWrapPoints() {
    if (widget.text.isEmpty || widget.pinyin.isEmpty) return [];

    final pinyinSyllables = widget.pinyin.split(' ');

    // With 1:1 character-to-syllable correspondence, lengths should match
    if (pinyinSyllables.length != widget.text.length) {
      // Pinyin doesn't match characters, can't synchronize
      return [];
    }

    // Apply multiplier to account for TextPainter width calculation differences
    final pinyinMultiplier = 0.99;
    final charMultiplier = 0.98;

    final wrapPoints = <int>[];
    int currentOffset = 0;

    // Process each line independently
    while (currentOffset < widget.text.length) {
      // Find where Chinese text would wrap from current position
      final remainingText = widget.text.substring(currentOffset);
      final chinesePainter = TextPainter(
        text: TextSpan(text: remainingText, style: chineseTextStyle),
        textDirection: TextDirection.ltr,
      );
      chinesePainter.layout(maxWidth: widget.maxWidth * charMultiplier);

      // Get the first line boundary
      final lineBoundary = chinesePainter.getLineBoundary(const TextPosition(offset: 0));
      int lineEndOffset = currentOffset + lineBoundary.end;

      // Get pinyin for this segment and check if it fits
      // (Do this even if Chinese fits on one line, because pinyin might not)
      final segmentLength = lineEndOffset - currentOffset;
      final segmentPinyin = pinyinSyllables.skip(currentOffset).take(segmentLength).join(' ');

      // Check if pinyin fits on one line with the constrained width
      final pinyinPainter = TextPainter(
        text: TextSpan(text: segmentPinyin, style: const TextStyle(fontSize: pinyinFontSize)),
        textDirection: TextDirection.ltr,
      );
      pinyinPainter.layout(maxWidth: widget.maxWidth * pinyinMultiplier);

      // If pinyin wraps to multiple lines, shorten the segment
      if (pinyinPainter.computeLineMetrics().length > 1) {
        // Find the longest segment where pinyin fits on one line
        bool found = false;
        for (int testLength = segmentLength - 1; testLength > 0; testLength--) {
          final testPinyin = pinyinSyllables.skip(currentOffset).take(testLength).join(' ');
          final testPinyinPainter = TextPainter(
            text: TextSpan(text: testPinyin, style: const TextStyle(fontSize: pinyinFontSize)),
            textDirection: TextDirection.ltr,
          );
          testPinyinPainter.layout(maxWidth: widget.maxWidth * pinyinMultiplier);

          // Check if pinyin fits on one line
          if (testPinyinPainter.computeLineMetrics().length == 1) {
            lineEndOffset = currentOffset + testLength;
            found = true;
            break;
          }
        }

        // If we couldn't find any length that fits, use a minimal segment (1 character)
        // to ensure we make progress and don't get stuck
        if (!found && segmentLength > 1) {
          lineEndOffset = currentOffset + 1;
        }
      }

      // Check if this is the last line (after adjusting for pinyin)
      if (lineEndOffset >= widget.text.length) {
        break; // No more wrap points needed
      }

      // Add this wrap point and move to next line
      wrapPoints.add(lineEndOffset);
      currentOffset = lineEndOffset;
    }

    return wrapPoints;
  }

  Widget _buildPinyinAndText(String pinyin, String text, GlobalKey textKey, int characterOffset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pinyin.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, 3),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: pinyinFontSize,
                  height: 1.0,
                ),
                children: LyricLineWidget._colorPinyin(pinyin),
              ),
            ),
          ),
        if (widget.showDebugOverlay)
          _DebugTextWidget(
            textKey: textKey,
            text: text,
            style: chineseTextStyle,
          )
        else
          _buildHighlightedText(text, textKey, characterOffset),
      ],
    );
  }

  Widget _buildHighlightedText(String text, GlobalKey textKey, int characterOffset) {
    // If no highlighted ranges, just show normal text
    if (widget.highlightedRanges.isEmpty) {
      return Text(
        key: textKey,
        text,
        style: chineseTextStyle,
        strutStyle: StrutStyle.disabled,
      );
    }

    final rowStart = characterOffset;
    final rowEnd = characterOffset + text.length;

    // Find all highlighted ranges that overlap with this row
    final overlappingRanges = <Map<String, int>>[];
    for (final range in widget.highlightedRanges) {
      final start = range['start']!;
      final end = range['end']!;

      // Check if this range overlaps with the current row
      if (!(end <= rowStart || start >= rowEnd)) {
        overlappingRanges.add({
          'start': (start - rowStart).clamp(0, text.length),
          'end': (end - rowStart).clamp(0, text.length),
        });
      }
    }

    // If no overlapping ranges, show normal text
    if (overlappingRanges.isEmpty) {
      return Text(
        key: textKey,
        text,
        style: chineseTextStyle,
        strutStyle: StrutStyle.disabled,
      );
    }

    // Build TextSpan with multiple highlighted sections
    final spans = <TextSpan>[];
    int currentPos = 0;

    // Sort ranges by start position
    overlappingRanges.sort((a, b) => a['start']!.compareTo(b['start']!));

    for (final range in overlappingRanges) {
      final start = range['start']!;
      final end = range['end']!;

      // Add text before this highlight
      if (currentPos < start) {
        spans.add(TextSpan(
          text: text.substring(currentPos, start),
          style: chineseTextStyle,
        ));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: chineseTextStyle.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.4),
          height: 1.2, // Reduce height to make highlighting more compact
        ),
      ));

      currentPos = end;
    }

    // Add remaining text after last highlight
    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: chineseTextStyle,
      ));
    }

    return RichText(
      key: textKey,
      text: TextSpan(children: spans),
      strutStyle: StrutStyle.disabled,
    );
  }

  void _handleTapOnRow(TapDownDetails details, GlobalKey textKey, String rowText, int characterOffset) {
    final renderObject = textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;

    final textBox = renderObject as RenderBox;
    final localPosition = textBox.globalToLocal(details.globalPosition);

    // Find which character box contains the tap
    int? tapIndex;
    Rect? characterBox;

    for (int i = 0; i < rowText.length; i++) {
      final boxes = renderObject.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );

      if (boxes.isNotEmpty) {
        final box = boxes.first;
        if (localPosition.dx >= box.left &&
            localPosition.dx <= box.right &&
            localPosition.dy >= box.top &&
            localPosition.dy <= box.bottom) {
          tapIndex = i + characterOffset; // Add row offset to get global character index
          final localBox = box.toRect();
          final globalTopLeft = textBox.localToGlobal(localBox.topLeft);
          characterBox = Rect.fromLTWH(
            globalTopLeft.dx,
            globalTopLeft.dy,
            localBox.width,
            localBox.height,
          );
          break;
        }
      }
    }

    if (tapIndex == null) return;

    // Ignore taps on spaces and punctuation
    if (tapIndex < widget.text.length) {
      final char = widget.text[tapIndex];
      final isPunctuation = RegExp(r'[\s，。！？：；""''、…—·《》（）【】,.!?:;-]').hasMatch(char);
      if (isPunctuation) {
        return;
      }
    }

    widget.onTap(tapIndex, details.globalPosition, characterBox);
  }

  @override
  Widget build(BuildContext context) {
    final wrapPoints = _findWrapPoints();

    // Build rows (single line is just a list with one element)
    final rows = <Widget>[];
    final pinyinSyllables = widget.pinyin.split(' ');
    int lastPoint = 0;

    for (int i = 0; i <= wrapPoints.length; i++) {
      final endPoint = i < wrapPoints.length ? wrapPoints[i] : widget.text.length;
      final rowText = widget.text.substring(lastPoint, endPoint);
      final rowPinyin = pinyinSyllables.skip(lastPoint).take(endPoint - lastPoint).join(' ');
      final characterOffset = lastPoint;

      // Create a unique key for each row
      final rowKey = GlobalKey();

      final rowWidget = _buildPinyinAndText(rowPinyin, rowText, rowKey, characterOffset);

      rows.add(
        widget.enableTap
            ? GestureDetector(
                onTapDown: (details) => _handleTapOnRow(details, rowKey, rowText, characterOffset),
                child: rowWidget,
              )
            : rowWidget,
      );

      lastPoint = endPoint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

/// Debug widget that shows the text with character boundaries using the actual RenderParagraph
class _DebugTextWidget extends StatelessWidget {
  final GlobalKey textKey;
  final String text;
  final TextStyle style;

  const _DebugTextWidget({
    required this.textKey,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          key: textKey,
          style: style,
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RenderParagraphDebugPainter(
              textKey: textKey,
              text: text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter that uses the actual RenderParagraph from the Text widget
class _RenderParagraphDebugPainter extends CustomPainter {
  final GlobalKey textKey;
  final String text;

  _RenderParagraphDebugPainter({
    required this.textKey,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Get the actual RenderParagraph from the Text widget
    final renderObject = textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;

    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw boxes around each character using the actual rendered positions
    for (int i = 0; i < text.length; i++) {
      final boxes = renderObject.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );

      if (boxes.isNotEmpty) {
        canvas.drawRect(boxes.first.toRect(), paint);

        // Draw character index
        final indexPainter = TextPainter(
          text: TextSpan(
            text: '$i',
            style: const TextStyle(
              fontSize: 8,
              color: Colors.red,
              backgroundColor: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        indexPainter.layout();
        indexPainter.paint(canvas, Offset(boxes.first.left, boxes.first.top - 10));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

