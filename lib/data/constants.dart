import 'package:flutter/material.dart';

// Primary colors for the app
const Color primaryColor = Color.fromARGB(255, 3, 78, 140);
Color secondaryColor = Colors.grey[200]!;
Color dullColor = Colors.grey[500]!;

// Action colors for consistent UI feedback
class ActionColors {
  static final Color delete = Colors.red[700]!;
  static const Color error = Colors.red;
}

// Reusable button styles
final primaryButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: primaryColor,
  side: BorderSide(color: primaryColor),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
);

final compactButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: primaryColor,
  side: BorderSide(color: primaryColor),
);

final smallButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
);

// Text styles
class TextStyles {
  static const TextStyle titleText = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
  );

  static TextStyle subtitleText = TextStyle(
    fontSize: 14,
    color: Colors.grey[600],
  );
}

// Lyrics display settings
const double pinyinFontSize = 12.0;
const double chineseFontSize = 20.0;
final Color pinyinColor = Colors.grey[600]!;

// Chinese text style for lyrics
const TextStyle chineseTextStyle = TextStyle(
  fontSize: chineseFontSize,
  color: Colors.black87,
  height: 1.5,
  fontWeight: FontWeight.w500,
);

// Pinyin tone colors
class PinyinToneColors {
  static const Color tone1 = Colors.red;        // Flat tone (ā)
  static const Color tone2 = Colors.orange;     // Rising tone (á)
  static const Color tone3 = Colors.green;      // Falling-rising tone (ǎ)
  static const Color tone4 = Colors.blue;       // Falling tone (à)
  static const Color neutral = Colors.black54;  // Neutral tone
}
