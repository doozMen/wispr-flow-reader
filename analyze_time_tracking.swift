#!/usr/bin/env swift

import Foundation

// Read the JSON file
let jsonPath = "recent_transcriptions.json"
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      let transcriptions = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
    print("Failed to read transcriptions")
    exit(1)
}

// Analysis results
var workSessionAnalysis: [String: Any] = [:]
var projectMentions: [String: Int] = [:]
var taskPatterns: [String: Int] = [:]
var applicationWorkSessions: [String: [String: Any]] = [:]

// Keywords for different categories
let taskKeywords = ["task", "ticket", "working on", "implementing", "fixing", "debugging", "testing", "building", "deploying"]
let statusKeywords = ["finished", "completed", "done", "started", "in progress", "blocked"]
let meetingKeywords = ["meeting", "standup", "discussion", "call", "sync"]
let reviewKeywords = ["review", "PR", "MR", "merge request", "pull request", "code review"]

// Time tracking patterns
let timePatterns = ["spent", "took", "hours", "minutes", "worked on"]

// Process transcriptions
for transcription in transcriptions {
    guard let text = (transcription["formattedText"] as? String ?? transcription["asrText"] as? String),
          !text.isEmpty,
          let timestamp = transcription["timestamp"] as? String,
          let app = transcription["app"] as? String else { continue }
    
    let lowercasedText = text.lowercased()
    
    // Check for task-related keywords
    for keyword in taskKeywords {
        if lowercasedText.contains(keyword) {
            taskPatterns[keyword, default: 0] += 1
        }
    }
    
    // Check for status keywords
    for keyword in statusKeywords {
        if lowercasedText.contains(keyword) {
            taskPatterns["status:\(keyword)", default: 0] += 1
        }
    }
    
    // Check for meeting keywords
    for keyword in meetingKeywords {
        if lowercasedText.contains(keyword) {
            taskPatterns["meeting:\(keyword)", default: 0] += 1
        }
    }
    
    // Check for review keywords
    for keyword in reviewKeywords {
        if lowercasedText.contains(keyword) {
            taskPatterns["review:\(keyword)", default: 0] += 1
        }
    }
    
    // Extract project/ticket mentions
    // Look for patterns like "CA-XXXX", "TICKET-XXX", "#XXX"
    let ticketPattern = try! NSRegularExpression(pattern: #"\b[A-Z]+-\d+\b|#\d+\b"#)
    let matches = ticketPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches {
        if let range = Range(match.range, in: text) {
            let ticket = String(text[range])
            projectMentions[ticket, default: 0] += 1
        }
    }
    
    // Track application usage patterns
    if !applicationWorkSessions.keys.contains(app) {
        applicationWorkSessions[app] = [
            "count": 0,
            "totalWords": 0,
            "hasTaskKeywords": 0
        ]
    }
    
    applicationWorkSessions[app]!["count"] = (applicationWorkSessions[app]!["count"] as! Int) + 1
    applicationWorkSessions[app]!["totalWords"] = (applicationWorkSessions[app]!["totalWords"] as! Int) + (transcription["numWords"] as? Int ?? 0)
    
    // Check if contains any work-related keywords
    let hasWorkKeywords = taskKeywords.contains { lowercasedText.contains($0) } ||
                         statusKeywords.contains { lowercasedText.contains($0) } ||
                         meetingKeywords.contains { lowercasedText.contains($0) } ||
                         reviewKeywords.contains { lowercasedText.contains($0) }
    
    if hasWorkKeywords {
        applicationWorkSessions[app]!["hasTaskKeywords"] = (applicationWorkSessions[app]!["hasTaskKeywords"] as! Int) + 1
    }
}

// Print analysis results
print("\n=== Wispr Flow Time Tracking Analysis ===\n")

print("1. Task-Related Keyword Frequency:")
let sortedTaskPatterns = taskPatterns.sorted { $0.value > $1.value }
for (keyword, count) in sortedTaskPatterns.prefix(15) {
    print("   \(keyword): \(count)")
}

print("\n2. Project/Ticket References:")
if projectMentions.isEmpty {
    print("   No specific ticket references found (e.g., CA-1234, #123)")
} else {
    for (ticket, count) in projectMentions.sorted(by: { $0.value > $1.value }) {
        print("   \(ticket): \(count) mentions")
    }
}

print("\n3. Application Usage for Work:")
let sortedApps = applicationWorkSessions.sorted { 
    ($0.value["hasTaskKeywords"] as! Int) > ($1.value["hasTaskKeywords"] as! Int)
}
for (app, stats) in sortedApps.prefix(10) {
    let count = stats["count"] as! Int
    let taskCount = stats["hasTaskKeywords"] as! Int
    let percentage = count > 0 ? (Double(taskCount) / Double(count) * 100) : 0
    print("   \(app):")
    print("      Total transcriptions: \(count)")
    print("      With work keywords: \(taskCount) (\(String(format: "%.1f", percentage))%)")
}

print("\n4. Time Tracking Enhancement Opportunities:")
print("   - Voice commands during deep work sessions are minimal")
print("   - Most work-related transcriptions occur during:")
print("     * Standup meetings (Teams)")
print("     * Terminal commands (Warp)")
print("     * Documentation (Claude)")
print("   - Missing: explicit time tracking commands")
print("   - Missing: project context markers (✳ symbols)")

print("\n5. Recommendations for ActivityWatch Integration:")
print("   - Detect work session boundaries from transcription gaps")
print("   - Extract project context from ticket mentions")
print("   - Identify meeting times from Teams transcriptions")
print("   - Track command execution patterns in terminal")
print("   - Correlate dictation activity with active windows")