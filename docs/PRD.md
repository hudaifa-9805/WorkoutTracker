# Product Requirements Document — WorkoutTracker
> Generated: 2026-05-06  |  Source: WorkoutTracker/  |  Author: Claude Code

**TL;DR: WorkoutTracker is a SwiftUI iOS fitness companion that lets athletes log workouts set-by-set, plan training splits, scan food barcodes to track macros, track body weight trends, and query a rule-based AI coach — all persisted locally with Supabase authentication.**

---

## 1. PRODUCT OVERVIEW

### What it does

WorkoutTracker is a mobile-first fitness tracking application for iOS. It covers four primary user jobs:

1. **Workout logging** — start a session, add exercises, log sets with weight / reps / RIR (Reps In Reserve), and finish to record history.
2. **Routine planning** — build named training splits (e.g. Push/Pull/Legs) with prescribed sets, reps, and RIR per exercise, then activate one to use as a session template.
3. **Nutrition tracking** — log meals by meal type, select foods from a library or scan a product barcode (Open Food Facts lookup), and track daily macro progress against configurable targets.
4. **Progress analysis** — review training volume, body weight trends (with Swift Charts visualisations), personal records, and AI coaching advice in a conversational chat UI.

### Intended users

- Intermediate to advanced gym athletes who want structured, data-driven training.
- Users who track macros alongside their training.
- Athletes who want coaching feedback without a live human coach.

### Core problem solved

Commercial fitness apps are either too simple (no RIR, no split planning) or too complex and subscription-locked. WorkoutTracker gives a self-coached athlete structured session logging, routine management, nutrition tracking, and conversational AI guidance in one dark-themed, opinionated UI — with all data stored on-device for speed and offline reliability.

---

## 2. FUNCTIONAL REQUIREMENTS

### 2.1 Authentication

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Email sign-up | email, password (≥ 6 chars), full name | Creates Supabase account; signs in immediately if email confirmation is disabled; otherwise prompts confirmation email |
| Email sign-in | email, password | Restores session; sets `currentUser`; routes to main tab |
| Session restore | (none — fires on app launch) | Reads Supabase session from iOS Keychain; routes to home or login accordingly |
| Sign-out | Tap "Sign Out" → destructive confirm | Fires Supabase `signOut()` async; clears `isAuthenticated` and `currentUser` immediately |
| Auth loading state | — | Shows full-screen loading overlay on `AuthView`; disables the submit button |
| Error display | Network/validation error from Supabase | Animated inline error message below the form |

**Edge cases handled:**
- Empty email or password fields → inline validation message, no network call.
- Password < 6 characters on sign-up → inline validation message.
- App launch with a valid cached session → splash screen shown until async Keychain check completes (prevents login page flash).

---

### 2.2 Workout Logging

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Start empty workout | Tap "Start Workout" | Creates a `WorkoutSession`; starts a 1-second Combine timer |
| Start from split day | Tap a split day card | Pre-populates session with prescribed exercises/sets; starts timer |
| Add exercise | Select from `ExercisePickerSheet` | Appends `WorkoutExercise` with one empty working set |
| Log a set | Weight (decimal), reps (int), RIR (0–4 stepper) | Updates `WorkoutSet` fields; marks set type badge |
| Mark set complete | Tap circle button | Toggles `isCompleted`; row highlights orange |
| Add set | Tap "Add Set" | Appends empty `WorkoutSet` with next sequential set number |
| Remove set | Swipe (via `removeSet`) | Deletes `WorkoutSet` at index |
| Finish workout | Tap "Finish" | Stamps `durationSeconds`; prepends session to `pastSessions` |
| Discard workout | Tap "Discard" → destructive confirm | Drops active session; resets timer |
| Timer display | — | Elapsed time shown as `MM:SS` or `H:MM:SS` in `WorkoutTimerBanner`; also shown as `ActiveWorkoutBanner` on HomeView |

**Set types:** Warmup (`W`) / Working (`S`) / Drop set (`D`), distinguished by a colored badge.

**Edge cases handled:**
- Finishing with no exercises → works (empty session is saved).
- Empty weight/reps fields → text fields show placeholder; `volume = 0` for those sets.
- Best set badge shows only if at least one set is completed with `weight > 0`.

