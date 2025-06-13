import Foundation
import SQLite
import ArgumentParser

// MARK: - Helper Functions

func parseDate(_ dateString: String) -> Date? {
    // Try with fractional seconds first
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Try format with timezone offset (e.g., "2025-06-03 19:03:31.586 +00:00")
    let timezoneFormatter = DateFormatter()
    timezoneFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
    if let date = timezoneFormatter.date(from: dateString) {
        return date
    }
    
    // Try without milliseconds
    timezoneFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    if let date = timezoneFormatter.date(from: dateString) {
        return date
    }
    
    // Try basic date format
    let basicFormatter = DateFormatter()
    basicFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return basicFormatter.date(from: dateString)
}

func formatTimestamp(_ timestamp: String) -> String {
    // Use the same parsing logic as parseDate
    guard let date = parseDate(timestamp) else {
        return timestamp // Return original if parsing fails
    }
    
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .medium
    displayFormatter.timeZone = TimeZone.current
    
    return displayFormatter.string(from: date)
}

@main
struct WisprFlowReader: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wispr-flow-reader",
        abstract: "Query and analyze voice transcriptions from Wispr Flow and WhisperNotes",
        subcommands: [
            Wispr.self,
            Whisper.self,
            List.self, Search.self, Export.self, Stats.self  // Legacy commands for backward compatibility
        ]
    )
}

// MARK: - Wispr Flow Commands

extension WisprFlowReader {
    struct Wispr: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "wispr",
            abstract: "Commands for Wispr Flow transcriptions",
            subcommands: [WisprList.self, WisprSearch.self, WisprExport.self, WisprStats.self]
        )
    }
    
    struct WisprList: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List Wispr Flow transcriptions")
        
        @Option(name: .shortAndLong, help: "Number of transcriptions to show")
        var limit: Int = 10
        
        @Option(name: .shortAndLong, help: "Filter by application name")
        var app: String?
        
        @Flag(name: .long, help: "Show only shared transcriptions")
        var sharedOnly = false
        
        func run() throws {
            var command = List()
            command.limit = limit
            command.app = app
            command.sharedOnly = sharedOnly
            try command.run()
        }
    }
    
    struct WisprSearch: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "search", abstract: "Search Wispr Flow transcriptions")
        
        @Argument(help: "Search query")
        var query: String
        
        @Option(name: .shortAndLong, help: "Number of results to show")
        var limit: Int = 10
        
        func run() throws {
            var command = Search()
            command.query = query
            command.limit = limit
            try command.run()
        }
    }
    
    struct WisprExport: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "export", abstract: "Export Wispr Flow transcriptions")
        
        @Option(name: .shortAndLong, help: "Output format (json, csv, txt)")
        var format: String = "json"
        
        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?
        
        @Option(name: .long, help: "Start date (YYYY-MM-DD)")
        var startDate: String?
        
        @Option(name: .long, help: "End date (YYYY-MM-DD)")
        var endDate: String?
        
        func run() throws {
            var command = Export()
            command.format = format
            command.output = output
            command.startDate = startDate
            command.endDate = endDate
            try command.run()
        }
    }
    
    struct WisprStats: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "stats", abstract: "Show Wispr Flow statistics")
        
        @Option(name: .long, help: "Group by period (day, week, month)")
        var groupBy: String = "day"
        
        func run() throws {
            var command = Stats()
            command.groupBy = groupBy
            try command.run()
        }
    }
}

// MARK: - WhisperNotes Commands

