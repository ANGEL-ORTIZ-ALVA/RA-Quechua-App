class EvaluationModel {
  final int? id;
  final int moduleId;
  final int userId;
  final int correctAnswers;
  final int totalQuestions;
  final double percentage;
  final String completedAt;

  EvaluationModel({
    this.id,
    required this.moduleId,
    required this.userId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.completedAt,
  });

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'] as int?,
      moduleId: map['module_id'] as int,
      userId: map['user_id'] as int,
      correctAnswers: map['correct_answers'] as int,
      totalQuestions: map['total_questions'] as int,
      percentage: map['percentage'] as double,
      completedAt: map['completed_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'module_id': moduleId,
      'user_id': userId,
      'correct_answers': correctAnswers,
      'total_questions': totalQuestions,
      'percentage': percentage,
      'completed_at': completedAt,
    };
  }

  bool get isPassed => percentage >= 70.0;

  String get grade {
    if (percentage >= 90) return 'Excelente';
    if (percentage >= 70) return 'Aprobado';
    if (percentage >= 50) return 'Regular';
    return 'Necesita mejorar';
  }

  @override
  String toString() {
    return 'EvaluationModel{moduleId: $moduleId, correctAnswers: $correctAnswers/$totalQuestions, percentage: $percentage%}';
  }
}