---

### 2.3 Routine Planning

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Create split | Name, optional description, days, exercises per day | Persisted to UserDefaults; optionally seeds AI hints |
| Edit split | Any field | In-place update persisted |
| Delete split | Swipe → destructive | Removes from list; updates active split reference |
| Set split active | Swipe "Set Active" or button | Deactivates all others; triggers `AIRoutineService.suggest()` if AI enabled |
| Reorder days | Drag handles | Updates `order` index on all days |
| Add training day | Name via alert | Appends `SplitDay` with `order = days.count` |
| Add exercise to day | Select from `ExercisePickerSheet` | Creates `SplitExercise` with default 3×8 RIR 2 |
| Edit exercise targets | Sets (1–10), Reps (1–30), RIR (0–4) via `TargetStepper` | In-place update |
| AI suggestions | Toggle in `RoutinesView` | Fetches rule-based hints for all exercises in active split; written to `SplitExercise.aiHint`; displayed as expandable `AIHintBanner` |

**Sample data:** Two splits seed on first launch (Push/Pull/Legs and Upper/Lower).

**Edge cases handled:**
- Creating a split with no days is allowed (days are optional).
- Deleting the active split sets `activeSplit = nil`.
- AI hints are additive — existing hints are never cleared by a partial refresh.

---

### 2.4 Nutrition Tracking

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Add meal | Meal type, selected food items, serving sizes | Creates `MealEntry`; persisted; updates today's totals |
| Select food from library | Search (name, case-insensitive) | Filtered from 15 built-in `FoodItem.sampleFoods` |
| Scan barcode | Camera capture (EAN-8/13, UPC-A/E, QR, etc.) | Calls Open Food Facts API; adds `FoodItem` to selection or shows error banner |
| Adjust serving size | `ServingStepper` (±10 g increments, min 10 g) | Scales displayed macros; stored in `servingGrams` |
| Edit meal | Tap meal card | Opens `EditMealSheet`; can delete individual food items |
| Delete meal | Swipe trailing | Removes `MealEntry`; updates daily totals |
| Set macro targets | Daily calories, protein, carbs, fat | Stored in `MacroTarget`; persisted separately from entries |
| Daily progress ring | — | Calorie progress arc (0–100 %); protein/carb/fat bars |

**Barcode scan states:** Success (product added + green banner) / Not found (yellow banner) / Network error (red banner).

**Feature flag:** Nutrition tracking is off by default; enabled via Account → Features → Nutrition Tracking. The Log tab segment and Progress nutrition card are hidden until enabled.

**Edge cases handled:**
- Barcode lookup timeout: 10 s `URLRequest` timeout; any error maps to `.networkError`.
- Product with no name: falls back to brand name, then "Unknown Product".
- Serving size string parsing: regex for `\d+g` pattern with a numeric fallback.
- Duplicate food selection: guarded (`contains(where: $0.id == food.id)`).

---

### 2.5 Body Weight Tracking

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Log weight | Weight (kg or lbs), date/time picker, optional notes | Creates `BodyWeightEntry`; converts lbs → kg before storing |
| Delete entry | Swipe trailing | Removes entry; updates stats |
| View trend chart | 7-day or 30-day toggle | Swift Charts line+area chart with Catmull-Rom interpolation |
| Stat cards | — | Current weight, 7-day average, 30-day delta (±) |
| Unit preference | kg / lbs (Account → Preferences) | Applies globally across display; kg always stored canonically |

**Feature flag:** Off by default; enabled via Account → Features → Body Weight Tracking.

**Edge cases handled:**
- Fewer than 2 entries → chart hidden, replaced by empty-state message.
- `monthlyChange` returns `nil` with < 2 entries in the 30-day window.
- History list capped at 20 most recent entries to limit list rendering.

---

### 2.6 AI Coach Chat

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Send message | Free-text input (1–4 lines) | Appended to message history; triggers rule-based reply (~900 ms simulated latency) |
| Contextual replies | — | Reply uses today's calories, protein target, latest weight, recent workout count, fitness goal, experience level, dietary style |
| Quick prompts | Tap a chip | Pre-fills and sends a curated question |
| Clear history | Tap trash icon | Erases `messages` array |
| AI preferences | Fitness goal (5 options), experience level (3), dietary style (6), calorie/protein/weight targets | Persisted to UserDefaults; informs all replies |

