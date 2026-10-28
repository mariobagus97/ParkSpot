# ParkSpot: Product Requirements (v1)

Status: v3 · 2026-10-27 · PRD v2 and UI v3 approved by Mario; v3 records the UI decisions
Owner: Mario Bagus · Builder: Hermes (writes the code, Mario steers)

Marked **[Hermes's call]** = decided by Hermes, not yet confirmed by Mario. Change any of them.
Marked **(Mario)** = Mario's decision.

Changes in v2: photo is mandatory on save (Mario); architecture is MVVM + Coordinator (Mario); project lives on the Desktop (Mario).
Changes in v3: UI v3 (Spotify-style, dark only) picked by Mario, with its decisions in 8c; tooling, font and test choices added to 8; R14 is now dark only.

## 1. Why

People forget where they parked, and the usual fixes (remembering, a photo lost in the camera roll) break down in big lots and multi-level malls. ParkSpot saves the spot with a photo in one quick flow and walks you back to it.

It is also Mario's first Xcode app from scratch, so it should be small enough to finish and use real iPhone features (location, compass, maps, camera).

## 2. Who

- Mario first: a driver who parks on open-air streets, in open lots, and in multi-level malls.
- Anyone with an iPhone who has lost their car once.

## 3. Success looks like

- Saving a spot (tap, take photo, done) takes under about 8 seconds from opening the app.
- On a street or open lot, the arrow gets you within about 15 m of the car without looking at a map.
- In a mall garage, the photo + floor + note is enough to find the car even when GPS is off.
- Mario actually uses it for a week.

## 4. Goals, non-goals, anti-goals

**Goals (v1)**
- Quick save of the current spot with a mandatory photo **(Mario)**.
- Find mode: arrow pointing at the car plus distance, updating as you walk and turn.
- Indoor details: floor/level and short note (optional), photo (always present).
- Map view of the spot and your position, with "Walking directions" handing off to Apple Maps.
- History of recent spots.

**Non-goals (v1)** (maybe later)
- Home-screen / Lock Screen widget and Control Center button.
- Parking meter timer and reminders.
- Automatic save when the phone disconnects from CarPlay / car Bluetooth.
- Automatic floor detection with the barometer.
- Apple Watch app, sharing a spot with family, iCloud sync.
- Light mode and in-app Settings (UI v3 is dark only; the language follows the phone).

**Anti-goals** (would make it a failure even if it works)
- Accounts, sign-in, ads, or any server. Location and photos never leave the phone.
- A save flow longer than: tap "Park here" → take one photo → saved. Floor and note stay optional and come after.
- Losing the location because the photo step was slow: location capture starts at the tap, not after the photo.
- Showing a confident arrow when the GPS fix is poor. Bad accuracy must be visible.

## 5. Core flows

**Save** (photo mandatory, Mario)
1. Open app → big "Park here" button.
2. Tap → location capture starts immediately (timestamp + best fix so far), and the camera opens full screen.
3. Take the photo → spot is saved with location, accuracy, time and photo.
4. Optional sheet slides up: floor, note. Can be dismissed; the spot is already saved.
5. If the user cancels the camera: nothing is saved. The app says "A photo is needed to save your spot" with "Take photo" and "Cancel" **[Hermes's call]**.

**Find**
1. Open app with an active spot → Find screen is shown first, with the photo visible.
2. Arrow rotates toward the car using heading; distance shown in m (km above 1000 m).
3. If accuracy is poor (see 6b), the screen leads with photo, floor and note instead of the arrow, and says the arrow is rough here.
4. "Map" shows both pins. "Directions" opens Apple Maps in walking mode.
5. "Found it" ends the session; the spot moves to history.

**History**
- List of past spots (date, place name, floor, photo thumbnail). Tap to view details on map. "Use this spot again" makes it active. Swipe to delete (also deletes the photo file).

## 6. Requirements

| # | Requirement | Priority |
|---|---|---|
| R1 | Tap "Park here" starts location capture and opens the camera; spot is stored once the photo is taken; store lat/long, horizontal accuracy, timestamp, photo | Must |
| R2 | Only one active spot at a time; saving a new one moves the old to history | Must |
| R3 | Arrow bearing from current location to spot, corrected by device heading | Must |
| R4 | Live distance, m / km | Must |
| R5 | Show GPS accuracy; degrade to indoor details when it's poor | Must |
| R6 | Floor/level field (quick picker: B3…B1, G, 1…10, plus free text) | Must |
| R7 | Photo from the camera is **mandatory** on save; stored locally as JPEG; full-screen viewer with zoom on Find | Must |
| R8 | Note, up to ~140 chars | Must |
| R9 | Map with spot pin + user location; hand-off to Apple Maps walking directions | Must |
| R10 | History list with delete and "Use this spot again" | Should |
| R11 | Reverse-geocoded place name ("Jl. Sudirman", "Grand Indonesia") | Should |
| R12 | Works offline (arrow and distance need no network; map tiles may not load) | Must |
| R13 | Location and camera permissions, each with a clear screen if denied and a link to Settings | Must |
| R14 | Dark appearance only (UI v3); Dynamic Type | Should |
| R15 | English and Bahasa Indonesia | Must |

## 6b. Decisions

- **Saving without a good fix [Hermes's call].** Location capture starts at the tap, using the freshest fix (last known only if under 2 minutes old). While the user takes the photo and after, the spot keeps refining for up to 20 s or until accuracy is 20 m or better, keeping the best reading. The confirmation shows "Improving position…" while this runs. Saving never waits for GPS.
- **Spots without coordinates [Hermes's call].** Allowed when location is denied or there is no fix. `latitude`, `longitude` and `accuracy` are optional in the model; the photo is not. Such a spot can be active and appears in History; Find shows photo, floor and note, and Map/Directions are hidden.
- **Camera unavailable or denied [Hermes's call].** Saving is blocked, because the photo is mandatory. The app explains why and links to Settings. On the iOS Simulator (no camera), a debug-only photo-library picker stands in so flows can be tested; it is compiled out of release builds.
- **When the arrow shows [Hermes's call].** Only if the saved spot's accuracy and the current accuracy are both 30 m or better. Otherwise Find leads with photo, floor and note, shows distance as "about X m", and labels the arrow as rough.
- **Replacing the active spot [Hermes's call].** When an active spot exists, "Park here" asks for confirmation ("Replace your current spot?") before opening the camera.
- **Distribution (Mario).** v1 is for Mario's iPhone; App Store / TestFlight later. v1 includes a privacy manifest, real permission texts (location and camera) and an app icon so the later release needs no rework. Store review prep is out of scope.
- **Language (Mario).** English and Bahasa Indonesia from the start, with a String Catalog (`Localizable.xcstrings`); the app follows the phone's language.
- **How the build runs [Hermes's call].** Hermes creates the project, builds and runs tests from the command line (`xcodebuild`, iOS Simulator). Mario tests compass and camera on his iPhone. Build tools are allowed; the no-third-party rule applies only to code shipped in the app.

## 7. Approaches considered

| Approach | Trade-off |
|---|---|
| **A. SwiftUI + SwiftData + CoreLocation + MapKit (picked)** | Native, all on device, the least code for compass and maps, matches Xcode. iOS 17+ only. |
| B. UIKit + Core Data | Older devices and more control, but much more code for the same screens. Nothing in this app needs it. |
| C. Flutter / React Native | One codebase for Android too, but compass/heading and camera go through plugins, and Mario chose Xcode. |

A is picked **[Hermes's call]**: Mario asked for an Xcode app, and nothing here needs B or C.

## 8. Technical decisions

- Language/UI: Swift 6, SwiftUI. Minimum iOS 17 **[Hermes's call]** (SwiftData needs 17).
- Storage: SwiftData model `ParkingSpot` (id, latitude?, longitude?, accuracy?, createdAt, photoFileName, floor?, note?, placeName?, isActive). Photos saved as JPEG in Application Support/Photos, not in the database.
- Location: `CLLocationManager` for location and heading (true north when available). Bearing and distance math in the app.
- Camera: `UIImagePickerController` (camera source) wrapped for SwiftUI **[Hermes's call]**: the simplest reliable capture; a custom AVFoundation camera is not needed for v1.
- Map: SwiftUI `Map` (MapKit). Directions via `MKMapItem.openInMaps` walking mode.
- No third-party packages, no network calls besides Apple's map tiles and geocoder.
- Project location: `~/Desktop/ParkSpot` **(Mario)**.
- App name "ParkSpot" is a working title **[Hermes's call]**.
- Tooling: the Xcode project is generated with XcodeGen from `project.yml` (installed with Homebrew); `ParkSpot.xcodeproj` is never hand-edited **[Hermes's call]**.
- Bundle ID `com.mariobagus.parkspot`, iPhone only, portrait only **[Hermes's call]**.
- Font: Apple's system font (SF Pro) at UI v3's weights instead of the mockup's DM Sans, so Dynamic Type works fully and no font files ship **[Hermes's call]**.
- Tests: Swift Testing for unit tests; one XCUITest drives save → find with fake services **[Hermes's call]**.

## 8b. Architecture: MVVM + Coordinator (Mario)

```
App (ParkSpotApp)
 └─ AppCoordinator ── owns the TabView (Home · Your spots), the now-parked bar, Find full screen
     ├─ SaveCoordinator      Park here → (confirm replace) → Camera → Details sheet
     ├─ FindCoordinator      Find → Map → Photo viewer → Directions hand-off
     └─ HistoryCoordinator   History list → Spot detail
```

- **Model:** SwiftData `ParkingSpot`, plus plain value types (`Coordinate`, `Bearing`, `AccuracyLevel`).
- **View:** SwiftUI views only render state and forward user intents. They never navigate or touch services.
- **ViewModel:** one `@Observable @MainActor` class per screen (`ParkViewModel`, `FindViewModel`, `MapViewModel`, `HistoryViewModel`, `SpotDetailsViewModel`, `PermissionViewModel`). Holds screen state, calls services, and reports navigation events to its coordinator through closures or a small delegate protocol.
- **Coordinator:** `@Observable` classes that own navigation (`NavigationStack` path, sheets, full-screen covers) and build each screen with its ViewModel. A `Route` enum per coordinator lists the destinations. The coordinators decide flow order (e.g. Save → Camera → Details); ViewModels don't know what comes next.
- **Services** (injected through an `AppDependencies` container). Hardware-facing ones sit behind protocols so ViewModels test with fakes: `LocationService` (location + heading streams), `CameraAccess`, `PhotoStore`, `GeocodingService`, `MapsLauncher`. `SpotRepository` (SwiftData) is concrete and tested against an in-memory store. `SpotSaver` runs the capture-and-refine logic of the Save flow.
- **Folders:** `App/`, `Coordinators/`, `Features/<Home|Camera|Details|Find|Map|History|Permissions>/` (View + ViewModel), `Services/`, `Models/`, `UI/` (theme and shared components), `Resources/` (Localizable.xcstrings, InfoPlist.xcstrings, assets, PrivacyInfo.xcprivacy).

## 8c. UI decisions (UI v3, picked by Mario)

Source: `design/ParkSpot UI v3.html` (layout, colours, EN/ID copy).

- **Look (Mario).** Spotify-style dark UI: surfaces #121212 / #181818 / #1f1f1f / #252525, text #ffffff / #b3b3b3, green #1ed760 only on actions and the active spot, warning #ffa42b, negative #f3727f. Uppercase pill buttons, circular icon buttons, 6–8 pt photo corners.
- **Structure.** Tab bar with Home and Your spots. While a spot is active, a "now parked" bar sits above the tab bar on both tabs; tapping it opens Find full screen.
- **Find works like Now Playing.** The spot photo is the cover art. In precise mode the compass sits on it. A progress bar shows the walk back: 1 − (distance now ÷ distance when Find opened).
- **Photo tint.** Each spot stores the average colour of its photo; Find's background gradient and the now-parked bar use it.
- **Filter chips** (All / Malls / Streets) on Home and Your spots. A spot with a floor counts as Mall, without as Street **[Hermes's call]**. Your spots also has search over place name and note.
- **Changed from the mockup [Hermes's call].** The "M" avatar becomes the ParkSpot "P" mark, because there are no accounts. The Share button on the weak-GPS screen becomes Map, because sharing is a non-goal and photos never leave the phone. In-app Settings is out of v1.
- **Before App Store [Hermes's call].** Swap Spotify's exact green #1ed760 for ParkSpot's own green; it is one token, `Theme.accent`.
- **Directions hand-off (Mario, after v1).** The Directions button prefers the Google Maps app when it is installed, using the `comgooglemaps://` URL with `directionsmode=walking`, and falls back to Apple Maps otherwise. No SDK and no API key: the app still sends nothing anywhere, and its in-app map stays MapKit.
- **Platform note.** On iOS 26 and later the system tab bar draws in Apple's glass style rather than the flat bar in the mockup, and the camera keeps Apple's own shutter.

## 8d. Vehicle (Mario, after v1)

- Every spot records **what was parked**: Car, Motorbike or Bike. Mario's reason: with more than one vehicle, the thing you forget is which one you took.
- Picked on the "Spot saved" sheet, above the floor, as three chips. The sheet opens on **the previous spot's vehicle**, so parking the same one again stays a single tap, and there is always exactly one selected (tapping the current one keeps it).
- Stored as an optional raw string on the spot, so spots saved before this existed still open, as cars **[Hermes's call]**.
- Shown in three places: the now-parked bar (after the place name), the Your spots row, and the spot's detail screen. Not on Find, where the photo already answers it **[Hermes's call]**.
- No icons or SF Symbols: the vehicle is a word in the existing chip/type language, which keeps the sets honest across languages and avoids a symbol that may not exist on iOS 17 **[Hermes's call]**.
- Deliberately not stored in `UserDefaults`: "last used" comes from the newest saved spot, so the privacy manifest keeps declaring no collected data and no required-reason APIs.

## 9. Edge cases

- Location denied or "approximate location" only: explain and link to Settings; saving still works (photo + floor + note, no coordinates).
- Camera denied: saving blocked with explanation and Settings link (photo is mandatory).
- User cancels the camera: nothing saved, prompt to retake (see Save flow).
- No heading (no compass / interference): show distance and map, hide the arrow, ask the user to wave the phone (calibration).
- Saved in a garage with no GPS: store last known location with its accuracy and say so.
- Very close (< 10 m): show "You're here, look around" with the photo, instead of a spinning arrow.
- Low storage when saving the photo: show an error; the spot is not saved without its photo.

## 10. Testing

- Unit tests for bearing and distance math, the active/history rule (R2), the arrow-visibility rule, and every ViewModel with fake services.
- Coordinator tests: given an event (photo taken, cancel, replace confirmed), the right route is shown.
- Simulator with custom locations for flows (debug photo picker stands in for the camera); a real iPhone for compass and camera.

## 11. Left to the builder

Exact file names within the folder layout, animations, error copy wording. Colors, typography and icon come from the UI design step.

## 12. Next steps

1. PRD v2 and UI v3 approved by Mario.
2. Implementation plan: `docs/superpowers/plans/2026-10-27-parkspot-v1.md`.
3. Code, task by task, with tests.
