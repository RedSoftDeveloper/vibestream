import 'package:flutter/material.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';
import 'package:vibestream/features/profiles/presentation/widgets/add_profile_sheet.dart';
import 'package:vibestream/features/profiles/presentation/widgets/edit_profile_sheet.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_onProfilesChanged);
  }

  @override
  void dispose() {
    _profileService.removeListener(_onProfilesChanged);
    super.dispose();
  }

  void _onProfilesChanged() {
    if (mounted) setState(() {});
  }

  void _showAddProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddProfileSheet(),
    );
  }

  void _showEditProfileSheet(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profiles = _profileService.profiles;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profiles',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: profiles.length + 1,
            itemBuilder: (context, index) {
              if (index == profiles.length) {
                return _AddProfileCard(
                  isDark: isDark,
                  onTap: _showAddProfileSheet,
                );
              }
              return _ProfileCard(
                isDark: isDark,
                profile: profiles[index],
                onTap: () => _showEditProfileSheet(profiles[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final bool isDark;
  final UserProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.isDark,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8766C),
                    Color(0xFFB85450),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  profile.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddProfileCard({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            ),
            child: Icon(
              Icons.add,
              size: 24,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          const Text(''),
        ],
      ),
    );
  }
}
