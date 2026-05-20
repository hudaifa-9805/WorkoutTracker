# Architecture Overview — WorkoutTracker
> Generated: 2026-05-06  |  Source: WorkoutTracker/  |  Author: Claude Code

**TL;DR: A five-domain SwiftUI MVVM app wired together at app launch via `@EnvironmentObject` injection, with UserDefaults for local persistence, Supabase for auth, and two external APIs (Supabase Auth, Open Food Facts) — all currently running without a live AI backend.**

---

## System Topology

```
iOS Device
┌──────────────────────────────────────────────────────────────────┐
│  WorkoutTrackerApp (@main)                                       │
│  ┌────────────┐  Creates & injects 6 ViewModels as @StateObject  │
│  │ContentView │  ── auth gate (splash → login | home)           │
│  └────┬───────┘                                                  │
│       │                                                          │
│  ┌────▼────────────────────────────────────────────────────────┐ │
│  │  MainTabView  (4 tabs + floating AI button)                 │ │
│  │  ┌──────────┐ ┌─────────────────┐ ┌──────────┐ ┌────────┐  │ │
│  │  │ HomeView │ │ LogDashboardView│ │ Progress │ │Account │  │ │
│  │  └──────────┘ └─────────────────┘ └──────────┘ └────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ViewModels (all @MainActor, all ObservableObject)               │
│  AuthViewModel  WorkoutViewModel  RoutineViewModel               │
│  NutritionViewModel  BodyWeightViewModel  AIChatViewModel        │
│                                                                  │
│  Services (singletons)                                           │
│  SupabaseService  FoodLookupService  AIRoutineService            │
│                                                                  │
│  Local Storage                                                   │
│  UserDefaults (JSON)   iOS Keychain (via Supabase SDK)           │
└──────────────────────────────────────────────────────────────────┘
        │                          │
        ▼                          ▼
┌───────────────┐        ┌──────────────────────┐
│ Supabase Auth │        │ Open Food Facts API   │
│ (JWT + RLS)   │        │ /api/v0/product/{id}  │
└───────────────┘        └──────────────────────┘
```

---

## File Map

```
WorkoutTracker/
├── WorkoutTrackerApp.swift          # @main, ViewModel creation, Color constants
├── ContentView.swift                # Auth gate: SplashView | AuthView | MainTabView
│
├── Models/
│   ├── Exercise.swift               # Exercise, ExerciseCategory, MuscleGroup, Equipment + sampleData
│   ├── WorkoutSet.swift             # WorkoutSet, SetType (W/S/D)
│   ├── Workout.swift                # WorkoutSession, WorkoutExercise
│   ├── WorkoutSplit.swift           # WorkoutSplit, SplitDay, SplitExercise
│   ├── NutritionModels.swift        # FoodItem, MealEntry, MealType, MacroTarget
│   ├── BodyWeightEntry.swift        # BodyWeightEntry
│   └── AIModels.swift               # AIMessage, AIRole, ChatContext, AIPreferences
│
├── Services/
│   ├── SupabaseService.swift        # Singleton SupabaseClient; auth calls only
│   ├── FoodLookupService.swift      # Open Food Facts barcode lookup; OFFResponse private DTOs
│   └── AIRoutineService.swift       # Rule-based hint generator; LLM stub
│
├── ViewModels/
│   ├── AuthViewModel.swift          # Auth state, AppUser, session restore
│   ├── WorkoutViewModel.swift       # Active session lifecycle, timer, in-memory history
│   ├── RoutineViewModel.swift       # Split CRUD, active split, AI hint coordination
│   ├── NutritionViewModel.swift     # Meal CRUD, macro targets, analytics queries
│   ├── BodyWeightViewModel.swift    # Weight log CRUD, stats (avg, delta)
│   ├── AIChatViewModel.swift        # Chat history, context assembly, preferences persistence
│   └── ExerciseLibraryViewModel.swift  # Filter/group Exercise.sampleData
│
└── Views/
    ├── Auth/
    │   └── AuthView.swift           # Login/signup form, AuthTextField, AuthPasswordField
    ├── Home/
    │   └── HomeView.swift           # Dashboard: greeting, stats, today plan, recent history
    ├── Log/
    │   ├── LogDashboardView.swift   # Segmented Workout/Nutrition/Body tab host
    │   ├── NutritionLogView.swift   # Macro ring, meal log, AddMealSheet, EditMealSheet
    │   ├── BodyWeightLogView.swift  # Chart, stats, history, LogWeightSheet
    │   └── BarcodeScannerView.swift # AVFoundation camera; 6-state FSM; UIViewControllerRepresentable
    ├── WorkoutLog/
    │   └── WorkoutLogView.swift     # Modal session view + ALL shared workout components:
    │                                #   WorkoutTimerBanner, EmptyWorkoutStartView,
    │                                #   SplitDayPickerView, ActiveWorkoutScrollContent,
    │                                #   ExerciseLogCard, SetRow, LogTextField,
    │                                #   RIRStepper, ExercisePickerSheet
    ├── Progress/
    │   └── ProgressView.swift       # Charts (volume/weight/calories), PRs, all-time stats
    ├── Routines/
    │   ├── RoutinesView.swift       # Split list, AI toggle, ActiveSplitCard, SplitDetailView
    │   └── SplitEditorView.swift    # Create/edit split; DayExerciseEditorView; SplitExerciseEditorSheet
    ├── Account/
    │   ├── AccountView.swift        # Profile, feature flags, settings, all sub-sheets
    │   └── AIPreferencesView.swift  # Goal/level/diet/nutrition targets
    ├── ExerciseLibrary/
    │   └── ExerciseLibraryView.swift  # Searchable, filterable exercise browse (orphaned — no nav entry)
    └── AI/
        └── AIChatView.swift         # Chat bubbles, TypingIndicator, FloatingAIButton
```

