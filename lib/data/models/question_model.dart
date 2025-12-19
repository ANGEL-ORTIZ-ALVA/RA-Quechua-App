import 'word_model.dart';

class QuestionModel {
  final WordModel correctWord;
  final List<String> options;
  String? selectedAnswer;

  QuestionModel({
    required this.correctWord,
    required this.options,
    this.selectedAnswer,
  });

  bool get isAnswered => selectedAnswer != null;

  bool get isCorrect => selectedAnswer == correctWord.wordSpanish;

  String get correctAnswer => correctWord.wordSpanish;
}