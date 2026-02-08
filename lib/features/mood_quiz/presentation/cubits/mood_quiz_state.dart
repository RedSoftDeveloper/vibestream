import 'package:equatable/equatable.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';

enum MoodQuizStatus { initial, submitting, success, error }

class MoodQuizState extends Equatable {
  final MoodQuizStatus status;
  final int selectedViewingStyle;
  final Map<String, double> moodSliders;
  final Set<String> selectedGenres;
  final String freeText;
  final RecommendationSession? session;
  final String? errorMessage;

  const MoodQuizState({
    this.status = MoodQuizStatus.initial,
    this.selectedViewingStyle = 0,
    this.moodSliders = const {
      'Complexity': 3,
      'Emotional Depth': 4,
      'Excitement': 5,
      'Joy': 4,
      'Feel Good': 5,
      'Motivation': 5,
    },
    this.selectedGenres = const {'Sci-fi', 'Comedy'},
    this.freeText = '',
    this.session,
    this.errorMessage,
  });

  bool get isSubmitting => status == MoodQuizStatus.submitting;

  String get viewingStyleKey {
    switch (selectedViewingStyle) {
      case 0: return 'personal';
      case 1: return 'social';
      case 2: return 'discovery';
      default: return 'personal';
    }
  }

  Map<String, double> get slidersForApi => {
    'complexity': moodSliders['Complexity'] ?? 3,
    'emotional_depth': moodSliders['Emotional Depth'] ?? 3,
    'excitement': moodSliders['Excitement'] ?? 3,
    'joy': moodSliders['Joy'] ?? 3,
    'feel_good': moodSliders['Feel Good'] ?? 3,
    'motivation': moodSliders['Motivation'] ?? 3,
  };

  MoodQuizState copyWith({
    MoodQuizStatus? status,
    int? selectedViewingStyle,
    Map<String, double>? moodSliders,
    Set<String>? selectedGenres,
    String? freeText,
    RecommendationSession? session,
    String? errorMessage,
  }) {
    return MoodQuizState(
      status: status ?? this.status,
      selectedViewingStyle: selectedViewingStyle ?? this.selectedViewingStyle,
      moodSliders: moodSliders ?? this.moodSliders,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      freeText: freeText ?? this.freeText,
      session: session ?? this.session,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedViewingStyle,
    moodSliders,
    selectedGenres,
    freeText,
    session,
    errorMessage,
  ];
}
