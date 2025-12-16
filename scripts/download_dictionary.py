#!/usr/bin/env python3
"""
Download and convert CC-CEDICT dictionary to JSON format.
Adds character frequency data from wiktionary frequency list.
"""

import json
import gzip
import os
import sys
import subprocess
import re

# Configuration
CEDICT_URL = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz"
FREQUENCY_URLS = [
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/1-1000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/1001-2000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/2001-3000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/3001-4000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/4001-5000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/5001-6000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/6001-7000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/7001-8000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/8001-9000",
    "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists/9001-10000",
]
OUTPUT_FILE = "../assets/dictionary/cedict.json"
MAX_ENTRIES = None  # None = get all entries (full dictionary)

def download_frequency_lists():
    """Download and parse word frequency lists from Wiktionary"""
    print(f"\nDownloading word frequency lists from Wiktionary...")

    # Maps traditional word -> frequency rank (lower rank = more common)
    frequency_map = {}

    for i, url in enumerate(FREQUENCY_URLS):
        try:
            print(f"  Fetching {url}...")

            # Use curl to download (avoids SSL issues)
            temp_file = f"freq_temp_{i}.html"
            subprocess.run(
                ['curl', '-L', '-s', '-o', temp_file, url],
                capture_output=True,
                text=True,
                check=True
            )

            # Read the downloaded file
            with open(temp_file, 'r', encoding='utf-8') as f:
                html = f.read()

            # Clean up temp file
            os.remove(temp_file)

            # Parse Wiktionary table format
            # Looking for rows like: <td>1</td><td>的</td><td>的</td><td>de</td>...
            # or with links: <td>1</td><td><a ...>的</a></td><td><a ...>的</a></td>...

            # Pattern to match table rows with rank, simplified, and traditional
            # More flexible pattern that handles nested tags
            # Captures content between <td> tags, removing any nested HTML
            tr_pattern = r'<tr[^>]*>(.*?)</tr>'
            tr_matches = re.findall(tr_pattern, html, re.DOTALL)

            # Debug: show first few rows from first page
            if i == 0 and len(tr_matches) > 0:
                print(f"\n  DEBUG: Found {len(tr_matches)} table rows")
                print(f"  DEBUG: First row HTML: {tr_matches[0][:200]}...")

            row_count = 0
            for tr_content in tr_matches:
                # Extract all <td> cells from this row
                td_pattern = r'<td[^>]*>(.*?)</td>'
                cells = re.findall(td_pattern, tr_content, re.DOTALL)

                if len(cells) < 2:
                    continue

                # Remove HTML tags from cell contents
                def strip_tags(text):
                    return re.sub(r'<[^>]+>', '', text).strip()

                # Debug: show first data row structure
                if i == 0 and row_count == 0 and cells:
                    print(f"\n  DEBUG: First data row has {len(cells)} cells:")
                    for idx, cell in enumerate(cells[:5]):
                        print(f"    Cell {idx}: {strip_tags(cell)[:50]}")

                row_count += 1

                # Based on the header, columns are: Traditional, Simplified, Pinyin, Meaning
                # The rank is implicit based on row order within each page
                if len(cells) < 2:
                    continue

                traditional = strip_tags(cells[0])
                simplified = strip_tags(cells[1])

                # Skip if cells are empty or invalid
                if not traditional or not simplified:
                    continue

                # Calculate rank based on page number and row number
                # Each page has 1000 words, starting from i*1000 + 1
                rank = (i * 1000) + row_count

                # Debug: show first successfully parsed row from first page
                if i == 0 and row_count == 1:
                    print(f"\n  DEBUG: First parsed row:")
                    print(f"    Rank: {rank}")
                    print(f"    Traditional: {traditional}")
                    print(f"    Simplified: {simplified}")

                # Clean up the text (remove whitespace)
                trad = traditional.strip()
                simp = simplified.strip()

                # Use the rank as frequency (lower rank = higher frequency)
                # Store both traditional and simplified with their rank
                if trad and trad not in frequency_map:
                    frequency_map[trad] = 11000 - rank  # Invert so higher = more common
                if simp and simp not in frequency_map:
                    frequency_map[simp] = 11000 - rank

        except Exception as e:
            print(f"  ⚠ Warning: Could not download {url}: {e}")
            # Clean up temp file if it exists
            if os.path.exists(temp_file):
                os.remove(temp_file)
            continue

    print(f"✓ Loaded {len(frequency_map)} word frequencies")
    return frequency_map

