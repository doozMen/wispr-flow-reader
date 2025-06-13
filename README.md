# Wispr Flow Reader

> ⚠️ **Early Stage Software**: This tool is in early development and may have bugs or incomplete features. Use at your own risk.

A command-line tool to query and analyze transcriptions from the [Wispr Flow](https://wispr.com/) voice dictation app database on macOS.

## Features

- List recent transcriptions with filtering options
- Search transcriptions by text content
- Export transcriptions to JSON, CSV, or plain text
- View statistics about your transcription usage
- Filter by application, date range, or sharing status

## Installation

```bash
swift build -c release
cp .build/release/wispr-flow-reader /usr/local/bin/
```

Or run directly:
```bash
swift run wispr-flow-reader
```

## Usage

### List Recent Transcriptions

```bash
# List last 10 transcriptions
wispr-flow-reader list

# List last 20 transcriptions
wispr-flow-reader list --limit 20

# Filter by application
wispr-flow-reader list --app "Xcode"

# Show only shared transcriptions
wispr-flow-reader list --shared-only
```

### Search Transcriptions

```bash
# Search for specific text
wispr-flow-reader search "server-side Swift"

# Limit search results
wispr-flow-reader search "ActivityWatch" --limit 5
```

### Export Transcriptions

```bash
# Export to JSON (default)
wispr-flow-reader export --output transcriptions.json

# Export to CSV
wispr-flow-reader export --format csv --output transcriptions.csv

# Export to plain text
wispr-flow-reader export --format txt --output transcriptions.txt

# Export with date range
wispr-flow-reader export --start-date 2025-06-01 --end-date 2025-06-13
```

### View Statistics

```bash
# Show daily statistics
wispr-flow-reader stats

# Group by week
wispr-flow-reader stats --group-by week

# Group by month
wispr-flow-reader stats --group-by month
```

## Database Location

The tool reads from the Wispr Flow SQLite database located at:
```
~/Library/Application Support/Wispr Flow/flow.sqlite
```

## Requirements

- macOS 15.0+
- Swift 6.1+
- Wispr Flow must be installed with existing transcriptions

## Privacy Note

This tool reads your local Wispr Flow database in read-only mode. It does not modify any data or connect to any external services.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This tool is not affiliated with, endorsed by, or sponsored by Wispr or the Wispr Flow application. It is an independent open-source project for personal use.