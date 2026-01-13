# Shlf iOS 26 - Complete App Documentation

**Version**: 26.0
**Platform**: iOS 17+, watchOS 10+
**Framework**: SwiftUI, SwiftData
**Last Updated**: January 12, 2026

---

## Table of Contents

1. [App Overview](#1-app-overview)
2. [Project Structure](#2-project-structure)
3. [Core Features](#3-core-features)
4. [Data Models](#4-data-models)
5. [Architecture](#5-architecture)
6. [Services](#6-services)
7. [User Interface](#7-user-interface)
8. [Platform-Specific Features](#8-platform-specific-features)
9. [Technical Implementation](#9-technical-implementation)
10. [Configuration & Settings](#10-configuration--settings)
11. [File Reference](#11-file-reference)

---

## 1. App Overview

### 1.1 Purpose

Shlf is a comprehensive book reading tracker application designed for iOS and Apple Watch. The app helps users:

- Track their reading habits and progress
- Set and monitor reading goals
- Maintain a personal library of books
- Log reading sessions with detailed metrics
- Earn achievements through gamification
- Sync data seamlessly across devices
- View detailed statistics and analytics

### 1.2 Target Platforms

| Platform | Minimum Version | Description |
|----------|----------------|-------------|
| iOS | 17.0+ | Main application |
| watchOS | 10.0+ | Companion Apple Watch app |
| iOS Widget | 17.0+ | Home screen widgets |
| Live Activities | 17.0+ | Dynamic Island integration |

### 1.3 Key Technologies

- **SwiftUI**: Declarative UI framework
- **SwiftData**: Modern data persistence (iOS 17+)
- **CloudKit**: Optional iCloud synchronization
- **WatchConnectivity**: iPhone-Watch communication
- **ActivityKit**: Live Activities for Dynamic Island
- **WidgetKit**: Home screen widgets
- **StoreKit**: In-app purchases for Pro features

---

## 2. Project Structure

### 2.1 Target Organization

```
Shlf.xcodeproj
├── Shlf (iOS App)
│   ├── ShlfApp.swift
│   ├── ContentView.swift
│   └── ...
├── ShlfWatch (watchOS App)
│   ├── ShlfWatchApp.swift
│   └── ...
├── ReadingSessionWidget (Widget Extension)
│   ├── ReadingSessionWidgetBundle.swift
│   └── ...
└── ShlfLiveActivityWidget (Live Activity Extension)
    ├── ShlfLiveActivityWidget.swift
    └── ...
```

### 2.2 Directory Structure

```
Shlf/
├── Features/
│   ├── BookDetail/
│   │   ├── BookDetailView.swift
│   │   ├── BookDetailViewModel.swift
│   │   ├── ReadingSessionsListView.swift
│   │   ├── QuotesListView.swift
│   │   └── BookPositionsView.swift
│   ├── Goals/
│   │   ├── GoalsView.swift
│   │   ├── GoalCreationView.swift
│   │   ├── GoalProgressView.swift
│   │   └── GoalsSettingsView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── ReadingPulseCard.swift
│   │   ├── CurrentlyReadingCard.swift
│   │   └── QuickActionsCard.swift
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   ├── LibraryViewModel.swift
│   │   ├── BookListView.swift
│   │   ├── AddBookView.swift
│   │   └── BarcodeScannerView.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingPage.swift
│   │   └── OnboardingCompletionView.swift
│   ├── Pro/
│   │   ├── ProFeaturesView.swift
│   │   ├── ProPaywallView.swift
│   │   └── ProBenefitsView.swift
│   ├── Quotes/
│   │   ├── QuotesView.swift
│   │   ├── QuoteDetailView.swift
│   │   └── QuoteEditorView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── SettingsViewModel.swift
│   │   ├── AppearanceSettingsView.swift
│   │   ├── ReadingSettingsView.swift
│   │   ├── PrivacySettingsView.swift
│   │   ├── DeveloperSettingsView.swift
│   │   └── StreakSettingsView.swift
│   ├── Share/
│   │   ├── ShareSheet.swift
│   │   └── ShareActivityItemSource.swift
│   └── Stats/
│       ├── StatsView.swift
│       ├── StatsViewModel.swift
│       ├── StatsDetailView.swift
│       ├── ReadingHeatmapView.swift
│       ├── ReadingChartsView.swift
│       └── StatsExportView.swift
├── Models/
│   ├── Book.swift
│   ├── ReadingSession.swift
│   ├── UserProfile.swift
│   ├── ReadingGoal.swift
│   ├── Achievement.swift
│   ├── Quote.swift
│   ├── BookPosition.swift
│   ├── ActiveReadingSession.swift
│   ├── StreakEvent.swift
│   └── AppSettings.swift
├── Services/
│   ├── SessionManager.swift
│   ├── GamificationEngine.swift
│   ├── StreakService.swift
│   ├── GoalTracker.swift
│   ├── WatchConnectivityManager.swift
│   ├── ReadingSessionActivityManager.swift
│   ├── BookAPIService.swift
│   ├── ProAccess.swift
│   ├── StoreKitService.swift
│   ├── NotificationManager.swift
│   └── DataExportImportService.swift
├── Shared/
│   ├── Components/
│   │   ├── BookCard.swift
│   │   ├── SessionCard.swift
│   │   ├── StatCard.swift
│   │   ├── AchievementBadge.swift
│   │   ├── ProgressBar.swift
│   │   ├── CustomStepper.swift
│   │   └── CustomSlider.swift
│   ├── DesignSystem/
│   │   ├── Theme.swift
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   ├── Spacing.swift
│   │   └── Shadows.swift
│   ├── Extensions/
│   │   ├── ViewExtensions.swift
│   │   ├── ColorExtensions.swift
│   │   ├── DateExtensions.swift
│   │   ├── ArrayExtensions.swift
│   │   └── OptionalExtensions.swift
│   ├── Helpers/
│   │   ├── ValidationHelper.swift
│   │   ├── DateHelper.swift
│   │   ├── FormatHelper.swift
│   │   └── HapticHelper.swift
│   └── Utilities/
│       ├── Constants.swift
│       ├── AppGroup.swift
│       └── Logger.swift
├── LiveActivities/
│   ├── ReadingSessionLiveActivity.swift
│   ├── ReadingSessionActivityAttributes.swift
│   └── LiveActivityView.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Localizable.xcstrings/
    └── Info.plist
```

---

## 3. Core Features

### 3.1 Book Management

#### 3.1.1 Adding Books

Users can add books through multiple methods:

**Method 1: Barcode Scanner**
- Uses device camera to scan ISBN barcode
- Automatic metadata fetch from book APIs
- Cover image retrieval
- Supported barcode formats: EAN-13, EAN-8, UPC

**Method 2: Manual Entry**
- Text fields for all metadata
- Optional cover image from photo library
- Custom book types support

**Method 3: Online Search**
- Search by title, author, or ISBN
- Browse search results
- One-tap book addition

#### 3.1.2 Book Metadata

Each book stores:
- **Primary**: Title, author(s), ISBN-10/ISBN-13
- **Publication**: Publisher, publication date, language
- **Physical**: Total pages, cover image (URL/Data)
- **Classification**: Genres/subjects, book type
- **Personal**: Reading status, rating, notes
- **Progress**: Current page, percentage complete, last read date

#### 3.1.3 Book Types

| Type | Description | Session Tracking |
|------|-------------|------------------|
| Physical | Traditional print books | Pages |
| eBook | Digital books | Pages/Location |
| Audiobook | Audio format | Minutes/Hours |

#### 3.1.4 Reading Statuses

- **Want to Read**: Books in queue to be read
- **Currently Reading**: Actively being read (max 3)
- **Finished**: Completed reading
- **Did Not Finish**: Started but abandoned

### 3.2 Reading Sessions

#### 3.2.1 Session Creation

**Standard Sessions**
- Start time and end time tracking
- Starting page and ending page
- Duration calculation
- Automatic page difference validation

**Quick Sessions**
- +1 page quick increment
- -1 page quick decrement
- Automatic timestamp
- Useful for small reading updates

**Active Sessions**
- Real-time tracking while reading
- Pause/resume functionality
- Auto-end after configurable inactivity
- Live Activity integration

#### 3.2.2 Session Validation

- End page must be >= start page
- Pages must be within book's total page count
- No duplicate sessions within tolerance window
- Clock skew tolerance for multi-device sync
- Maximum session duration validation

#### 3.2.3 Session Management

- Edit existing sessions
- Delete sessions (bulk available)
- Export sessions to JSON/CSV
- Import sessions from backup
- Session history with filtering

### 3.3 Gamification System

#### 3.3.1 Experience Points (XP)

| Activity | XP Awarded |
|----------|------------|
| Pages read | 1 XP per page |
| Reading session | 1 XP per minute |
| Finishing a book | 100 XP bonus |
| Daily reading goal | 50 XP bonus |
| Achievements | Variable (10-500 XP) |

#### 3.3.2 Leveling System

- **Base formula**: Level = Total XP / 1000
- **Level 1**: 0-999 XP
- **Level 2**: 1000-1999 XP
- **And so on...**

Level milestones trigger achievements and notifications.

#### 3.3.3 Streak System

**Current Streak**
- Consecutive days with reading activity
- Resets after 48 hours of inactivity
- Streak pardon available once every 7 days

**Streak Pardon**
- Activatable within 48 hours after streak break
- 7-day cooldown after use
- Prevents streak reset
- Manual activation in Settings

**Longest Streak**
- Records personal best
- Persistent across app lifetime
- Achievement milestones at 7, 30, 100 days

#### 3.3.4 Achievements

**Book Milestones**
- First Book (10 XP)
- 10 Books Read (100 XP)
- 50 Books Read (500 XP)
- 100 Books Read (1000 XP)

**Page Milestones**
- 100 Pages (50 XP)
- 1,000 Pages (200 XP)
- 10,000 Pages (1000 XP)
- 100,000 Pages (5000 XP)

**Streak Milestones**
- 7 Day Streak (100 XP)
- 30 Day Streak (500 XP)
- 100 Day Streak (2000 XP)

**Level Milestones**
- Level 5 (100 XP)
- Level 10 (200 XP)
- Level 20 (500 XP)

**Special Achievements**
- Speed Reader: 100 pages in one day (200 XP)
- Marathon Reader: 2+ hour reading session (150 XP)
- Night Owl: Reading between 12-4 AM (100 XP)
- Early Bird: Reading between 4-6 AM (100 XP)
- Dedication: 365-day streak (5000 XP)

### 3.4 Goals System

#### 3.4.1 Goal Types

**Books Per Year**
- Target: Number of books to complete in a calendar year
- Progress: Counts finished books
- Reset: Annually on January 1

**Books Per Month**
- Target: Number of books to complete in a month
- Progress: Counts finished books
- Reset: Monthly on 1st

**Pages Per Day**
- Target: Daily page reading goal
- Progress: Pages read today
- Reset: Daily at midnight

**Minutes Per Day**
- Target: Daily reading time goal
- Progress: Minutes read today
- Reset: Daily at midnight

**Reading Streak**
- Target: Maintain active streak for X days
- Progress: Current streak days
- No auto-reset

#### 3.4.2 Goal Configuration

- Custom target values
- Start date customization
- End date (for fixed goals)
- Priority ordering
- Visibility toggles
- Progress notification preferences

#### 3.4.3 Goal Tracking

Real-time progress updates with:
- Visual progress bars
- Percentage completion
- Estimated completion date
- Historical performance
- Streak/freeze days tracking

### 3.5 Statistics and Analytics

#### 3.5.1 Dashboard Metrics

**Lifetime Stats**
- Total books finished
- Total pages read
- Total reading time
- Average pages per session
- Average session duration
- Current level and XP

**Period Stats**
- Books this year/month
- Pages this year/month
- Reading time this year/month
- Active days this month

**Current Trends**
- Current streak
- Longest streak
- XP earned today
- Progress toward daily goals

#### 3.5.2 Visualizations

**Reading Heatmap**
- GitHub-style contribution graph
- Color intensity based on pages read
- Daily granularity
- Year-at-a-glance view
- Tap for day details

**Bar Charts**
- Monthly reading comparison
- Pages per day (last 7/30/90 days)
- Reading time distribution
- Books by genre
- Completion rate over time

**Pie Charts**
- Books by reading status
- Books by type (physical/ebook/audio)
- Achievement completion

#### 3.5.3 Export Options

- Share statistics as image
- Export data as CSV
- Export data as JSON
- Print-friendly format
- Custom date range selection

### 3.6 Notes and Quotes

#### 3.6.1 Book Notes

- Rich text notes per book
- Character limit: 10,000
- Timestamped entries
- Edit history preserved
- Searchable content

#### 3.6.2 Quotes System

**Quote Data**
- Quote text
- Page number
- Book reference
- Personal notes
- Favorite flag
- Date added

**Quote Features**
- Add from book detail view
- Manual page number entry
- Edit and delete
- Mark as favorite
- Share quotes
- Filter by book or favorites

#### 3.6.3 Book Positions

- Save specific page positions
- Add position notes
- Line number tracking
- Quick navigation
- Color-coded markers

### 3.7 Settings and Preferences

#### 3.7.1 Appearance

**Theme Options**
- Light mode
- Dark mode
- System default
- Custom accent colors (8 options)

**Color Themes**
- Blue (default)
- Purple
- Green
- Orange
- Red
- Pink
- Teal
- Yellow

#### 3.7.2 Reading Preferences

**Progress Entry**
- Stepper (+/- buttons)
- Slider
- Direct text input
- Increment step size (1, 5, 10 pages)

**Session Management**
- Auto-end after inactivity (5/15/30/60 minutes)
- Require confirmation for session deletion
- Show session notes in list
- Display session duration format

#### 3.7.3 Display Settings

**Home Card Visibility**
- Reading Pulse Card
- Currently Reading Card
- Quick Actions Card
- Stats Summary Card
- Goals Progress Card
- Streak Status Card

**Book Detail Sections**
- Show/hide sessions list
- Show/hide quotes
- Show/hide positions
- Show/hide notes
- Cover image size

**Stats Display**
- Chart type preference (bar/heatmap)
- Date range for stats
- Show/hide comparisons
- Decimal places for averages

#### 3.7.4 Privacy and Sync

**Cloud Sync**
- iCloud sync toggle
- Sync status indicator
- Manual sync trigger
- Conflict resolution preference

**Streak Privacy**
- Pause streak (hide from display)
- Streak visibility in stats
- Share streak data

#### 3.7.5 Watch Settings

- Sync on app launch
- Background sync interval
- Watch complication update frequency
- Data to sync (all/books only/sessions only)

#### 3.7.6 Developer Settings (Debug)

- Enable debug logging
- Force theme override
- Mock data generation
- Reset all data
- Export diagnostics
- Crash reporting toggle

---

## 4. Data Models

### 4.1 Book

```swift
@Model
final class Book {
    // Identification
    var id: UUID
    var isbn: String?
    var isbn13: String?

    // Basic Info
    var title: String
    var authors: [String]
    var subtitle: String?
    var publisher: String?
    var publishedDate: Date?
    var language: String?

    // Physical Details
    var totalPages: Int
    var coverImageURL: String?
    var coverImageData: Data?
    var subjects: [String]

    // Reading Status
    var readingStatus: ReadingStatus
    var rating: Int?
    var currentPage: Int
    var notes: String
    var dateAdded: Date
    var dateModified: Date

    // Relationships
    @Relationship(deleteRule: .cascade)
    var sessions: [ReadingSession]

    @Relationship(deleteRule: .cascade)
    var quotes: [Quote]

    @Relationship(deleteRule: .cascade)
    var positions: [BookPosition]

    enum ReadingStatus: String, Codable {
        case wantToRead = "want_to_read"
        case currentlyReading = "currently_reading"
        case finished = "finished"
        case didNotFinish = "did_not_finish"
    }

    // Computed Properties
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}
```

### 4.2 ReadingSession

```swift
@Model
final class ReadingSession {
    var id: UUID
    var bookID: UUID

    // Session Details
    var startPage: Int
    var endPage: Int
    var pagesRead: Int
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval  // in seconds

    // Additional Info
    var notes: String?
    var sessionType: SessionType
    var dateCreated: Date
    var dateModified: Date

    // Sync Status
    var isSynced: Bool
    var deviceID: String?

    enum SessionType: String, Codable {
        case standard
        case quick
        case active
    }

    // Validation
    var isValid: Bool {
        endPage >= startPage &&
        pagesRead > 0 &&
        duration >= 0 &&
        endTime >= startTime
    }
}
```

### 4.3 UserProfile

```swift
@Model
final class UserProfile {
    var id: UUID

    // Basic Info
    var name: String?
    var joinDate: Date

    // Gamification
    var totalXP: Int
    var currentLevel: Int
    var currentStreak: Int
    var longestStreak: Int

    // Reading Stats
    var totalBooksRead: Int
    var totalPagesRead: Int
    var totalMinutesRead: Int

    // Preferences
    var themeColor: String
    var prefersDarkMode: Bool
    var notificationsEnabled: Bool

    // Relationships
    @Relationship(deleteRule: .cascade)
    var goals: [ReadingGoal]

    @Relationship(deleteRule: .cascade)
    var achievements: [Achievement]
}
```

### 4.4 ReadingGoal

```swift
@Model
final class ReadingGoal {
    var id: UUID
    var type: GoalType
    var target: Int
    var current: Int
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var priority: Int
    var isVisible: Bool

    enum GoalType: String, Codable {
        case booksPerYear
        case booksPerMonth
        case pagesPerDay
        case minutesPerDay
        case readingStreak
    }

    // Computed
    var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
}
```

### 4.5 Achievement

```swift
@Model
final class Achievement {
    var id: UUID
    var type: AchievementType
    var title: String
    var description: String
    var xpReward: Int
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Int
    var maxProgress: Int

    enum AchievementType: String, Codable {
        case firstBook
        case tenBooks
        case fiftyBooks
        case hundredBooks
        case hundredPages
        case thousandPages
        case tenThousandPages
        case sevenDayStreak
        case thirtyDayStreak
        case hundredDayStreak
        case levelFive
        case levelTen
        case levelTwenty
        case speedReader
        case marathonReader
        case nightOwl
        case earlyBird
        case dedication
    }
}
```

### 4.6 Quote

```swift
@Model
final class Quote {
    var id: UUID
    var bookID: UUID
    var text: String
    var pageNumber: Int?
    var notes: String?
    var isFavorite: Bool
    var dateAdded: Date
    var dateModified: Date
}
```

### 4.7 BookPosition

```swift
@Model
final class BookPosition {
    var id: UUID
    var bookID: UUID
    var pageNumber: Int
    var lineNumber: Int?
    var notes: String?
    var color: String?
    var dateCreated: Date
}
```

### 4.8 ActiveReadingSession

```swift
@Model
final class ActiveReadingSession {
    var id: UUID
    var bookID: UUID
    var startPage: Int
    var startTime: Date
    var isPaused: Bool
    var pausedDuration: TimeInterval
    var lastPauseTime: Date?
    var deviceID: String?
    var dateCreated: Date

    // Computed
    var totalDuration: TimeInterval {
        let base = Date().timeIntervalSince(startTime)
        return isPaused ? base - pausedDuration : base
    }
}
```

### 4.9 StreakEvent

```swift
@Model
final class StreakEvent {
    var id: UUID
    var eventDate: Date
    var eventPages: Int
    var eventMinutes: Int
    var wasStreakActive: Bool
    var pardonUsed: Bool
    var pardonAvailableAfter: Date?
}
```

### 4.10 AppSettings

```swift
@Model
final class AppSettings {
    var id: UUID

    // Appearance
    var selectedTheme: String
    var useSystemAppearance: Bool

    // Reading
    var progressInputMethod: InputMethod
    var pageIncrementStep: Int
    var autoEndSessionMinutes: Int

    // Display
    var showReadingPulse: Bool
    var showCurrentlyReading: Bool
    var showQuickActions: Bool
    var showStatsSummary: Bool
    var showGoalsProgress: Bool
    var showStreakStatus: Bool

    // Privacy
    var iCloudSyncEnabled: Bool
    var streakIsPaused: Bool

    // Session List Display
    var showSessionNotes: Bool
    var sessionDurationFormat: DurationFormat

    enum InputMethod: String, Codable {
        case stepper
        case slider
        case direct
    }

    enum DurationFormat: String, Codable {
        case minutes
        case hoursMinutes
        case abbreviated
    }
}
```

---

## 5. Architecture

### 5.1 Architectural Pattern

Shlf follows the **MVVM (Model-View-ViewModel)** architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                    │
│  (Presentation, User Interaction, Display Logic)    │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ @State, @Binding, @Environment
                  │
┌─────────────────▼───────────────────────────────────┐
│                    ViewModels                       │
│     (Business Logic, State Management, Formatting)  │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ Dependencies
                  │
┌─────────────────▼───────────────────────────────────┐
│                     Services                        │
│  (Data Operations, External APIs, Complex Logic)    │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ SwiftData @Query, @Relationship
                  │
┌─────────────────▼───────────────────────────────────┐
│                     Models                          │
│          (Data Structure, Persistence)              │
└─────────────────────────────────────────────────────┘
```

### 5.2 State Management

**Local State**
- `@State`: View-local mutable state
- `@Binding`: Child-to-parent state flow
- `@StateObject`: Observable objects in views
- `@ObservedObject`: Observable objects passed to views
- `@EnvironmentObject`: Shared global state

**Data State**
- `@Query`: SwiftData reactive queries
- `@Model`: SwiftData model properties
- `@Relationship`: Related model access

**Shared State**
- `@Environment`: App-wide preferences
- `NotificationCenter`: Cross-component events
- `WatchConnectivity`: Device-to-device sync

### 5.3 Data Flow

```
User Action
     │
     ▼
SwiftUI View (Event Handler)
     │
     ▼
ViewModel (Process Action)
     │
     ├─────────────┐
     │             │
     ▼             ▼
Service      Direct Model Update
     │
     ▼
SwiftData Context
     │
     ▼
Persistent Store
     │
     ▼
@Query ←←←←←←←←←← Automatic View Update
     │
     ▼
View Re-render
```

### 5.4 Dependency Injection

Services are injected through:
- Environment values for app-wide services
- Initializer injection for view-specific services
- Singleton pattern for shared services (where appropriate)

```swift
// Environment Key for Service Injection
private struct SessionManagerKey: EnvironmentKey {
    static let defaultValue: SessionManager = SessionManager.shared
}

extension EnvironmentValues {
    var sessionManager: SessionManager {
        get { self[SessionManagerKey.self] }
        set { self[SessionManagerKey.self] = newValue }
    }
}
```

---

## 6. Services

### 6.1 SessionManager

**Responsibilities**: Reading session CRUD operations

**Key Methods**:
```swift
class SessionManager {
    static let shared = SessionManager()

    // Create
    func createSession(book: Book, startPage: Int, endPage: Int, notes: String?) throws

    // Read
    func getSessions(for book: Book) -> [ReadingSession]
    func getSession(id: UUID) -> ReadingSession?
    func getSessions(in dateRange: ClosedRange<Date>) -> [ReadingSession]

    // Update
    func updateSession(_ session: ReadingSession) throws

    // Delete
    func deleteSession(_ session: ReadingSession) throws
    func deleteSessions(for book: Book) throws
    func batchDeleteSessions(_ sessions: [ReadingSession]) throws

    // Validation
    func validateSession(startPage: Int, endPage: Int, totalPages: Int) throws
}
```

**Features**:
- Duplicate detection within tolerance window
- Clock skew tolerance for multi-device sync
- Atomic transaction support
- Batch operations for iOS 26+

### 6.2 GamificationEngine

**Responsibilities**: XP calculation, level progression, achievement tracking

**Key Methods**:
```swift
class GamificationEngine {
    static let shared = GamificationEngine()

    // XP
    func calculateXP(for pages: Int, duration: TimeInterval) -> Int
    func addXP(_ amount: Int) -> (newLevel: Int, levelUp: Bool)
    func getCurrentLevel(for totalXP: Int) -> Int

    // Achievements
    func checkAchievements(for profile: UserProfile) -> [Achievement]
    func unlockAchievement(_ type: Achievement.AchievementType)
    func getAchievementProgress(type: Achievement.AchievementType) -> Double
}
```

**XP Calculation**:
```
Total XP = (Pages × 1) + (Minutes × 1) + Bonuses
Level = floor(Total XP / 1000)
```

### 6.3 StreakService

**Responsibilities**: Streak tracking, pardon management

**Key Methods**:
```swift
class StreakService {
    static let shared = StreakService()

    // Streak Calculation
    func calculateCurrentStreak() -> Int
    func updateStreak(for date: Date, hasActivity: Bool)
    func getLongestStreak() -> Int

    // Pardon System
    func canUsePardon() -> Bool
    func usePardon() throws
    func getPardonCooldownRemaining() -> TimeInterval?

    // Streak Events
    func recordStreakEvent(date: Date, pages: Int, minutes: Int)
    func getStreakEvents(in range: ClosedRange<Date>) -> [StreakEvent]
}
```

**Streak Rules**:
- Activity within 24 hours maintains streak
- 48-hour grace period before streak breaks
- Pardon prevents break (48-hour window after break)
- 7-day cooldown between pardon uses

### 6.4 GoalTracker

**Responsibilities**: Goal progress tracking and updates

**Key Methods**:
```swift
class GoalTracker {
    static let shared = GoalTracker()

    // Goal Management
    func createGoal(type: ReadingGoal.GoalType, target: Int, startDate: Date) throws
    func updateGoalProgress(_ goal: ReadingGoal)
    func updateAllGoals()

    // Progress
    func getProgress(for goal: ReadingGoal) -> (current: Int, percentage: Double)
    func getCompletedGoals() -> [ReadingGoal]
    func getActiveGoals() -> [ReadingGoal]

    // Notifications
    func scheduleGoalReminder(for goal: ReadingGoal)
    func checkGoalCompletion(_ goal: ReadingGoal) -> Bool
}
```

### 6.5 WatchConnectivityManager

**Responsibilities**: iPhone-Watch data synchronization

**Key Methods**:
```swift
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // Connection State
    var isWatchPaired: Bool
    var isWatchAppInstalled: Bool
    var isReachable: Bool

    // Sending Data
    func sendBooks(_ books: [Book])
    func sendSessions(_ sessions: [ReadingSession])
    func sendActiveSession(_ session: ActiveReadingSession?)
    func sendSettings(_ settings: AppSettings)

    // Receiving Data
    func didReceiveSessionData(_ data: [String: Any])
    func didReceiveSettingsUpdate(_ data: [String: Any])

    // Sync
    func syncAllData()
    func requestFullSync()
}
```

**Sync Strategy**:
- Bi-directional synchronization
- Conflict resolution: Latest write wins
- Background transfers for large datasets
- Immediate sync for active session changes

### 6.6 ReadingSessionActivityManager

**Responsibilities**: Live Activity management for Dynamic Island

**Key Methods**:
```swift
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()

    // Lifecycle
    func startActivity(book: Book, startTime: Date, startPage: Int)
    func updateActivity(endPage: Int, currentPage: Int)
    func endActivity(endPage: Int, endTime: Date, pagesRead: Int)

    // State
    var isActivityActive: Bool
    var currentActivityID: String?

    // Updates
    func pushLiveActivityUpdate()
    func endLiveActivity(dismissPolicy: DismissPolicy)
}
```

**Live Activity Data**:
```swift
struct ReadingSessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentBookTitle: String
        var currentBookAuthor: String
        var currentPage: Int
        var totalPages: Int
        var startTime: Date
        var duration: TimeInterval
    }
}
```

### 6.7 BookAPIService

**Responsibilities**: External book data fetching

**Key Methods**:
```swift
class BookAPIService {
    static let shared = BookAPIService()

    // Search
    func searchBooks(query: String) async throws -> [BookSearchResult]
    func fetchBookDetails(isbn: String) async throws -> BookDetails

    // Barcode
    func fetchBookFromBarcode(_ barcode: String) async throws -> BookDetails

    // Image
    func fetchCoverImage(url: String) async throws -> Data
}
```

**APIs Used**:
- Open Library API (primary)
- Google Books API (fallback)

### 6.8 ProAccess

**Responsibilities**: Premium feature access control

**Key Methods**:
```swift
class ProAccess: ObservableObject {
    static let shared = ProAccess()

    var isPro: Bool { get }
    var proStatus: ProStatus { get }

    func checkProStatus() async
    func grantProAccess()
    func revokeProAccess()
    func canAccess(feature: ProFeature) -> Bool
}

enum ProFeature {
    case unlimitedGoals
    case advancedStats
    case customThemes
    case dataExport
    case widgets
}

enum ProStatus {
    case free
    case pro
    case expired
}
```

### 6.9 StoreKitService

**Responsibilities**: In-app purchase management

**Key Methods**:
```swift
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    // Products
    func fetchProducts() async
    var products: [Product]

    // Purchase
    func purchase(_ product: Product) async throws
    func restorePurchases() async

    // Subscription
    var subscriptionStatus: SubscriptionStatus
    func checkSubscriptionStatus() async
}
```

### 6.10 NotificationManager

**Responsibilities**: Local notification scheduling

**Key Methods**:
```swift
class NotificationManager {
    static let shared = NotificationManager()

    // Scheduling
    func scheduleReadingReminder(time: Date, weekdays: Set<Weekday>)
    func scheduleGoalReminder(for goal: ReadingGoal)
    func scheduleStreakWarning()

    // Management
    func getPendingNotifications() -> [UNNotificationRequest]
    func cancelAllNotifications()
    func cancelNotification(id: String)
}
```

### 6.11 DataExportImportService

**Responsibilities**: Data backup and restore

**Key Methods**:
```swift
class DataExportImportService {
    static let shared = DataExportImportService()

    // Export
    func exportAllData() async throws -> URL
    func exportBooks() async throws -> URL
    func exportSessions() async throws -> URL
    func exportToCSV() async throws -> URL

    // Import
    func importData(from url: URL) async throws
    func validateImportData(_ data: Data) throws

    // Formats
    enum ExportFormat {
        case json
        case csv
    }
}
```

---

## 7. User Interface

### 7.1 Navigation Structure

**Tab Bar (Main Navigation)**
```
┌─────────────────────────────────────────────────┐
│  Home    │   Library    │    Stats    │  Settings│
└─────────────────────────────────────────────────┘
```

**Home Tab**
- Reading Pulse Card (daily progress)
- Currently Reading Card (active books)
- Quick Actions Card (start session, add book)
- Stats Summary Card (weekly overview)
- Goals Progress Card (goal status)
- Streak Status Card (current streak)

**Library Tab**
- Search bar
- Filter by status
- Sort options
- Grid/List view toggle
- Add book FAB

**Stats Tab**
- Dashboard metrics
- Chart type selector
- Date range selector
- Heatmap/Charts
- Export button

**Settings Tab**
- Profile section
- Appearance settings
- Reading settings
- Privacy settings
- Watch settings
- Developer settings
- About section

### 7.2 Book Detail View

**Header**
- Cover image
- Title and author
- Rating (stars)
- Reading status badge

**Progress Section**
- Progress bar
- Current page / total pages
- Percentage display

**Quick Actions**
- Start/continue reading button
- Quick log session button
- Add note button

**Tabs**
- Overview (details, metadata)
- Sessions (reading session history)
- Quotes (saved quotes)
- Notes (personal notes)

### 7.3 Apple Watch Interface

**Main View**
- Currently reading list
- Last session quick action
- Stats summary
- Settings access

**Session View**
- Book title and page
- Timer display
- Pause/resume button
- End session button

**Quotes View**
- Quote list
- Scroll with digital crown
- Tap to view full quote

### 7.4 Widgets

**Small Widget**
- Current book cover
- Progress percentage
- XP today

**Medium Widget**
- Currently reading
- Progress bar
- Current streak
- Active session (if any)

**Widget Configuration**
- Display type selection
- Theme color matching
- Update frequency

---

## 8. Platform-Specific Features

### 8.1 iOS Features

**Live Activities**
- Real-time reading progress in Dynamic Island
- Shows current book, page progress, session duration
- Updates every 30 seconds during active session

**Haptic Feedback**
- Light haptic on button tap
- Success haptic on session completion
- Warning haptic on deletion

**Spotlight Integration**
- Search books from home screen
- Search quotes and notes

**Share Sheet**
- Share reading progress
- Share statistics image
- Share quotes

**Context Menus**
- Long press on books for quick actions
- Session quick actions
- Quote sharing

### 8.2 watchOS Features

**Watch Complications**
- Modular Small: Current page
- Modular Large: Current book + progress
- Circular Small: Streak icon

**Digital Crown**
- Scroll through lists
- Increment page counter
- Navigate quotes

**Force Touch**
- Quick actions menu
- Force touch on book → start session
- Force touch on session → end/pause

**Offline Support**
- Local data storage
- Sync when connected
- Background data updates

### 8.3 Widget Features

**Timeline Refresh**
- Updates every 15 minutes (system limit)
- Background URL refresh for live data
- App Group shared data access

**Configuration**
- Widget size selection
- Display options
- Theme matching

**Deep Links**
- Tap widget → open to book detail
- Tap session → active session view

---

## 9. Technical Implementation

### 9.1 SwiftData Configuration

**Model Container**
```swift
let modelContainer = try ModelContainer(
    for: [
        Book.self,
        ReadingSession.self,
        UserProfile.self,
        ReadingGoal.self,
        Achievement.self,
        Quote.self,
        BookPosition.self,
        ActiveReadingSession.self,
        StreakEvent.self,
        AppSettings.self
    ],
    configurations: [
        .init(isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
    ]
)
```

**Query Optimization**
```swift
// Pagination
@Query(filter: predicate, sort: sortDescriptor)
var books: [Book]

// Fetch limit for large datasets
let fetchDescriptor = FetchDescriptor<Book>(
    predicate: predicate,
    fetchLimit: 100
)
```

**Batch Operations (iOS 26+)**
```swift
try context.delete(model: ReadingSession.self, where: #Predicate { session in
    session.endTime < cutoffDate
})
```

### 9.2 App Groups Configuration

**Group Identifier**
```
group.com.shlf.app
```

**Shared Container Access**
```swift
let userDefaults = UserDefaults(suiteName: "group.com.shlf.app")
let sharedContainer = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.shlf.app"
)
```

**Shared Data**
- Active session state
- User preferences
- Theme settings
- Widget display data

### 9.3 WatchConnectivity Implementation

**Transfer Modes**
```swift
// Interactive (immediate)
session.transferUserInfo(data)

// Background (queued)
session.transferCurrentComplicationUserInfo(data)

// File (large data)
session.transferFile(file, metadata: metadata)
```

**Message Handling**
```swift
func session(_ session: WCSession, didReceiveMessageData data: Data) {
    // Decode and process
}

func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    // Background data received
}
```

### 9.4 ActivityKit Implementation

**Starting Activity**
```swift
let attributes = ReadingSessionActivityAttributes(
    bookTitle: book.title,
    bookAuthor: book.authors.joined(separator: ", ")
)

let initialState = ReadingSessionActivityAttributes.ContentState(
    currentBookTitle: book.title,
    currentBookAuthor: book.authors.joined(separator: ", "),
    currentPage: startPage,
    totalPages: book.totalPages,
    startTime: Date(),
    duration: 0
)

let activity = try Activity<ReadingSessionActivityAttributes>.request(
    attributes: attributes,
    content: .init(state: initialState, staleDate: nil),
    pushType: nil
)
```

**Updating Activity**
```swift
Task {
    await activity.update(using: .init(state: newState, staleDate: nil))
}
```

### 9.5 Widget Implementation

**Widget Provider**
```swift
struct ReadingPulseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReadingPulseEntry {
        ReadingPulseEntry(date: Date(), progress: 0.5, xpToday: 100)
    }

    func getSnapshot(for configuration: ReadingPulseConfiguration, in context: Context) async -> ReadingPulseEntry {
        // Fetch current data
    }

    func getTimeline(for configuration: ReadingPulseConfiguration, in context: Context) async -> Timeline<ReadingPulseEntry> {
        // Generate timeline entries
    }
}
```

**Widget View**
```swift
struct ReadingPulseWidget: Widget {
    let kind: String = "ReadingPulseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ReadingPulseConfiguration.self, provider: ReadingPulseProvider()) { entry in
            ReadingPulseWidgetEntryView(entry: entry)
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Reading Pulse")
        .description("See your current reading progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### 9.6 Performance Optimizations

**Lazy Loading**
```swift
LazyVGrid(columns: columns) {
    ForEach(books) { book in
        BookCell(book: book)
            .onAppear {
                // Load more when approaching end
                if book.id == books.last?.id {
                    loadMoreBooks()
                }
            }
    }
}
```

**Image Caching**
```swift
struct AsyncCachedImage: View {
    @State private var image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
        } else {
            ProgressView()
                .task {
                    image = await loadImage()
                }
        }
    }
}
```

**Debounced Updates**
```swift
@Observable
class DebouncedUpdater {
    private var debounceTask: Task<Void, Never>?

    func scheduleUpdate(_ action: @escaping () async -> Void) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await action()
        }
    }
}
```

---

## 10. Configuration & Settings

### 10.1 App Configuration

**Info.plist Keys**
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan book barcodes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Used to select book cover images</string>

<key>NSFaceIDUsageDescription</key>
<string>Secure access to your reading data</string>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.shlf.background-sync</string>
</array>

<key>NSSharingSceneConfiguration</key>
<dict>
    <key>Default</key>
    <string>Share your reading progress</string>
</dict>
```

### 10.2 Entitlements

**iCloud**
```
com.apple.developer.icloud-container-identifiers
com.apple.developer.icloud-services
```

**App Groups**
```
com.apple.security.application-groups
```

**Background Modes**
```
fetch
processing
remote-notification
```

### 10.3 Build Settings

**Swift Compiler Flags**
- `-strict-concurrency=complete`
- `-enable-upcoming-feature` BareSlashRegexLiterals
- `-enable-upcoming-feature` ConciseMagicFile
- `-enable-upcoming-feature` ExistentialAny

**Deployment Targets**
- iOS: 17.0
- watchOS: 10.0

### 10.4 Environment Variables

**Debug Mode**
```
SHLF_DEBUG_ENABLED = true
SHLF_MOCK_DATA = false
SHLF_LOG_LEVEL = verbose
```

**API Keys**
```
SHLF_OPEN_LIBRARY_API_KEY = (optional)
SHLF_GOOGLE_BOOKS_API_KEY = (optional)
```

---

## 11. File Reference

### 11.1 Core Files

| File | Description |
|------|-------------|
| `ShlfApp.swift` | App entry point, setup |
| `ContentView.swift` | Main tab view container |
| `ShlfWatchApp.swift` | Watch app entry point |

### 11.2 Feature Files

| File | Description |
|------|-------------|
| `BookDetailView.swift` | Individual book screen |
| `LibraryView.swift` | Book library management |
| `HomeView.swift` | Main dashboard |
| `StatsView.swift` | Statistics and analytics |
| `SettingsView.swift` | App settings |
| `GoalsView.swift` | Goal tracking |
| `ProFeaturesView.swift` | Premium features |
| `OnboardingView.swift` | First-run experience |

### 11.3 Service Files

| File | Description |
|------|-------------|
| `SessionManager.swift` | Session CRUD operations |
| `GamificationEngine.swift` | XP and achievements |
| `StreakService.swift` | Streak management |
| `GoalTracker.swift` | Goal progress |
| `WatchConnectivityManager.swift` | iPhone-Watch sync |
| `ReadingSessionActivityManager.swift` | Live Activities |
| `BookAPIService.swift` | External book data |
| `StoreKitService.swift` | In-app purchases |
| `DataExportImportService.swift` | Backup/restore |

### 11.4 Model Files

| File | Description |
|------|-------------|
| `Book.swift` | Book data model |
| `ReadingSession.swift` | Session data model |
| `UserProfile.swift` | User profile model |
| `ReadingGoal.swift` | Goal data model |
| `Achievement.swift` | Achievement model |
| `Quote.swift` | Quote model |
| `BookPosition.swift` | Book position marker |
| `ActiveReadingSession.swift` | Active session model |
| `StreakEvent.swift` | Streak tracking events |
| `AppSettings.swift` | App settings model |

### 11.5 Widget Files

| File | Description |
|------|-------------|
| `ReadingSessionWidgetBundle.swift` | Widget bundle definition |
| `ReadingSessionWidget.swift` | Main widget implementation |
| `ReadingPulseWidget.swift` | Progress widget |
| `ShlfLiveActivityWidget.swift` | Live Activity widget |

### 11.6 Watch Files

| File | Description |
|------|-------------|
| `ShlfWatchApp.swift` | Watch app entry |
| `WatchHomeView.swift` | Watch main view |
| `WatchSessionView.swift` | Active session on Watch |
| `WatchQuotesView.swift` | Quotes browser |
| `WatchSettingsView.swift` | Watch settings |

---

## Appendix

### A. Supported Languages

- English (en)
- [Additional languages can be added]

### B. Accessibility

Shlf is designed with accessibility in mind:
- VoiceOver support throughout
- Dynamic Type support
- High contrast mode support
- Reduce motion support
- Keyboard navigation on iPad
- Large text support

### C. Security Features

- Local data encryption (iOS device encryption)
- Secure iCloud sync (encrypted at rest)
- No third-party analytics
- No data collection beyond app functionality
- Privacy-first design

### D. Backup Recommendations

Users should:
1. Enable iCloud sync for automatic backup
2. Export data periodically via Settings → Export Data
3. Keep device backups via iTunes/F Finder

### E. Troubleshooting

**Sync Issues**
- Check iCloud is enabled
- Verify internet connection
- Force sync from Settings

**Streak Issues**
- Check reading activity dates
- Use pardon if eligible
- Contact support if data appears incorrect

**Widget Not Updating**
- Ensure app groups are configured
- Check background refresh is enabled
- Remove and re-add widget

---

**Document Version**: 1.0
**Generated for**: Shlf iOS 26
**Generated on**: January 12, 2026
