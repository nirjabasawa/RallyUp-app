# RallyUp

A Flutter + Firebase mobile app that helps amateur sports players find each
other, reserve courts, organise open matches, and chat — all in one
integrated experience.

Existing tools split this work across three places: court-booking apps for
the venue, generic messaging apps for organising who shows up, and DMs to
invite individual players. None of them share a real schedule or contact
graph, so it's easy to double-book yourself, lose track of who said yes,
or miss a host's last-minute cancellation. RallyUp keeps booking,
messaging, invites, and notifications inside one Firebase-backed data
model so a single tap can take you from "I want to play tennis Saturday"
to "court reserved, three friends invited, group chat ready."


---

## What's implemented

### Authentication and onboarding
- Email + password sign-up and sign-in via Firebase Authentication
- Multi-step onboarding wizard: name → email → photo → sports → location
- Profile photo capture (camera or library) uploaded to Cloudinary
- One-time GPS location capture with manual city picker fallback
- "Forgot password?" flow on the login screen and inside Account Settings
- Account deletion with the auth-first invariant (the UI never enters a
  fake signed-out state if Firebase Auth deletion fails)

### Profile and account settings
- Display name, profile photo (Cloudinary URL OR curated avatar OR
  initials), bio, age, postal code, sports played, weekly availability
- Profile visibility toggle that hides the user from discovery
- Editable avatar, sports list, and availability windows
- Optional ID verification submission (document + selfie)
- Privacy Policy + Terms of Service real content pages
- Feedback & Suggestions persisted to Firestore
- Report user → `reports/{id}` for moderator follow-up

### Courts and private bookings
- Streamed catalogue of seeded courts with Cloudinary images
- Sport / search / sort filters (default, distance, rating, lowest price)
- Distance + same-city ranking via haversine from the user's location
- Per-court details page with an image carousel
- BookCourtSheet picks sport / date / 1-hour slot / match type
- Confirm-before-write flow: nothing reaches Firestore until the user
  taps Confirm
- Live availability — already-occupied slots are removed from the picker
- MyBookings shows Upcoming / Past with tags: Confirmed / In progress /
  Completed / Cancelled
- Soft cancel from MyBookings via the 3-dot menu

### Open matches
- Hosts create an open match through PlayersSetupSheet (sets
  `playersRequired` + already-confirmed offline guests)
- Atomic join via Firestore transaction — capacity / cancelled / host-self
  / duplicate are all rejected inside the same atomic read-write
- Leave (joined player) and Cancel (host) are also transactional
- Host cancel auto-notifies joined players AND cancels every pending
  invite for the match
- Public lists hide cancelled, full, past, host's own, and already-joined
  matches
- "+1 other" / "+N others" placeholder for offline-confirmed players in
  the match players strip

### Invites
- Unified Invites page with Sent / Received tabs (no pop-based switching)
- Host opens a player's profile → Invite → picker shows only their hosted
  matches still actionable for that invitee
- Live "X / Y joined · N spots left" line on every sent-invite card
  streams the underlying open match doc
- Accept routes to MatchJoinedPage; decline notifies the host
- Host cancellation triggers a fanout: joined players get one
  notification type, pending invitees get a different one (no overlap)

### Notifications
- Per-user `notifications/{id}` collection with ten typed events
- Bell icon with live unread badge
- Tap routing by `targetType`: booking → BookingConfirmedPage; match →
  MatchDetailsPage; pending invite → Received tab; resolved invite →
  MatchDetailsPage
- Mark-all-read action
- Empty + error states

### Push notifications (FCM)
- Client-side wiring: permission prompt, multi-device FCM token capture
  to `users/{uid}.fcmTokens` via `arrayUnion`, token rotation handler,
  foreground in-app banner, cold-launch + warm-launch tap routing
- Server-side: a Cloud Function (`functions/index.js`) triggers on
  `notifications/{id}` create events and fans out FCM messages to every
  recipient device. Dead tokens are pruned from the user's array.

### Messaging
- Direct 1-to-1 chat with a deterministic thread id (`uidA_uidB` sorted)
  — one doc read finds "the thread between A and B," no `where()` query,
  no duplicate threads
- Group chat per open match with deterministic id `match_<matchId>`
- Single `threads/{threadId}` collection with `type: 'direct' | 'group'`
- Three tabs in Messages: All (direct only), Unread (merged direct +
  group), Groups
- Per-user `lastReadAtByUser` map drives the unread state. Opening a chat
  is the only path that bumps the read marker — visiting MessagesPage /
  GroupMessagesPage / UnreadMessagesPage does not