def download_cedict(url, output_file):
    """Download CC-CEDICT file using curl"""
    print(f"Downloading CC-CEDICT from {url}...")
    print("This may take a minute...")

    try:
        # Use curl to avoid SSL issues
        subprocess.run(
            ['curl', '-L', '-o', output_file, url],
            capture_output=True,
            text=True,
            check=True
        )
        print(f"✓ Downloaded to {output_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Error downloading: {e}")
        print(f"Error output: {e.stderr}")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def parse_cedict(filename, frequency_map, max_entries=None):
    """Parse CC-CEDICT file and convert to dictionary"""
    dictionary = {}
    count = 0

    if max_entries:
        print(f"\nParsing CC-CEDICT (keeping up to {max_entries} entries)...")
    else:
        print(f"\nParsing CC-CEDICT (keeping all entries)...")

    with gzip.open(filename, 'rt', encoding='utf-8') as f:
        for line in f:
            # Skip comments
            if line.startswith('#'):
                continue

            # Parse line format: Traditional Simplified [pinyin] /def1/def2/
            try:
                # Split on first [ only to handle definitions containing [ or ]
                parts = line.split('[', 1)
                if len(parts) < 2:
                    continue

                chars = parts[0].strip().split()
                if len(chars) < 2:
                    continue

                traditional = chars[0]
                simplified = chars[1]

                # Split on first ] only to handle definitions containing ]
                pinyin_def = parts[1].split(']', 1)
                if len(pinyin_def) < 2:
                    continue

                pinyin = pinyin_def[0].strip()

                # Extract definitions (between slashes)
                definitions = [d.strip() for d in pinyin_def[1].strip('/').split('/') if d.strip()]

                # Get frequency from the frequency map (word-based)
                # Check both traditional and simplified forms
                frequency = frequency_map.get(traditional) or frequency_map.get(simplified)

                # Use traditional Chinese as the key
                if traditional in dictionary:
                    # Entry already exists - merge definitions
                    existing = dictionary[traditional]

                    # Add pinyin if different
                    if pinyin != existing['pinyin']:
                        existing['pinyin'] = f"{existing['pinyin']}; {pinyin}"

                    # Add separator and append new definitions with pronunciation context
                    existing['definitions'].append(f"[{pinyin}]")
                    existing['definitions'].extend(definitions)

                    # Keep the higher frequency
                    if frequency and (existing['frequency'] is None or frequency > existing['frequency']):
                        existing['frequency'] = frequency
                else:
                    # New entry
                    dictionary[traditional] = {
                        'traditional': traditional,
                        'simplified': simplified,
                        'pinyin': pinyin,
                        'definitions': definitions,
                        'frequency': frequency
                    }

                count += 1

                # Show progress
                if count % 10000 == 0:
                    print(f"  Processed {count:,} entries...")

                # Stop if we've reached max entries
                if max_entries and count >= max_entries:
                    print(f"  Reached limit of {max_entries:,} entries")
                    break

            except Exception as e:
                # Skip malformed lines
                continue

    print(f"✓ Parsed {len(dictionary):,} entries")
    return dictionary

def save_json(dictionary, output_file):
    """Save dictionary to JSON file"""
    print(f"\nSaving to {output_file}...")

    # Get the directory path
    output_dir = os.path.dirname(output_file)

    # Create directory if it doesn't exist
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(dictionary, f, ensure_ascii=False, indent=2)

    # Get file size
    size_bytes = os.path.getsize(output_file)
    size_mb = size_bytes / (1024 * 1024)

    print(f"✓ Saved {len(dictionary):,} entries")
    print(f"✓ File size: {size_mb:.2f} MB")

def main():
    print("=== CC-CEDICT Dictionary Downloader ===\n")

    # Change to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    # Download word frequency lists from Wiktionary
    frequency_map = download_frequency_lists()

    # Download file
    temp_file = "cedict_temp.txt.gz"
    if not download_cedict(CEDICT_URL, temp_file):
        sys.exit(1)

    # Parse dictionary
    try:
        dictionary = parse_cedict(temp_file, frequency_map, max_entries=MAX_ENTRIES)
    except Exception as e:
        print(f"\n✗ Error parsing dictionary: {e}")
        os.remove(temp_file)
        sys.exit(1)

    # Save to JSON
    try:
        save_json(dictionary, OUTPUT_FILE)
    except Exception as e:
        print(f"\n✗ Error saving JSON: {e}")
        os.remove(temp_file)
        sys.exit(1)

    # Clean up
    os.remove(temp_file)
    print("\n✓ Done! Dictionary is ready to use.")
    print("\nNext steps:")
    print("1. Run 'flutter pub get' to update assets")
    print("2. Restart your app to load the new dictionary")

if __name__ == "__main__":
    main()
