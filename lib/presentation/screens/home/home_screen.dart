import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/module_model.dart';
import '../modules/module_screen.dart';

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
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadUserData();
    await _loadModules();
    await _loadProgress();
    await _updateStreak();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
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

      for (var module in _modules) {
        final learned =
        await DatabaseHelper.instance.getLearnedWordsCount(module.id!);
        moduleProgressMap[module.id!] = learned;
        total += learned;
      }

      setState(() {
        _totalLearnedWords = total;
        _moduleProgress = moduleProgressMap;
        _isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_level', _getLevelLabel());
    } catch (e) {
      print('Error loading progress: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── RACHA DE DÍAS CONSECUTIVOS ───
  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _dateToString(DateTime.now());
    final lastActiveDate = prefs.getString('last_active_date') ?? '';
    final currentStreak = prefs.getInt('streak_count') ?? 0;

    if (lastActiveDate == todayStr) {
      setState(() => _streakDays = currentStreak);
      return;
    }

    final yesterdayStr =
    _dateToString(DateTime.now().subtract(const Duration(days: 1)));

    int newStreak;
    if (lastActiveDate == yesterdayStr) {
      newStreak = currentStreak + 1;
    } else {
      newStreak = 1;
    }

    await prefs.setString('last_active_date', todayStr);
    await prefs.setInt('streak_count', newStreak);
    setState(() => _streakDays = newStreak);
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshProgress() async {
    await _loadProgress();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Allin punchaw';
    if (hour >= 12 && hour < 18) return 'Allin chisi';
    return 'Allin tuta';
  }

  String _getLevelLabel() {
    final totalWords = _modules.length * 10;
    if (totalWords == 0) return 'Qallariq';
    if (_totalLearnedWords >= (totalWords * 0.67).round()) return "Hamawt'a";
    if (_totalLearnedWords >= (totalWords * 0.33).round()) return 'Yachaq';
    return 'Qallariq';
  }

  String _getLevelSubtitle() {
    switch (_getLevelLabel()) {
      case 'Qallariq':
        return 'Principiante';
      case 'Yachaq':
        return 'Intermedio';
      case "Hamawt'a":
        return 'Avanzado';
      default:
        return '';
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
                  Text(
                    'Módulos de Aprendizaje',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildModuleCards(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡${_getGreeting()}, $_userName!',
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
                  Text(
                    '${_getLevelLabel()} · ${_getLevelSubtitle()}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
          child: Icon(Icons.person, size: 32, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildStreakCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _streakDays > 0 ? '🔥' : '❄️',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_streakDays ${_streakDays == 1 ? 'día' : 'días'} de racha',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _streakDays >= 7
                      ? '¡Increíble constancia! Sigue así'
                      : _streakDays >= 3
                      ? '¡Vas muy bien! No pierdas la racha'
                      : '¡Aprende hoy para mantener tu racha!',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_streakDays',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.secondary,
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

    // En dark mode: fondo gris oscuro con borde de acento
    // En light mode: gradiente rojo original
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

    // Colores de texto adaptados
    final titleColor = isDark ? Colors.white : AppColors.textLight;
    final badgeBg = isDark
        ? AppColors.primary.withOpacity(0.3)
        : Colors.white.withOpacity(0.2);
    final badgeText = isDark ? AppColors.primaryLight : AppColors.textLight;
    final progressBg = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.white.withOpacity(0.3);
    final progressFill = isDark ? AppColors.primaryLight : Colors.white;
    final messageColor = isDark
        ? Colors.white70
        : AppColors.textLight.withOpacity(0.9);

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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            style: AppTextStyles.bodyMedium.copyWith(color: messageColor),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildModuleCards(bool isDark) {
    return _modules.asMap().entries.map((entry) {
      final module = entry.value;
      final color = AppColors.getModuleColor(module.id ?? 1);
      final icon = AppColors.getModuleIcon(module.icon);
      final learnedWords = _moduleProgress[module.id] ?? 0;
      final progress = learnedWords / 10.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: _buildModuleCard(
          module: module,
          icon: icon,
          color: color,
          progress: progress,
          learnedWords: learnedWords,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleScreen(module: module),
              ),
            );
            _refreshProgress();
          },
        ),
      );
    }).toList();
  }

  Widget _buildModuleCard({
    required ModuleModel module,
    required IconData icon,
    required Color color,
    required double progress,
    required int learnedWords,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : AppColors.progressBackground,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.name,
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.nameQuechua,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.book_outlined,
                          size: 16,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$learnedWords/10 palabras',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? Colors.white54 : null,
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
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 20,
                color: isDark ? Colors.white38 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}