- Group chat auto-creates on match create; new joiners get added via
  `arrayUnion`; leavers get removed via `arrayRemove`

### Schedule conflict prevention
Two distinct conflicts are checked before every write that creates or
joins a session:
- **Court occupancy** — a court cannot host two overlapping reservations.
  Active sources: confirmed bookings + non-cancelled open matches on that
  court.
- **User schedule** — a user cannot be in two overlapping active sessions
  even at different courts. Active sources: their bookings, hosted
  matches, and matches their uid is in `joinedPlayerIds` for.

Both use the canonical interval overlap test
(`existingStart < newEnd && newStart < existingEnd`) so 6:00–7:00 PM
correctly rejects 6:30–7:30 PM. Insertion points: `createBooking`,
`createOpenMatch`, `joinOpenMatch`, and (via delegation)
`acceptInvite`. Friendly SnackBar messages distinguish "court already
booked" from "you already have another session."

### Admin / moderation
- Hidden in-app review queue gated by a hardcoded allow-list of admin
  emails
- Streams every user whose `idVerification.status == 'submitted'`
- Reviewer can open the uploaded document images, approve or reject, and
  attach an optional note
- The row disappears from the queue the moment the status flips

### Image handling
- Cloudinary unsigned upload via `ImageUploadService`
- Used by profile photo and ID verification documents
- Court images are pre-seeded Cloudinary URLs (`f_auto,q_auto` for
  client-appropriate format + quality)
- Shared `CourtNetworkImage` widget renders a placeholder for null /
  empty / network errors so the UI never shows a broken-image icon

### Location and distance
- `geolocator` + `geocoding` for GPS capture and reverse geocode
- Persisted under `users/{uid}.location` as `{ lat, lng, city, region,
  country, source }`
- Manual override via the location-picker bottom sheet (used from
  Courts, Nearby Players, and the home top header)
- Haversine distance ranking, displayed in miles

---

## Technology stack

### Frontend
| Tech | Purpose |
|---|---|
| Flutter (Dart) | Single codebase for iOS + Android |
| Provider | State management (auth + signup form) |
| `intl` | Locale-aware date and time formatting |
| `cached_network_image` | Cloudinary image loading with placeholder + error fallback |
| `image_picker` + `permission_handler` | Camera / library access with permission prompts |
| `geolocator` + `geocoding` | GPS capture and city resolution |
| `http` | Cloudinary upload (multipart POST) |

### Backend (Firebase)
| Product | How it's used |
|---|---|
| Firebase Authentication | Email + password, password reset, account deletion |
| Cloud Firestore | Primary data store: 10 collections, real-time streams, transactional writes |
| Firebase Cloud Messaging | Client token capture + foreground / background / cold-launch tap routing |
| Firebase Storage | Declared (some image flows; Cloudinary is the primary store) |
| Cloud Functions (Node.js) | `functions/index.js` — server-side push sender triggered on `notifications/{id}` create |

### Third-party
| Service | Purpose |
|---|---|
| Cloudinary | Unsigned upload for profile photos, ID verification documents, seeded court images |

---

## Firestore data model

Ten collections, all queries are single-field equality so no composite
indexes are required.

| Collection | Purpose |
|---|---|
| `users/{uid}` | Profile snapshot (name, photo, bio, sports, availability, location, profileVisible, idVerification, FCM tokens) |
| `courts/{id}` | Court catalogue (name, address, sports, price/hour, rating, image URLs) |
| `bookings/{id}` | Confirmed private court reservations |
| `open_matches/{id}` | Open matches with parallel join arrays + offline-confirmed guest count |
| `invites/{id}` | One invite from a host to one specific player for one match, with pinned snapshots of both sides |
| `threads/{id}` | Direct AND group chat threads (`type` discriminator, lastMessage previews, per-uid read markers) |
| `threads/{id}/messages/{messageId}` | Individual chat messages |
| `notifications/{id}` | Per-user notification feed (10 typed events) |
| `feedback/{id}` | User feedback / bug reports |
| `reports/{id}` | "Report another user" submissions |

---

## Project structure

