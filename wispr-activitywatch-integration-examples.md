# Wispr Flow + ActivityWatch Integration: Practical Examples

## Real Data Insights

Based on the analysis of your actual data, here are the key insights and integration opportunities:

### 1. **Current State Analysis**

**ActivityWatch is already capturing:**
- Window titles with ticket numbers (e.g., "CA-5006-tracking-events-when-closing-deep-linked-screen")
- Git branch names in Tower (e.g., "feature/CA-3527-ga4-user-properties")
- Application switches with precise timestamps
- Active/idle time through AFK watcher

**Wispr Flow is capturing:**
- Natural language during meetings (Teams standup with 649 words)
- Terminal commands and developer thoughts
- Status updates ("finished", "done", "working on")
- Code review discussions

### 2. **Discovered Patterns**

From your recent activity (June 13, 09:00-09:15):
```
09:05:24 - Wispr: "check that we removed all debug prints... commit is clean... related to the ticket we fixed"
09:07:08 - Wispr: "Helder has created a new ticket"
09:07:15 - Teams Meeting: Discussing "NMO ticket I'm working on... marked for 16.1.0"
09:13:39 - Tower: Working on "CA-3527-ga4-user-properties"
09:13:49 - Tower: Switched to "CA-5006-tracking-events"
```

### 3. **Integration Implementation**

#### A. Wispr Flow Watcher for ActivityWatch

```python
# aw-watcher-wispr/main.py
import time
import sqlite3
from datetime import datetime, timedelta
from aw_core import Event
from aw_client import ActivityWatchClient

class WisprFlowWatcher:
    def __init__(self):
        self.client = ActivityWatchClient("aw-watcher-wispr")
        self.bucket_id = "aw-watcher-wispr_" + self.client.get_info()["hostname"]
        self.client.create_bucket(self.bucket_id, event_type="transcription")
        self.db_path = os.path.expanduser("~/Library/Application Support/Wispr Flow/flow.sqlite")
        self.last_check = datetime.now()
    
    def extract_context(self, text):
        """Extract meaningful context from transcription"""
        context = {
            "has_ticket": False,
            "tickets": [],
            "status": None,
            "category": "general"
        }
        
        # Extract ticket numbers
        import re
        tickets = re.findall(r'\b[A-Z]+-\d+\b', text)
        if tickets:
            context["has_ticket"] = True
            context["tickets"] = tickets
        
        # Detect status updates
        status_keywords = {
            "completed": ["finished", "done", "completed"],
            "in_progress": ["working on", "implementing", "fixing"],
            "blocked": ["blocked", "waiting", "stuck"]
        }
        
        for status, keywords in status_keywords.items():
            if any(keyword in text.lower() for keyword in keywords):
                context["status"] = status
                break
        
        # Categorize by content
        if any(word in text.lower() for word in ["meeting", "standup", "call"]):
            context["category"] = "meeting"
        elif any(word in text.lower() for word in ["review", "pr", "merge"]):
            context["category"] = "code_review"
        elif any(word in text.lower() for word in ["test", "debug", "fix"]):
            context["category"] = "debugging"
            
        return context
    
    def get_new_transcriptions(self):
        """Fetch transcriptions since last check"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = """
        SELECT transcriptEntityId, timestamp, app, formattedText, 
               asrText, duration, numWords
        FROM History
        WHERE timestamp > ?
        ORDER BY timestamp ASC
        """
        
        cursor.execute(query, (self.last_check.isoformat(),))
        transcriptions = cursor.fetchall()
        conn.close()
        
        return transcriptions
    
    def run(self):
        """Main watcher loop"""
        while True:
            try:
                transcriptions = self.get_new_transcriptions()
                
                for trans in transcriptions:
                    trans_id, timestamp, app, formatted, asr, duration, words = trans
                    text = formatted or asr or ""
                    
                    if text:
                        context = self.extract_context(text)
                        
                        event_data = {
                            "app": app,
                            "text": text[:200],  # Truncate for privacy
                            "words": words,
                            "duration": duration,
                            **context
                        }
                        
                        event = Event(
                            timestamp=datetime.fromisoformat(timestamp),
                            duration=duration or 0,
                            data=event_data
                        )
                        
                        self.client.heartbeat(self.bucket_id, event, pulsetime=30)
                
                self.last_check = datetime.now()
                time.sleep(10)  # Check every 10 seconds
                
            except Exception as e:
                print(f"Error: {e}")
                time.sleep(60)
```