**Reply topics handled:** nutrition/calories, body weight, workouts/training, sleep/recovery, supplements, plateaus.

**Edge cases handled:**
- Empty/whitespace-only input → send button disabled.
- `isLoading` true → send button disabled; shows `TypingIndicator`.
- `recentWorkouts` hard-coded to 0 (known gap — see Section 6).

---

### 2.7 Account & Settings

| Capability | Inputs | Outputs / Side effects |
|---|---|---|
| Profile photo | System photo picker | JPEG compressed to 40% quality; stored in UserDefaults as `Data` (local-only) |
| Edit display name | Text field | Updates `authViewModel.currentUser` in memory only (not persisted to Supabase) |
| Weight unit | kg / lbs | `@AppStorage`; affects all weight displays app-wide |
| Appearance | Dark / Light / System | `@AppStorage`; passed to `preferredColorScheme` at app root |
| Workout reminders | Toggle | Requests `UNUserNotificationCenter` authorization; reverts toggle if denied |
| Feature flags | AI Chat, Nutrition, Body Weight | `@AppStorage` booleans; gate UI segments and tab content |
| AI preferences | See §2.6 | Navigates to `AIPreferencesView` |
| Routine management | — | Navigates to `RoutinesView` |
| Export workouts | Tap | Generates a plain-text export string (currently stubbed: "No workouts logged yet") |
| Sync status | — | Static "Connected" label (no real-time status) |
| Help & FAQ | — | 5 hardcoded Q&A pairs |
| Privacy Policy | — | Hardcoded text blocks |
| Contact | — | Opens `mailto:support@workouttracker.app` |
| Sign out | Tap → destructive confirm | Calls `authViewModel.signOut()` |

---

## 3. NON-FUNCTIONAL REQUIREMENTS

### 3.1 Performance

- **Startup latency:** The Keychain session check (`checkAuthState`) is async; the splash screen is shown for its duration (typically < 100 ms on cache hit, up to ~1 s on a cold token refresh). The login page never flashes.
- **Timer precision:** The workout timer uses `Timer.publish(every: 1, on: .main, in: .common)` — accurate to ±1 s, appropriate for session display.
- **Barcode lookup:** 10-second `URLRequest` timeout. The UI shows a spinner and disables the scan button during lookup.
- **AI reply latency:** Simulated 900 ms for chat, 600 ms for routine hints. No real network call.
- **Chart rendering:** Swift Charts with Catmull-Rom interpolation on up to 365 data points. No virtualization — acceptable for the expected data volume.
- **Persistence:** UserDefaults JSON encode/decode on every write. No background queuing. Acceptable for the current data volume (hundreds of entries).

### 3.2 Security

- **Supabase anon key** is hard-coded in `SupabaseService.swift`. This is a public key restricted by Row-Level Security policies on the Supabase side. It must not be a service-role key.
- **Session storage:** Handled entirely by the Supabase Swift SDK, which uses the iOS Keychain.
- **Profile photos** are stored only in UserDefaults (device-local) and never transmitted.
- **Password exposure:** Auth form has a show/hide toggle using `SecureField` / `TextField` swap. Passwords are never logged.
- **No sensitive data in URL parameters** (barcode lookup uses a path segment, not a query string).

### 3.3 Scalability / Constraints

- **Exercise library:** Currently 10 hard-coded entries. The code anticipates a Supabase-backed library (comments in `ExerciseLibraryViewModel` and `WorkoutViewModel`).
- **Food library:** 15 hard-coded entries. Open Food Facts covers millions of products via barcode.
- **Workout history:** In-memory only. As the list grows, no pagination is in place. For large history sizes this will degrade.
- **All ViewModels are `@MainActor`:** Guarantees UI updates on the main thread. Blocking operations (e.g. `URLSession.shared.data`) are awaited in async contexts.
- **Scanner session queue:** AVFoundation's blocking calls (`startRunning`, `stopRunning`) are dispatched to a dedicated `DispatchQueue` to prevent main-thread blocking.

---

## 4. SYSTEM ARCHITECTURE