---

## ViewModel Ownership Map

Each ViewModel owns one data domain. The table shows what it owns, where it reads from (inputs), and who reads from it (consumers).

| ViewModel | Owns | Persists to | Read by |
|---|---|---|---|
| `AuthViewModel` | `isAuthenticated`, `isCheckingAuth`, `currentUser: AppUser` | Supabase / Keychain | `ContentView`, `HomeView`, `AccountView`, `AuthView` |
| `WorkoutViewModel` | `activeSession: WorkoutSession?`, `pastSessions: [WorkoutSession]`, timer | **Nothing** (in-memory only) | `HomeView`, `LogDashboardView`, `WorkoutLogView`, `ProgressDashboardView`, `AIChatViewModel` (context) |
| `RoutineViewModel` | `splits: [WorkoutSplit]`, `activeSplit` | `workout_splits_v1` (UD) | `LogDashboardView`, `WorkoutLogView`, `AccountView`, `RoutinesView` |
| `NutritionViewModel` | `entries: [MealEntry]`, `macroTarget` | `nutrition_entries_v1`, `nutrition_target_v1` (UD) | `NutritionLogView`, `ProgressDashboardView`, `AIChatViewModel` |
| `BodyWeightViewModel` | `entries: [BodyWeightEntry]` | `bodyweight_entries_v1` (UD) | `BodyWeightLogView`, `ProgressDashboardView`, `AIChatViewModel` |
| `AIChatViewModel` | `messages: [AIMessage]`, `preferences: AIPreferences` | `ai_preferences_v1` (UD) | `AIChatView`, `AccountView`, `AIPreferencesView` |
| `ExerciseLibraryViewModel` | filter state only | nothing | `ExerciseLibraryView` |

---

## Auth State Machine

```
App Launch
    │
    ▼
isCheckingAuth = true ──────────────── SplashView renders
    │
    │  checkAuthState() fires via .task
    │
    ├─ Keychain hit (valid session)
    │       └──► isAuthenticated = true  ──► MainTabView
    │
    └─ No session / expired
            └──► isAuthenticated = false ──► AuthView
                        │
                        ├─ signIn() ──► success ──► isAuthenticated = true ──► MainTabView
                        ├─ signUp() ──► session created ──► isAuthenticated = true ──► MainTabView
                        └─ signUp() ──► email confirm needed ──► errorMessage shown
```

---

## Data Flow: Barcode Scan → Meal Log

