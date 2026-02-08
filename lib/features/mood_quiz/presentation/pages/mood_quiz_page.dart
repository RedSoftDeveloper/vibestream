import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';

class MoodQuizPage extends StatefulWidget {
  const MoodQuizPage({super.key});

  @override
  State<MoodQuizPage> createState() => _MoodQuizPageState();
}

class _MoodQuizPageState extends State<MoodQuizPage> {
  final ProfileService _profileService = ProfileService();
  int _selectedViewingStyle = 0;
  bool _isLoading = false;
  final Map<String, double> _moodSliders = {
    'Complexity': 3,
    'Emotional Depth': 4,
    'Excitement': 5,
    'Joy': 4,
    'Feel Good': 5,
    'Motivation': 5,
  };
  final Set<String> _selectedGenres = {'Sci-fi', 'Comedy'};
  final TextEditingController _moodController = TextEditingController();

  final List<Map<String, String>> _viewingStyles = [
    {
      'title': 'Personal',
      'subtitle': 'Movies that resonate with my emotions',
      'icon': 'person',
    },
    {
      'title': 'Social',
      'subtitle': 'Great for watching with friends',
      'icon': 'group',
    },
    {
      'title': 'Discovery',
      'subtitle': 'Something completely new to explore',
      'icon': 'search',
    },
  ];

  final List<Map<String, String>> _genres = [
    {'name': 'Thriller', 'emoji': '😱'},
    {'name': 'Sci-fi', 'emoji': '🚀'},
    {'name': 'Romance', 'emoji': '💕'},
    {'name': 'Action', 'emoji': '💥'},
    {'name': 'Comedy', 'emoji': '😂'},
    {'name': 'Drama', 'emoji': '🎭'},
    {'name': 'Horror', 'emoji': '👻'},
    {'name': 'Fantasy', 'emoji': '🐲'},
    {'name': 'Mystery', 'emoji': '🔍'},
  ];

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  String get _viewingStyleKey {
    switch (_selectedViewingStyle) {
      case 0: return 'personal';
      case 1: return 'social';
      case 2: return 'discovery';
      default: return 'personal';
    }
  }

  Map<String, double> get _slidersForApi => {
    'complexity': _moodSliders['Complexity'] ?? 3,
    'emotional_depth': _moodSliders['Emotional Depth'] ?? 3,
    'excitement': _moodSliders['Excitement'] ?? 3,
    'joy': _moodSliders['Joy'] ?? 3,
    'feel_good': _moodSliders['Feel Good'] ?? 3,
    'motivation': _moodSliders['Motivation'] ?? 3,
  };

