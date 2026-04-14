import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/database_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final String category;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.category,
    required this.isUnlocked,
  });
}

class AchievementsHelper {
  static Future<List<Achievement>> getAchievements() async {
    final db = DatabaseHelper.instance;
    final prefs = await SharedPreferences.getInstance();
    final modules = await db.getAllModules();

    int totalLearned = 0;
    int totalEvals = 0;
    int masteredModules = 0;
    int completedModules = 0;
    bool hasPerfectScore = false;
    int modulesWithPassingEval = 0;

    for (var module in modules) {
      final learned = await db.getLearnedWordsCount(module.id!);
      final bestScore = await db.getBestEvaluationScore(module.id!);
      final evals = await db.getEvaluationsByModule(module.id!);

      totalLearned += learned;
      totalEvals += evals.length;

      if (learned >= 5 && bestScore >= 70) masteredModules++;
      if (learned >= 10 && bestScore >= 70) completedModules++;
      if (bestScore >= 100) hasPerfectScore = true;
      if (bestScore >= 70) modulesWithPassingEval++;
    }

    final streakDays = prefs.getInt('streak_count') ?? 0;

    return [
      Achievement(
        id: 'first_word',
        emoji: '🌱',
        title: 'Primera Palabra',
        description: 'Aprende tu primera palabra',
        category: 'Aprendizaje',
        isUnlocked: totalLearned >= 1,
      ),
      Achievement(
        id: 'half_vocab',
        emoji: '📚',
        title: 'Estudiante Dedicado',
        description: 'Aprende 30 palabras',
        category: 'Aprendizaje',
        isUnlocked: totalLearned >= 30,
      ),
      Achievement(
        id: 'full_vocab',
        emoji: '🎓',
        title: 'Maestro del Vocabulario',
        description: 'Aprende las 60 palabras',
        category: 'Aprendizaje',
        isUnlocked: totalLearned >= 60,
      ),
      Achievement(
        id: 'first_eval',
        emoji: '✏️',
        title: 'Primera Evaluación',
        description: 'Completa tu primera evaluación',
        category: 'Evaluaciones',
        isUnlocked: totalEvals >= 1,
      ),
      Achievement(
        id: 'perfect_score',
        emoji: '💯',
        title: 'Perfección',
        description: 'Obtén 100% en una evaluación',
        category: 'Evaluaciones',
        isUnlocked: hasPerfectScore,
      ),
      Achievement(
        id: 'all_modules_eval',
        emoji: '🏆',
        title: 'Evaluador Experto',
        description: 'Aprueba evaluación en los 6 módulos',
        category: 'Evaluaciones',
        isUnlocked: modulesWithPassingEval >= 6,
      ),
      Achievement(
        id: 'first_module',
        emoji: '⭐',
        title: 'Primer Módulo',
        description: 'Completa tu primer módulo',
        category: 'Módulos',
        isUnlocked: completedModules >= 1,
      ),
      Achievement(
        id: 'half_modules',
        emoji: '🌟',
        title: 'Medio Camino',
        description: 'Completa 3 módulos',
        category: 'Módulos',
        isUnlocked: completedModules >= 3,
      ),
      Achievement(
        id: 'all_modules',
        emoji: '👑',
        title: 'Conquistador Total',
        description: 'Completa los 6 módulos',
        category: 'Módulos',
        isUnlocked: completedModules >= 6,
      ),
      Achievement(
        id: 'streak_3',
        emoji: '🔥',
        title: 'Inicio de Racha',
        description: '3 días consecutivos practicando',
        category: 'Constancia',
        isUnlocked: streakDays >= 3,
      ),
      Achievement(
        id: 'streak_7',
        emoji: '⚡',
        title: 'Racha Imparable',
        description: '7 días consecutivos practicando',
        category: 'Constancia',
        isUnlocked: streakDays >= 7,
      ),
      Achievement(
        id: 'streak_14',
        emoji: '🌋',
        title: 'Leyenda Constante',
        description: '14 días consecutivos practicando',
        category: 'Constancia',
        isUnlocked: streakDays >= 14,
      ),
    ];
  }

  static Future<Map<String, int>> getAchievementCount() async {
    final achievements = await getAchievements();
    final unlocked = achievements.where((a) => a.isUnlocked).length;
    return {'unlocked': unlocked, 'total': achievements.length};
  }

  static Future<void> checkAndNotify(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final previouslyUnlocked =
        prefs.getStringList('unlocked_achievements') ?? [];

    final achievements = await getAchievements();
    final currentlyUnlocked = achievements
        .where((a) => a.isUnlocked)
        .map((a) => a.id)
        .toList();

    final newlyUnlocked = currentlyUnlocked
        .where((id) => !previouslyUnlocked.contains(id))
        .toList();

    await prefs.setStringList('unlocked_achievements', currentlyUnlocked);

    if (newlyUnlocked.isNotEmpty && context.mounted) {
      final newAchievements =
      achievements.where((a) => newlyUnlocked.contains(a.id)).toList();

      for (var achievement in newAchievements) {
        if (!context.mounted) break;
        await _showAchievementNotification(context, achievement);
      }
    }
  }

  static Future<void> initializeTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('unlocked_achievements');
    if (existing == null) {
      await prefs.setStringList('unlocked_achievements', []);
    }
  }

  static Future<void> resetTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', []);
  }

  static Future<void> _showAchievementNotification(
      BuildContext context, Achievement achievement) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vibración de feedback
    HapticFeedback.mediumImpact();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.secondary
                          .withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        achievement.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎉 ¡Logro desbloqueado!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.title,
                          style: AppTextStyles.h3.copyWith(
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          achievement.description,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}