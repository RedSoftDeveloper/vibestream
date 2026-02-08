import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibestream/supabase/supabase_config.dart';

SupabaseClient get _supabase => SupabaseConfig.client;

/// Represents a streaming provider (Netflix, Disney+, etc.)
class StreamingProvider {
  final String id;
  final int tmdbProviderId;
  final String name;
  final String? logoUrl;
  final int displayPriority;

  StreamingProvider({
    required this.id,
    required this.tmdbProviderId,
    required this.name,
    this.logoUrl,
    this.displayPriority = 100,
  });

  factory StreamingProvider.fromJson(Map<String, dynamic> json) => StreamingProvider(
    id: json['id'].toString(),
    tmdbProviderId: json['tmdb_provider_id'] as int,
    name: json['name'] as String,
    logoUrl: json['logo_url'] as String?,
    displayPriority: json['display_priority'] as int? ?? 100,
  );
}

/// Represents streaming availability for a title in a specific region
class StreamingAvailability {
  final String id;
  final String titleId;
  final String providerId;
  final String region;
  final String availabilityType;
  final String? watchLink;
  final StreamingProvider? provider;

  StreamingAvailability({
    required this.id,
    required this.titleId,
    required this.providerId,
    required this.region,
    required this.availabilityType,
    this.watchLink,
    this.provider,
  });

  factory StreamingAvailability.fromJson(Map<String, dynamic> json) {
    final providerData = json['provider'];
    return StreamingAvailability(
      id: json['id'].toString(),
      titleId: json['title_id'] as String,
      providerId: json['provider_id'].toString(),
      region: json['region'] as String,
      availabilityType: json['availability_type'] as String,
      watchLink: json['watch_link'] as String?,
      provider: providerData != null ? StreamingProvider.fromJson(providerData as Map<String, dynamic>) : null,
    );
  }

  /// Whether this is a subscription service (included with subscription)
  bool get isFlatrate => availabilityType == 'flatrate';

  /// Whether this is available for rent
  bool get isRent => availabilityType == 'rent';

  /// Whether this is available for purchase
  bool get isBuy => availabilityType == 'buy';

  /// Whether this is free (with or without ads)
  bool get isFree => availabilityType == 'free' || availabilityType == 'ads';
}

/// Service for fetching streaming provider data
class StreamingProviderService {
  static final StreamingProviderService _instance = StreamingProviderService._internal();
  factory StreamingProviderService() => _instance;
  StreamingProviderService._internal();

  /// Fetches streaming availability for a title in a specific region
  /// Returns providers sorted by display priority (lowest first = most important)
  Future<List<StreamingAvailability>> getAvailabilityForTitle({
    required String titleId,
    String region = 'US',
    String? availabilityType,
  }) async {
    try {
      debugPrint('[StreamingProviderService] Fetching availability for title: $titleId, region: $region');
      
      var query = _supabase
          .from('title_streaming_availability')
          .select('''
            id,
            title_id,
            provider_id,
            region,
            availability_type,
            watch_link,
            provider:streaming_providers(
              id,
              tmdb_provider_id,
              name,
              logo_url,
              display_priority
            )
          ''')
          .eq('title_id', titleId)
          .eq('region', region);

      if (availabilityType != null) {
        query = query.eq('availability_type', availabilityType);
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      debugPrint('[StreamingProviderService] Found ${data.length} providers for title $titleId');

      final results = data.map((json) => StreamingAvailability.fromJson(json as Map<String, dynamic>)).toList();

      // Sort by provider display priority
      results.sort((a, b) {
        final priorityA = a.provider?.displayPriority ?? 100;
        final priorityB = b.provider?.displayPriority ?? 100;
        return priorityA.compareTo(priorityB);
      });

      return results;
    } catch (e) {
      debugPrint('[StreamingProviderService] Error fetching availability: $e');
      return [];
    }
  }

  /// Fetches flatrate (subscription) providers for a title
  Future<List<StreamingAvailability>> getFlatrateProvidersForTitle({
    required String titleId,
    String region = 'US',
  }) => getAvailabilityForTitle(
    titleId: titleId,
    region: region,
    availabilityType: 'flatrate',
  );

  /// Fetches all streaming providers (master list)
  Future<List<StreamingProvider>> getAllProviders() async {
    try {
      final response = await _supabase
          .from('streaming_providers')
          .select()
          .order('display_priority', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => StreamingProvider.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[StreamingProviderService] Error fetching providers: $e');
      return [];
    }
  }

  /// Fetches a specific provider by ID
  Future<StreamingProvider?> getProviderById(String providerId) async {
    try {
      final response = await _supabase
          .from('streaming_providers')
          .select()
          .eq('id', providerId)
          .maybeSingle();

      if (response == null) return null;
      return StreamingProvider.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[StreamingProviderService] Error fetching provider: $e');
      return null;
    }
  }

  /// Gets the watch provider link for a title from title_streaming_availability
  /// Returns the first non-null watch_link found for the title
  Future<String?> getWatchProviderLink(String titleId, {String region = 'US'}) async {
    try {
      final response = await _supabase
          .from('title_streaming_availability')
          .select('watch_link')
          .eq('title_id', titleId)
          .eq('region', region)
          .not('watch_link', 'is', null)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return response['watch_link'] as String?;
    } catch (e) {
      debugPrint('[StreamingProviderService] Error fetching watch link: $e');
      return null;
    }
  }
}
