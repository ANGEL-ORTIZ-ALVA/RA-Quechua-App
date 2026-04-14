import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/streak_helper.dart';
import '../../../core/utils/achievements_helper.dart';
import '../../../data/models/evaluation_model.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/question_model.dart';
import 'evaluation_screen.dart';
import '../modules/module_screen.dart';
import '../modules/lesson_screen.dart';
import '../../../data/models/word_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ResultsScreen extends StatefulWidget {
  final EvaluationModel evaluation;
  final ModuleModel module;
  final List<QuestionModel> questions;
  final QuestionType? filterType;

  const ResultsScreen({
    super.key,
    required this.evaluation,
    required this.module,
    required this.questions,
    this.filterType,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Color get _moduleColor => AppColors.getModuleColor(widget.module.id ?? 1);
  /// Palabras que el usuario falló
  List<WordModel> get _failedWords => widget.questions
      .where((q) => !q.isCorrect)
      .map((q) => q.correctWord)
      .toList();

  void _showReviewErrors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Palabras a repasar',
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca una palabra para ir a su lección',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _failedWords.length,
                      itemBuilder: (context, index) {
                        final word = _failedWords[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isDark ? const Color(0xFF2A2A2A) : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.3),
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.pop(ctx); // cerrar bottom sheet
                              Navigator.popUntil(
                                  context, (route) => route.isFirst);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LessonScreen(
                                    word: word,
                                    moduleColor: _moduleColor,
                                  ),
                                ),
                              );
                            },
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.close,
                                  color: AppColors.error, size: 20),
                            ),
                            title: Text(
                              word.wordQuechua,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                            subtitle: Text(
                              '${word.wordSpanish} • ${word.phonetic}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondary,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: isDark
                                  ? Colors.white38
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    StreakHelper.recordActivity();
    // Verificar logros con delay para que la UI se cargue primero
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        AchievementsHelper.checkAndNotify(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _getResultColor(),
        foregroundColor: AppColors.textLight,
        title: Text(
          'Resultados',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildScoreCard(context, isDark),
            const SizedBox(height: 24),
            _buildDetailsCard(context, isDark),
            const SizedBox(height: 24),
            _buildQuestionsReview(context, isDark),
            const SizedBox(height: 24),
            _buildFeedbackCard(context, isDark),
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
          Icon(_getResultIcon(), size: 80, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            widget.evaluation.grade,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textLight,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.module.name,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textLight.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 4,
        color: isDark ? Theme.of(context).cardColor : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Tu Puntuación',
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: widget.evaluation.percentage / 100,
                      strokeWidth: 12,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : AppColors.progressBackground,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(_getResultColor()),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${widget.evaluation.percentage.toInt()}%',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 48,
                          color: _getResultColor(),
                        ),
                      ),
                      Text(
                        '${widget.evaluation.correctAnswers}/${widget.evaluation.totalQuestions}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
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

  Widget _buildDetailsCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 2,
        color: isDark ? Theme.of(context).cardColor : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.check_circle,
                label: 'Respuestas correctas',
                value: '${widget.evaluation.correctAnswers}',
                color: AppColors.success,
                isDark: isDark,
              ),
              Divider(height: 24, color: isDark ? Colors.white12 : null),
              _buildDetailRow(
                icon: Icons.cancel,
                label: 'Respuestas incorrectas',
                value:
                '${widget.evaluation.totalQuestions - widget.evaluation.correctAnswers}',
                color: AppColors.error,
                isDark: isDark,
              ),
              Divider(height: 24, color: isDark ? Colors.white12 : null),
              _buildDetailRow(
                icon: Icons.quiz,
                label: 'Total de preguntas',
                value: '${widget.evaluation.totalQuestions}',
                color: AppColors.info,
                isDark: isDark,
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
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
        ),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
      ],
    );
  }

  Widget _buildQuestionsReview(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revisión de Respuestas',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final isCorrect = question.isCorrect;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                color: isDark ? Theme.of(context).cardColor : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                    isCorrect ? AppColors.success : AppColors.error,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCorrect ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pregunta ${index + 1}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _moduleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getShortTypeLabel(question.type),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: _moduleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (question.type ==
                          QuestionType.imageToQuechua) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 80,
                            width: 80,
                            child: CachedNetworkImage(
                              imageUrl:
                              question.correctWord.imagePath ?? '',
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.image,
                                      color: _moduleColor, size: 40),
                            ),
                          ),
                        ),
                      ] else
                      if (question.type ==
                          QuestionType.audioToSpanish) ...[
                        Row(
                          children: [
                            Icon(Icons.volume_up_rounded,
                                color: _moduleColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              question.correctWord.wordQuechua,
                              style: AppTextStyles.h3.copyWith(
                                color: _moduleColor,
                              ),
                            ),
                          ],
                        ),
                      ] else if (question.type ==
                          QuestionType.spanishToQuechua) ...[
                        Text(
                          question.correctWord.wordSpanish,
                          style: AppTextStyles.h3.copyWith(
                            color: _moduleColor,
                          ),
                        ),
                      ] else ...[
                        Text(
                          question.correctWord.wordQuechua,
                          style: AppTextStyles.h3.copyWith(
                            color: _moduleColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        question.correctWord.phonetic,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white12 : null),
                      const SizedBox(height: 8),
                      // Respuesta del usuario
                      if (question.selectedAnswer != null) ...[
                        Row(
                          children: [
                            Icon(
                              isCorrect
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: isCorrect
                                  ? AppColors.success
                                  : AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tu respuesta:',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.selectedAnswer == '__timeout__' ||
                              question.selectedAnswer == ''
                              ? '⏱️ Sin responder (tiempo agotado)'
                              : question.selectedAnswer!,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: question.selectedAnswer == '__timeout__' ||
                                question.selectedAnswer == ''
                                ? AppColors.warning
                                : (isCorrect
                                ? AppColors.success
                                : AppColors.error),
                            fontWeight: FontWeight.w600,
                            fontStyle:
                            question.selectedAnswer == '__timeout__' ||
                                question.selectedAnswer == ''
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Respuesta correcta:',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.correctAnswer,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getShortTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.quechuaToSpanish:
        return 'Q → E';
      case QuestionType.spanishToQuechua:
        return 'E → Q';
      case QuestionType.audioToSpanish:
        return '🔊 → E';
      case QuestionType.imageToQuechua:
        return '🖼️ → Q';
    }
  }

  Widget _buildFeedbackCard(BuildContext context, bool isDark) {
    final feedback = _getFeedbackMessage();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _getResultColor().withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getResultColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                color: _getResultColor(), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                feedback,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final didPass = widget.evaluation.percentage >= 70;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: didPass
                  ? () => Navigator.popUntil(
                  context, (route) => route.isFirst)
                  : () {
                Navigator.popUntil(
                    context, (route) => route.isFirst);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ModuleScreen(module: widget.module),
                  ),
                );
              },
              icon: Icon(didPass ? Icons.home : Icons.book),
              label: Text(
                didPass ? 'Volver al Inicio' : 'Repasar Palabras',
                style: AppTextStyles.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _moduleColor,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // ─── BOTÓN REPASAR ERRORES ───
          if (_failedWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewErrors(context),
                icon: const Icon(Icons.replay),
                label: Text(
                    'Repasar ${_failedWords.length} ${_failedWords.length == 1 ? 'error' : 'errores'}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: didPass
                  ? () {
                Navigator.popUntil(
                    context, (route) => route.isFirst);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvaluationScreen(
                      module: widget.module,
                      filterType: widget.filterType,
                    ),
                  ),
                );
              }
                  : () => Navigator.popUntil(
                  context, (route) => route.isFirst),
              icon: Icon(didPass ? Icons.refresh : Icons.home),
              label: Text(
                  didPass ? 'Intentar de Nuevo' : 'Volver al Inicio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _moduleColor,
                side: BorderSide(color: _moduleColor),
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
    if (widget.evaluation.percentage >= 90) return AppColors.success;
    if (widget.evaluation.percentage >= 70) return AppColors.info;
    if (widget.evaluation.percentage >= 50) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getResultIcon() {
    if (widget.evaluation.percentage >= 90) return Icons.emoji_events;
    if (widget.evaluation.percentage >= 70) return Icons.thumb_up;
    if (widget.evaluation.percentage >= 50) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  String _getFeedbackMessage() {
    if (widget.evaluation.percentage >= 90) {
      return '¡Excelente trabajo! Dominas este módulo. Sigue así y continúa con el siguiente.';
    } else if (widget.evaluation.percentage >= 70) {
      return '¡Buen trabajo! Has aprobado. Repasa las palabras que fallaste para mejorar.';
    } else if (widget.evaluation.percentage >= 50) {
      return 'Regular. Te recomendamos repasar las lecciones antes de volver a intentarlo.';
    } else {
      return 'Necesitas más práctica. Repasa todas las palabras del módulo y vuelve a intentarlo.';
    }
  }
}