import 'word_model.dart';

/// Tipos de pregunta en la evaluación
enum QuestionType {
  quechuaToSpanish, // Muestra palabra quechua → elige español
  spanishToQuechua, // Muestra palabra español → elige quechua
  audioToSpanish,   // Reproduce audio → elige español
  imageToQuechua,   // Muestra imagen → elige quechua
  fillInBlank,      // Escribe la palabra quechua (con pista de consonantes)
  scramble,         // Ordena las letras desordenadas
}

class QuestionModel {
  final WordModel correctWord;
  final List<String> options;
  final QuestionType type;

  /// Para multiple-choice: una opción seleccionada.
  /// Para fillInBlank: la palabra completa escrita por el usuario.
  /// Para scramble: la palabra construida letra por letra.
  String? selectedAnswer;

  QuestionModel({
    required this.correctWord,
    required this.options,
    this.type = QuestionType.quechuaToSpanish,
  });

  bool get isAnswered {
    if (selectedAnswer == null || selectedAnswer!.isEmpty) return false;
    if (type == QuestionType.fillInBlank) {
      // El usuario debe escribir algo con al menos 2 caracteres
      return selectedAnswer!.trim().length >= 2;
    }
    if (type == QuestionType.scramble) {
      return selectedAnswer!.length == correctWord.wordQuechua.length;
    }
    return true;
  }

  /// La respuesta correcta "canónica" (para display en results screen).
  String get correctAnswer {
    switch (type) {
      case QuestionType.spanishToQuechua:
      case QuestionType.imageToQuechua:
      case QuestionType.fillInBlank:
      case QuestionType.scramble:
        return correctWord.wordQuechua;
      case QuestionType.quechuaToSpanish:
      case QuestionType.audioToSpanish:
        return correctWord.wordSpanish;
    }
  }

  bool get isCorrect {
    if (selectedAnswer == null || selectedAnswer!.isEmpty) return false;
    if (type == QuestionType.fillInBlank) {
      // Comparar la palabra completa, case-insensitive, sin espacios extra
      return selectedAnswer!.trim().toLowerCase() ==
          correctWord.wordQuechua.toLowerCase();
    }
    if (type == QuestionType.scramble) {
      return selectedAnswer!.toLowerCase() ==
          correctWord.wordQuechua.toLowerCase();
    }
    return selectedAnswer == correctAnswer;
  }

  /// Etiqueta del tipo de pregunta
  String get typeLabel {
    switch (type) {
      case QuestionType.quechuaToSpanish:
        return '¿Qué significa en español?';
      case QuestionType.spanishToQuechua:
        return '¿Cómo se dice en quechua?';
      case QuestionType.audioToSpanish:
        return 'Escucha y selecciona';
      case QuestionType.imageToQuechua:
        return '¿Cómo se llama en quechua?';
      case QuestionType.fillInBlank:
        return 'Escribe la palabra en quechua';
      case QuestionType.scramble:
        return 'Ordena las letras correctamente';
    }
  }
}