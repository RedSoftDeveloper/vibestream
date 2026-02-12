import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/services/onboarding_funnel_tracker.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/data/app_user_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/supabase/supabase_config.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentPage = 0;
  // Page 3 (movie swipe personalization) is intentionally hidden for now.
  // We keep the code below for later re-enable, but the user will complete
  // onboarding on page 2.
  static const int _totalPages = 3;

  // Services
  final ProfileService _profileService = ProfileService();
  final InteractionService _interactionService = InteractionService();
  final AppUserService _appUserService = AppUserService();

  // Profile state
  String? _activeProfileId;

  // Country selection (new step)
  Country? _selectedCountry;

  // Selections for taste preferences (page 2)
  int? _movieNightSelection = 0;
  int? _discoverSelection = 0;
  int? _lengthSelection = 0;

  // Taste preference keys mapping
  static const List<String> _movieNightKeys = [
    'comfort_rewatch',
    'high_energy_action',
    'mind_bending_plots',
    'emotional_stories',
  ];
  static const List<String> _discoverKeys = [
    'friends_family_recs',
    'trending_popular',
    'critics_reviews',
    'browse_discovery',
  ];
  static const List<String> _lengthKeys = [
    'short_under_90',
    'standard_90_120',
    'epic_over_120',
    'depends_on_mood',
  ];

  // Movie swipe data (page 3)
  int _currentMovieIndex = 0;
  double _swipeOffset = 0;
  double _swipeRotation = 0;
  bool _isAnimating = false;

  bool _isSavingPreferences = false;
  
  // Recommendation session data
  RecommendationSession? _session;
  List<RecommendationCard> _cards = [];
  bool _isLoadingCards = false;
  String? _cardsError;

  @override
  void initState() {
    super.initState();
    _trackOnboardingStart();
    _initProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  static String _stepNameForIndex(int index) {
    switch (index) {
      case 0:
        return 'explain_magic';
      case 1:
        return 'country_selection';
      case 2:
        return 'taste_preferences';
      default:
        return 'unknown';
    }
  }

  void _trackOnboardingStart() {
    // Funnel should fire every time we are routed to onboarding.
    OnboardingFunnelTracker.start(
      stepIndex: _currentPage,
      totalSteps: _totalPages,
      stepName: _stepNameForIndex(_currentPage),
    );
  }

  void _trackStepViewed(int stepIndex) => OnboardingFunnelTracker.stepViewed(
    stepIndex: stepIndex,
    totalSteps: _totalPages,
    stepName: _stepNameForIndex(stepIndex),
  );

  Future<void> _initProfile() async {
    try {
      debugPrint('OnboardingPage: Starting profile initialization...');
      debugPrint('OnboardingPage: Current user: ${SupabaseConfig.auth.currentUser?.id}');
      
      final profile = await _profileService.ensureProfileExists();
      
      if (profile != null && mounted) {
        debugPrint('OnboardingPage: Profile found/created: ${profile.id}');
        setState(() => _activeProfileId = profile.id);
      } else {
        debugPrint('OnboardingPage: No profile returned - check RLS policies on profiles table');
        // Show error to user
        if (mounted) {
          setState(() {
            _cardsError = 'Could not create user profile. Please check your account setup.';
          });
        }
      }
    } catch (e) {
      debugPrint('OnboardingPage: Error initializing profile: $e');
      if (mounted) {
        setState(() {
          _cardsError = 'Failed to initialize profile: $e';
        });
      }
    }
  }

  Map<String, dynamic> _buildPreferencesJson() => {
    'movie_night': _movieNightKeys[_movieNightSelection ?? 0],
    'discover': _discoverKeys[_discoverSelection ?? 0],
    'length': _lengthKeys[_lengthSelection ?? 0],
    if (_selectedCountry != null) ...{
      'country_code': _selectedCountry!.countryCode,
      'country_name': _selectedCountry!.name,
    },
  };

  Future<void> _persistCountrySelectionIfAny() async {
    final selected = _selectedCountry;
    if (selected == null) return;

    // Store country code at the account level (app_users.region)
    // and also store (code+name) inside:
    // - profiles.country_code / profiles.country_name (used by Settings + title availability)
    // - profile_preferences.answers (used by recommendation tuning)
    try {
      await _appUserService.updateRegion(region: selected.countryCode);
    } catch (e) {
      debugPrint('OnboardingPage: Failed to update app user region: $e');
    }

    // Persist on the active profile so Settings shows the selection.
    try {
      final profileId = _activeProfileId;
      if (profileId != null) {
        // Ensure ProfileService knows which profile is active for this user.
        await _profileService.setActiveProfile(profileId);
      }
      final ok = await _profileService.updateActiveProfileCountry(
        countryCode: selected.countryCode,
        countryName: selected.name,
      );
      if (!ok) {
        debugPrint('OnboardingPage: Failed to persist country on active profile');
      }
    } catch (e) {
      debugPrint('OnboardingPage: Failed to update profile country: $e');
    }
  }

  Future<void> _savePreferencesAndLoadCards() async {
    if (_activeProfileId == null) {
      debugPrint('OnboardingPage: No active profile, cannot save preferences');
      return;
    }

    setState(() {
      _isLoadingCards = true;
      _cardsError = null;
    });

    try {
      // Save preferences to profile_preferences table
      final preferences = _buildPreferencesJson();
      await _profileService.savePreferences(_activeProfileId!, preferences);

      // Call Edge Function to get recommendation cards
      final session = await RecommendationService.createOnboardingSession(
        profileId: _activeProfileId!,
        preferences: preferences,
      );

      if (mounted) {
        setState(() {
          _session = session;
          _cards = session.cards;
          _isLoadingCards = false;
        });
      }
    } catch (e) {
      debugPrint('OnboardingPage: Error loading cards: $e');
      if (mounted) {
        setState(() {
          _cardsError = 'Failed to load recommendations. Please try again.';
          _isLoadingCards = false;
        });
      }
    }
  }

  Future<void> _savePreferencesAndCompleteOnboarding() async {
    if (_isSavingPreferences) return;

    if (_activeProfileId == null) {
      debugPrint('OnboardingPage: No active profile, cannot complete onboarding');
      if (mounted) {
        SnackbarUtils.showError(context, 'Profile not ready yet. Please try again.');
      }
      return;
    }

    setState(() {
      _isSavingPreferences = true;
    });

    try {
      await _persistCountrySelectionIfAny();
      final preferences = _buildPreferencesJson();
      final success = await _profileService.savePreferences(_activeProfileId!, preferences);
      if (!success) {
        throw Exception('Failed to save preferences');
      }
      if (!mounted) return;
      OnboardingFunnelTracker.completed(
        stepIndex: _currentPage,
        totalSteps: _totalPages,
        stepName: _stepNameForIndex(_currentPage),
      );
      context.go(AppRoutes.home);
    } catch (e) {
      debugPrint('OnboardingPage: Error saving preferences: $e');
      if (mounted) {
        SnackbarUtils.showError(context, 'Could not save preferences. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPreferences = false;
        });
      }
    }
  }

  bool get _hasMoreCards => _cards.isNotEmpty && _currentMovieIndex < _cards.length;

  void _onSwipeLeft() {
    if (_isAnimating || !_hasMoreCards) return;
    _animateSwipe(-1, InteractionAction.dislike);
  }

  void _onSwipeRight() {
    if (_isAnimating || !_hasMoreCards) return;
    _animateSwipe(1, InteractionAction.like);
  }

  void _animateSwipe(int direction, InteractionAction action) async {
    setState(() => _isAnimating = true);
    final targetOffset = direction * 400.0;
    final targetRotation = direction * 0.3;

    // Log interaction
    if (_activeProfileId != null && _cards.isNotEmpty) {
      final card = _cards[_currentMovieIndex];
      _interactionService.logInteraction(
        profileId: _activeProfileId!,
        titleId: card.titleId,
        sessionId: _session?.id,
        action: action,
        source: InteractionSource.onboardingSwipe,
      );
    }

    // Animate out
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() {
        _swipeOffset += (targetOffset - _swipeOffset) * 0.3;
        _swipeRotation += (targetRotation - _swipeRotation) * 0.3;
      });
    }

    // Reset and move to next card
    setState(() {
      _currentMovieIndex++;
      _swipeOffset = 0;
      _swipeRotation = 0;
      _isAnimating = false;
    });

    // Auto-advance to next page if all cards are done
    if (_currentMovieIndex >= _cards.length) {
      // Show completion state for 2 seconds before navigating
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _nextPage();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _swipeOffset += details.delta.dx;
      _swipeRotation = _swipeOffset / 1000;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_swipeOffset.abs() > 100 || velocity.abs() > 500) {
      if (_swipeOffset > 0 || velocity > 500) {
        _onSwipeRight();
      } else {
        _onSwipeLeft();
      }
    } else {
      // Snap back
      _snapBack();
    }
  }

  void _snapBack() async {
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() {
        _swipeOffset *= 0.6;
        _swipeRotation *= 0.6;
      });
    }
    setState(() {
      _swipeOffset = 0;
      _swipeRotation = 0;
    });
  }

  void _nextPage() {
    if (_currentPage == 1 && _selectedCountry == null) {
      OnboardingFunnelTracker.blocked(
        reason: 'country_required',
        stepIndex: _currentPage,
        totalSteps: _totalPages,
        stepName: _stepNameForIndex(_currentPage),
      );
      SnackbarUtils.showError(context, 'Please select your country to continue.');
      return;
    }

    if (_currentPage < _totalPages - 1) {
      OnboardingFunnelTracker.action(
        actionName: 'next',
        stepIndex: _currentPage,
        totalSteps: _totalPages,
        stepName: _stepNameForIndex(_currentPage),
      );
      setState(() => _currentPage++);
      _trackStepViewed(_currentPage);
      return;
    }

    // Last page (taste preferences) completes onboarding.
    OnboardingFunnelTracker.action(
      actionName: 'finish',
      stepIndex: _currentPage,
      totalSteps: _totalPages,
      stepName: _stepNameForIndex(_currentPage),
    );
    _savePreferencesAndCompleteOnboarding();
  }

  void _previousPage() {
    if (_currentPage > 0) {
      OnboardingFunnelTracker.action(
        actionName: 'back',
        stepIndex: _currentPage,
        totalSteps: _totalPages,
        stepName: _stepNameForIndex(_currentPage),
      );
      setState(() => _currentPage--);
      _trackStepViewed(_currentPage);
    } else {
      context.pop();
    }
  }

  void _skip() async {
    OnboardingFunnelTracker.action(
      actionName: 'skip_tap',
      stepIndex: _currentPage,
      totalSteps: _totalPages,
      stepName: _stepNameForIndex(_currentPage),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Skip personalization?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          'You can always update your preferences later in Settings.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(
              'Continue setup',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(
              'Skip',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (shouldSkip == true && mounted) {
      OnboardingFunnelTracker.skipped(
        stepIndex: _currentPage,
        totalSteps: _totalPages,
        stepName: _stepNameForIndex(_currentPage),
      );
      // Treat skip as onboarding complete so relaunch lands on Home.
      if (_activeProfileId == null) {
        debugPrint('OnboardingPage: Skip pressed before profile ready; navigating to home');
        context.go(AppRoutes.home);
        return;
      }

      setState(() => _isSavingPreferences = true);
      try {
        await _persistCountrySelectionIfAny();
        final preferences = _buildPreferencesJson();
        await _profileService.savePreferences(_activeProfileId!, preferences);
      } catch (e) {
        debugPrint('OnboardingPage: Error saving preferences on skip: $e');
      } finally {
        if (!mounted) return;
        setState(() => _isSavingPreferences = false);
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Top bar with back button and progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (hidden on first page)
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _previousPage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                          shape: BoxShape.circle,
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          size: 28,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const SizedBox(width: 24),
                  // Progress indicator
                  SizedBox(width: 80, child: OnboardingProgressBar(currentPage: _currentPage, totalPages: _totalPages)),
                  const SizedBox(width: 24),
                  // Invisible duplicate button for balance
                  const SizedBox(width: 48, height: 48),
                ],
              ),
              const SizedBox(height: 32),
              // Page content
              Expanded(child: _buildPageContent(context, isDark)),
              const SizedBox(height: 24),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingPreferences ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.lightSurface : AppColors.lightText,
                    foregroundColor: isDark ? AppColors.lightText : AppColors.lightSurface,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isSavingPreferences
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? AppColors.lightText : AppColors.lightSurface,
                            ),
                          )
                        : Text(
                            key: const ValueKey('text'),
                            _currentPage == _totalPages - 1 ? 'Finish' : 'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.lightText : AppColors.lightSurface,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Skip button
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(BuildContext context, bool isDark) {
    switch (_currentPage) {
      case 0:
        return _buildExplainMagicPage(context, isDark);
      case 1:
        return _buildCountrySelectionPage(context, isDark);
      case 2:
        return _buildTastePreferencesPage(context, isDark);
      default:
        return _buildExplainMagicPage(context, isDark);
    }
  }

  Widget _buildCountrySelectionPage(BuildContext context, bool isDark) {
    return OnboardingCountryStep(
      selected: _selectedCountry,
      isDark: isDark,
      onSelected: (country) => setState(() => _selectedCountry = country),
    );
  }

  Widget _buildExplainMagicPage(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explain the Magic',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          "Why we're different — it's all about the vibe",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Image.asset('assets/images/illustration.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Pick your mood, not a genre',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Feeling adventurous? Cozy? We get it. Choose how you want to feel, not what category to browse.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        /*Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _totalPages,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _currentPage ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _currentPage
                    ? (isDark ? AppColors.darkTextSecondary : AppColors.lightText)
                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),*/
      ],
    );
  }

  Widget _buildTastePreferencesPage(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your taste',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick questions to understand your preferences',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Question 1: Movie night
          Text(
            "What's your go-to movie night?",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _TasteOptionTile(
            icon: Icons.weekend_outlined,
            label: 'Cozy night in with comfort films',
            isSelected: _movieNightSelection == 0,
            onTap: () => setState(() => _movieNightSelection = 0),
          ),
          _TasteOptionTile(
            icon: Icons.bolt_outlined,
            label: 'High-energy action and thrills',
            isSelected: _movieNightSelection == 1,
            onTap: () => setState(() => _movieNightSelection = 1),
          ),
          _TasteOptionTile(
            icon: Icons.psychology_outlined,
            label: 'Mind-bending plots that make me think',
            isSelected: _movieNightSelection == 2,
            onTap: () => setState(() => _movieNightSelection = 2),
          ),
          _TasteOptionTile(
            icon: Icons.favorite_border,
            label: 'Emotional stories that touch my heart',
            isSelected: _movieNightSelection == 3,
            onTap: () => setState(() => _movieNightSelection = 3),
          ),
          const SizedBox(height: 24),
          // Question 2: Discover movies
          Text(
            'How do you usually discover movies?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _TasteOptionTile(
            icon: Icons.people_outline,
            label: 'Friends and family recommendations',
            isSelected: _discoverSelection == 0,
            onTap: () => setState(() => _discoverSelection = 0),
          ),
          _TasteOptionTile(
            icon: Icons.local_fire_department_outlined,
            label: "What's trending and popular",
            isSelected: _discoverSelection == 1,
            onTap: () => setState(() => _discoverSelection = 1),
          ),
          _TasteOptionTile(
            icon: Icons.star_border,
            label: "Critics' reviews and ratings",
            isSelected: _discoverSelection == 2,
            onTap: () => setState(() => _discoverSelection = 2),
          ),
          _TasteOptionTile(
            icon: Icons.shuffle,
            label: 'I browse until something catches my eye',
            isSelected: _discoverSelection == 3,
            onTap: () => setState(() => _discoverSelection = 3),
          ),
          const SizedBox(height: 24),
          // Question 3: Movie length
          Text(
            'Movie length preference?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _TasteOptionTile(
            icon: Icons.timer_outlined,
            label: 'Quick watch (under 90 min)',
            isSelected: _lengthSelection == 0,
            onTap: () => setState(() => _lengthSelection = 0),
          ),
          _TasteOptionTile(
            icon: Icons.access_time,
            label: 'Standard length (90-120 min)',
            isSelected: _lengthSelection == 1,
            onTap: () => setState(() => _lengthSelection = 1),
          ),
          _TasteOptionTile(
            icon: Icons.hourglass_bottom,
            label: 'Epic experience (2+ hours)',
            isSelected: _lengthSelection == 2,
            onTap: () => setState(() => _lengthSelection = 2),
          ),
          _TasteOptionTile(
            icon: Icons.mood,
            label: 'Depends on my mood',
            isSelected: _lengthSelection == 3,
            onTap: () => setState(() => _lengthSelection = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnAboutYouPage(BuildContext context, bool isDark) {
    // Show loading state
    if (_isLoadingCards) {
      return _buildLoadingState(context, isDark);
    }

    // Show error state with retry
    if (_cardsError != null) {
      return _buildErrorState(context, isDark);
    }

    // Show empty state if no cards
    if (_cards.isEmpty) {
      return _buildLoadingState(context, isDark);
    }

    // Guard against index out of range when transitioning to home
    if (_currentMovieIndex >= _cards.length) {
      return _buildCompletionState(context, isDark);
    }

    final card = _cards[_currentMovieIndex];
    
    // Calculate card height based on available space
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 280; // Account for header, buttons, safe area
    final cardHeight = availableHeight.clamp(320.0, 480.0); // Min 320, max 480
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's learn about you",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe right on films you love, left on ones you don\'t',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Movie card indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _cards.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentMovieIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentMovieIndex
                      ? (isDark ? AppColors.darkText : AppColors.lightText)
                      : index < _currentMovieIndex
                          ? AppColors.accent
                          : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Movie card with swipe animation - constrained height for scrollability
          SizedBox(
            height: cardHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next card preview (behind)
                if (_currentMovieIndex < _cards.length - 1)
                  Transform.scale(
                    scale: 0.95,
                    child: Opacity(
                      opacity: 0.5,
                      child: _RecommendationCardWidget(card: _cards[_currentMovieIndex + 1], isDark: isDark),
                    ),
                  ),
                // Current card with drag
                GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Transform.translate(
                    offset: Offset(_swipeOffset, 0),
                    child: Transform.rotate(
                      angle: _swipeRotation,
                      child: _RecommendationCardWidget(card: card, isDark: isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reject button
              GestureDetector(
                onTap: _onSwipeLeft,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.close, color: isDark ? AppColors.darkText : AppColors.lightText, size: 24),
                ),
              ),
              const SizedBox(width: 32),
              // Like button
              GestureDetector(
                onTap: _onSwipeRight,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.favorite_border, color: isDark ? AppColors.darkText : AppColors.lightText, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Swipe or tap on buttons',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            'Finding movies for you...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            'All done!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Taking you to your personalized feed...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.accent,
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _cardsError ?? 'Failed to load recommendations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _savePreferencesAndLoadCards,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.lightSurface : AppColors.lightText,
                foregroundColor: isDark ? AppColors.lightText : AppColors.lightSurface,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCardWidget extends StatelessWidget {
  final RecommendationCard card;
  final bool isDark;

  const _RecommendationCardWidget({required this.card, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapt to available height - use smaller image on shorter screens
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 450;
        final imageAspectRatio = isCompact ? 16 / 8 : 16 / 10;
        final contentPadding = isCompact ? 12.0 : 16.0;
        final spacingSmall = isCompact ? 6.0 : 8.0;
        final spacingMedium = isCompact ? 8.0 : 12.0;
        
        return Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: imageAspectRatio,
                      child: card.posterUrl != null && card.posterUrl!.isNotEmpty
                          ? Image.network(
                              card.posterUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: card.genres.take(2).map((genre) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _GlassChip(label: genre),
                        )).toList(),
                      ),
                    ),
                    if (card.quote.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              card.quote,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.accent.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RatingBadge(label: 'IMDb - ${card.rating}', isDark: isDark),
                          const SizedBox(width: 8),
                          if (card.ageRating.isNotEmpty)
                            _RatingBadge(label: card.ageRating, isDark: isDark),
                        ],
                      ),
                      SizedBox(height: spacingMedium),
                      Text(
                        card.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: spacingSmall / 2),
                      Text(
                        '${card.year}, ${card.duration}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      SizedBox(height: spacingMedium),
                      Expanded(
                        child: Text(
                          card.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            height: 1.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: isCompact ? 3 : 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() => Container(
    color: AppColors.accent.withValues(alpha: 0.2),
    child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.white54)),
  );
}

class _GlassChip extends StatelessWidget {
  final String label;

  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _RatingBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}

class _TasteOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TasteOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceVariant : Colors.transparent;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final unselectedBorderColor = isDark ? Colors.transparent : AppColors.lightBorder;
    final selectedBorderColor = isDark ? const Color(0xFFF6F6F6) : const Color(0xFF1B181C);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? selectedBorderColor : unselectedBorderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingProgressBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const OnboardingProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (currentPage + 1) / totalPages;

    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF88312C) : const Color(0xFFFEE3E1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: constraints.maxWidth * progress,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingCountryStep extends StatefulWidget {
  const OnboardingCountryStep({super.key, required this.selected, required this.onSelected, required this.isDark});

  final Country? selected;
  final ValueChanged<Country> onSelected;
  final bool isDark;

  @override
  State<OnboardingCountryStep> createState() => _OnboardingCountryStepState();
}

class _OnboardingCountryStepState extends State<OnboardingCountryStep> {
  late final List<Country> _allCountries;
  late List<Country> _filteredCountries;
  String _query = '';

  static const List<String> _suggestedCountryCodes = [
    // North America
    'US', 'CA', 'MX',
    // Western/Northern Europe (practical “top picks”)
    'GB', 'IE', 'FR', 'DE', 'NL', 'BE', 'LU', 'CH', 'AT', 'ES', 'PT', 'IT',
    'SE', 'NO', 'DK', 'FI', 'IS',
  ];

  @override
  void initState() {
    super.initState();
    _allCountries = CountryService().getAll();
    _filteredCountries = List.of(_allCountries);
  }

  void _filter(String query) {
    setState(() {
      _query = query;
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _filteredCountries = List.of(_allCountries);
        return;
      }
      _filteredCountries = _allCountries.where((c) {
        final name = c.name.toLowerCase();
        return name.contains(q) || c.countryCode.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surface = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final border = isDark ? Colors.transparent : AppColors.lightBorder;
    final dividerColor = (isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder).withValues(alpha: 0.6);

    final suggested = <Country>[];
    final byCode = {for (final c in _allCountries) c.countryCode: c};
    for (final code in _suggestedCountryCodes) {
      final c = byCode[code];
      if (c != null) suggested.add(c);
    }

    final selectedCode = widget.selected?.countryCode;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where are you right now?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'We’ll use this to tailor streaming availability for your region.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: border, width: 1),
                ),
                child: TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: 'Search country',
                    hintStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.search, color: textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_query.trim().isEmpty) ...[
                Text(
                  'Suggested',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: suggested.map((c) {
                    final isSelected = c.countryCode == selectedCode;
                    return _CountryChip(country: c, isSelected: isSelected, onTap: () => widget.onSelected(c));
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'All countries',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: _filteredCountries.length,
            (context, index) {
              final c = _filteredCountries[index];
              final isSelected = c.countryCode == selectedCode;
              final isFirst = index == 0;
              final isLast = index == _filteredCountries.length - 1;

              return Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isFirst ? AppRadius.lg : 0),
                    topRight: Radius.circular(isFirst ? AppRadius.lg : 0),
                    bottomLeft: Radius.circular(isLast ? AppRadius.lg : 0),
                    bottomRight: Radius.circular(isLast ? AppRadius.lg : 0),
                  ),
                  border: Border(
                    top: isFirst ? BorderSide(color: dividerColor, width: 1) : BorderSide.none,
                    left: BorderSide(color: dividerColor, width: 1),
                    right: BorderSide(color: dividerColor, width: 1),
                    bottom: BorderSide(color: isLast ? dividerColor : dividerColor, width: 1),
                  ),
                ),
                child: _CountryListTile(country: c, isSelected: isSelected, onTap: () => widget.onSelected(c)),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.country, required this.isSelected, required this.onTap});

  final Country country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final border = isSelected ? AppColors.accent : (isDark ? Colors.transparent : AppColors.lightBorder);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              country.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryListTile extends StatelessWidget {
  const _CountryListTile({required this.country, required this.isSelected, required this.onTap});

  final Country country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    country.countryCode,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: isSelected
                  ? const Icon(Icons.check_circle, key: ValueKey('check'), color: AppColors.accent, size: 22)
                  : Icon(Icons.chevron_right, key: const ValueKey('chev'), color: subtitleColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

