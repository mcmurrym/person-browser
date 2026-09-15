# Person Browser

A small native iPhone app for browsing records and navigating relatives, including previously loaded content offline.

## Run

Open `person-browser.xcodeproj`, select the **person-browser** scheme and an iPhone simulator running **iOS 26.0 or newer**, and press Run. No packages, keys, setup tools, or account are required. The project uses **Swift 6 language mode**; development and validation used Xcode 27.0 RC. Running on a physical iPhone requires selecting your own signing team.

Use Product → Test (⌘U) to run the tests. Unit tests use bundled fixtures and isolated temporary SwiftData databases. The UI browsing test uses the public sample service for its initial online phase.

## Decisions

### Native UI and feature organization

`People/Browse` and `People/Profile` contain the screens and their view models. `People/Data` holds the domain, response models, repository, and SwiftData implementation. `Portraits`, `Networking`, and `App` provide shared functionality. Small feature directories remain flat, and Xcode follows the directory structure automatically. Full-screen views end in `Screen`; reusable pieces end in `View`.

The interface uses standard navigation, lists, sections, semantic colors, and Dynamic Type. Records remain in service order. Sources are shown when provided. Empty occupation/source sections are omitted. Imprecise dates are displayed exactly as supplied, and living people have a “Living” lifespan label. There is no authentication, editing, search, custom navigation chrome, or prefetching of unopened profiles.

### MVVM and explicit state

Screens render `DataLoadState<Value>` and forward actions; they do not import SwiftData, decode responses, or save records. Observable main-actor view models own these transitions:

- `.initial` → `.loading` while reading saved data and performing a first fetch.
- `.success(savedContent)` immediately when saved data exists.
- A separate `VoidDataLoadState` tracks refreshes so a failed refresh cannot erase saved content.
- `.success([])` represents an empty list; `.error` represents failure without usable content.
- Cancellation restores a retryable state without displaying an error.

The generic loading state has no `Codable` constraint because rendering does not require serialization. Domain values are snapshots: repository responses explicitly update the view model. This app does not depend on `@Query` or automatic database observation. Screens refresh on entry and support pull-to-refresh.

### Network and persistence boundaries

`HTTPClient`, `PeopleRepository`, `PeopleStore`, and `PortraitLoading` are injectable interfaces. The URLSession client validates HTTP status and honors cancellation. The repository decodes separate response types, resolves portrait paths against the service URL, validates list counts/IDs and full-profile responses, and saves before returning success.

SwiftData is isolated behind a model actor created away from the main actor. SwiftData model instances do not cross that boundary; callers receive Sendable values. Network decoding and image thumbnail creation also happen off the main actor. Swift 6 checking was enabled to catch unsafe sharing at these boundaries; the starter used Swift 5 language mode.

The store has three schema models:

- **StoredPerson:** unique person ID, individual name/life-event fields, optional list order, and an explicit full-profile marker. A predicate with a fetch limit retrieves one person by ID without loading the list.
- **StoredList:** records that a list was successfully fetched, including a valid empty list.
- **StoredPortrait:** unique resolved URL and durable image bytes.

Profile-only details are encoded into a per-person payload. This keeps the ordered relatives and citations simple for 16 people; it is not a separately queryable family graph. List updates preserve that payload. Saving a new list updates membership/order but retains previously opened profiles. Writes explicitly save or roll back; save failures are surfaced instead of claiming offline availability. A store-opening failure shows Retry and does not erase the database or fall back to volatile storage.

### Portraits: persistence and display are separate

SwiftData stores original portrait bytes using `@Attribute(.externalStorage)`. The custom loader reads those records before requesting the network, validates downloaded image data, saves it, and prepares a thumbnail for the displayed size. List and profile reuse the same original bytes. Person queries do not fetch portrait bytes.

A bounded 24 MiB memory cache holds prepared images. Durable portrait records have no eviction policy in this version. Nuke was unnecessary for this small app, and an evictable image cache alone would not satisfy the offline requirement. Portrait failures display an independent placeholder with details and Retry, without blocking the person's text. The immutable CGImage wrapper has the sole explicit unchecked Sendable conformance; it has no mutable state.

An image is offline-ready after its download and save complete. Force-quitting while a request is still loading cannot preserve unfinished content. Previously opened profiles and successfully displayed portraits remain available across launches. A summary-only profile reached offline shows its known fields and an explicit unavailable-details state.

## Verification

**Results:** A fresh local clone built and launched successfully without configuration edits. 14 focused tests and 3 UI tests passed on the iPhone 17 simulator running iOS 27.0. Large-text screenshots were inspected, including adaptive list rows; dark appearance and standard back navigation are covered by the UI checks.

The focused tests cover decoding, nullable fields, display dates, malformed responses, HTTP errors, state transitions, retry/cancellation, preservation of profile details during list refresh, direct ID lookup, valid empty lists, save failures, image validation, and reopening disk-backed records and portraits without a working network.

UI tests cover a first offline launch with Retry and an online browse → terminate → offline relaunch sequence, including a saved relative profile and persisted portraits. Debug-only launch arguments inject an unavailable transport and use a separate test database; they never reset the normal app store. This makes the offline test independent of URLCache and the machine's connectivity.

### Physical-device acceptance sequence

1. Launch online and browse the list, waiting for portraits to finish loading.
2. Open two or three profiles, including one reached through a relative link.
3. Force-quit, enable Airplane Mode, and relaunch.
4. Confirm the list, saved portraits, and opened profiles render; follow the previously opened relative again.
5. Open an unvisited profile and confirm its summary remains visible with an unavailable-details message.

The simulator has no physical Airplane Mode switch. Automated testing substitutes an unavailable network transport after terminating the process; the literal Airplane Mode sequence still needs a physical-device check.

## Tradeoffs and next steps

- At **100,000 people**, the service needs pagination or incremental synchronization first. Add paged store queries and indexes for chosen filters/sort order; avoid loading or replacing the entire membership set. Normalize relatives if graph queries become necessary, and define a portrait storage budget plus explicit offline pinning/retention behavior.
- Portrait URLs are treated as stable content identifiers. A changed image at the same URL currently remains saved; a production service should provide a version or validation policy.
- No cross-device sync, editing, migrations beyond the initial schema, automatic background refresh, or proactive database-change observation. Existing content refreshes on screen entry and user request.
- Database read errors are surfaced; there is no destructive recovery or silent replacement with an empty database.
- With another day: add versioned portrait invalidation, shared in-flight request coalescing, deterministic UI service fixtures, broader accessibility/device checks, and a migration test before evolving the schema.

**Dependencies:** Apple frameworks only (SwiftUI, Observation, SwiftData, Foundation, ImageIO; Swift Testing and XCTest for tests).

**Time:** Approximately 15 minutes for implementation and verification, excluding the earlier planning discussion. AI assistance was used for implementation, tests, and review; the architecture and tradeoffs above are intended to be discussed in the interview.
