import 'word_model.dart';

/// Tipos de pregunta en la evaluación
enum QuestionType {
  quechuaToSpanish, // Muestra palabra quechua → elige español
  spanishToQuechua, // Muestra palabra español → elige quechua
  audioToSpanish,   // Reproduce audio → elige español
}

class QuestionModel {
  final WordModel correctWord;
  final List<String> options;
  final QuestionType type;
  String? selectedAnswer;

  QuestionModel({
    required this.correctWord,
    required this.options,
    this.type = QuestionType.quechuaToSpanish,
  });

  bool get isAnswered => selectedAnswer != null;

  /// La respuesta correcta depende del tipo de pregunta
  String get correctAnswer {
    switch (type) {
      case QuestionType.spanishToQuechua:
        return correctWord.wordQuechua;
      case QuestionType.quechuaToSpanish:
      case QuestionType.audioToSpanish:
        return correctWord.wordSpanish;
    }
  }

  bool get isCorrect => selectedAnswer == correctAnswer;

  /// Etiqueta del tipo de pregunta (para revisión de resultados)
  String get typeLabel {
    switch (type) {
      case QuestionType.quechuaToSpanish:
        return '¿Qué significa en español?';
      case QuestionType.spanishToQuechua:
        return '¿Cómo se dice en quechua?';
      case QuestionType.audioToSpanish:
        return 'Escucha y selecciona';
    }
  }
}