extension WisprFlowReader {
    struct Whisper: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "whisper",
            abstract: "Commands for WhisperNotes transcriptions",
            subcommands: [WhisperImport.self, WhisperList.self, WhisperSearch.self]
        )
    }
    
    struct WhisperImport: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import WhisperNotes transcriptions from exported files"
        )
        
        @Argument(help: "Path to WhisperNotes export file or directory")
        var path: String
        
        @Option(name: .shortAndLong, help: "Output database path")
        var database: String = "~/.wispr-flow-reader/whisper.db"
        
        func run() throws {
            print("⚠️  WhisperNotes Integration")
            print("\nWhisperNotes uses macOS sandboxing, preventing direct database access.")
            print("\nTo import your transcriptions:")
            print("1. Open WhisperNotes")
            print("2. Export your transcriptions (if the app supports it)")
            print("3. Run: wispr-flow-reader whisper import <export-path>\n")
            print("Note: Full implementation pending based on WhisperNotes export format.")
            
            // TODO: Implement import once we know the export format
            throw WhisperError.notImplemented
        }
    }
    
    struct WhisperList: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List WhisperNotes transcriptions (requires import first)"
        )
        
        @Option(name: .shortAndLong, help: "Number of transcriptions to show")
        var limit: Int = 10
        
        func run() throws {
            print("⚠️  WhisperNotes data not available")
            print("\nPlease import your WhisperNotes transcriptions first:")
            print("wispr-flow-reader whisper import <path-to-exports>\n")
            throw WhisperError.noDataAvailable
        }
    }
    
    struct WhisperSearch: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "search",
            abstract: "Search WhisperNotes transcriptions (requires import first)"
        )
        
        @Argument(help: "Search query")
        var query: String
        
        @Option(name: .shortAndLong, help: "Number of results to show")
        var limit: Int = 10
        
        func run() throws {
            print("⚠️  WhisperNotes data not available")
            print("\nPlease import your WhisperNotes transcriptions first:")
            print("wispr-flow-reader whisper import <path-to-exports>\n")
            throw WhisperError.noDataAvailable
        }
    }
}

// MARK: - Legacy Commands (for backward compatibility)

extension WisprFlowReader {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List recent transcriptions"
        )
        
        @Option(name: .shortAndLong, help: "Number of transcriptions to show")
        var limit: Int = 10
        
        @Option(name: .shortAndLong, help: "Filter by application name")
        var app: String?
        
        @Flag(name: .long, help: "Show only shared transcriptions")
        var sharedOnly = false
        
        func run() throws {
            let reader = try DatabaseReader()
            let transcriptions = try reader.listTranscriptions(
                limit: limit,
                app: app,
                sharedOnly: sharedOnly
            )
            
            for transcription in transcriptions {
                print("\n---")
                print("Date: \(formatTimestamp(transcription.timestamp))")
                print("App: \(transcription.app ?? "Unknown")")
                if let url = transcription.url, !url.isEmpty {
                    print("URL: \(url)")
                }
                print("Words: \(transcription.numWords ?? 0)")
                if transcription.shareType == "yes" {
                    print("Shared: ✓")
                }
                print("\nText:")
                print(transcription.formattedText ?? transcription.asrText ?? "No text")
            }
        }
    }
    
    struct Search: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Search transcriptions by text"
        )
        
        @Argument(help: "Search query")
        var query: String
        
        @Option(name: .shortAndLong, help: "Number of results to show")
        var limit: Int = 10
        
        func run() throws {
            let reader = try DatabaseReader()
            let transcriptions = try reader.searchTranscriptions(query: query, limit: limit)
            
            print("Found \(transcriptions.count) matches for '\(query)':\n")
            
            for transcription in transcriptions {
                print("\n---")
                print("Date: \(formatTimestamp(transcription.timestamp))")
                print("App: \(transcription.app ?? "Unknown")")
                
                let text = transcription.formattedText ?? transcription.asrText ?? ""
                if let range = text.lowercased().range(of: query.lowercased()) {
                    let startIndex = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
                    let endIndex = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
                    let snippet = String(text[startIndex..<endIndex])
                    print("...".appending(snippet).appending("..."))
                }
            }
        }
    }
    
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export transcriptions to various formats"
        )
        
        @Option(name: .shortAndLong, help: "Output format (json, csv, txt)")
        var format: String = "json"
        
        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?
        
        @Option(name: .long, help: "Start date (YYYY-MM-DD)")
        var startDate: String?
        
        @Option(name: .long, help: "End date (YYYY-MM-DD)")
        var endDate: String?
        
        func run() throws {
            let reader = try DatabaseReader()
            let transcriptions = try reader.exportTranscriptions(
                startDate: startDate,
                endDate: endDate
            )
            
            let output = switch format.lowercased() {
            case "csv":
                try exportAsCSV(transcriptions)
            case "txt":
                exportAsText(transcriptions)
            default:
                try exportAsJSON(transcriptions)
            }
            
            if let outputPath = self.output {
                try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
                print("Exported \(transcriptions.count) transcriptions to \(outputPath)")
            } else {
                print(output)
            }
        }
        
        func exportAsJSON(_ transcriptions: [Transcription]) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(transcriptions)
            return String(data: data, encoding: .utf8) ?? ""
        }
        
        func exportAsCSV(_ transcriptions: [Transcription]) throws -> String {
            var csv = "Timestamp,App,URL,Words,Duration,Text\n"
            for t in transcriptions {
                let text = (t.formattedText ?? t.asrText ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\"\(t.timestamp)\",\"\(t.app ?? "")\",\"\(t.url ?? "")\",\(t.numWords ?? 0),\(t.duration ?? 0),\"\(text)\"\n"
            }
            return csv
        }
        
        func exportAsText(_ transcriptions: [Transcription]) -> String {
            transcriptions.map { t in
                """
                Date: \(formatTimestamp(t.timestamp))
                App: \(t.app ?? "Unknown")
                \(t.url.map { "URL: \($0)\n" } ?? "")Words: \(t.numWords ?? 0)
                
                \(t.formattedText ?? t.asrText ?? "No text")
                
                ---
                """
            }.joined(separator: "\n")
        }
    }
    
    struct Stats: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show statistics about transcriptions"
        )
        
        @Option(name: .long, help: "Group by period (day, week, month)")
        var groupBy: String = "day"
        
        func run() throws {
            let reader = try DatabaseReader()
            let stats = try reader.getStatistics(groupBy: groupBy)
            
            print("Wispr Flow Statistics")
            print("====================\n")
            
            print("Overall:")
            print("  Total Transcriptions: \(stats.totalTranscriptions)")
            print("  Total Words: \(stats.totalWords)")
            print("  Total Duration: \(formatDuration(stats.totalDuration))")
            print("  Average WPM: \(String(format: "%.1f", stats.averageWPM))")
            
            print("\nTop Applications:")
            for (app, count) in stats.topApps.prefix(10) {
                print("  \(app): \(count) transcriptions")
            }
            
            print("\nActivity by \(groupBy.capitalized):")
            for (period, count) in stats.activityByPeriod.sorted(by: { $0.key > $1.key }).prefix(10) {
                print("  \(period): \(count) transcriptions")
            }
        }
        
        func formatDuration(_ seconds: Double) -> String {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            let seconds = Int(seconds) % 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m \(seconds)s"
            } else if minutes > 0 {
                return "\(minutes)m \(seconds)s"
            } else {
                return "\(seconds)s"
            }
        }
    }
}