#### B. Enhanced Work Session Analyzer

```python
# analyze_work_sessions.py
from aw_client import ActivityWatchClient
from datetime import datetime, timedelta

class WorkSessionAnalyzer:
    def __init__(self):
        self.aw = ActivityWatchClient()
        
    def get_correlated_data(self, start, end):
        """Get all relevant data for time period"""
        
        # Window data
        window_events = self.aw.get_events(
            "aw-watcher-window_" + self.aw.get_info()["hostname"],
            start=start, end=end
        )
        
        # Wispr transcriptions
        wispr_events = self.aw.get_events(
            "aw-watcher-wispr_" + self.aw.get_info()["hostname"],
            start=start, end=end
        )
        
        # AFK status
        afk_events = self.aw.get_events(
            "aw-watcher-afk_" + self.aw.get_info()["hostname"],
            start=start, end=end
        )
        
        return self.correlate_events(window_events, wispr_events, afk_events)
    
    def extract_ticket_from_window(self, title):
        """Extract ticket number from window title"""
        import re
        matches = re.findall(r'\b[A-Z]+-\d+\b', title)
        return matches[0] if matches else None
    
    def correlate_events(self, windows, transcriptions, afk):
        """Correlate events to create enriched work sessions"""
        sessions = []
        current_session = None
        
        # Sort all events by timestamp
        all_events = []
        for w in windows:
            all_events.append(("window", w))
        for t in transcriptions:
            all_events.append(("wispr", t))
        for a in afk:
            all_events.append(("afk", a))
            
        all_events.sort(key=lambda x: x[1]["timestamp"])
        
        for event_type, event in all_events:
            if event_type == "afk" and event["data"]["status"] == "afk":
                # End current session if AFK
                if current_session:
                    sessions.append(current_session)
                    current_session = None
                    
            elif event_type == "window":
                ticket = self.extract_ticket_from_window(
                    event["data"].get("title", "")
                )
                
                if ticket:
                    if not current_session or current_session["ticket"] != ticket:
                        # New ticket, new session
                        if current_session:
                            sessions.append(current_session)
                        
                        current_session = {
                            "ticket": ticket,
                            "start": event["timestamp"],
                            "end": event["timestamp"],
                            "app": event["data"]["app"],
                            "transcriptions": [],
                            "duration": 0
                        }
                    else:
                        # Continue current session
                        current_session["end"] = event["timestamp"]
                        current_session["duration"] += event.get("duration", 0)
                        
            elif event_type == "wispr" and current_session:
                # Add transcription to current session
                current_session["transcriptions"].append({
                    "time": event["timestamp"],
                    "text": event["data"]["text"],
                    "category": event["data"].get("category", "general")
                })
        
        if current_session:
            sessions.append(current_session)
            
        return sessions
    
    def generate_time_report(self, date):
        """Generate daily time tracking report"""
        start = datetime.combine(date, datetime.min.time())
        end = start + timedelta(days=1)
        
        sessions = self.get_correlated_data(start, end)
        
        # Group by ticket
        ticket_time = {}
        for session in sessions:
            ticket = session["ticket"]
            duration = session["duration"]
            
            if ticket not in ticket_time:
                ticket_time[ticket] = {
                    "total_seconds": 0,
                    "transcriptions": [],
                    "apps": set()
                }
            
            ticket_time[ticket]["total_seconds"] += duration
            ticket_time[ticket]["transcriptions"].extend(
                session["transcriptions"]
            )
            ticket_time[ticket]["apps"].add(session["app"])
        
        # Format report
        print(f"\n=== Time Report for {date} ===\n")
        
        total_time = sum(t["total_seconds"] for t in ticket_time.values())
        print(f"Total tracked time: {total_time/3600:.1f} hours\n")
        
        for ticket, data in sorted(ticket_time.items()):
            hours = data["total_seconds"] / 3600
            print(f"{ticket}: {hours:.2f} hours")
            print(f"  Apps: {', '.join(data['apps'])}")
            
            # Show key transcriptions
            key_trans = [t for t in data["transcriptions"] 
                        if t["category"] != "general"]
            if key_trans:
                print("  Key activities:")
                for t in key_trans[:3]:
                    print(f"    - {t['text'][:60]}...")
            print()
```