### Layers

```
┌─────────────────────────────────────────────────────┐
│  Presentation Layer (Views)                         │
│  SwiftUI views, sub-components, sheets, overlays    │
├─────────────────────────────────────────────────────┤
│  ViewModel Layer                                    │
│  @MainActor ObservableObjects, business logic,      │
│  persistence coordination                           │
├─────────────────────────────────────────────────────┤
│  Service Layer                                      │
│  SupabaseService, FoodLookupService,                │
│  AIRoutineService (all singletons)                  │
├─────────────────────────────────────────────────────┤
│  Model Layer                                        │
│  Codable value types (structs + enums)              │
├─────────────────────────────────────────────────────┤
│  Persistence                          │  External   │
│  UserDefaults (JSON)                  │  Supabase   │
│  iOS Keychain (via Supabase SDK)      │  Open Food  │
│  UserDefaults (profile photo Data)    │  Facts API  │
└───────────────────────────────────────┴─────────────┘
```

### Key Modules

| Module | File(s) | Responsibility |
|---|---|---|
| App Bootstrap | `WorkoutTrackerApp.swift` | Entry point, ViewModel creation, color constants |
| Auth | `AuthViewModel.swift`, `AuthView.swift`, `SupabaseService.swift` | Login/signup/session |
| Workout | `WorkoutViewModel.swift`, `WorkoutLogView.swift`, `LogDashboardView.swift`, `HomeView.swift` | Session lifecycle, shared UI |
| Routine | `RoutineViewModel.swift`, `AIRoutineService.swift`, `RoutinesView.swift`, `SplitEditorView.swift` | Split management, AI hints |
| Nutrition | `NutritionViewModel.swift`, `FoodLookupService.swift`, `NutritionLogView.swift`, `BarcodeScannerView.swift` | Meal logging, barcode lookup |
| Body Weight | `BodyWeightViewModel.swift`, `BodyWeightLogView.swift` | Weight log, trend charts |
| AI Chat | `AIChatViewModel.swift`, `AIChatView.swift`, `AIModels.swift` | Coach chat, context assembly, preferences |
| Exercise Library | `ExerciseLibraryViewModel.swift`, `ExerciseLibraryView.swift` | Browse/filter exercises |
| Progress | `ProgressView.swift` | Charts, PR display, all-time stats |
| Account | `AccountView.swift`, `AIPreferencesView.swift` | Settings, feature flags, profile |
| Content Routing | `ContentView.swift` | Auth gate, main tab shell |

### External Dependencies

| Dependency | Purpose | Integration point |
|---|---|---|
| Supabase Swift SDK | Auth (sign-in, sign-up, session restore, sign-out) | `SupabaseService.shared.client` |
| Open Food Facts REST API | Barcode → product nutrition lookup | `FoodLookupService.lookup(barcode:)` |
| Apple Combine | Workout timer (`Timer.publisher`) | `WorkoutViewModel.startTimer()` |
| Apple AVFoundation | Camera and barcode scanning | `ScannerVC` in `BarcodeScannerView.swift` |
| Apple Swift Charts | Weight trend + nutrition + progress charts | `BodyWeightLogView`, `ProgressDashboardView`, `NutritionLogView` |
| Apple PhotosUI | Profile photo selection | `AccountView` |
| Apple UserNotifications | Workout reminder permission request | `AccountView.handleNotificationToggle()` |

---

## 5. DATA MODEL

### Core Entities

#### `Exercise`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Stable identity |
| `name` | `String` | Display name |
| `category` | `ExerciseCategory` | Strength / Cardio / Flexibility |
| `primaryMuscles` | `[MuscleGroup]` | 1+ muscles |
| `secondaryMuscles` | `[MuscleGroup]` | 0+ muscles |
| `equipment` | `Equipment` | Barbell / Dumbbell / Machine / Cable / Bodyweight / Kettlebell / Band |
| `instructions` | `String` | Coaching cue text |

#### `WorkoutSet`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `setNumber` | `Int` | 1-based display index |
| `weight` | `Double` | Kilograms |
| `reps` | `Int` | |
| `rir` | `Int` | 0–4; default 2 |
| `isCompleted` | `Bool` | |
| `setType` | `SetType` | Warmup / Working / DropSet |
| `volume` | `Double` (computed) | `weight × reps` |

