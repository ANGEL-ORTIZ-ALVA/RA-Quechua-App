import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/evaluation_model.dart';
import 'results_screen.dart';

class EvaluationScreen extends StatefulWidget {
  final ModuleModel module;

  const EvaluationScreen({
    super.key,
    required this.module,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _isEvaluationComplete = false;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  Future<void> _generateQuestions() async {
    try {
      final words = await DatabaseHelper.instance.getWordsByModule(widget.module.id!);

      if (words.length < 4) {
        _showError('El módulo necesita al menos 4 palabras para evaluación');
        return;
      }

      // Mezclar palabras
      words.shuffle(Random());

      // Tomar 5 preguntas (o todas si hay menos de 5)
      final questionCount = min(5, words.length);
      final selectedWords = words.take(questionCount).toList();

      final questions = <QuestionModel>[];

      for (var correctWord in selectedWords) {
        // Generar opciones incorrectas
        final incorrectWords = words
            .where((w) => w.id != correctWord.id)
            .toList()
          ..shuffle(Random());

        final options = [
          correctWord.wordSpanish,
          incorrectWords[0].wordSpanish,
          incorrectWords[1].wordSpanish,
          incorrectWords[2].wordSpanish,
        ]..shuffle(Random());

        questions.add(QuestionModel(
          correctWord: correctWord,
          options: options,
        ));
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating questions: $e');
      _showError('Error al cargar las preguntas');
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _questions[_currentQuestionIndex].selectedAnswer = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishEvaluation();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _finishEvaluation() async {
    final correctAnswers = _questions.where((q) => q.isCorrect).length;
    final totalQuestions = _questions.length;
    final percentage = (correctAnswers / totalQuestions) * 100;

    final evaluation = EvaluationModel(
      moduleId: widget.module.id!,
      userId: 1, // TODO: Obtener del usuario actual
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      completedAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.insertEvaluation(evaluation);

    setState(() {
      _isEvaluationComplete = true;
    });

    _navigateToResults(evaluation);
  }

  void _navigateToResults(EvaluationModel evaluation) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          evaluation: evaluation,
          module: widget.module,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Text('No hay preguntas disponibles'),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        title: Text(
          'Evaluación: ${widget.module.name}',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(progress),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuestionCounter(),
                  const SizedBox(height: 24),
                  _buildQuestionCard(currentQuestion),
                  const SizedBox(height: 24),
                  _buildOptionsGrid(currentQuestion),
                  const SizedBox(height: 32),
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppColors.primary,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pregunta ${_currentQuestionIndex + 1} de ${_questions.length}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCounter() {
    final answered = _questions.where((q) => q.isAnswered).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (index) {
        final isAnswered = _questions[index].isAnswered;
        final isCurrent = index == _currentQuestionIndex;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAnswered
                ? AppColors.success
                : isCurrent
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  Widget _buildQuestionCard(QuestionModel question) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              '¿Qué significa en español?',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              question.correctWord.wordQuechua,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              question.correctWord.phonetic,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsGrid(QuestionModel question) {
    return Column(
      children: question.options.map((option) {
        final isSelected = question.selectedAnswer == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _selectAnswer(option),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        width: 2,
                      ),
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons() {
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    final isFirstQuestion = _currentQuestionIndex == 0;
    final canProceed = _questions[_currentQuestionIndex].isAnswered;

    return Column(
      children: [
        if (canProceed)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLastQuestion ? _finishEvaluation : _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isLastQuestion ? 'Finalizar Evaluación' : 'Siguiente',
                style: AppTextStyles.button,
              ),
            ),
          ),
        if (!canProceed)
          Container(
            width: double.infinity,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Selecciona una respuesta para continuar',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (!isFirstQuestion) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _previousQuestion,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Anterior'),
            ),
          ),
        ],
      ],
    );
  }
}

// Continúa en el siguiente mensaje...