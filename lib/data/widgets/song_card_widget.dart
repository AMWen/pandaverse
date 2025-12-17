import 'package:flutter/material.dart';
import '../models/song_model.dart';

class SongCardWidget extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final String? displayTitle;
  final String? displayAuthor;
  final bool isGeneratingPinyin;

  const SongCardWidget({
    super.key,
    required this.song,
    required this.onTap,
    this.displayTitle,
    this.displayAuthor,
    this.isGeneratingPinyin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 2,
      child: InkWell(
        onTap: isGeneratingPinyin ? null : onTap, // Disable tap while generating
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isGeneratingPinyin ? 0.6 : 1.0, // Dim when generating
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  size: 40,
                  color: isGeneratingPinyin ? Colors.grey : Colors.blue,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle ?? song.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isGeneratingPinyin)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Generating pinyin (app may be slower)...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          displayAuthor ?? song.author,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: isGeneratingPinyin ? Colors.grey[400] : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
