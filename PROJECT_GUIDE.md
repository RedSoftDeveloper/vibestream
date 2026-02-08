# VibeStream Project Guide

> **Master Reference Document**  
> This file is the single source of truth for the VibeStream project. All future development must follow the guidelines documented here.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Folder Structure](#2-folder-structure)
3. [State Management](#3-state-management)
4. [Routing System](#4-routing-system)
5. [Theming](#5-theming)
6. [UI Design Rules](#6-ui-design-rules)
7. [API Integration Plan](#7-api-integration-plan)
8. [Supabase Integration](#8-supabase-integration)
9. [Development Rules](#9-development-rules)
10. [Future Extensions](#10-future-extensions)

---

## 1. Project Overview

### App Name
**VibeStream**

### Purpose
A movie and TV series discovery app that helps users find content based on their mood and vibe. The app aggregates data from multiple sources to provide comprehensive information including ratings, streaming availability, and AI-powered mood classifications.

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| Backend | Supabase (Auth + Database) |
| Architecture | Clean Architecture |
| Structure | Feature-First |
| State Management | Bloc / Cubit |
| Navigation | go_router |
| Font | Inter (via Google Fonts) |

### External APIs

| API | Purpose |
|-----|---------|
| TMDB | Movie/TV metadata, search, watch providers |
| OMDb | IMDb ratings, Rotten Tomatoes, Metacritic scores |
| ChatGPT | Vibe classification, mood explanations, recommendations |

### Design Reference

**Figma File:** [VibeStream Design](https://www.figma.com/design/PgJGhun2dZdsBDTrSAfRTu/VibeStream?node-id=0-1)

> All UI must follow the Figma design exactly in layout, spacing, typography, and colors.

### Theme Support
- Full **Light Mode** support
- Full **Dark Mode** support
- System theme detection by default

---

## 2. Folder Structure

### Architecture Overview

VibeStream follows a **Feature-First Clean Architecture** pattern. This separates concerns by feature while maintaining clear boundaries between data, domain, and presentation layers.

```
lib/
├── main.dart                    # App entry point
├── core/                        # Shared/global code
│   ├── theme/                   # Theme definitions
│   ├── routing/                 # Router configuration
│   ├── widgets/                 # Reusable UI components
│   ├── services/                # Global services (Supabase, HTTP)
│   └── utils/                   # Utilities, extensions, constants
└── features/                    # Feature modules
    ├── onboarding/
    ├── auth/
    ├── home/
    ├── search/
    ├── title_details/
    └── profile/
```

### Core Folder Details

#### `core/theme/`
**Purpose:** Centralized theme definitions for the entire app.

**Contains:**
- `app_theme.dart` - Light and dark ThemeData
- Color constants (AppColors)
- Spacing constants (AppSpacing)
- Border radius constants (AppRadius)
- Typography definitions

**Rules:**
- All colors must be defined here
- No hardcoded colors in widgets
- Both light and dark variants required

#### `core/routing/`
**Purpose:** Centralized navigation configuration.

**Contains:**
- `app_router.dart` - GoRouter configuration
- Route path constants (AppRoutes)
- Navigation helpers

**Rules:**
- All routes defined in one place
- Use named routes
- Deep link ready paths

#### `core/widgets/`
**Purpose:** Reusable UI components shared across features.

**Contains:**
- `title_card.dart` - Movie/series card widget
- `vibe_chip.dart` - Mood/vibe tag chips
- `rating_badge.dart` - Rating display badges
- `section_header.dart` - Section title headers
- `streaming_provider_chip.dart` - Provider badges

**Rules:**
- Must be stateless or minimal state
- No business logic
- Configurable via parameters
- Theme-aware (light/dark)

#### `core/services/`
**Purpose:** Global services and clients.

**Will Contain:**
- Supabase client initialization
- HTTP client configuration
- Environment configuration
- Network helpers

**Rules:**
- Service initialization only
- No business logic
- Singleton patterns where appropriate

#### `core/utils/`
**Purpose:** Utilities and helpers.

**Will Contain:**
- String formatters
- Date formatters
- Extension methods
- Constants
- Validators

**Rules:**
- Pure functions preferred
- No side effects
- Well-tested utilities

### Feature Folder Structure

Each feature follows the same three-layer structure:

```
feature_name/
├── data/                        # Data layer
│   ├── datasources/             # Remote/local data sources
│   ├── models/                  # DTOs and data models
│   └── repositories/            # Repository implementations
├── domain/                      # Domain layer
│   ├── entities/                # Business entities
│   ├── repositories/            # Repository interfaces
│   └── usecases/                # Use cases (optional)
└── presentation/                # Presentation layer
    ├── pages/                   # Screen widgets
    ├── widgets/                 # Feature-specific widgets
    └── cubit/                   # State management
```

### Layer Responsibilities

#### Data Layer (`data/`)

**Purpose:** Handle all data operations and external communication.

**Contains:**
- DTOs (Data Transfer Objects)
- API data sources
- Local data sources
- Repository implementations

**Example:**
```dart
// data/models/title_dto.dart
class TitleDto {
  final String id;
  final String title;
  // ... JSON serialization
  
  factory TitleDto.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
  TitleEntity toEntity() => ...
}

// data/repositories/title_repository_impl.dart
class TitleRepositoryImpl implements TitleRepository {
  final TmdbDataSource _tmdbDataSource;
  final OmdbDataSource _omdbDataSource;
  
  @override
  Future<TitleEntity> getTitleDetails(String id) async {
    final tmdbData = await _tmdbDataSource.getDetails(id);
    final omdbData = await _omdbDataSource.getRatings(tmdbData.imdbId);
    return tmdbData.toEntity().copyWith(ratings: omdbData.toRatings());
  }
}
```

**Forbidden:**
- UI code
- Cubit/Bloc code
- Direct widget dependencies

#### Domain Layer (`domain/`)

**Purpose:** Define business logic and contracts.

**Contains:**
- Entities (pure business objects)
- Repository interfaces (abstract classes)
- Use cases (optional, for complex logic)

**Example:**
```dart
// domain/entities/title_entity.dart
class TitleEntity extends Equatable {
  final String id;
  final String title;
  final List<String> vibeTags;
  // ... pure data, no behavior
}

// domain/repositories/title_repository.dart
abstract class TitleRepository {
  Future<List<TitleEntity>> searchTitles(String query);
  Future<TitleEntity> getTitleDetails(String id);
  Future<List<TitleEntity>> getRecommendations(String titleId);
}
```

**Forbidden:**
- Framework dependencies (Flutter)
- Implementation details
- UI code

#### Presentation Layer (`presentation/`)

**Purpose:** Handle UI and user interaction.

**Contains:**
- Page widgets (screens)
- Feature-specific widgets
- Cubits/Blocs and states

**Example:**
```dart
// presentation/cubit/search_cubit.dart
class SearchCubit extends Cubit<SearchState> {
  final TitleRepository _repository;
  
  SearchCubit(this._repository) : super(SearchInitial());
  
  Future<void> search(String query) async {
    emit(SearchLoading());
    try {
      final results = await _repository.searchTitles(query);
      emit(SearchLoaded(results));
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }
}

// presentation/pages/search_page.dart
class SearchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        if (state is SearchLoading) return LoadingIndicator();
        if (state is SearchLoaded) return ResultsList(state.results);
        // ...
      },
    );
  }
}
```

**Forbidden:**
- Direct API calls
- Data parsing/serialization
- Business logic beyond UI state

### Feature Modules

| Feature | Purpose |
|---------|---------|
| `onboarding/` | Splash screen, welcome flow |
| `auth/` | Login, register, password reset |
| `home/` | Main feed, mood selection, carousels |
| `search/` | Search, filters, results |
| `title_details/` | Movie/series detail page |
| `profile/` | User settings, preferences |

---

## 3. State Management

### Why Bloc/Cubit?

VibeStream uses **Cubit** (from flutter_bloc) for state management because:

1. **Separation of concerns** - Business logic isolated from UI
2. **Testability** - Easy to unit test state changes
3. **Predictability** - Unidirectional data flow
4. **Scalability** - Pattern scales with app complexity

### Cubit Rules

#### One Cubit Per Logical Unit

```dart
// Good: One cubit per screen
class HomeCubit extends Cubit<HomeState> { ... }
class SearchCubit extends Cubit<SearchState> { ... }
class TitleDetailsCubit extends Cubit<TitleDetailsState> { ... }

// Good: Shared cubit for cross-cutting concerns
class AuthCubit extends Cubit<AuthState> { ... }
class ThemeCubit extends Cubit<ThemeState> { ... }
```

#### Immutable State

```dart
// Good: Immutable state class
class SearchState extends Equatable {
  final List<TitleEntity> results;
  final bool isLoading;
  final String? error;
  
  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });
  
  SearchState copyWith({
    List<TitleEntity>? results,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
  
  @override
  List<Object?> get props => [results, isLoading, error];
}
```

#### No UI Logic in Cubits

```dart
// Bad: UI logic in cubit
class BadCubit extends Cubit<State> {
  void onTap() {
    showDialog(...); // Wrong!
    Navigator.push(...); // Wrong!
  }
}

// Good: Pure business logic
class GoodCubit extends Cubit<State> {
  Future<void> loadData() async {
    emit(state.copyWith(isLoading: true));
    final data = await repository.getData();
    emit(state.copyWith(data: data, isLoading: false));
  }
}
```

### UI Rules

#### UI Only Consumes State

```dart
// Good: UI reacts to state
BlocBuilder<SearchCubit, SearchState>(
  builder: (context, state) {
    if (state.isLoading) {
      return const CircularProgressIndicator();
    }
    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (_, i) => TitleCard(title: state.results[i]),
    );
  },
)
```

#### UI Only Triggers Events

```dart
// Good: UI triggers cubit methods
ElevatedButton(
  onPressed: () => context.read<SearchCubit>().search(query),
  child: const Text('Search'),
)
```

### State Patterns

#### Loading/Loaded/Error Pattern

```dart
sealed class SearchState extends Equatable {
  const SearchState();
}

class SearchInitial extends SearchState {
  @override
  List<Object> get props => [];
}

class SearchLoading extends SearchState {
  @override
  List<Object> get props => [];
}

class SearchLoaded extends SearchState {
  final List<TitleEntity> results;
  const SearchLoaded(this.results);
  
  @override
  List<Object> get props => [results];
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
  
  @override
  List<Object> get props => [message];
}
```

#### Single State with Flags Pattern

```dart
class HomeState extends Equatable {
  final List<TitleEntity> trending;
  final List<TitleEntity> recommended;
  final String? selectedMood;
  final bool isLoading;
  final String? error;
  
  const HomeState({
    this.trending = const [],
    this.recommended = const [],
    this.selectedMood,
    this.isLoading = false,
    this.error,
  });
  
  // copyWith method...
}
```

---

## 4. Routing System

### Router Configuration

All routing is configured in `lib/core/routing/app_router.dart`.

```dart
// Route path constants
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String home = '/home';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String titleDetails = '/title/:id';
  
  // Helper for dynamic routes
  static String titleDetailsPath(String id) => '/title/$id';
}
```

### Required Routes

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | SplashPage | App launch, auth check |
| `/onboarding` | OnboardingPage | First-time user flow |
| `/auth/login` | LoginPage | User sign in |
| `/auth/register` | RegisterPage | New account creation |
| `/auth/forgot-password` | ForgotPasswordPage | Password reset |
| `/home` | HomePage | Main content feed |
| `/search` | SearchPage | Search and browse |
| `/profile` | ProfilePage | User settings |
| `/title/:id` | TitleDetailsPage | Movie/series details |

### Navigation Patterns

```dart
// Navigate and replace stack
context.go(AppRoutes.home);

// Push onto stack (can go back)
context.push(AppRoutes.titleDetailsPath('123'));

// Pop current route
context.pop();

// Navigate with extra data
context.push(AppRoutes.titleDetails, extra: titleEntity);
```

### Deep Link Readiness

All routes are designed for deep linking:

```
vibestream://title/550        -> Title details for ID 550
vibestream://search?q=action  -> Search with query
vibestream://profile          -> User profile
```

### Shell Route (Bottom Navigation)

The main app uses a ShellRoute for persistent bottom navigation:

```dart
ShellRoute(
  builder: (context, state, child) => MainShell(child: child),
  routes: [
    GoRoute(path: '/home', ...),
    GoRoute(path: '/search', ...),
    GoRoute(path: '/profile', ...),
  ],
)
```

---

## 5. Theming

### Theme Files

Located in `lib/core/theme/app_theme.dart`.

### Color System

```dart
class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF7C3AED);
  
  // Accent
  static const Color accent = Color(0xFFFF6B6B);
  
  // Mood colors
  static const Color moodHappy = Color(0xFFFFD93D);
  static const Color moodSad = Color(0xFF6B7FD7);
  static const Color moodExcited = Color(0xFFFF6B6B);
  static const Color moodRelaxed = Color(0xFF4ECDC4);
  // ... more moods
  
  // Rating colors
  static const Color ratingImdb = Color(0xFFF5C518);
  static const Color ratingRotten = Color(0xFFFA320A);
  static const Color ratingMeta = Color(0xFFFFCC33);
  
  // Light mode neutrals
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1A2E);
  
  // Dark mode neutrals
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkText = Color(0xFFF8F9FA);
}
```

### Spacing System

```dart
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: md);
}
```

### Border Radius

```dart
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 100.0;
}
```

### Typography

All text uses **Inter** font via Google Fonts:

```dart
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
    // ... complete theme
  );
}
```

### Theme Switching

```dart
// In MaterialApp
MaterialApp.router(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ThemeMode.system, // or .light / .dark
)

// Accessing current theme
final isDark = Theme.of(context).brightness == Brightness.dark;
final colors = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
```

### Figma Alignment Rules

1. Match exact spacing values from Figma
2. Match exact corner radii
3. Match exact font sizes and weights
4. Match exact colors (use color picker)
5. Match exact shadows and elevations

---

## 6. UI Design Rules

### Reusable Components

All shared UI components live in `lib/core/widgets/`:

| Component | File | Purpose |
|-----------|------|---------|
| TitleCard | `title_card.dart` | Movie/series poster card |
| TitleCardWide | `title_card.dart` | Horizontal list item card |
| VibeChip | `vibe_chip.dart` | Mood/vibe tag pill |
| MoodChip | `vibe_chip.dart` | Selectable mood button |
| RatingBadge | `rating_badge.dart` | IMDb/RT/MC rating display |
| SectionHeader | `section_header.dart` | Section title with "See all" |
| StreamingProviderChip | `streaming_provider_chip.dart` | Provider logo/name |

### Component Rules

```dart
// Good: Configurable, stateless component
class TitleCard extends StatelessWidget {
  final TitleEntity title;
  final VoidCallback? onTap;
  final double width;
  final bool showRating;
  
  const TitleCard({
    required this.title,
    this.onTap,
    this.width = 140,
    this.showRating = true,
  });
  
  @override
  Widget build(BuildContext context) {
    // Theme-aware implementation
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ...
  }
}
```

### Widget Rules

1. **No business logic in widgets**
   ```dart
   // Bad
   onTap: () async {
     final data = await api.fetchData(); // Wrong!
     setState(() => _data = data);
   }
   
   // Good
   onTap: () => context.read<MyCubit>().loadData(),
   ```

2. **Theme-aware colors**
   ```dart
   // Bad
   color: Colors.white,
   
   // Good
   color: Theme.of(context).colorScheme.surface,
   ```

3. **Use theme text styles**
   ```dart
   // Bad
   style: TextStyle(fontSize: 16),
   
   // Good
   style: Theme.of(context).textTheme.bodyLarge,
   ```

4. **Extract repeated widgets**
   ```dart
   // Bad: Inline complex widget trees
   
   // Good: Extract to class
   class MovieRatingRow extends StatelessWidget { ... }
   ```

### Figma Component Matching

Every Figma component should have a corresponding Flutter widget:

| Figma Component | Flutter Widget |
|-----------------|----------------|
| Movie Card | TitleCard |
| Vibe Tag | VibeChip |
| Mood Button | MoodChip |
| Rating Badge | RatingBadge |
| Section Header | SectionHeader |
| Provider Pill | StreamingProviderChip |

---

## 7. API Integration Plan

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      PRESENTATION                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Pages     │ ── │   Cubits    │ ── │   States    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        DOMAIN                                │
│  ┌─────────────┐    ┌─────────────────────────────┐        │
│  │  Entities   │    │  Repository Interfaces      │        │
│  └─────────────┘    └─────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         DATA                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │    DTOs     │    │ Repositories│    │ DataSources │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     EXTERNAL APIS                            │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │  TMDB   │    │  OMDb   │    │ ChatGPT │    │Supabase │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### TMDB Integration

**Base URL:** `https://api.themoviedb.org/3`

**Endpoints:**

| Endpoint | Purpose |
|----------|---------|
| `/search/multi` | Search movies and TV shows |
| `/movie/{id}` | Movie details |
| `/tv/{id}` | TV show details |
| `/movie/{id}/watch/providers` | Streaming availability |
| `/trending/all/week` | Trending content |
| `/discover/movie` | Browse with filters |

**Data Retrieved:**
- Title, overview, release date
- Poster and backdrop images
- Genres, runtime
- TMDB rating
- IMDb ID (for OMDb lookup)
- Watch providers by region

### OMDb Integration

**Base URL:** `http://www.omdbapi.com/`

**Parameters:**
- `i={imdbId}` - Lookup by IMDb ID
- `apikey={key}` - API key

**Data Retrieved:**
- IMDb rating and vote count
- Rotten Tomatoes critic score
- Rotten Tomatoes audience score
- Metacritic score

### ChatGPT Integration

**Purpose:** AI-powered mood analysis and recommendations.

**Use Cases:**

1. **Vibe Classification**
   ```
   Input: Movie title + overview + genres
   Output: List of vibe tags (e.g., "Mind-bending", "Feel-good", "Intense")
   ```

2. **Mood Explanation**
   ```
   Input: Movie data + assigned vibes
   Output: Short explanation of why it matches the vibe
   ```

3. **Personalized Recommendations**
   ```
   Input: User's current mood + watch history
   Output: Recommended titles with explanations
   ```

### Repository Interfaces

```dart
// domain/repositories/title_repository.dart
abstract class TitleRepository {
  Future<List<TitleEntity>> searchTitles(String query, {TitleType? type});
  Future<TitleEntity> getTitleDetails(String id);
  Future<List<TitleEntity>> getTrendingTitles({TitleType? type});
  Future<List<TitleEntity>> getTitlesByGenre(String genreId);
  Future<List<TitleEntity>> getRecommendations(String titleId);
}

abstract class RatingsRepository {
  Future<TitleRatings> getRatings(String imdbId);
}

abstract class StreamingRepository {
  Future<List<StreamingProvider>> getProviders(String titleId, {String region});
}

abstract class VibeRepository {
  Future<List<String>> classifyVibes(TitleEntity title);
  Future<String> generateVibeExplanation(TitleEntity title, List<String> vibes);
}
```

### DTO Structure

```dart
// data/models/tmdb_title_dto.dart
class TmdbTitleDto {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String releaseDate;
  final List<int> genreIds;
  
  factory TmdbTitleDto.fromJson(Map<String, dynamic> json) => ...
  TitleEntity toEntity() => ...
}

// data/models/omdb_ratings_dto.dart
class OmdbRatingsDto {
  final String imdbRating;
  final String imdbVotes;
  final List<OmdbRatingSource> ratings;
  
  factory OmdbRatingsDto.fromJson(Map<String, dynamic> json) => ...
  TitleRatings toRatings() => ...
}
```

### Current State: Mock Data

The project currently uses mock data in `lib/features/title_details/data/mock_title_data.dart`.

```dart
class MockTitleData {
  static final List<TitleEntity> mockTitles = [
    // Pre-populated sample movies and series
  ];
  
  static TitleEntity? getTitleById(String id) => ...
  static List<TitleEntity> searchTitles(String query) => ...
  static List<TitleEntity> getTrendingTitles() => ...
}
```

**Migration Path:**
1. Create data sources for each API
2. Implement repository classes
3. Replace mock data calls with repository calls
4. Add error handling and caching

---

## 8. Supabase Integration

### Authentication Strategy

**Supported Methods:**
- Email/Password
- Google OAuth
- Apple OAuth (iOS)

**Auth Flow:**
1. Check session on app launch (SplashPage)
2. Redirect to onboarding if first launch
3. Redirect to login if no session
4. Redirect to home if valid session

```dart
// Planned auth check
Future<void> checkAuth() async {
  final session = supabase.auth.currentSession;
  if (session != null) {
    context.go(AppRoutes.home);
  } else {
    context.go(AppRoutes.onboarding);
  }
}
```

### User Table Schema (Planned)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  preferred_theme TEXT DEFAULT 'system',
  preferred_region TEXT DEFAULT 'US',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Session Persistence

Supabase handles session persistence automatically:
- Tokens stored securely
- Auto-refresh of expired tokens
- Session restored on app restart

### Future Supabase Features

| Feature | Table/Function |
|---------|----------------|
| Watchlist | `watchlist` table |
| Watch History | `watch_history` table |
| User Preferences | `user_preferences` table |
| Custom Moods | `user_moods` table |
| Favorites | `favorites` table |

---

## 9. Development Rules

### Mandatory Rules

> **These rules must be followed in all future development.**

1. **Follow the folder structure**
   - All code must be placed in the correct layer and feature
   - No cross-layer imports (data cannot import presentation)

2. **Match Figma design exactly**
   - All screens must replicate the Figma design
   - Spacing, colors, typography must match

3. **Use Inter font**
   - All text must use Inter via Google Fonts
   - No other fonts unless explicitly designed

4. **Use Cubit/Bloc for state**
   - All state logic in Cubits
   - No setState for business logic
   - UI only consumes and triggers

5. **Route through central router**
   - All navigation via go_router
   - No Navigator.push direct calls
   - All routes defined in AppRoutes

6. **Separate layers strictly**
   - Data layer: API calls, DTOs, storage
   - Domain layer: Entities, interfaces
   - Presentation layer: UI, Cubits

7. **Follow repository pattern**
   - Abstract interface in domain
   - Implementation in data
   - Inject into Cubits

8. **Support both themes**
   - All UI must work in light AND dark mode
   - Use theme colors, not hardcoded values

9. **Use mock data until integration**
   - MockTitleData for development
   - Replace with real API when ready

10. **Reference this guide**
    - All future work must consult PROJECT_GUIDE.md
    - This is the source of truth

### Code Style

```dart
// File naming: snake_case
title_card.dart
home_cubit.dart
title_repository.dart

// Class naming: PascalCase
class TitleCard extends StatelessWidget
class HomeCubit extends Cubit<HomeState>
class TitleRepository

// Method naming: camelCase
Future<void> loadTitles() async
void onSearchChanged(String query)

// Constants: camelCase or SCREAMING_SNAKE_CASE
static const double defaultPadding = 16.0;
static const String API_KEY = '...';
```

### Import Order

```dart
// 1. Dart imports
import 'dart:async';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Package imports
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// 4. Project imports (absolute)
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/features/home/presentation/cubit/home_cubit.dart';
```

---

## 10. Future Extensions

### Watchlist Feature

**Description:** Allow users to save titles to watch later.

**Requirements:**
- Add to watchlist from title details
- View watchlist in profile
- Sync with Supabase
- Offline support

**Files to Create:**
- `features/watchlist/`
- `watchlist` Supabase table

---

### Custom User Moods

**Description:** Let users create and save custom mood profiles.

**Requirements:**
- Create mood with name and emoji
- Assign colors to moods
- Get recommendations by custom mood
- Sync with Supabase

**Files to Create:**
- `features/moods/`
- `user_moods` Supabase table

---

### Notifications

**Description:** Push notifications for new releases and recommendations.

**Requirements:**
- New release alerts
- Weekly recommendations
- Watchlist reminders
- Notification preferences

**Files to Create:**
- `core/services/notification_service.dart`
- `features/profile/presentation/pages/notification_settings_page.dart`

---

### Actors & Credits

**Description:** Display cast and crew information.

**Requirements:**
- Cast list on title details
- Tap to view actor filmography
- Search by actor name

**Files to Create:**
- `features/person/`
- Person entity and repository

---

### Advanced Settings

**Description:** Extended user preferences.

**Requirements:**
- Content filtering (ratings, genres)
- Streaming service preferences
- Language preferences
- Data usage settings

**Files to Create:**
- `features/settings/`
- Extended user preferences table

---

## Document Maintenance

This document should be updated when:
- New features are added
- Architecture decisions change
- New APIs are integrated
- Folder structure evolves

**Last Updated:** Initial Creation  
**Version:** 1.0.0

---

*End of PROJECT_GUIDE.md*
