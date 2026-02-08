import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class ShareExperiencePage extends StatefulWidget {
  final String titleId;
  final String? sessionId;
  final bool fromRecommendations;
  final List<String> remainingTitleIds;
  final bool showBackButton;

  const ShareExperiencePage({
    super.key, 
    required this.titleId, 
    this.sessionId,
    this.fromRecommendations = false,
    this.remainingTitleIds = const [],
    this.showBackButton = true,
  });

  @override
  State<ShareExperiencePage> createState() => _ShareExperiencePageState();
}

class _ShareExperiencePageState extends State<ShareExperiencePage> {
  final ProfileService _profileService = ProfileService();
  final InteractionService _interactionService = InteractionService();
  
  // Static cache to avoid repeated fetches when navigating back and forth
  static final Map<String, TitleDetail> _titleCache = {};
  
  TitleDetail? _title;
  bool _isLoading = true;
  bool _isLoadingRemainingTitles = true;
  bool _isSubmitting = false;
  bool _hasNoPendingTitles = false;
  int _selectedMoodRating = 4;
  bool? _wouldWatchAgain;
  final Set<String> _selectedTags = {};
  final TextEditingController _feedbackController = TextEditingController();
  
  // Tracking for skip functionality in recommendation flow
  late String _currentTitleId;
  late List<String> _remainingTitles;
  int _currentIndex = 0;

  final List<String> _quickTags = [
    'Amazing story',
    'Great acting',
    'Perfect length',
    'Excellent pacing',
    'Too slow',
    'Boring plot',
    'Bad ending',
    'Predictable',
    'Too emotional',
    'Wrong genre',
  ];

  @override
  void initState() {
    super.initState();
    _currentTitleId = widget.titleId;
    // Build remaining titles list: current title + any additional remaining titles
    _remainingTitles = [widget.titleId, ...widget.remainingTitleIds.where((id) => id != widget.titleId)];
    _initializePage();
  }

  Future<void> _initializePage() async {
    // If we already have remaining titles passed (from RecommendationResultsPage), use them
    if (widget.remainingTitleIds.isNotEmpty) {
      setState(() {
        _isLoadingRemainingTitles = false;
      });
      _loadTitle();
      return;
    }

    final profileId = _profileService.selectedProfileId;
    
    // Try to show cached title immediately (stale-while-revalidate)
    if (_titleCache.containsKey(widget.titleId)) {
      debugPrint('ShareExperiencePage: Using cached title immediately: ${_titleCache[widget.titleId]!.title}');
      setState(() {
        _title = _titleCache[widget.titleId];
        _isLoading = false;
        _isLoadingRemainingTitles = false;
      });
      
      // Fetch pending titles in background (won't show shimmer)
      if (profileId != null) {
        _fetchPendingTitlesInBackground(profileId);
      }
      return;
    }

    // Otherwise, fetch pending feedback titles for this profile
    if (profileId == null) {
      setState(() {
        _isLoadingRemainingTitles = false;
      });
      _loadTitle();
      return;
    }

    // Check for cached pending titles first
    if (InteractionService.hasPendingTitlesCache(profileId)) {
      final cachedPending = InteractionService.getCachedPendingTitles(profileId);
      if (cachedPending != null) {
        _processPendingTitles(cachedPending, profileId);
        
        // Refresh in background if stale
        if (InteractionService.isPendingTitlesCacheStale(profileId)) {
          _refreshPendingTitlesInBackground(profileId);
        }
        return;
      }
    }

    // No cache - fetch from network
    try {
      final pendingTitles = await _interactionService.getPendingFeedbackTitleIds(
        profileId: profileId,
      );

      if (!mounted) return;
      _processPendingTitles(pendingTitles, profileId);
    } catch (e) {
      debugPrint('ShareExperiencePage: Error fetching pending titles: $e');
      setState(() {
        _isLoadingRemainingTitles = false;
      });
      _loadTitle();
    }
  }

  void _processPendingTitles(List<String> pendingTitles, String profileId) {
    if (pendingTitles.isEmpty) {
      // No pending titles at all - show empty state
      setState(() {
        _hasNoPendingTitles = true;
        _isLoadingRemainingTitles = false;
        _isLoading = false;
      });
      return;
    }

    // Check if current title has feedback already
    final currentTitleHasFeedback = !pendingTitles.contains(widget.titleId);
    
    if (currentTitleHasFeedback && pendingTitles.isNotEmpty) {
      // Current title already has feedback, use first pending title instead
      _currentTitleId = pendingTitles.first;
      _remainingTitles = pendingTitles;
    } else {
      // Include current title and add other pending titles
      _remainingTitles = [
        widget.titleId,
        ...pendingTitles.where((id) => id != widget.titleId),
      ];
    }

    setState(() {
      _isLoadingRemainingTitles = false;
    });
    _loadTitleById(_currentTitleId);
  }

