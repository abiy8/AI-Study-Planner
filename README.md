# AI Study Planner

A Flutter application for organizing courses, tracking study tasks, and requesting syllabus-based task plans through an external AI backend.

**Stack:** Flutter · Dart · Firebase Authentication · Cloud Firestore · Material 3

## Features represented in the code

- Google sign-in and authentication state handling.
- Course and task screens backed by Firestore services.
- Syllabus upload / text submission through an HTTP API client.
- Google Calendar event-creation links and local notification services (not automatic calendar synchronization).
- Progress tracking and course detail views.

## Architecture

`Flutter screens → Firebase auth streams / service layer → Firebase Auth + Firestore`

`Syllabus input → HTTP API client → separately hosted task-generation backend → task models`

## Current build status

The checked-in Firestore service has existing compile blockers: helper methods appear outside the class before imports, reference class-private fields, and call a missing `TaskModel.fromFirestore` factory. This README-only change does not fix application code. The commands below describe the intended setup, not a verified clean build. The included widget test still expects the starter counter app and does not match this implementation.

## Run locally

```bash
git clone https://github.com/abiy8/AI-Study-Planner.git
cd AI-Study-Planner
flutter pub get
flutter run
```

Use a Flutter installation compatible with Dart `>=3.1.0 <4.0.0`. Configure your own Firebase project, enable Google authentication and Cloud Firestore, register the target app, configure Android SHA fingerprints / OAuth as appropriate, and generate matching FlutterFire configuration. Firestore rules are not included, so user isolation must be enforced in your Firebase project. The checked-in Firebase client configuration is not a server credential. Notification support is configured for Android/iOS; the presence of other platform folders does not establish working web/desktop support.

## Backend requirements

This repository contains the Flutter client. The Node.js backend described in the previous README is **not included**. AI generation requires a separate backend exposing `/api/generate-tasks` and `/api/generate-tasks-from-file` on port 3000. The client uses `10.0.2.2` for Android emulators and `localhost` for other platforms; physical devices require a reachable backend address. Backend API credentials belong on the server.

## Repository map

- `lib/screens/` — authentication, courses, planner, calendar, and task views.
- `lib/services/` — authentication, Firestore, API, accounts, and notifications.
- `lib/models/` — course and task data models.
- `lib/state/` — authentication state.
- `assets/mock/` — example course and task data.

## Project status and provenance

This is an application project whose end-to-end behavior depends on Firebase and a separately supplied backend. No live demo or production-readiness claim is made here. The previous README referenced [yeabsira-mesfin/Planner](https://github.com/yeabsira-mesfin/Planner); that reference is preserved for transparency without claiming sole original authorship. The existing usage restriction remains: private project, not for public reuse.
