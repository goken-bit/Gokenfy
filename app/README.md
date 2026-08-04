# Gokenfy

A free, ad-free, **Spotify-class music streaming app** for Android. Stream any song for free using YouTube's innertube API (the same mechanism `yt-dlp` uses) — no accounts, no keys, no server.

> Built with **Flutter**. The APK is compiled on a PC (this folder is the full project source).

## Status (milestones)
- [x] **M1** Scaffold + dark Spotify-style theme + Home / Search / Library skeleton
- [x] **M2** innertube client + working Search
- [x] **M3** Player (play/pause/seek, mini + full player, queue)
- [x] **M4** Library (likes, playlists, history, Hive persistence)
- [x] **M5** Polish (page transitions, animated equalizer, shimmer, haptics)
- [x] **M6** Android packaging guide (`BUILD.md`)
- [x] **M7** Playback smarts: speed, volume boost, crossfade, autoplay, sleep timer
- [x] **M8** Offline downloads (managed in Library, played from cache)
- [x] **M9** Synced lyrics + music-video mode
- [x] **M10** Discovery feed (curated shelves on Home)
- [x] **M11** Smart playlists, playlist folders, Spotify CSV import
- [x] **M12** Background playback + media notification (`just_audio_background`)
- [x] **M13** i18n plumbing, accessibility semantics, backup/restore
- [x] **M14** Stability polish

## Features
- Free, keyless streaming via YouTube innertube (search) + `youtube_explode_dart` (streams)
- Likes, playlists (with folders), recently played, play counts
- Smart playlists: "Most played", "Liked mix"
- Offline downloads with progress, playable from cache
- Synced lyrics (auto-scrolls to current line) with plain-text fallback
- Full-screen music video playback (`video_player`)
- Playback speed, volume boost, crossfade, autoplay ("radio"), sleep timer, shuffle & repeat
- Spotify CSV import (Liked Songs export → new playlist)
- Backup & restore your library as JSON
- Media notification + lock-screen controls + background playback
- i18n ready (flutter_localizations delegates + multi-locale list), semantic labels on controls

## Requirements (PC only)
- Flutter SDK **stable 3.27+** (recommend latest `flutter stable`)
- Android Studio / Android SDK (for building the APK), JDK 17+

## Build the APK
Open a terminal on your PC in this `app/` folder:

```bash
# 1. Generate the Android project scaffolding once (matches your Flutter version)
flutter create --org com.gokenfy --project-name gokenfy .

# 2. Install dependencies
flutter pub get

# 3. (Optional) check the code
flutter analyze

# 4. Build a release APK (smaller per-architecture builds)
flutter build apk --release --split-per-abi
```

APKs land in `build/app/outputs/flutter-apk/`. Install on your phone:

```bash
adb install build/app/outputs/flutter-apk/app-release-arm64-v8a.apk
```

or just copy that `.apk` to the phone and tap it.

## Project layout
```
app/lib/
  main.dart            entrypoint + just_audio_background init + i18n delegates
  core/theme.dart      colors + ThemeData (design tokens); haptics
  screens/             home, search, library, player, lyrics, video, settings
  widgets/             reusables (art tiles, song tiles, mini player, shimmer)
  models/              Song/Album/Artist/Playlist + state models
  services/            innertube, storage, player, downloads, CSV importer
  providers.dart       Riverpod wiring for everything
```

## Streaming note
No `yt-dlp` is bundled — it can't run inside an APK. Instead:

- **Search** talks to YouTube's innertube API directly (the exact protocol `yt-dlp`
  uses) — free, keyless, music-typed results.
- **Playback** resolves audio streams with `youtube_explode_dart`, which handles
  YouTube's signature / n-signature challenges (verified working). Streams play via
  `just_audio`.

`YoutubeExplode` and all clients live in `services/`, with config in
`services/innertube_client.dart` plain to tweak if YouTube changes something.