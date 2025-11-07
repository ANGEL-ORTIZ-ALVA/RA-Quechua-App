class ProgressModel {
  final int? id;
  final int userId;
  final int wordId;
  final bool isLearned;
  final int timesReviewed;
  final String? lastReview;

  ProgressModel({
    this.id,
    required this.userId,
    required this.wordId,
    this.isLearned = false,
    this.timesReviewed = 0,
    this.lastReview,
  });

  factory ProgressModel.fromMap(Map<String, dynamic> map) {
    return ProgressModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      wordId: map['word_id'] as int,
      isLearned: (map['is_learned'] as int) == 1,
      timesReviewed: map['times_reviewed'] as int,
      lastReview: map['last_review'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'word_id': wordId,
      'is_learned': isLearned ? 1 : 0,
      'times_reviewed': timesReviewed,
      'last_review': lastReview,
    };
  }

  ProgressModel copyWith({
    int? id,
    int? userId,
    int? wordId,
    bool? isLearned,
    int? timesReviewed,
    String? lastReview,
  }) {
    return ProgressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordId: wordId ?? this.wordId,
      isLearned: isLearned ?? this.isLearned,
      timesReviewed: timesReviewed ?? this.timesReviewed,
      lastReview: lastReview ?? this.lastReview,
    );
  }

  @override
  String toString() {
    return 'ProgressModel{id: $id, wordId: $wordId, isLearned: $isLearned, timesReviewed: $timesReviewed}';
  }
}