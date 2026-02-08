# AGENTS GUIDE

## 1. Project Overview
- **Name:** VibeStream
- **Purpose:** Cross-platform Flutter app that curates movie/TV recommendations based on a users mood, recent vibes, and streaming preferences. Users can take quick mood quizzes, view tailored recommendation stacks, and inspect detailed title pages enriched with Supabase-backed data.
- **Tech Stack:** Flutter (web + mobile), go_router for navigation, Supabase for auth/data, feature-first clean architecture, Google Fonts (Inter), theming via `AppTheme`.

## 2. Architectural Patterns & Conventions
- **Feature-First Clean Architecture:** Each feature folder contains data, domain, and presentation layers. Data handles DTOs/services, domain exposes entities/repos, presentation hosts UI + state.
- **State Management:** Cubit (flutter_bloc) is preferred; UI stays declarative and reads immutable state objects. Business logic lives in Cubits/services only.
- **Routing:** Centralized go_router setup (`core/routing/app_router.dart`) with route constants. Use `context.go`, `context.push`, `context.pop`. Never invoke Navigator directly.
- **Supabase Integration:** Configured in `lib/supabase/supabase_config.dart`. Services query Supabase tables/functions for vibes, recommendation sessions, and title metadata instead of local mocks.
- **UI System:** Reusable components in `core/widgets`. All widgets are theme-aware, use Inter typography, and avoid business logic.

## 3. Important Directories
- `lib/main.dart`: App bootstrap with router + theming.
- `lib/core/`: Shared infrastructure.
  - `routing/`: go_router config and route helpers.
  - `theme/`: Light/dark `ThemeData`, color/spacing/typography tokens.
  - `widgets/`: Reusable presentation components (cards, chips, badges, glass nav, headers).
- `lib/features/`: Feature modules (auth, onboarding, home, recommendations, mood quiz, title details, profiles, search, settings, chat, feedback, etc.). Each feature follows data/domain/presentation split.
- `lib/supabase/`: Connection config + future Supabase helpers.
- `assets/`: Packaged imagery/icons referenced via `pubspec.yaml`.
- `PROJECT_GUIDE.md`: Master reference for architecture/UI rules; keep aligned.

## 4. Code Style & Naming
- **Imports:** Absolute paths (`package:vibestream/...`). Order: Dart → Flutter → Packages → Project.
- **Files:** `snake_case.dart`; Classes: `PascalCase`; methods/properties: `camelCase`; constants: `lowerCamel` or `SCREAMING_SNAKE` for globals.
- **Widgets:** Prefer separate public classes instead of private builder functions. Break large trees into reusable widgets.
- **Theming:** Never hardcode colors; pull from `Theme.of(context)` or AppColors tokens. Support light & dark. Use `withValues(alpha: ...)` instead of `withOpacity`.
- **Fonts:** Always use Inter via theme text styles.
- **Null Safety:** Embrace `late`, `required`, and exhaustive handling; avoid unchecked null operations.
- **Logging:** Use `debugPrint` for diagnostics, especially around async errors.

## 5. Feature Implementation Patterns
1. **Data Flow:** Cubit → Repository (domain interface) → Service/DataSource (Supabase/API). Convert DTOs to domain entities before exposing to UI.
2. **Navigation:** Define route path in `AppRoutes`, wire page builder inside `GoRouter`, call `context.go/ push` from UI.
3. **Async UI:** Use `BlocBuilder`/`BlocConsumer` to react to loading, success, error states. Provide skeleton or shimmer placeholders for loading (see Title Details implementation).
4. **Reusable Components:** Compose sections using `SectionHeader`, `TitleCard`, `VibeChip`, etc. Add new shared widgets under `core/widgets` only when no existing component fits.
5. **Theme Responsiveness:** Always reference `MediaQuery` and `LayoutBuilder` for adaptive sizing, wrap long lists in `Expanded`/`Flexible`, and ensure scrollables are constrained (e.g., `Expanded(ListView...)`).
6. **Supabase Access:** Use centralized services (`RecommendationService`, `ProfileService`, etc.) for queries. Handle errors with try/catch, log, and surface graceful UI states.

## 6. Supabase Schema Management
- **ALWAYS read `docs/SUPABASE_SCHEMA.md` before any database-related work** — this is the source of truth for table names, column types, relationships, enums, and RLS policies.
- **Never assume table or column names** — always verify against the schema file first to avoid migration errors (e.g., `media_titles` vs `titles`, `profiles` vs `user_profiles`).
- **Update `docs/SUPABASE_SCHEMA.md` after schema changes** — when new tables, columns, indexes, or policies are added, immediately update the schema documentation to keep it in sync.
- **Key tables reference:**
  | Table | Purpose |
  |-------|---------|
  | `profiles` | User profiles (linked to auth.users) |
  | `media_titles` | Movies/TV shows metadata |
  | `profile_title_interactions` | User interactions (like, dislike, skip, etc.) |
  | `profile_favorites` | User's favorite titles |
  | `vibe_tags` | Mood/vibe tags for recommendations |
  | `recommendation_sessions` | Quiz sessions |
- **Enum types:** Check existing enums (e.g., `interaction_action`) before adding new action types — adding to enums requires ALTER TYPE migration.

## 7. Project-Specific Rules & Constraints
- Respect PROJECT_GUIDE.md for any architectural or design decision; update it when conventions change.
- Maintain Figma parity for spacing, typography, and colors; use theme spacing constants (`AppSpacing`) and radii (`AppRadius`).
- Support both light and dark themes in every UI addition.
- Do not use `dart:io`; for file interactions rely on cross-platform plugins (e.g., file_picker) if necessary.
- Avoid Navigator APIs, manual stack manipulation, or platform-specific code unless explicitly justified.
- Always run `compile_project` after modifications to ensure analyzer + build cleanliness.
- When working with Supabase edge functions or network calls, add appropriate CORS headers and handle failures gracefully in services.
- Component reuse is preferred; consult `core/widgets` and existing feature widgets before creating new ones.
- Keep AGENTS.md synchronized whenever core practices evolve so future agents can ramp quickly.
