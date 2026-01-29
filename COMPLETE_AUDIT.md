# COMPLETE AUDIT — art.kubus + backend

## Table of Contents
- [Scope Map](#scope-map)
- [Audit Methodology](#audit-methodology)
- [Findings (Master Table)](#findings-master-table)
- [Findings by Repo](#findings-by-repo)
  - [Frontend (art.kubus)](#frontend-artkubus)
  - [Backend (art.kubus-backend)](#backend-artkubus-backend)
- [Cross-Cutting Root Causes](#cross-cutting-root-causes)
- [Verification Runs](#verification-runs)
- [Change Log](#change-log)

## Scope Map

### Repos in scope
- **Frontend**: `g:\WorkingDATA\art.kubus\art.kubus` (Flutter/Dart)
- **Backend**: `g:\WorkingDATA\art.kubus\art.kubus\backend` (Node.js/Express + Postgres/PostGIS + Redis)

### Frontend entry points and structure
- Entry: `lib/main.dart`, `lib/main_app.dart`
- Boot/initialization: `lib/core/app_initializer.dart`, `lib/services/app_bootstrap_service.dart`
- Navigation/routing: `lib/core/app_navigator.dart`, `lib/screens/**`, `lib/screens/desktop/**`
- State management: `lib/providers/**` (ChangeNotifier + ProxyProviders)
- Services: `lib/services/**`
- Widgets: `lib/widgets/**`
- Utilities: `lib/utils/**`

### Backend entry points and structure
- Entry: `backend/src/server.js`
- Routing: `backend/src/routes/**`
- Middleware: `backend/src/middleware/**`
- Services: `backend/src/services/**`
- DB/migrations: `backend/src/db/**`, `backend/migrations/**`

### Command scripts (from docs + package.json)
- Frontend:
  - `flutter analyze`
  - `flutter test`
  - `flutter run --debug`
  - `flutter build web`
- Backend:
  - `npm test`
  - `npm run lint`
  - `npm run dev`

## Audit Methodology
- Static inspection of app + backend code.
- Focused review of auth/reauth, map, analytics/telemetry, security baseline, and performance/fetch duplication.
- Evidence recorded with file path + line anchors.

## Findings (Master Table)

| ID | Severity | Category | Repo | Title | Status |
|---|---|---|---|---|---|
| _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | Open |

## Findings by Repo

### Frontend (artkubus)

#### Security
_TBD_

#### Reliability
_TBD_

#### Performance
_TBD_

#### Architecture
_TBD_

#### Tests
_TBD_

### Backend (artkubus-backend)

#### Security
_TBD_

#### Reliability
_TBD_

#### Performance
_TBD_

#### Architecture
_TBD_

#### Tests
_TBD_

## Cross-Cutting Root Causes
_TBD_

## Verification Runs
_TBD_

## Change Log
- Initial skeleton created.
