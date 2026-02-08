# VibeStream Onboarding Flow

This document describes the onboarding flow for new users in the VibeStream app.

## Overview

The onboarding flow guides new users through app introduction, taste preference collection, and initial movie rating to personalize their recommendation experience.

---

## Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           APP LAUNCH                                      │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  SPLASH PAGE (/)                                                          │
│  ─────────────                                                            │
│  • Displays animated VibeStream logo                                      │
│  • Shows tagline: "Find your vibe"                                        │
│  • Auto-navigates to Login after 2 seconds                                │
│                                                                           │
│  Buttons: None (automatic transition)                                     │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ After 2 seconds
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  LOGIN PAGE (/auth/login)                                                 │
│  ────────────────────────                                                 │
│  • Email and password input fields                                        │
│  • Social login options (Apple, Google)                                   │
│                                                                           │
│  Buttons:                                                                 │
│  ┌─────────────────┬─────────────────────────────────────────────────┐   │
│  │ "Sign in"       │ Validates credentials → Routes to Home          │   │
│  │ "Forgot pass?"  │ Routes to Forgot Password Page                  │   │
│  │ "Sign up"       │ Routes to Register Page                         │   │
│  │ "Apple"         │ Social auth (placeholder)                       │   │
│  │ "Google"        │ Social auth (placeholder)                       │   │
│  └─────────────────┴─────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ After successful login (for new users)
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  ONBOARDING PAGE (/onboarding)                                            │
│  ──────────────────────────────                                           │
│  Multi-step flow with 3 pages (detailed below)                            │
│                                                                           │
│  Global Buttons:                                                          │
│  ┌─────────────────┬─────────────────────────────────────────────────┐   │
│  │ Back (←)        │ Goes to previous page (hidden on Page 0)        │   │
│  │ "Continue"      │ Advances to next page (hidden on Page 2)        │   │
│  │ "Skip"          │ Skips entire onboarding → Routes to Home        │   │
│  └─────────────────┴─────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ After completing or skipping
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  HOME PAGE (/home)                                                        │
│  ─────────────────                                                        │
│  • Main app experience with personalized recommendations                  │
│  • Bottom navigation bar for app sections                                 │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Onboarding Page Details

The onboarding flow consists of **3 pages** within a single `OnboardingPage` widget. A progress bar at the top shows completion status.

### Page 0: Explain the Magic

**Purpose:** Introduce users to VibeStream's unique value proposition

**Content:**
- Headline: "Explain the Magic"
- Subheadline: "Why we're different — it's all about the vibe"
- Illustration image
- Feature text: "Pick your mood, not a genre"
- Description explaining mood-based recommendations
- Page indicator dots

**User Actions:**
| Button | Action |
|--------|--------|
| Back (←) | **Hidden** - This is the first page, no back navigation |
| Continue | Advances to Page 1 |
| Skip | Routes directly to Home |

---

### Page 1: Tell Us About Your Taste

**Purpose:** Collect user preferences through 3 multiple-choice questions

**Questions:**

1. **"What's your go-to movie night?"**
   - 🛋️ Cozy night in with comfort films
   - ⚡ High-energy action and thrills
   - 🧠 Mind-bending plots that make me think
   - ❤️ Emotional stories that touch my heart

2. **"How do you usually discover movies?"**
   - 👥 Friends and family recommendations
   - 🔥 What's trending and popular
   - ⭐ Critics' reviews and ratings
   - 🔀 I browse until something catches my eye

3. **"Movie length preference?"**
   - ⏱️ Quick watch (under 90 min)
   - 🕐 Standard length (90-120 min)
   - ⏳ Epic experience (2+ hours)
   - 😊 Depends on my mood

**Data Storage:** Preferences are saved to `profile_preferences` table in Supabase

**User Actions:**
| Button | Action |
|--------|--------|
| Option tiles | Selects preference (single selection per question) |
| Back (←) | Returns to Page 0 |
| Continue | Saves preferences, triggers card loading, advances to Page 2 |
| Skip | Routes directly to Home |

---

### Page 2: Let's Learn About You (Final Page)

**Purpose:** Collect initial movie ratings through swipe interaction

**Content:**
- Headline: "Let's learn about you"
- Instruction: "Swipe right on films you love, left on ones you don't"
- Progress dots showing cards completed
- Swipeable movie cards (fetched from Supabase Edge Function)
- Like/Dislike action buttons

**Movie Card Display:**
- Poster image
- Genre tags (glass chips)
- Quote from the movie
- IMDb rating badge
- Age rating badge
- Title, year, duration
- Description

**User Actions:**
| Action | Effect |
|--------|--------|
| Swipe Right / ❤️ button | Likes the movie, logs interaction, moves to next card |
| Swipe Left / ✕ button | Dislikes the movie, logs interaction, moves to next card |
| Complete all cards | **Routes to Home automatically** |
| Back (←) | Returns to Page 1 |
| Skip | Routes directly to Home |

**Note:** The "Continue" button is hidden on this page. Users advance by swiping through all cards or by tapping Skip.

**Data Storage:** 
- Interactions logged to `interactions` table via `InteractionService`
- Session created via `RecommendationService.createOnboardingSession()`

**Error Handling:**
- Loading state with spinner and "Finding movies for you..." message
- Error state with retry button

---

## Technical Implementation

### Routes (defined in `lib/core/routing/app_router.dart`)

```dart
static const String splash = '/';
static const String onboarding = '/onboarding';
static const String login = '/auth/login';
static const String register = '/auth/register';
static const String home = '/home';
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/features/onboarding/presentation/pages/splash_page.dart` | Splash screen with animated logo |
| `lib/features/onboarding/presentation/pages/onboarding_page.dart` | Multi-step onboarding flow |
| `lib/features/auth/presentation/pages/login_page.dart` | Sign in screen |
| `lib/features/auth/presentation/pages/register_page.dart` | Sign up screen |
| `lib/core/routing/app_router.dart` | Navigation configuration |

### Services Used

| Service | Purpose |
|---------|---------|
| `ProfileService` | Creates/ensures profile exists, saves preferences |
| `RecommendationService` | Creates onboarding session, fetches recommendation cards |
| `InteractionService` | Logs like/dislike interactions |
| `AuthService` | Handles user authentication |

### State Management

The `OnboardingPage` uses local `StatefulWidget` state to manage:
- `_currentPage`: Current step index (0-2)
- `_movieNightSelection`, `_discoverSelection`, `_lengthSelection`: Taste preferences
- `_currentMovieIndex`: Current card being displayed
- `_swipeOffset`, `_swipeRotation`: Card animation state
- `_cards`: List of recommendation cards
- `_isLoadingCards`, `_cardsError`: Async state

---

## Navigation Pattern

All navigation uses **go_router** via `context.go()`, `context.push()`, and `context.pop()`:

```dart
// Navigate to new route (replaces stack)
context.go(AppRoutes.home);

// Push route onto stack
context.push(AppRoutes.register);

// Pop current route
context.pop();
```

**Important:** Do NOT use `Navigator.push()` or `Navigator.pop()` directly per project conventions.

---

## Future Improvements

- [ ] Add auth state check in Splash to route returning users directly to Home
- [ ] Add onboarding completion flag to skip for returning users
- [ ] Consider adding skip confirmation dialog
- [ ] Add more movie cards variety based on initial preferences