```
User taps "Scan Barcode"
    │
    ▼
BarcodeScannerView (fullScreenCover)
    │  state: .requesting → .scanning
    │
    │  AVCaptureMetadataOutput delegate fires
    │  state: .success(barcodeString)
    │
    │  onScan callback returns barcodeString
    ▼
AddMealSheet.handleScan()
    │
    ▼
FoodLookupService.lookup(barcode:)     ← async, 10s timeout
    │
    │  GET https://world.openfoodfacts.org/api/v0/product/{barcode}.json
    │
    ├─ .found(FoodItem) ──► addFood() ──► selectedItems.append + scanBanner = .success
    ├─ .notFound         ──► scanBanner = .notFound
    └─ .networkError     ──► scanBanner = .error
    │
    ▼
User taps "Add" → saveMeal()
    │
    ▼
NutritionViewModel.addMeal(MealEntry)
    │  entries.insert + save()
    ▼
UserDefaults["nutrition_entries_v1"]
```

---

## Data Flow: AI Coach Reply

```
User types message → sendMessage()
    │
    ▼
AIChatViewModel.buildContext(nutritionVM:bodyWeightVM:recentWorkouts:)
    │  Reads: todayCalories, targetCalories, targetProtein,
    │         latest weightKg, recentWorkouts (⚠ hard-coded 0),
    │         preferences.fitnessGoal, experienceLevel, dietaryStyle
    ▼
AIChatViewModel.send(message:context:)
    │  Appends user AIMessage
    │  isLoading = true
    ▼
generateReply(to:context:)   ← Task.sleep(900ms) then keyword match
    │
    ▼
Appends assistant AIMessage
isLoading = false
```

---

## Feature Flag Architecture

Six `@AppStorage` booleans gate UI at multiple levels:

| Flag key | Default | What it gates |
|---|---|---|
| `ai_chat_enabled` | `true` | `FloatingAIButton` in `MainTabView` |
| `nutrition_tracking_enabled` | `false` | "Nutrition" segment in `LogDashboardView`; nutrition cards in `ProgressDashboardView`; nutrition metric in metric picker |
| `bodyweight_tracking_enabled` | `false` | "Body" segment in `LogDashboardView`; body weight cards in `ProgressDashboardView`; weight metric in metric picker |
| `ai_routines_enabled` | `false` | AI toggle UI + hint fetch in `RoutineViewModel`; `AIHintBanner` in `SplitDetailView` |
| `notificationsEnabled` | `false` | Notification permission request in `AccountView` |
| `weightUnit` | `"kg"` | All weight display strings (applies globally) |

---

## Key Patterns

### Shared Workout UI Components
All shared workout UI lives in `WorkoutLogView.swift` and is consumed by both `WorkoutLogView` (modal) and `LogDashboardView` (tab). This avoids a dedicated shared-components file while keeping both views in sync.

### UserDefaults Persistence
Every persisting ViewModel uses a private `StorageKey` enum for string constants and JSON encode/decode via `Codable`. All writes happen synchronously on the main thread at the point of mutation.

### `@MainActor` Isolation
All six ViewModels are `@MainActor final class`. Async service calls (`signIn`, `lookup`, `suggest`) are `await`ed in async functions — the `@MainActor` isolation guarantees that `@Published` property assignments always happen on the main thread.

### Service Singletons
`SupabaseService`, `FoodLookupService`, and `AIRoutineService` are singletons with private `init()`. They hold no mutable state — all state lives in the ViewModels. This makes them safe to call from any actor context.

---

## What to Build Next

The following are the highest-leverage missing pieces, ordered by impact:

1. **Persist `WorkoutViewModel.pastSessions`** — Add `save()`/`load()` with UserDefaults or Supabase. This is the #1 data-loss risk.
2. **Connect `AIChatViewModel` to a real LLM** — Swap `generateReply()` for an Anthropic API call. The scaffolding is already in place.
3. **Compute real progress metrics** — Wire `pastSessions` into `ProgressDashboardView.chartData` for Volume/Workouts/Sets; compute real PRs from session history.
4. **Persist profile name to Supabase** — Call `auth.update(user:)` in `EditProfileSheet.save()`.
5. **Add `onAuthStateChange` listener** — Handle mid-session token expiry in `AuthViewModel.init()`.
6. **Add `ExerciseLibraryView` to navigation** — Add a fifth tab or navigation link from an existing tab.
7. **Schedule workout reminder notifications** — Wire `UNNotificationRequest` into `handleNotificationToggle()`.
