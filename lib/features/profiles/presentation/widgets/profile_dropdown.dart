import 'package:flutter/material.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';
import 'package:vibestream/features/profiles/presentation/pages/profiles_page.dart';

class ProfileDropdown extends StatelessWidget {
  final List<UserProfile> profiles;
  final String? selectedProfileId;
  final VoidCallback onDismiss;

  const ProfileDropdown({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...profiles.map((profile) => _ProfileDropdownItem(
                    profile: profile,
                    isSelected: profile.id == selectedProfileId,
                    isDark: isDark,
                    onTap: () async {
                      final wasChanged = profile.id != selectedProfileId;
                      await ProfileService().selectProfile(profile.id);
                      // Request home page refresh after profile switch
                      if (wasChanged) {
                        HomeRefreshService().requestRefresh(reason: HomeRefreshReason.profileSwitched);
                      }
                      onDismiss();
                    },
                  )),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  _ManageProfilesItem(
                    isDark: isDark,
                    onTap: () {
                      onDismiss();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const ProfilesPage()),
                      );
                    },
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

class _ProfileDropdownItem extends StatelessWidget {
  final UserProfile profile;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileDropdownItem({
    required this.profile,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? (isDark ? AppColors.darkText : AppColors.lightText)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageProfilesItem extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _ManageProfilesItem({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              'Manage profiles',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