#### `WorkoutExercise`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `exercise` | `Exercise` | Embedded copy |
| `sets` | `[WorkoutSet]` | |
| `notes` | `String` | |
| `totalVolume` | `Double` (computed) | Completed sets only |
| `bestSet` | `WorkoutSet?` (computed) | Heaviest completed set |

#### `WorkoutSession`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | User-editable or auto-generated |
| `date` | `Date` | Session start |
| `exercises` | `[WorkoutExercise]` | |
| `notes` | `String` | |
| `durationSeconds` | `Int?` | Set on finish |
| `totalSets` | `Int` (computed) | Completed sets only |
| `totalVolume` | `Double` (computed) | kg |
| `formattedDuration` | `String` (computed) | "1h 15m" / "45m" |

#### `WorkoutSplit`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | |
| `description` | `String` | |
| `days` | `[SplitDay]` | Ordered |
| `createdAt` | `Date` | |
| `isActive` | `Bool` | At most one active at a time |
| `aiSuggestionsEnabled` | `Bool` | Split-level flag (unused by RoutineViewModel; global flag used instead) |

#### `SplitDay`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | e.g. "Push" |
| `order` | `Int` | 0-based |
| `exercises` | `[SplitExercise]` | |
| `muscleSummary` | `String` (computed) | Up to 3 unique muscles, "·" separated |

#### `SplitExercise`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `exerciseName` | `String` | Name only; no FK to `Exercise` |
| `targetSets` | `Int` | 1–10 |
| `targetReps` | `Int` | 1–30 |
| `targetRIR` | `Int` | 0–4 |
| `order` | `Int` | 0-based |
| `targetMuscles` | `[String]` | Muscle names as strings |
| `aiHint` | `String?` | Written by `AIRoutineService` |

#### `FoodItem`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | |
| `caloriesPer100g` | `Double` | |
| `proteinPer100g` | `Double` | |
| `carbsPer100g` | `Double` | |
| `fatPer100g` | `Double` | |
| `servingGrams` | `Double` | Default 100 |
| `barcode` | `String?` | EAN/UPC if scanned |
| `calories/protein/carbs/fat` | `Double` (computed) | `per100g × servingGrams / 100` |

#### `MealEntry`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `date` | `Date` | |
| `type` | `MealType` | Breakfast / Lunch / Dinner / Snack |
| `items` | `[FoodItem]` | |
| `notes` | `String` | |
| `totalCalories/Protein/Carbs/Fat` | `Double` (computed) | Sums across items |

#### `MacroTarget`
| Field | Type | Notes |
|---|---|---|
| `calories` | `Double` | kcal/day |
| `protein` | `Double` | g/day |
| `carbs` | `Double` | g/day |
| `fat` | `Double` | g/day |

#### `BodyWeightEntry`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `date` | `Date` | |
| `weightKg` | `Double` | Canonical unit |
| `notes` | `String` | |
| `weightLbs` | `Double` (computed) | `× 2.20462` |

#### `AIMessage`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `role` | `AIRole` | `.user` / `.assistant` |
| `content` | `String` | |
| `timestamp` | `Date` | |

#### `AIPreferences`
| Field | Type | Default |
|---|---|---|
| `fitnessGoal` | `FitnessGoal` | `.buildMuscle` |
| `dietaryStyle` | `DietaryStyle` | `.standard` |
| `experienceLevel` | `ExperienceLevel` | `.intermediate` |
| `targetCalories` | `Double` | 2000 |
| `targetProteinG` | `Double` | 150 |
| `targetWeightKg` | `Double?` | `nil` |

### Validation Rules (enforced in code)

| Rule | Location |
|---|---|
| Sign-up: email and password non-empty | `AuthViewModel.signUp()` |
| Sign-up: password ≥ 6 characters | `AuthViewModel.signUp()` |
| Sign-up: full name non-empty | `AuthViewModel.signUp()` |
| Sign-in: email and password non-empty | `AuthViewModel.signIn()` |
| Split name non-empty (Save disabled) | `SplitEditorView` |
| Profile name non-whitespace (Save disabled) | `EditProfileSheet` |
| Log weight: value non-empty (Save disabled) | `LogWeightSheet` |
| RIR stepper: 0 ≤ value ≤ 4 | `RIRStepper.maxRIR = 4` |
| Serving stepper: min 10 g | `ServingStepper` (clamps to max(10, value - 10)) |
| Add meal button disabled if no items selected | `AddMealSheet` toolbar |

