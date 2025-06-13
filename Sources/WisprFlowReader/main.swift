import Foundation
import SQLite
import ArgumentParser

@main
struct WisprFlowReader: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wispr-flow-reader",
        abstract: "Query and analyze Wispr Flow transcriptions",
        subcommands: [List.self, Search.self, Export.self, Stats.self]
    )
}

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
                print("Date: \(transcription.timestamp)")
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
                print("Date: \(transcription.timestamp)")
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
            encoder.dateEncodingStrategy = .iso8601
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
                Date: \(t.timestamp)
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
    let timestamp: Date
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
    private let timestamp = Expression<Date>("timestamp")
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
                transcriptEntityId: row[id],
                asrText: row[asrText],
                formattedText: row[formattedText],
                editedText: row[editedText],
                timestamp: row[timestamp],
                app: row[app],
                url: row[url],
                shareType: row[shareType],
                status: row[status],
                language: row[language],
                duration: row[duration],
                numWords: row[numWords]
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
                transcriptEntityId: row[id],
                asrText: row[asrText],
                formattedText: row[formattedText],
                editedText: row[editedText],
                timestamp: row[timestamp],
                app: row[app],
                url: row[url],
                shareType: row[shareType],
                status: row[status],
                language: row[language],
                duration: row[duration],
                numWords: row[numWords]
            )
        }
    }
    
    func exportTranscriptions(startDate: String? = nil, endDate: String? = nil) throws -> [Transcription] {
        var query = historyTable.order(timestamp.desc)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let startDate = startDate, let date = formatter.date(from: startDate) {
            query = query.filter(timestamp >= date)
        }
        
        if let endDate = endDate, let date = formatter.date(from: endDate) {
            let nextDay = date.addingTimeInterval(86400) // Add one day
            query = query.filter(timestamp < nextDay)
        }
        
        return try db.prepare(query).map { row in
            Transcription(
                transcriptEntityId: row[id],
                asrText: row[asrText],
                formattedText: row[formattedText],
                editedText: row[editedText],
                timestamp: row[timestamp],
                app: row[app],
                url: row[url],
                shareType: row[shareType],
                status: row[status],
                language: row[language],
                duration: row[duration],
                numWords: row[numWords]
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
            totalWords += row[numWords] ?? 0
            totalDuration += row[duration] ?? 0
            
            if let app = row[app] {
                appCounts[app, default: 0] += 1
            }
            
            let period = formatter.string(from: row[timestamp])
            periodCounts[period, default: 0] += 1
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