  Future<void> _onFindMovies() async {
    if (_isLoading) return;

    final profileId = _profileService.selectedProfileId;
    if (profileId == null) {
      SnackbarUtils.showWarning(context, 'Please select a profile first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = await RecommendationService.createMoodSession(
        profileId: profileId,
        viewingStyle: _viewingStyleKey,
        sliders: _slidersForApi,
        selectedGenres: _selectedGenres.toList(),
        freeText: _moodController.text.trim(),
      );

      if (mounted) {
        // Request home page refresh after quiz completion
        HomeRefreshService().requestRefresh(reason: HomeRefreshReason.moodQuizCompleted);
        
        context.push(AppRoutes.recommendations, extra: {
          'session': session,
          'source': InteractionSource.moodResults,
        });
      }
    } catch (e) {
      debugPrint('MoodQuiz error: $e');
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to get recommendations. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppBar(isDark: isDark),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ViewingStyleSection(
                      isDark: isDark,
                      selectedIndex: _selectedViewingStyle,
                      viewingStyles: _viewingStyles,
                      onSelect: (index) => setState(() => _selectedViewingStyle = index),
                    ),
                    const SizedBox(height: 32),
                    _MoodSlidersSection(
                      isDark: isDark,
                      sliders: _moodSliders,
                      onChanged: (name, value) => setState(() => _moodSliders[name] = value),
                    ),
                    const SizedBox(height: 32),
                    _GenresSection(
                      isDark: isDark,
                      genres: _genres,
                      selectedGenres: _selectedGenres,
                      onToggle: (genre) {
                        setState(() {
                          if (_selectedGenres.contains(genre)) {
                            _selectedGenres.remove(genre);
                          } else if (_selectedGenres.length < 3) {
                            _selectedGenres.add(genre);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    _DescribeMoodSection(
                      isDark: isDark,
                      controller: _moodController,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _BottomButton(
                isDark: isDark,
                isLoading: _isLoading,
                onPressed: _onFindMovies,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final bool isDark;
  const _AppBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              ),
              child: Icon(
                Icons.chevron_left,
                size: 24,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'How are you feeling?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              ),
              child: Icon(
                Icons.close,
                size: 20,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewingStyleSection extends StatelessWidget {
  final bool isDark;
  final int selectedIndex;
  final List<Map<String, String>> viewingStyles;
  final Function(int) onSelect;

  const _ViewingStyleSection({
    required this.isDark,
    required this.selectedIndex,
    required this.viewingStyles,
    required this.onSelect,
  });

  IconData _getIcon(String icon) {
    switch (icon) {
      case 'person':
        return Icons.person_outline;
      case 'group':
        return Icons.people_outline;
      case 'search':
        return Icons.search;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your viewing style?",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This helps us understand your preferences',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(viewingStyles.length, (index) {
            final style = viewingStyles[index];
            final isSelected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ViewingStyleCard(
                isDark: isDark,
                icon: _getIcon(style['icon']!),
                title: style['title']!,
                subtitle: style['subtitle']!,
                isSelected: isSelected,
                onTap: () => onSelect(index),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ViewingStyleCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewingStyleCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? (isDark ? AppColors.darkText : AppColors.lightText)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodSlidersSection extends StatelessWidget {
  final bool isDark;
  final Map<String, double> sliders;
  final Function(String, double) onChanged;

  const _MoodSlidersSection({
    required this.isDark,
    required this.sliders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjust your mood',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Move the sliders to match how you want to feel',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ...sliders.entries.map((entry) => _MoodSlider(
                isDark: isDark,
                label: entry.key,
                value: entry.value,
                onChanged: (value) => onChanged(entry.key, value),
              )),
        ],
      ),
    );
  }
}

class _MoodSlider extends StatelessWidget {
  final bool isDark;
  final String label;
  final double value;
  final Function(double) onChanged;

  const _MoodSlider({
    required this.isDark,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const sliderColor = Color(0xFFE8766C);
    final trackColor = isDark 
        ? AppColors.darkSurfaceVariant 
        : const Color(0xFFE8E8E8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${value.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    TextSpan(
                      text: '/5',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: sliderColor,
              inactiveTrackColor: trackColor,
              thumbColor: isDark ? AppColors.darkText : AppColors.lightText,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              overlayColor: sliderColor.withValues(alpha: 0.2),
              trackShape: _CustomTrackShape(),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class _GenresSection extends StatelessWidget {
  final bool isDark;
  final List<Map<String, String>> genres;
  final Set<String> selectedGenres;
  final Function(String) onToggle;

  const _GenresSection({
    required this.isDark,
    required this.genres,
    required this.selectedGenres,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What genres interest you?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Select up to 3 genres you're in the mood for",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: genres.map((genre) {
              final isSelected = selectedGenres.contains(genre['name']);
              return _GenreChip(
                isDark: isDark,
                emoji: genre['emoji']!,
                name: genre['name']!,
                isSelected: isSelected,
                onTap: () => onToggle(genre['name']!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final bool isDark;
  final String emoji;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.isDark,
    required this.emoji,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected colors
    const selectedBgDark = Color(0xFFF6F6F6);
    const selectedTextDark = Color(0xFF1B181C);
    const selectedBgLight = Color(0xFF1B181C);
    const selectedTextLight = Color(0xFFF6F6F6);

    final bgColor = isSelected
        ? (isDark ? selectedBgDark : selectedBgLight)
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final textColor = isSelected
        ? (isDark ? selectedTextDark : selectedTextLight)
        : (isDark ? AppColors.darkText : AppColors.lightText);
    final borderColor = isSelected
        ? (isDark ? selectedBgDark : selectedBgLight)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescribeMoodSection extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;

  const _DescribeMoodSection({
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe your mood',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Tell us more about what you're looking for",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            decoration: InputDecoration(
              hintText: 'I want something exciting but emotionally deep...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final VoidCallback onPressed;
  
  const _BottomButton({
    required this.isDark,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkText : AppColors.lightText,
                foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                disabledBackgroundColor: (isDark ? AppColors.darkText : AppColors.lightText).withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                    )
                  : Text(
                      'Find My Movies',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLoading ? 'Finding your perfect matches...' : 'This will take about 10 seconds',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
