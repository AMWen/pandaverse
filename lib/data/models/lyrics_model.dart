import 'dart:convert';
import 'lyric_line_model.dart';

class Lyrics {
  final String songId;
  final List<LyricLine> lines;

  Lyrics({
    required this.songId,
    required this.lines,
  });

  Map<String, dynamic> toJson() {
    return {
      'song_id': songId,
      'lines': lines.map((line) => line.toJson()).toList(),
    };
  }

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      songId: json['song_id'] as String,
      lines: (json['lines'] as List)
          .map((line) => LyricLine.fromJson(line as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory Lyrics.fromJsonString(String jsonString) {
    return Lyrics.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'Lyrics(songId: $songId, lines: ${lines.length})';
  }
}
