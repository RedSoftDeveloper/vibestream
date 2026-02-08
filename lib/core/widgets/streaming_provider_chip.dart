import 'package:flutter/material.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/features/title_details/domain/entities/title_entity.dart';

class StreamingProviderChip extends StatelessWidget {
  final StreamingProvider provider;
  final bool compact;

  const StreamingProviderChip({
    super.key,
    required this.provider,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 24 : 32,
            height: compact ? 24 : 32,
            decoration: BoxDecoration(
              color: _getProviderColor(provider.name),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                provider.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12 : 14,
                ),
              ),
              Text(
                _getTypeLabel(provider.type),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'flatrate':
        return 'Subscription';
      case 'rent':
        return 'Rent';
      case 'buy':
        return 'Purchase';
      default:
        return type;
    }
  }

  Color _getProviderColor(String name) {
    switch (name.toLowerCase()) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon prime':
        return const Color(0xFF00A8E1);
      case 'hbo max':
        return const Color(0xFF5822B4);
      case 'disney+':
        return const Color(0xFF113CCF);
      case 'paramount+':
        return const Color(0xFF0064FF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple tv+':
        return const Color(0xFF000000);
      default:
        return AppColors.primary;
    }
  }
}

class StreamingProvidersRow extends StatelessWidget {
  final List<StreamingProvider> providers;
  final bool compact;

  const StreamingProvidersRow({
    super.key,
    required this.providers,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return Text(
        'No streaming info available',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: providers.map((p) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: StreamingProviderChip(provider: p, compact: compact),
        )).toList(),
      ),
    );
  }
}
