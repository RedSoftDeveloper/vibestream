class UserProfile {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final String? countryCode;
  final String? countryName;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.emoji = '👤',
    this.countryCode,
    this.countryName,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    String? countryCode,
    String? countryName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    countryCode: countryCode ?? this.countryCode,
    countryName: countryName ?? this.countryName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Converts to Supabase-compatible JSON (snake_case)
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'emoji': emoji,
    'country_code': countryCode,
    'country_name': countryName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Creates from Supabase JSON (snake_case)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final emojiValue = json['emoji'];
    final emoji = (emojiValue != null && emojiValue is String && emojiValue.isNotEmpty) 
        ? emojiValue 
        : '👤';
    
    // Handle both snake_case (Supabase) and camelCase (legacy local)
    final createdAtStr = json['created_at'] ?? json['createdAt'];
    final updatedAtStr = json['updated_at'] ?? json['updatedAt'];
    
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      emoji: emoji,
      countryCode: (json['country_code'] ?? json['countryCode']) as String?,
      countryName: (json['country_name'] ?? json['countryName']) as String?,
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr as String) : DateTime.now(),
      updatedAt: updatedAtStr != null ? DateTime.parse(updatedAtStr as String) : DateTime.now(),
    );
  }
}