#### C. Real-time Dashboard Integration

```javascript
// dashboard-widget.js
class WisprActivityWidget {
    constructor() {
        this.awClient = new ActivityWatchClient();
        this.updateInterval = 5000; // 5 seconds
    }
    
    async getCurrentContext() {
        const now = new Date();
        const fiveMinAgo = new Date(now - 5 * 60 * 1000);
        
        // Get recent window and wispr events
        const [windowEvents, wisprEvents] = await Promise.all([
            this.awClient.getEvents('aw-watcher-window', fiveMinAgo, now),
            this.awClient.getEvents('aw-watcher-wispr', fiveMinAgo, now)
        ]);
        
        // Extract current ticket from window title
        const currentWindow = windowEvents[0];
        const ticketMatch = currentWindow?.data?.title?.match(/\b[A-Z]+-\d+\b/);
        const currentTicket = ticketMatch ? ticketMatch[0] : null;
        
        // Get last transcription
        const lastTranscription = wisprEvents[0];
        
        return {
            ticket: currentTicket,
            app: currentWindow?.data?.app,
            lastWords: lastTranscription?.data?.text,
            category: lastTranscription?.data?.category
        };
    }
    
    render() {
        const context = await this.getCurrentContext();
        
        return `
            <div class="wispr-activity-widget">
                <h3>Current Context</h3>
                ${context.ticket ? 
                    `<div class="ticket">Working on: ${context.ticket}</div>` : 
                    '<div class="no-ticket">No ticket detected</div>'
                }
                <div class="app">App: ${context.app || 'Unknown'}</div>
                ${context.lastWords ? 
                    `<div class="transcription">
                        <span class="category">${context.category}:</span>
                        "${context.lastWords}"
                    </div>` : ''
                }
            </div>
        `;
    }
}
```

## 4. **Key Benefits of Integration**

1. **Automatic Context**: No need to manually specify tickets - they're extracted from window titles
2. **Rich Annotations**: Meeting transcriptions provide context for time entries
3. **Natural Language**: Status updates in natural speech enhance time logs
4. **Zero Friction**: Works with existing workflow, no behavior change needed

## 5. **Privacy-Preserving Features**

- Store only first 200 characters of transcriptions
- Local processing only
- Configurable text filtering
- Separate buckets for easy data management
- Optional aggregation-only mode

## 6. **Quick Start Guide**

```bash
# 1. Install the Wispr watcher
git clone https://github.com/yourusername/aw-watcher-wispr
cd aw-watcher-wispr
pip install -r requirements.txt

# 2. Configure privacy settings
echo '{
  "max_text_length": 200,
  "excluded_apps": ["1Password", "Messages"],
  "aggregate_only": false
}' > config.json

# 3. Run the watcher
python main.py

# 4. View in ActivityWatch dashboard
open http://localhost:5600
```

## Next Steps

1. Implement the basic Wispr Flow watcher
2. Test correlation accuracy with your actual workflow
3. Build daily/weekly time reports
4. Create Raycast extension for quick time summaries
5. Set up automated time entry exports