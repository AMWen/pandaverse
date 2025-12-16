# PandaVerse App

A simple mobile app built with Flutter for learning Chinese through song lyrics. Meant to be a no-frills, offline app, not requiring creation or access to any accounts.

This app displays Chinese song lyrics with synchronized pinyin annotations, allows tap-to-translate for individual characters and words, lets you highlight vocabulary to review later, and intelligently wraps text to keep pinyin aligned with their corresponding characters across multiple lines.

## Features

### Lyrics & Translation
- **Synchronized Pinyin-Chinese Display**: Intelligent text wrapping that keeps pinyin aligned directly above their corresponding Chinese characters
  - **Multi-line wrapping**: When lyrics wrap to multiple lines, pinyin automatically wraps at the same positions
  - **Smart alignment**: Accounts for different text widths between pinyin and Chinese characters to prevent overflow
  - **1:1 character mapping**: Each Chinese character, space, and punctuation mark has a corresponding pinyin entry
- **Tap-to-Translate**: Touch any Chinese character to see its translation
  - **Word detection**: Dictionary-based greedy algorithm finds multi-character words at the tap position
  - **Dictionary lookup**: Shows word definitions with pinyin pronunciation (tone marks like nǐ hǎo)
  - **Smart positioning**: Translation overlay positions itself above or below the character to stay on screen
  - **Seamless switching**: Tap another character to instantly switch translations, or tap outside to dismiss
- **Character Script Toggle**: Switch between Traditional and Simplified Chinese characters on the fly
- **Tone-colored Pinyin**: Pinyin syllables are color-coded by tone for easier pronunciation learning
  - Tone 1 (flat): Red
  - Tone 2 (rising): Orange
  - Tone 3 (falling-rising): Green
  - Tone 4 (falling): Blue
  - Neutral tone: Gray

### Vocabulary Learning
- **Word Highlighting**: Highlight words while reading lyrics to save them for review
  - **One-tap highlighting**: Tap the highlighter icon in the translation overlay to save words
  - **Visual feedback**: Highlighted words show with Font Awesome highlighter/eraser icons
  - **Auto-save**: Words are automatically saved to the database with their pinyin
- **Vocabulary Review Screen**: Dedicated screen to review all your highlighted words
  - **Grouped by song**: Words organized by the song they came from
  - **Search**: Search by Chinese text, pinyin (with or without tone marks), definitions, song title, or author
  - **Sort options**: Sort by song title, author, or most recent highlight date
  - **Expand/collapse**: All songs expanded by default, with toggle for each song
  - **Quick navigation**: Tap song header to jump back to that song's lyrics
  - **Remove words**: Delete words from your vocabulary list

### Organization & Navigation
- **Song List**: Browse all your songs with search and sorting
  - **Search**: Find songs by title or author
  - **Sort by**: Title, author, or last viewed date
  - **Auto-refresh**: Song list updates when returning from lyrics (last viewed date changes)
- **Bottom Navigation**: Quick switch between Songs and Vocabulary tabs
- **Offline-first**: All lyrics, pinyin, and dictionary data stored locally for offline access
- **Clean UI**: Minimalist design focused on reading and learning lyrics

## Screenshots
(Screenshots to be added)

## Getting Started

### Prerequisites