// MARK: - Database Models

struct Transcription: Codable {
    let transcriptEntityId: String
    let asrText: String?
    let formattedText: String?
    let editedText: String?
    let timestamp: String
    let app: String?
    let url: String?
    let shareType: String?
    let status: String?
    let language: String?
    let duration: Double?
    let numWords: Int?
}

struct Statistics {
    let totalTranscriptions: Int
    let totalWords: Int
    let totalDuration: Double
    let averageWPM: Double
    let topApps: [(String, Int)]
    let activityByPeriod: [String: Int]
}

// MARK: - Database Reader

class DatabaseReader {
    private let db: Connection
    private let historyTable = Table("History")
    
    // Column definitions
    private let id = Expression<String>("transcriptEntityId")
    private let asrText = Expression<String?>("asrText")
    private let formattedText = Expression<String?>("formattedText")
    private let editedText = Expression<String?>("editedText")
    private let timestamp = Expression<String>("timestamp")
    private let app = Expression<String?>("app")
    private let url = Expression<String?>("url")
    private let shareType = Expression<String?>("shareType")
    private let status = Expression<String?>("status")
    private let language = Expression<String?>("language")
    private let duration = Expression<Double?>("duration")
    private let numWords = Expression<Int?>("numWords")
    
    init() throws {
        let dbPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Wispr Flow/flow.sqlite")
            .path
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw DatabaseError.databaseNotFound(path: dbPath)
        }
        