```
lib/
├── main.dart                  ← MaterialApp + global navigator key + MainShell
├── firebase_options.dart      ← FlutterFire CLI output
├── core/                      ← Cloudinary config
├── theme/                     ← AppColors, AppSpacing, AppTextStyles
├── utils/                     ← booking_slots, sport_emoji
├── models/                    ← 12 immutable data classes
├── providers/                 ← AuthProvider + SignupFormProvider (ChangeNotifier)
├── services/                  ← 16 Firestore / external service classes
├── screens/                   ← page widgets organised by feature
│   ├── login/                 ← onboarding + sign-in
│   ├── home/
│   ├── messages/              ← All / Unread / Group tabs
│   ├── player_details/        ← Nearby Players, profile, invites,
│   │                            match details, group chat, DMs
│   ├── profile/               ← profile + settings + legal + feedback
│   └── admin/                 ← admin-only ID verification queue
└── widgets/                   ← reusable presentational widgets

functions/                     ← Node.js Cloud Function (FCM sender)
docs/                          ← Project report sources (.docx, .html)
```

### Scale
- 29,208 lines of Dart across `lib/`
- 145 Dart files (12 models, 16 services, 2 providers, plus screens and widgets)
- 1 Node.js Cloud Function

### Notable engineering decisions
- **Deterministic thread ids** for both direct and group chats — one doc
  read by id beats a query and structurally prevents duplicates.
- **Snapshot fields written into create-time docs** (host name, court
  image URL, sport type, …) so list cards don't need follow-up reads and
  a profile rename doesn't retroactively rewrite history.
- **Parallel arrays with index-aware rebuilds** for joined players — leave
  finds the index, removes from both arrays in the same transaction,
  never `arrayRemove` on the uid alone (which would desync the names).
- **Transactional concurrency** on join, leave, host-cancel, and
  invite-accept — capacity / cancelled / duplicate are all asserted
  inside the same atomic read-write.
- **Best-effort side effects** (notification writes, group-thread
  updates, FCM token writes) all `catchError` so a Firestore rules blip
  never rolls back a successful primary mutation.
- **Single `MaterialApp` + a `MainShell` singleton.** Pushed routes never
  replace the shell; tab switching from any pushed route pops to the
  root and flips an `IndexedStack` via a global key. This keeps
  `AuthGate` in the stack so sign-out always lands cleanly on the
  unauthenticated branch.
- **Root `navigatorKey` + `scaffoldMessengerKey`** so the FCM tap handler
  can route + toast without a `BuildContext`.

---

## Getting started

### Prerequisites
- Flutter SDK
- Xcode (for iOS) or Android Studio (for Android)
- A Firebase project
- A Cloudinary account (free tier is enough)
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### One-time setup
```bash
# 1. Wire FlutterFire into the project (regenerates firebase_options.dart)
flutterfire configure

# 2. Cloudinary — edit lib/core/cloudinary_config.dart with your
#    cloudName and unsigned upload preset name

# 3. Admin allow-list — add your email to AdminService._adminEmails
#    in lib/services/admin_service.dart to access the moderator queue

# 4. Install Flutter dependencies
flutter pub get
```

### Run the app
```bash
# All connected devices
flutter run

# Specific device
flutter devices
flutter run -d <device_id>
```

### Deploy the Cloud Function (push sender)
```bash
cd functions
npm install
firebase login
firebase use --add        # pick the RallyUp project
firebase deploy --only functions
```

After this deploy, any new doc written to `notifications/{id}` triggers
the function and the recipient's devices receive a push.

### Optional
- **iOS production push** — upload an APNs auth key in the Firebase
  console (Project Settings → Cloud Messaging) and add an APNs
  entitlement on the iOS build. On the iOS simulator the FCM token is
  null; expected.
- **Android push** — `google-services.json` placed at `android/app/` is
  enough.

---

## Future work

Items intentionally out of scope for this submission:
- **Skill-level and peer rating system.** Player cards currently show a
  placeholder rating (no real data backing).
- **Monetization.** The Subscription screen is a UI mock — real
  subscriptions need a payment gateway (Stripe / RevenueCat / IAP).
- **Optional message attached to an invite.** Invite carries pinned
  snapshots but no free-text message from the host.
- **Group chat participant controls.** No leave-group, mute, kick, or
  remove — only the host's cancel-the-match action affects membership.
- **Variable-length bookings.** Every slot is currently 1 hour;
  `totalPrice` always equals `pricePerHour`.
- **Schedule conflict hardening.** The pre-flight check runs as a
  Firestore read before the write. A future hardening would move it
  inside the same `runTransaction` or back it with a per-court-day-slot
  lock document to close a small TOCTOU window.
- **Geo-bounded user query.** Nearby Players currently scans the full
  users collection client-side.
- **Notification archive.** Only mark-as-read exists today; no
  bulk-delete / archive.

---

## Authors

- Allurkar Sneha
- Nirja Basawa
- Answeeta Pereira

Developed as part of the SCU CSEN268 Flutter mobile application project.