- **Flutter** is required to build the app for both Android and iOS. To install Flutter, follow the instructions on the official Flutter website: [Flutter Installation Guide](https://flutter.dev/docs/get-started/install).
- **Android SDK** is needed to develop and run the app on Android devices. The Android SDK is included with Android Studio. Download and install **Android Studio**: [Download Android Studio](https://developer.android.com/studio).
- Once you have Flutter and the required SDKs installed, run `flutter doctor` to check for any missing dependencies and verify your environment setup.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/AMWen/pandaverse.git
   cd pandaverse
    ```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up the dictionary (required for translations):
```bash
# Download the full CC-CEDICT dictionary
cd scripts
python3 download_dictionary.py
cd ..
```

This will download and convert the CC-CEDICT Chinese-English dictionary to JSON format. The dictionary file will be created at `assets/dictionary/cedict.json`.

4. Add sample songs (optional):
```bash
# Add songs to the database
dart scripts/add_song.dart
```

The script will:
- Prompt for song title and artist name
- Search lrclib.net for matching lyrics
- Let you select the correct match
- Download and save the lyrics to the database

5. Set up pre-commit hooks (optional, but recommended for development):
```bash
# Create a virtual environment
python3 -m venv .venv

# Activate the virtual environment
# On macOS/Linux:
source .venv/bin/activate
# On Windows:
# .venv\Scripts\activate

# Install pre-commit
pip install pre-commit

# Install the git hooks
pre-commit install
```

The pre-commit hook will automatically run tests before each commit to ensure database operations work correctly.

6. Once you're ready to release the app, you can generate a release APK or appbundle using the following commands:

For android:
```bash
flutter build apk --release
flutter build appbundle
```

See instructions for [Signing the App for Flutter](https://docs.flutter.dev/deployment/android#sign-the-app) and [Uploading Native Debug Symbols](https://stackoverflow.com/questions/62568757/playstore-error-app-bundle-contains-native-code-and-youve-not-uploaded-debug)

You may also need to remove some files from the bundle if using a MacOS.
```bash
zip -d Archive.zip "__MACOSX*"
```

For iOS (need to create an an iOS Development Certificate in Apple Developer account):
```bash
flutter build ios --release
```

## Project Structure

```bash
lib/
├── data/
│   ├── models/
│   │   ├── song_model.dart                    # Song model with id, title, author
│   │   ├── lyrics_model.dart                  # Lyrics model with song_id and lines
│   │   └── lyric_line_model.dart              # Individual lyric line with Chinese, pinyin
│   ├── services/
│   │   ├── lyrics_db_service.dart             # SQLite database for songs, lyrics, and vocabulary
│   │   ├── database_schema.dart               # Shared database schema definitions
│   │   ├── pinyin_service.dart                # Pinyin generation with lpinyin and tone marks
│   │   ├── dictionary_service.dart            # Dictionary lookup and word segmentation
│   │   └── character_converter.dart           # Traditional/Simplified character conversion
│   ├── widgets/
│   │   ├── lyric_line_widget.dart             # Synchronized pinyin-Chinese text display
│   │   ├── song_card_widget.dart              # Song card display in song list
│   │   ├── sort_chips_widget.dart             # Reusable sort chips with direction toggle
│   │   └── search_bar_widget.dart             # Reusable search bar component
│   └── constants.dart                         # App constants, colors, text styles
├── screens/
│   ├── home_screen.dart                       # Bottom navigation container
│   ├── song_list_screen.dart                  # Main screen showing all songs
│   ├── lyrics_screen.dart                     # Lyrics display with tap-to-translate and highlighting
│   ├── vocabulary_review_screen.dart          # Vocabulary review with search and filtering
│   ├── add_song_dialog.dart                   # Dialog for adding new songs
│   └── onboarding.dart                        # First-time user onboarding screens
└── main.dart
scripts/
├── add_song.dart                              # Script to add songs from lrclib.net
└── download_dictionary.py                     # Script to download CC-CEDICT dictionary
assets/
├── dictionary/
│   └── cedict.json                            # CC-CEDICT dictionary in JSON format
├── images/
│   ├── icon.png
│   └── feature image.png
└── screenshots/
    └── (to be added)
sample_data/
└── pandaverse_lyrics.db                       # Pre-loaded sample lyrics database
pubspec.yaml
```

## Database Structure

### SQLite (Songs, Lyrics, and Vocabulary)
The app uses SQLite to store songs, lyrics, and highlighted vocabulary data with the following schema:

```sql
songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  added_date TEXT NOT NULL,
  last_activity TEXT NOT NULL           -- Updated when song is viewed or words highlighted
)

lyrics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  lyrics_data TEXT NOT NULL,            -- JSON array containing lyric lines with Chinese and pinyin
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
)

play_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  played_at TEXT NOT NULL,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
)

highlighted_words (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  line_index INTEGER NOT NULL,          -- Which line in the lyrics
  start_position INTEGER NOT NULL,      -- Character position where word starts
  end_position INTEGER NOT NULL,        -- Character position where word ends
  word_text TEXT NOT NULL,              -- The Chinese word
  word_pinyin TEXT NOT NULL,            -- Pinyin with tone marks
  created_at TEXT NOT NULL,             -- When the word was highlighted
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
  UNIQUE(song_id, line_index, start_position, end_position)
)
```

### SharedPreferences (User Settings)
User preferences are stored using SharedPreferences:

- **useSimplified** (`bool`): Whether to display Simplified Chinese instead of Traditional Chinese

### Data Format
- **Song**: `{id, title, author, addedDate, lastActivity}`
- **Lyrics**: `{songId, lines: [{lineNumber, traditionalChinese, pinyin}, ...]}`
- **LyricLine**: `{lineNumber, traditionalChinese, pinyin}`
  - Each character, space, and punctuation has a corresponding pinyin entry (space → empty string `""`, punctuation → preserved as-is)
  - Example: "你好 世界" → pinyin split: `["nǐ", "hǎo", "", "shì", "jiè"]`

## How It Works

1. **Adding Songs**: The `scripts/add_song.dart` script fetches lyrics from lrclib.net API and stores them in SQLite database
2. **Pinyin Generation**:
   - Dictionary-based greedy algorithm segments Chinese text into words (longest match first)
   - `lpinyin` package generates pinyin with tone marks (nǐ hǎo style) for each character
   - Combines accurate word boundaries with beautiful tone-marked pinyin
3. **Multi-line Wrapping**: The app uses TextPainter to calculate optimal wrap points, ensuring pinyin and Chinese text wrap at the same positions
4. **Translation**: Tapping a character uses greedy longest-match segmentation to find the word in the CC-CEDICT dictionary
5. **Vocabulary Highlighting**:
   - Words are saved with their position in the lyrics for precise highlighting
   - Auto-syncs when returning from lyrics screen
   - Search supports both pinyin with and without tone marks
6. **Offline**: Everything works offline once songs and dictionary are loaded - all data stored locally

## Acknowledgments

- **[lrclib.net](https://lrclib.net/)** - Community-maintained lyrics database API
- **[CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)** - Free Chinese-English dictionary (licensed under Creative Commons Attribution-ShareAlike 4.0)
- **[lpinyin](https://pub.dev/packages/lpinyin)** - Flutter package for Chinese to pinyin conversion with tone marks
- **[Font Awesome Flutter](https://pub.dev/packages/font_awesome_flutter)** - Font Awesome icon pack for Flutter
- **Wiktionary** - Word frequency lists for dictionary prioritization