---

## 6. KNOWN GAPS & OPEN QUESTIONS

### Critical — Data Loss Risk

| Gap | Evidence |
|---|---|
| **Workout history is not persisted.** `WorkoutViewModel.pastSessions` is in-memory; all completed sessions are lost on app restart. | No `save()` call in `finishWorkout()`; no StorageKey in `WorkoutViewModel` |
| **Profile name edit is local-only.** `EditProfileSheet` updates the in-memory `AppUser` but never calls `SupabaseService.shared.client.auth.update(user:)`. | TODO comment in `EditProfileSheet.save()` |

### Feature Stubs

| Gap | Evidence |
|---|---|
| **AI is rule-based, not LLM-backed.** Both `AIChatViewModel.generateReply()` and `AIRoutineService.generateHint()` use keyword matching + `Task.sleep` to simulate latency. | Comments: "Swap for an Anthropic API call when ready" |
| **`recentWorkouts` hard-coded to 0** in `AIChatView.sendMessage()`. AI context is inaccurate. | Comment: "TODO: Pass WorkoutViewModel here" |
| **Workout export stubbed.** `AccountView.buildExport()` always returns "No workouts logged yet." | Hard-coded string |
| **Total Volume and Training Time on Progress screen are always "0 kg" / "0h".** `BigStatCard` values are hard-coded. | Hard-coded strings in `ProgressDashboardView.statsSection` |
| **Personal Records are placeholder data.** `mockPRs` returns static weights/reps from the first 4 sample exercises. No real PR calculation from `pastSessions`. | Named `mockPRs` in `ProgressDashboardView` |
| **Progress chart for Volume/Workouts/Sets is empty.** `chartData` returns `[]` for these three metrics. | `default: return []` in `ProgressDashboardView.chartData` |
| **Sync Status always shows "Connected".** | `SettingsInfoRow(... value: "Connected")` hard-coded |
| **No mid-session token expiry handling.** No `onAuthStateChange` listener. | Absent in `AuthViewModel.init()` |

### Missing Features

| Gap | Evidence |
|---|---|
| **`ExerciseLibraryView` has no navigation entry point.** The view and ViewModel are complete but the view is not reachable in production. | Not referenced from any tab in `MainTabView` |
| **`ExercisePickerSheet` duplicates library filtering** independently of `ExerciseLibraryViewModel`. | Two separate filter implementations |
| **No exercise-specific progress charts.** The progress screen only shows total volume, not per-exercise strength curves. | Only aggregate metrics in `ProgressDashboardView.chartData` |
| **No set editing after completion.** Sets can be toggled and values changed in-session but there is no post-session edit screen. | FAQ: "Full editing coming in a future update" |
| **Workout reminders don't schedule `UNNotification` triggers.** The toggle only requests permission; no `UNNotificationRequest` is created. | `handleNotificationToggle()` does not call `UNUserNotificationCenter.add(request:)` |
| **User-defined foods not supported.** Only 15 built-in foods + barcode scan. No "create custom food" flow. | Only `FoodItem.sampleFoods` used in the picker |
| **No iCloud or multi-device sync.** All data (except auth) is local. | UserDefaults-only persistence for all domains |

### Code-Quality TODOs

| Location | Issue |
|---|---|
| `WorkoutViewModel.startWorkout(from:in:)` | Name-based exercise look-up; fragile if exercise names diverge between `SplitExercise` and `Exercise.sampleData` |
| `BodyWeightEntry.displayWeight(unit:)` | String comparison for unit — fragile if a third unit is added; a `WeightUnit` enum is recommended |
| `WorkoutSplit.aiSuggestionsEnabled` | Field exists on the model but the global `RoutineViewModel.aiEnabled` flag is used instead; the per-split field is never read |
| `ExerciseLibraryViewModel` | `allExercises` is `private let` — it cannot observe Supabase-fetched data without a refactor |
