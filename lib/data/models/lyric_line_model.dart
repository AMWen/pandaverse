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

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      lineNumber: json['line_number'] as int,
      traditionalChinese: json['traditional_chinese'] as String,
      pinyin: json['pinyin'] as String,
    );
  }

  @override
  String toString() {
    return 'LyricLine($lineNumber: $traditionalChinese - $pinyin)';
  }
}
