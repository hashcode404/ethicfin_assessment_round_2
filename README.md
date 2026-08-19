# Task Space - Offline-First Task Manager

Task Space is a production-quality, offline-first task management application built with **Flutter**, **Firebase Cloud Firestore**, and a local persistent **SQLite (`sqflite`)** database. State management is handled compose-ably using **Riverpod**.

The app is fully usable offline: all task creation, updates, completion toggling, and deletions are saved locally immediately, giving a lag-free UI experience. When internet connectivity returns, changes are synchronized to Firebase automatically in an idempotent and retryable manner.

---

## Technical Stack & Architecture

The application is structured following clean architecture principles, separating the UI from data fetching and core domain models:

*   **UI / Presentation Layer**: Clean Material 3 widgets with smooth transitions, theme selection, priority badge color coding, and composite reactive state (Search -> Filter -> Sort) built on top of **Riverpod**.
*   **Domain Layer**: Pure Dart entity models (`Task`, `TaskPriority`, `SyncStatus`) and the abstract repository contract, representing the core business rules independent of database implementations.
*   **Data Layer**: Contains database helpers, firestore services, serializable model maps (`TaskModel` extending `Task`), and the repository implementation coordinating local database caching and remote cloud syncing.

```text
lib/
├── core/
│   ├── errors/          # Custom AppExceptions (No database/Firebase leakage to UI)
│   ├── network/         # Connectivity monitoring and background SyncService
│   └── theme/           # Premium Material 3 Dark/Light slate-indigo theme configuration
│
├── domain/
│   ├── entities/        # Pure domain classes (Task, TaskPriority, SyncStatus)
│   └── repositories/    # Abstract TaskRepository interface
│
├── data/
│   ├── models/          # TaskModel with JSON serialization (Local & Remote mapping)
│   ├── local/           # SQLite (sqflite) database helper
│   ├── remote/          # Cloud Firestore client wrapper
│   └── repositories/    # Repository implementation coordinating local-first execution & sync
│
├── presentation/
│   ├── providers/       # Riverpod providers (TaskListNotifier, filters, search providers)
│   ├── screens/         # Dashboard TaskListScreen, Details Screen, Add/Edit Screen
│   └── widgets/         # TaskCard, stats widgets, search inputs
│
└── main.dart            # Eager database opening and Firebase initialization
```

---

## Offline Synchronization & Conflict Handling

### Sync Status Lifecycle

Each task carries synchronization metadata stored in the local SQLite database.

```text
[User Action] ──> Write to Local DB (Immediate UI update)
                        │
                  Is Online?
                 /          \
              [Yes]         [No]
               /              \
     Write to Firestore     Mark 'pendingCreate/Update/Delete'
    Mark local 'synced'        │
                         Internet returns
                               │
                       SyncService runs sync loop
                               │
                    Update remote, mark local 'synced'
```

*   **`synced`**: State is identical in local database and Firestore.
*   **`pendingCreate`**: Created offline. Needs to be uploaded to Firestore.
*   **`pendingUpdate`**: Modified offline. Needs to be updated in Firestore.
*   **`pendingDelete`**: Deleted offline. Hidden in the UI immediately, kept locally for deletion sync, deleted from remote and local DB upon success.
*   **`failed`**: Sync failed due to permission or data issues. Retried during the next sync cycle.

### Conflict Resolution: Last Write Wins

If a task is modified on multiple devices while offline:
1. The app fetches the remote document from Firestore.
2. It compares the `lastModifiedAt` timestamp of the local task against the remote task.
3. If the local version has a newer timestamp, it pushes the local updates to Firestore.
4. If the remote version has a newer timestamp (e.g. modified later on another device), the remote version overwrites the local SQLite record.

This resolution logic is idempotent, preventing duplicate documents or overwritten changes.

---

## Firebase Setup Instructions

To run the application with full cloud synchronization, connect it to your Firebase Project:

### 1. Create a Firebase Project
*   Go to the [Firebase Console](https://console.firebase.google.com/) and click **Add Project**.
*   Enable **Cloud Firestore** database.

### 2. Configure Platforms

#### Android Configuration
*   Register your Android app with package name: `com.example.ethicfin_assessment_round_2` (or your customized package name).
*   Download `google-services.json`.
*   Place it in: `android/app/google-services.json`.

#### iOS Configuration
*   Register your iOS app with bundle ID: `com.example.ethicfinAssessmentRound2` (or your customized bundle ID).
*   Download `GoogleService-Info.plist`.
*   Place it in: `ios/Runner/GoogleService-Info.plist`.

### 3. Firestore Security Rules
Configure the security rules in your Firestore dashboard to allow reads and writes. For testing, you can use:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /tasks/{taskId} {
      allow read, write: if true;
    }
  }
}
```

> [!NOTE]
> **Graceful Offline Fallback**:
> If the Firebase configuration files are not found, the app catches the initialization error gracefully, shows an information banner indicating that it's running in **Local-Only Offline Mode**, and functions perfectly using local SQLite storage.

---

## Running the Project

### Prerequisites
Make sure you have [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.

### Setup and Start
1.  Fetch dependencies:
    ```bash
    flutter pub get
    ```
2.  Run code analyzers to verify correctness:
    ```bash
    flutter analyze
    ```
3.  Run all unit, integration, and widget tests:
    ```bash
    flutter test
    ```
4.  Run the application on a connected device/emulator:
    ```bash
    flutter run
    ```