        self.db = try Connection(dbPath, readonly: true)
    }
    
    func listTranscriptions(limit: Int, app: String? = nil, sharedOnly: Bool = false) throws -> [Transcription] {
        var query = historyTable.order(timestamp.desc).limit(limit)
        
        if let app = app {
            query = query.filter(self.app == app)
        }
        
        if sharedOnly {
            query = query.filter(shareType == "yes")
        }
        
        return try db.prepare(query).map { row in
            Transcription(
                transcriptEntityId: row[self.id],
                asrText: row[self.asrText],
                formattedText: row[self.formattedText],
                editedText: row[self.editedText],
                timestamp: row[self.timestamp],
                app: row[self.app],
                url: row[self.url],
                shareType: row[self.shareType],
                status: row[self.status],
                language: row[self.language],
                duration: row[self.duration],
                numWords: row[self.numWords]
            )
        }
    }
    
    func searchTranscriptions(query searchQuery: String, limit: Int) throws -> [Transcription] {
        let query = historyTable
            .filter(
                (asrText != nil && asrText.like("%\(searchQuery)%")) ||
                (formattedText != nil && formattedText.like("%\(searchQuery)%")) ||
                (editedText != nil && editedText.like("%\(searchQuery)%"))
            )
            .order(timestamp.desc)
            .limit(limit)
        
        return try db.prepare(query).map { row in
            Transcription(
                transcriptEntityId: row[self.id],
                asrText: row[self.asrText],
                formattedText: row[self.formattedText],
                editedText: row[self.editedText],
                timestamp: row[self.timestamp],
                app: row[self.app],
                url: row[self.url],
                shareType: row[self.shareType],
                status: row[self.status],
                language: row[self.language],
                duration: row[self.duration],
                numWords: row[self.numWords]
            )
        }
    }
    
    func exportTranscriptions(startDate: String? = nil, endDate: String? = nil) throws -> [Transcription] {
        var query = historyTable.order(timestamp.desc)
        
        if let startDate = startDate {
            query = query.filter(timestamp >= startDate)
        }
        
        if let endDate = endDate {
            // Add one day to include the entire end date
            let nextDay = endDate + "T23:59:59"
            query = query.filter(timestamp <= nextDay)
        }
        
        return try db.prepare(query).map { row in
            Transcription(
                transcriptEntityId: row[self.id],
                asrText: row[self.asrText],
                formattedText: row[self.formattedText],
                editedText: row[self.editedText],
                timestamp: row[self.timestamp],
                app: row[self.app],
                url: row[self.url],
                shareType: row[self.shareType],
                status: row[self.status],
                language: row[self.language],
                duration: row[self.duration],
                numWords: row[self.numWords]
            )
        }
    }
    
    func getStatistics(groupBy: String) throws -> Statistics {
        let allTranscriptions = try db.prepare(historyTable)
        
        var totalWords = 0
        var totalDuration = 0.0
        var appCounts: [String: Int] = [:]
        var periodCounts: [String: Int] = [:]
        
        let formatter = DateFormatter()
        formatter.dateFormat = switch groupBy {
        case "month": "yyyy-MM"
        case "week": "yyyy-'W'ww"
        default: "yyyy-MM-dd"
        }
        
        var transcriptionCount = 0
        for row in allTranscriptions {
            transcriptionCount += 1
            totalWords += row[self.numWords] ?? 0
            totalDuration += row[self.duration] ?? 0
            
            if let app = row[self.app] {
                appCounts[app, default: 0] += 1
            }
            
            if let date = parseDate(row[self.timestamp]) {
                let period = formatter.string(from: date)
                periodCounts[period, default: 0] += 1
            }
        }
        
        let averageWPM = totalDuration > 0 ? (Double(totalWords) / totalDuration) * 60 : 0
        
        let topApps = appCounts.sorted { $0.value > $1.value }
        
        return Statistics(
            totalTranscriptions: transcriptionCount,
            totalWords: totalWords,
            totalDuration: totalDuration,
            averageWPM: averageWPM,
            topApps: topApps,
            activityByPeriod: periodCounts
        )
    }
}

// MARK: - Errors

enum DatabaseError: Error, LocalizedError {
    case databaseNotFound(path: String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "Wispr Flow database not found at: \(path)"
        }
    }
}

enum WhisperError: Error, LocalizedError {
    case notImplemented
    case noDataAvailable
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "WhisperNotes integration is not yet implemented"
        case .noDataAvailable:
            return "No WhisperNotes data available. Please import first."
        }
    }
}