  Future<void> _fetchPendingTitlesInBackground(String profileId) async {
    try {
      final pendingTitles = await _interactionService.getPendingFeedbackTitleIds(
        profileId: profileId,
      );
      
      if (!mounted) return;
      
      if (pendingTitles.isEmpty) {
        setState(() {
          _hasNoPendingTitles = true;
        });
        return;
      }

      // Update remaining titles list without triggering shimmer
      final currentTitleHasFeedback = !pendingTitles.contains(widget.titleId);
      
      if (currentTitleHasFeedback && pendingTitles.isNotEmpty) {
        _currentTitleId = pendingTitles.first;
        _remainingTitles = pendingTitles;
        // Need to load the new title
        _loadTitleById(_currentTitleId);
      } else {
        _remainingTitles = [
          widget.titleId,
          ...pendingTitles.where((id) => id != widget.titleId),
        ];
      }
    } catch (e) {
      debugPrint('ShareExperiencePage: Background fetch of pending titles failed: $e');
    }
  }

  Future<void> _refreshPendingTitlesInBackground(String profileId) async {
    try {
      await _interactionService.getPendingFeedbackTitleIds(
        profileId: profileId,
        forceRefresh: true,
      );
      debugPrint('ShareExperiencePage: Background refresh of pending titles completed');
    } catch (e) {
      debugPrint('ShareExperiencePage: Background refresh of pending titles failed: $e');
    }
  }
  
  bool get _hasMoreTitles => _currentIndex < _remainingTitles.length - 1;
  
  void _skipToNextTitle() {
    if (!_hasMoreTitles) {
      _finishFeedbackFlow();
      return;
    }
    
    setState(() {
      _currentIndex++;
      _currentTitleId = _remainingTitles[_currentIndex];
      _isLoading = true;
      // Reset form fields for new title
      _selectedMoodRating = 4;
      _wouldWatchAgain = null;
      _selectedTags.clear();
      _feedbackController.clear();
    });
    
    _loadTitleById(_currentTitleId);
  }
  
  void _goToNextOrFinish() {
    if (_hasMoreTitles) {
      setState(() {
        _currentIndex++;
        _currentTitleId = _remainingTitles[_currentIndex];
        _isLoading = true;
        // Reset form fields for new title
        _selectedMoodRating = 4;
        _wouldWatchAgain = null;
        _selectedTags.clear();
        _feedbackController.clear();
      });
      _loadTitleById(_currentTitleId);
    } else {
      _finishFeedbackFlow();
    }
  }
  
  void _finishFeedbackFlow() {
    // Navigate to home when all feedback is done
    if (mounted) {
      SnackbarUtils.showSuccess(context, 'All done! Thanks for your feedback.');
      context.go('/home');
    }
  }

  Future<void> _loadTitle() async {
    await _loadTitleById(_currentTitleId);
  }
  
