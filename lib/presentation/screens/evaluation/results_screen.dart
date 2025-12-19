import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/evaluation_model.dart';
import '../../../data/models/module_model.dart';

class ResultsScreen extends StatelessWidget {
  final EvaluationModel evaluation;
  final ModuleModel module;

  const ResultsScreen({
    super.key,
    required this.evaluation,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _getResultColor(),
        foregroundColor: AppColors.textLight,
        title: Text(
          'Resultados',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textLight,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildScoreCard(context),
            const SizedBox(height: 24),
            _buildDetailsCard(context),
            const SizedBox(height: 24),
            _buildFeedbackCard(context),
            const SizedBox(height: 32),
            _buildActions(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: _getResultColor(),
        boxShadow: [
          BoxShadow(
            color: _getResultColor().withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _getResultIcon(),
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            evaluation.grade,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textLight,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            module.name,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textLight.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Tu Puntuación',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: evaluation.percentage / 100,
                      strokeWidth: 12,
                      backgroundColor: AppColors.progressBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(_getResultColor()),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${evaluation.percentage.toInt()}%',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 48,
                          color: _getResultColor(),
                        ),
                      ),
                      Text(
                        '${evaluation.correctAnswers}/${evaluation.totalQuestions}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.check_circle,
                label: 'Respuestas correctas',
                value: '${evaluation.correctAnswers}',
                color: AppColors.success,
              ),
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.cancel,
                label: 'Respuestas incorrectas',
                value: '${evaluation.totalQuestions - evaluation.correctAnswers}',
                color: AppColors.error,
              ),
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.quiz,
                label: 'Total de preguntas',
                value: '${evaluation.totalQuestions}',
                color: AppColors.info,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final feedback = _getFeedbackMessage();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _getResultColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getResultColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: _getResultColor(),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                feedback,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Volver al Inicio',
                style: AppTextStyles.button,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Reiniciar evaluación
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de Nuevo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getResultColor() {
    if (evaluation.percentage >= 90) return AppColors.success;
    if (evaluation.percentage >= 70) return AppColors.info;
    if (evaluation.percentage >= 50) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getResultIcon() {
    if (evaluation.percentage >= 90) return Icons.emoji_events;
    if (evaluation.percentage >= 70) return Icons.thumb_up;
    if (evaluation.percentage >= 50) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  String _getFeedbackMessage() {
    if (evaluation.percentage >= 90) {
      return '¡Excelente trabajo! Dominas este módulo. Sigue así y continúa con el siguiente.';
    } else if (evaluation.percentage >= 70) {
      return '¡Buen trabajo! Has aprobado. Repasa las palabras que fallaste para mejorar.';
    } else if (evaluation.percentage >= 50) {
      return 'Regular. Te recomendamos repasar las lecciones antes de volver a intentarlo.';
    } else {
      return 'Necesitas más práctica. Repasa todas las palabras del módulo y vuelve a intentarlo.';
    }
  }
}