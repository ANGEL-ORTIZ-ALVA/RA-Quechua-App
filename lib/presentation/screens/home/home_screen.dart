import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/streak_helper.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/module_model.dart';
import '../modules/module_screen.dart';

const List<String> kAvatarEmojis = [
  '🦙', '🏔️', '🌞', '🦅', '🌽', '🎵',
  '🌈', '🪶', '🏺', '⭐', '🔥', '🌺',
];

// ─── DEFINICIÓN DE NIVELES ───
class LevelDefinition {
  final String name;
  final String nameQuechua;
  final String description;
  final IconData icon;
  final Color color;
  final List<int> moduleIds; // IDs de módulos en este nivel

  const LevelDefinition({
    required this.name,
    required this.nameQuechua,
    required this.description,
    required this.icon,
    required this.color,
    required this.moduleIds,
  });
}

final List<LevelDefinition> kLevels = [
  LevelDefinition(
    name: 'Básico',
    nameQuechua: 'Qallariq',
    description: 'Vocabulario fundamental: números y colores',
    icon: Icons.school,
    color: AppColors.success,
    moduleIds: [4, 6], // Números, Colores
  ),
  LevelDefinition(
    name: 'Intermedio',
    nameQuechua: 'Yachaq',
    description: 'Sustantivos concretos: fauna y naturaleza andina',
    icon: Icons.trending_up,
    color: AppColors.info,
    moduleIds: [1, 2], // Animales, Naturaleza
  ),
  LevelDefinition(
    name: 'Avanzado',
    nameQuechua: "Hamawt'a",
    description: 'Cultura y expresiones: familia y saludos',
    icon: Icons.whatshot,
    color: const Color(0xFF6A1B9A),
    moduleIds: [3, 5], // Familia y Cultura, Saludos
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  List<ModuleModel> _modules = [];
  bool _isLoading = true;
  int _totalLearnedWords = 0;
  Map<int, int> _moduleProgress = {};
  Map<int, double> _moduleEvalScores = {};
  int _masteredModulesCount = 0;
  int _streakDays = 0;
  bool _streakWasLost = false;
  int _previousStreak = 0;
  int _avatarIndex = 0;

  // ─── Estado de niveles desbloqueados ───
  Set<int> _unlockedLevelIndices = {0}; // Nivel 0 (Básico) siempre desbloqueado

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadUserData();
    await _loadModules();
    await _loadProgress();
    await _loadStreak();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _avatarIndex = prefs.getInt('user_avatar') ?? 0;
    });
  }

  Future<void> _loadModules() async {
    try {
      final modules = await DatabaseHelper.instance.getAllModules();
      setState(() => _modules = modules);
    } catch (e) {
      print('Error loading modules: $e');
    }
  }

  Future<void> _loadProgress() async {
    try {
      int total = 0;
      Map<int, int> moduleProgressMap = {};
      Map<int, double> evalScoresMap = {};
      int mastered = 0;

      for (var module in _modules) {
        final learned =
        await DatabaseHelper.instance.getLearnedWordsCount(module.id!);
        final bestScore =
        await DatabaseHelper.instance.getBestEvaluationScore(module.id!);

        moduleProgressMap[module.id!] = learned;
        evalScoresMap[module.id!] = bestScore;
        total += learned;

        if (learned >= 5 && bestScore >= 70) {
          mastered++;
        }
      }

      // Calcular niveles desbloqueados
      final unlocked = <int>{0}; // Básico siempre
      for (int i = 0; i < kLevels.length - 1; i++) {
        final levelModuleIds = kLevels[i].moduleIds;
        final allMastered = levelModuleIds.every((id) {
          final learned = moduleProgressMap[id] ?? 0;
          final score = evalScoresMap[id] ?? 0.0;
          return learned >= 5 && score >= 70;
        });
        if (allMastered) {
          unlocked.add(i + 1);
        }
      }

      setState(() {
        _totalLearnedWords = total;
        _moduleProgress = moduleProgressMap;
        _moduleEvalScores = evalScoresMap;
        _masteredModulesCount = mastered;
        _unlockedLevelIndices = unlocked;
        _isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_level', _getLevelLabel());
    } catch (e) {
      print('Error loading progress: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStreak() async {
    final info = await StreakHelper.getStreakInfo();
    setState(() {
      _streakDays = info['streak'] as int;
      _streakWasLost = info['wasLost'] as bool;
      _previousStreak = info['previousStreak'] as int;
    });
  }

  Future<void> _refreshProgress() async {
    await _loadUserData();
    await _loadProgress();
    await _loadStreak();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Allin punchaw';
    if (hour >= 12 && hour < 18) return 'Allin chisi';
    return 'Allin tuta';
  }

  String _getLevelLabel() {
    if (_masteredModulesCount >= 4) return "Hamawt'a";
    if (_masteredModulesCount >= 2) return 'Yachaq';
    return 'Qallariq';
  }

  String _getLevelSubtitle() {
    switch (_getLevelLabel()) {
      case 'Qallariq':
        return 'Principiante · $_masteredModulesCount/${_modules.length} módulos';
      case 'Yachaq':
        return 'Intermedio · $_masteredModulesCount/${_modules.length} módulos';
      case "Hamawt'a":
        return 'Avanzado · $_masteredModulesCount/${_modules.length} módulos';
      default:
        return '';
    }
  }

  bool _isModuleUnlocked(int moduleId) {
    for (int i = 0; i < kLevels.length; i++) {
      if (kLevels[i].moduleIds.contains(moduleId)) {
        if (!_unlockedLevelIndices.contains(i)) return false;

        // Dentro del nivel, el primer módulo siempre desbloqueado
        // El segundo requiere dominar el primero
        final moduleIndex = kLevels[i].moduleIds.indexOf(moduleId);
        if (moduleIndex == 0) return true;

        final previousModuleId = kLevels[i].moduleIds[moduleIndex - 1];
        final learned = _moduleProgress[previousModuleId] ?? 0;
        final score = _moduleEvalScores[previousModuleId] ?? 0.0;
        return learned >= 5 && score >= 70;
      }
    }
    return false;
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
          onRefresh: _refreshProgress,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 24),
                  _buildStreakCard(isDark),
                  const SizedBox(height: 16),
                  _buildProgressCard(isDark),
                  const SizedBox(height: 32),
                  // ─── MÓDULOS POR NIVELES ───
                  ...kLevels.asMap().entries.map((entry) {
                    final levelIndex = entry.key;
                    final level = entry.value;
                    final isUnlocked =
                    _unlockedLevelIndices.contains(levelIndex);
                    return _buildLevelSection(
                        level, levelIndex, isUnlocked, isDark);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── SECCIÓN DE NIVEL ───
  Widget _buildLevelSection(LevelDefinition level, int levelIndex,
      bool isUnlocked, bool isDark) {
    // Calcular progreso del nivel
    int levelLearned = 0;
    int levelTotal = level.moduleIds.length * 10;
    bool levelCompleted = true;

    for (var id in level.moduleIds) {
      levelLearned += _moduleProgress[id] ?? 0;
      final learned = _moduleProgress[id] ?? 0;
      final score = _moduleEvalScores[id] ?? 0.0;
      if (learned < 5 || score < 70) levelCompleted = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del nivel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUnlocked
                ? level.color.withOpacity(isDark ? 0.15 : 0.08)
                : (isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? level.color.withOpacity(0.3)
                  : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.15)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? level.color.withOpacity(isDark ? 0.3 : 0.15)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUnlocked ? level.icon : Icons.lock,
                  color: isUnlocked
                      ? level.color
                      : (isDark ? Colors.white24 : Colors.grey),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${level.name} — ${level.nameQuechua}',
                          style: AppTextStyles.h3.copyWith(
                            color: isUnlocked
                                ? (isDark ? Colors.white : AppColors.textPrimary)
                                : (isDark ? Colors.white24 : Colors.grey),
                            fontSize: 15,
                          ),
                        ),
                        if (levelCompleted && isUnlocked) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked
                          ? level.description
                          : 'Completa el nivel anterior para desbloquear',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isUnlocked
                            ? (isDark
                            ? Colors.white54
                            : AppColors.textSecondary)
                            : (isDark ? Colors.white12 : Colors.grey[400]),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Progreso del nivel
              if (isUnlocked)
                Text(
                  '$levelLearned/$levelTotal',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: level.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Módulos del nivel
        ...level.moduleIds.map((moduleId) {
          final module = _modules.firstWhere(
                (m) => m.id == moduleId,
            orElse: () => _modules.first,
          );
          final color = AppColors.getModuleColor(module.id ?? 1);
          final icon = AppColors.getModuleIcon(module.icon);
          final learnedWords = _moduleProgress[module.id] ?? 0;
          final bestScore = _moduleEvalScores[module.id] ?? 0.0;
          final isMastered = learnedWords >= 5 && bestScore >= 70;
          final isCompleted = learnedWords >= 10 && bestScore >= 70;
          final progress = learnedWords / 10.0;
          final moduleUnlocked = _isModuleUnlocked(module.id!);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildModuleCard(
              module: module,
              icon: icon,
              color: color,
              progress: progress,
              learnedWords: learnedWords,
              bestScore: bestScore,
              isMastered: isMastered,
              isCompleted: isCompleted,
              isLocked: !moduleUnlocked,
              isDark: isDark,
              onTap: moduleUnlocked
                  ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ModuleScreen(module: module),
                  ),
                );
                _refreshProgress();
              }
                  : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isUnlocked
                          ? 'Completa el módulo anterior para desbloquear este'
                          : 'Completa el nivel ${kLevels[levelIndex - 1].name} para desbloquear',
                    ),
                    backgroundColor: const Color(0xFF616161),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final firstName = _userName.split(' ').first;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡${_getGreeting()}, $firstName!',
                style: AppTextStyles.h2.copyWith(
                  color: isDark ? Colors.white : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${_getLevelLabel()} · ${_getLevelSubtitle()}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color:
                        isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 28,
          backgroundColor:
          AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
          child: Text(
            _avatarIndex < kAvatarEmojis.length
                ? kAvatarEmojis[_avatarIndex]
                : kAvatarEmojis[0],
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(bool isDark) {
    final String emoji;
    final String title;
    final String subtitle;
    final Color accentColor;

    if (_streakWasLost && _previousStreak > 1) {
      emoji = '💔';
      title = 'Racha perdida';
      subtitle =
      'Tenías $_previousStreak días. ¡Practica hoy para empezar una nueva!';
      accentColor = AppColors.warning;
    } else if (_streakDays == 0) {
      emoji = '❄️';
      title = 'Sin racha activa';
      subtitle =
      '¡Aprende una palabra o haz una evaluación para comenzar!';
      accentColor = AppColors.info;
    } else {
      emoji = '🔥';
      title =
      '$_streakDays ${_streakDays == 1 ? 'día' : 'días'} de racha';
      subtitle = _streakDays >= 7
          ? '¡Increíble constancia! Sigue así'
          : _streakDays >= 3
          ? '¡Vas muy bien! No pierdas la racha'
          : '¡Buen inicio! Practica mañana también';
      accentColor = AppColors.secondary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                    isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_streakDays > 0)
            Text(
              '$_streakDays',
              style: AppTextStyles.h1.copyWith(
                color: accentColor,
                fontSize: 36,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final totalWords = _modules.length * 10;
    final progressPercentage =
    totalWords > 0 ? _totalLearnedWords / totalWords : 0.0;

    final progressMessage = _totalLearnedWords == 0
        ? '¡Comienza tu viaje de aprendizaje!'
        : _totalLearnedWords < (totalWords * 0.25).round()
        ? '¡Vas muy bien! Sigue aprendiendo'
        : _totalLearnedWords < (totalWords * 0.75).round()
        ? '¡Gran progreso! Ya dominas varias palabras'
        : _totalLearnedWords < totalWords
        ? '¡Estás cerca de completar todo!'
        : '¡Felicidades! Has completado todas las palabras';

    final decoration = isDark
        ? BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.primary.withOpacity(0.4),
        width: 1.5,
      ),
    )
        : BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final titleColor = isDark ? Colors.white : AppColors.textLight;
    final badgeBg = isDark
        ? AppColors.primary.withOpacity(0.3)
        : Colors.white.withOpacity(0.2);
    final badgeText =
    isDark ? AppColors.primaryLight : AppColors.textLight;
    final progressBg = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.white.withOpacity(0.3);
    final progressFill = isDark ? AppColors.primaryLight : Colors.white;
    final messageColor =
    isDark ? Colors.white70 : AppColors.textLight.withOpacity(0.9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tu Progreso',
                style: AppTextStyles.h3.copyWith(color: titleColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_totalLearnedWords/$totalWords',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: badgeText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: progressBg,
              valueColor: AlwaysStoppedAnimation<Color>(progressFill),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progressMessage,
            style:
            AppTextStyles.bodyMedium.copyWith(color: messageColor),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required ModuleModel module,
    required IconData icon,
    required Color color,
    required double progress,
    required int learnedWords,
    required double bestScore,
    required bool isMastered,
    required bool isCompleted,
    required bool isLocked,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isLocked ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked
                  ? (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.15))
                  : isCompleted
                  ? AppColors.success.withOpacity(0.6)
                  : isMastered
                  ? AppColors.success.withOpacity(0.3)
                  : isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppColors.progressBackground,
              width: isCompleted ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock : icon,
                      color: isLocked
                          ? (isDark ? Colors.white24 : Colors.grey)
                          : color,
                      size: 28,
                    ),
                  ),
                  if (isMastered && !isLocked)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.secondary
                              : AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.emoji_events
                              : Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: AppTextStyles.h3.copyWith(
                        color: isLocked
                            ? (isDark ? Colors.white38 : Colors.grey)
                            : (isDark ? Colors.white : null),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.nameQuechua,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isLocked
                            ? (isDark ? Colors.white12 : Colors.grey[400])
                            : color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isLocked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.book_outlined,
                              size: 14,
                              color: learnedWords >= 10
                                  ? AppColors.success
                                  : (isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary)),
                          const SizedBox(width: 4),
                          Text(
                            '$learnedWords/10',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: learnedWords >= 10
                                  ? AppColors.success
                                  : (isDark ? Colors.white54 : null),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.quiz_outlined,
                            size: 14,
                            color: bestScore >= 70
                                ? AppColors.success
                                : (isDark
                                ? Colors.white54
                                : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bestScore > 0
                                ? '${bestScore.toInt()}%'
                                : 'Sin evaluar',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: bestScore >= 70
                                  ? AppColors.success
                                  : (isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary),
                              fontSize: 11,
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
                          valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isLocked
                    ? Icons.lock
                    : isCompleted
                    ? Icons.emoji_events
                    : Icons.arrow_forward_ios,
                size: 20,
                color: isLocked
                    ? (isDark ? Colors.white12 : Colors.grey[400])
                    : isCompleted
                    ? AppColors.secondary
                    : (isDark
                    ? Colors.white38
                    : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}