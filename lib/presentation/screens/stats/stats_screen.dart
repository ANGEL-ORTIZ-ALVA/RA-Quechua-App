import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/module_model.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  int _totalWords = 0;
  int _learnedWords = 0;
  int _totalEvaluations = 0;
  int _masteredModules = 0;
  int _streakDays = 0;
  double _avgScore = 0.0;
  List<_ModuleStat> _moduleStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final modules = await DatabaseHelper.instance.getAllModules();
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt('streak_count') ?? 0;

      int totalLearned = 0;
      int totalEvals = 0;
      int mastered = 0;
      double totalScore = 0;
      int scoredModules = 0;
      final stats = <_ModuleStat>[];

      for (var module in modules) {
        final learned =
        await DatabaseHelper.instance.getLearnedWordsCount(module.id!);
        final bestScore =
        await DatabaseHelper.instance.getBestEvaluationScore(module.id!);
        final evals =
        await DatabaseHelper.instance.getEvaluationsByModule(module.id!);

        totalLearned += learned;
        totalEvals += evals.length;

        if (bestScore > 0) {
          totalScore += bestScore;
          scoredModules++;
        }
        if (learned >= 5 && bestScore >= 70) mastered++;

        stats.add(_ModuleStat(
          module: module,
          learnedWords: learned,
          bestScore: bestScore,
          evalCount: evals.length,
          isMastered: learned >= 5 && bestScore >= 70,
          isCompleted: learned >= 10 && bestScore >= 70,
        ));
      }

      setState(() {
        _totalWords = modules.length * 10;
        _learnedWords = totalLearned;
        _totalEvaluations = totalEvals;
        _masteredModules = mastered;
        _streakDays = streak;
        _avgScore = scoredModules > 0 ? totalScore / scoredModules : 0;
        _moduleStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estadísticas',
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu progreso de aprendizaje',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color:
                    isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOverviewGrid(isDark),
                const SizedBox(height: 32),
                Text(
                  'Progreso por módulo',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 16),
                ..._moduleStats
                    .map((s) => _buildModuleStatCard(s, isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatTile(
          icon: Icons.book,
          label: 'Palabras',
          value: '$_learnedWords/$_totalWords',
          color: AppColors.primary,
          isDark: isDark,
        ),
        _buildStatTile(
          icon: Icons.emoji_events,
          label: 'Módulos dominados',
          value: '$_masteredModules/${_moduleStats.length}',
          color: AppColors.success,
          isDark: isDark,
        ),
        _buildStatTile(
          icon: Icons.local_fire_department,
          label: 'Racha actual',
          value: '$_streakDays días',
          color: AppColors.secondary,
          isDark: isDark,
        ),
        _buildStatTile(
          icon: Icons.quiz,
          label: 'Evaluaciones',
          value: '$_totalEvaluations',
          color: AppColors.info,
          isDark: isDark,
        ),
        _buildStatTile(
          icon: Icons.trending_up,
          label: 'Promedio',
          value: _avgScore > 0 ? '${_avgScore.toInt()}%' : '-',
          color: AppColors.accent,
          isDark: isDark,
        ),
        _buildStatTile(
          icon: Icons.star,
          label: 'Nivel',
          value: _getLevel(),
          color: const Color(0xFF6A1B9A),
          isDark: isDark,
        ),
      ],
    );
  }

  String _getLevel() {
    if (_masteredModules >= 4) return "Hamawt'a";
    if (_masteredModules >= 2) return 'Yachaq';
    return 'Qallariq';
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleStatCard(_ModuleStat stat, bool isDark) {
    final color = AppColors.getModuleColor(stat.module.id ?? 1);
    final progress = stat.learnedWords / 10.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stat.isCompleted
              ? AppColors.success.withOpacity(0.5)
              : (isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.progressBackground),
          width: stat.isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppColors.getModuleIcon(stat.module.icon),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.module.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    Text(
                      stat.module.nameQuechua,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (stat.isCompleted)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 16),
                )
              else if (stat.isMastered)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child:
                  const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progreso
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${stat.learnedWords}/10 palabras',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? Colors.white54 : null,
                          ),
                        ),
                        Text(
                          stat.bestScore > 0
                              ? 'Mejor: ${stat.bestScore.toInt()}%'
                              : 'Sin evaluar',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: stat.bestScore >= 70
                                ? AppColors.success
                                : (isDark ? Colors.white38 : AppColors.textSecondary),
                            fontWeight: stat.bestScore >= 70
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : AppColors.progressBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stat.evalCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.quiz_outlined,
                    size: 14,
                    color: isDark ? Colors.white38 : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${stat.evalCount} ${stat.evalCount == 1 ? 'evaluación' : 'evaluaciones'} realizadas',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleStat {
  final ModuleModel module;
  final int learnedWords;
  final double bestScore;
  final int evalCount;
  final bool isMastered;
  final bool isCompleted;

  _ModuleStat({
    required this.module,
    required this.learnedWords,
    required this.bestScore,
    required this.evalCount,
    required this.isMastered,
    required this.isCompleted,
  });
}