  Future<void> _loadTitleById(String titleId) async {
    debugPrint('ShareExperiencePage: Loading title with id: $titleId, sessionId: ${widget.sessionId}');
    
    // Check cache first
    if (_titleCache.containsKey(titleId)) {
      debugPrint('ShareExperiencePage: Found title in cache: ${_titleCache[titleId]!.title}');
      if (mounted) {
        setState(() {
          _title = _titleCache[titleId];
          _isLoading = false;
        });
      }
      return;
    }
    
    try {
      final title = await RecommendationService.getTitleById(titleId);
      debugPrint('ShareExperiencePage: Loaded title: ${title?.title ?? 'null'}');
      
      // Cache the title for future use
      if (title != null) {
        _titleCache[titleId] = title;
        // Limit cache size to prevent memory issues
        if (_titleCache.length > 20) {
          _titleCache.remove(_titleCache.keys.first);
        }
      }
      
      if (mounted) {
        setState(() {
          _title = title;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ShareExperiencePage: Error loading title: $e');
      if (mounted) {
        setState(() {
          _title = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show shimmer while loading remaining titles or title details
    if (_isLoadingRemainingTitles || _isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(isDark: isDark, onBack: widget.showBackButton ? () => context.pop() : null, showBackButton: widget.showBackButton),
              Expanded(
                child: _ShareExperienceShimmer(isDark: isDark),
              ),
            ],
          ),
        ),
      );
    }

    // Show empty state with party popper when no titles need feedback
    if (_hasNoPendingTitles) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(isDark: isDark, onBack: widget.showBackButton ? () => context.pop() : null, showBackButton: widget.showBackButton),
              Expanded(
                child: _AllFeedbackCompleteState(isDark: isDark),
              ),
            ],
          ),
        ),
      );
    }

    if (_title == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(isDark: isDark, onBack: widget.showBackButton ? () => context.pop() : null, showBackButton: widget.showBackButton),
              const Expanded(
                child: Center(
                  child: Text('Title not found'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(isDark: isDark, onBack: widget.showBackButton ? () => context.pop() : null, showBackButton: widget.showBackButton),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _MoviePosterCard(title: _title!, isDark: isDark),
                    const SizedBox(height: 28),
                    _MoodRatingSection(
                      isDark: isDark,
                      selectedRating: _selectedMoodRating,
                      onRatingChanged: (r) => setState(() => _selectedMoodRating = r),
                    ),
                    const SizedBox(height: 28),
                    _FeedbackInputSection(
                      isDark: isDark,
                      controller: _feedbackController,
                    ),
                    const SizedBox(height: 28),
                    _WatchAgainSection(
                      isDark: isDark,
                      selectedOption: _wouldWatchAgain,
                      onOptionChanged: (v) => setState(() => _wouldWatchAgain = v),
                    ),
                    const SizedBox(height: 28),
                    _QuickTagsSection(
                      isDark: isDark,
                      tags: _quickTags,
                      selectedTags: _selectedTags,
                      onTagToggle: (tag) => setState(() {
                        if (_selectedTags.contains(tag)) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      }),
                    ),
                    const SizedBox(height: 32),
                    _SubmitButton(isDark: isDark, onTap: _submitFeedback, isLoading: _isSubmitting, isEnabled: _wouldWatchAgain != null),
                    const SizedBox(height: 12),
                    _SkipButton(
                      isDark: isDark, 
                      onTap: _skipToNextTitle,
                      hasMoreTitles: _hasMoreTitles,
                    ),
                    const SizedBox(height: 20),
                    _FooterText(isDark: isDark),
                    const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    final profileId = _profileService.selectedProfileId;
    
    if (profileId == null) {
      debugPrint('ShareExperiencePage: No profile selected');
      _showError('Please select a profile first');
      return;
    }
    
    if (_title == null) {
      debugPrint('ShareExperiencePage: No title loaded');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final success = await _interactionService.logInteraction(
        profileId: profileId,
        titleId: _currentTitleId,
        sessionId: widget.sessionId,
        action: InteractionAction.feedback,
        source: InteractionSource.moodResults,
        rating: _selectedMoodRating,
        extra: {
          'feedback_text': _feedbackController.text.trim(),
          'would_watch_again': _wouldWatchAgain,
          'quick_tags': _selectedTags.toList(),
          'title_name': _title!.title,
        },
      );
      
      if (!mounted) return;
      
      if (success) {
        debugPrint('ShareExperiencePage: Feedback submitted successfully');
        
        // Update home feedback cache so home page shows correct state
        InteractionService.addTitleToHomeFeedbackCache(profileId, _currentTitleId);
        
        SnackbarUtils.showSuccess(context, 'Thank you for your feedback!');
        // Go to next recommendation or navigate home if done
        _goToNextOrFinish();
      } else {
        _showError('Failed to submit feedback. Please try again.');
      }
    } catch (e) {
      debugPrint('ShareExperiencePage._submitFeedback error: $e');
      if (mounted) {
        _showError('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  void _showError(String message) {
    SnackbarUtils.showError(context, message);
  }
}

class _ShareExperienceShimmer extends StatelessWidget {
  final bool isDark;
  const _ShareExperienceShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 28),
            Container(height: 20, width: 200, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 14, width: 280, color: Colors.white),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (_) => Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onBack;
  final bool showBackButton;

  const _AppBar({required this.isDark, this.onBack, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 28,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Share Your Experience',
              textAlign: showBackButton ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          if (showBackButton) const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;

  const _MoviePosterCard({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 180,
            child: title.posterUrl != null && title.posterUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: title.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: title.genres.take(2).map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GlassChip(label: tag),
              )).toList(),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              title.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
    width: double.infinity,
    height: 180,
    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
    child: const Center(
      child: Icon(Icons.movie, size: 50, color: Colors.white),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  final String label;

  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    // Using semi-transparent container instead of BackdropFilter for better web performance
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MoodRatingSection extends StatelessWidget {
  final bool isDark;
  final int selectedRating;
  final ValueChanged<int> onRatingChanged;

  const _MoodRatingSection({
    required this.isDark,
    required this.selectedRating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How well did this match your mood?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rate how perfectly this movie captured what you were feeling',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return _MoodEmoji(
              rating: rating,
              isSelected: selectedRating == rating,
              isDark: isDark,
              onTap: () => onRatingChanged(rating),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Not at all',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            Text(
              'Perfect match',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoodEmoji extends StatelessWidget {
  final int rating;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodEmoji({
    required this.rating,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  String get _emoji {
    switch (rating) {
      case 1: return '😞';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😊';
      case 5: return '🤩';
      default: return '😊';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
              ),
              child: Center(
                child: Text(
                  _emoji,
                  style: TextStyle(fontSize: isSelected ? 26 : 24),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$rating',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackInputSection extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;

  const _FeedbackInputSection({required this.isDark, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What felt off or missing?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us improve your recommendations (optional)',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            decoration: InputDecoration(
              hintText: "Tell us what didn't quite match your mood or what you were hoping for...",
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.7)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchAgainSection extends StatelessWidget {
  final bool isDark;
  final bool? selectedOption;
  final ValueChanged<bool> onOptionChanged;

  const _WatchAgainSection({
    required this.isDark,
    required this.selectedOption,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Would you watch something like this again?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This helps us understand your preferences better',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _WatchAgainOption(
          icon: Icons.check,
          label: "Yes, I'd love more like this",
          isSelected: selectedOption == true,
          isDark: isDark,
          onTap: () => onOptionChanged(true),
        ),
        const SizedBox(height: 12),
        _WatchAgainOption(
          icon: Icons.close,
          label: 'No, try something different next time',
          isSelected: selectedOption == false,
          isDark: isDark,
          onTap: () => onOptionChanged(false),
        ),
      ],
    );
  }
}

class _WatchAgainOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _WatchAgainOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBgColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final selectedBorderColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1A1A1A);
    final unselectedBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final unselectedBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedBorderColor : unselectedBorderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTagsSection extends StatelessWidget {
  final bool isDark;
  final List<String> tags;
  final Set<String> selectedTags;
  final ValueChanged<String> onTagToggle;

  const _QuickTagsSection({
    required this.isDark,
    required this.tags,
    required this.selectedTags,
    required this.onTagToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick tags (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap what resonated with you',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tags.map((tag) => _QuickTag(
            label: tag,
            isSelected: selectedTags.contains(tag),
            isDark: isDark,
            onTap: () => onTagToggle(tag),
          )).toList(),
        ),
      ],
    );
  }
}

class _QuickTag extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickTag({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBgColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final selectedTextColor = isDark ? Colors.black : Colors.white;
    final unselectedBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final unselectedTextColor = isDark ? AppColors.darkText : AppColors.lightText;
    final unselectedBorderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: unselectedBorderColor, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isEnabled;

  const _SubmitButton({required this.isDark, required this.onTap, this.isLoading = false, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    final isDisabled = !isEnabled || isLoading;
    
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDisabled 
              ? (isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1A1A1A).withValues(alpha: 0.3))
              : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(isDark ? Colors.black : Colors.white),
                ),
              )
            else
              Icon(
                Icons.send_rounded, 
                size: 18, 
                color: isDisabled
                    ? (isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5))
                    : (isDark ? Colors.black : Colors.white),
              ),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Submitting...' : 'Submit Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? (isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5))
                    : (isDark ? Colors.black : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final bool hasMoreTitles;

  const _SkipButton({required this.isDark, required this.onTap, required this.hasMoreTitles});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasMoreTitles ? Icons.double_arrow_rounded : Icons.home_rounded,
              size: 18,
              color: isDark ? Colors.black : Colors.black87,
            ),
            const SizedBox(width: 10),
            Text(
              hasMoreTitles ? 'Skip & Get Next Recommendation' : 'Skip & Go Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterText extends StatelessWidget {
  final bool isDark;

  const _FooterText({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your feedback helps us learn your taste and\nimprove recommendations for everyone',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _AllFeedbackCompleteState extends StatelessWidget {
  final bool isDark;

  const _AllFeedbackCompleteState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🎉',
            style: TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 24),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You\'ve shared feedback on all your recent vibes.\nWatch more recommendations to unlock new feedback opportunities!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_rounded,
                    size: 18,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Go to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/mood-quiz'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.2) 
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '✨',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Start New Mood Quiz',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
