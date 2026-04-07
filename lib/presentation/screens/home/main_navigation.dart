import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'home_screen.dart';
import '../stats/stats_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isBirthday = false;
  bool _bannerDismissed = false; // Para que el X funcione sin bloquear futuros checks
  String _userName = '';

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const StatsScreen(),
      ProfileScreen(onBirthdayChanged: _onBirthdayChanged),
    ];
    _checkBirthday();
  }

  /// Llamado cuando el usuario cambia su fecha de nacimiento en Perfil
  void _onBirthdayChanged() {
    _bannerDismissed = false; // Resetear el dismiss porque la fecha cambió
    _checkBirthday();
  }

  // ─── VERIFICAR CUMPLEAÑOS ───
  Future<void> _checkBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final birthdayStr = prefs.getString('user_birthday') ?? '';
    final name = prefs.getString('user_name') ?? 'Usuario';

    if (birthdayStr.isEmpty || birthdayStr.length < 10) {
      if (mounted) {
        setState(() {
          _isBirthday = false;
          _userName = name;
        });
      }
      return;
    }

    try {
      final parts = birthdayStr.split('-');
      if (parts.length != 3) {
        if (mounted) {
          setState(() {
            _isBirthday = false;
            _userName = name;
          });
        }
        return;
      }

      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final now = DateTime.now();
      final isToday = now.month == month && now.day == day;

      if (mounted) {
        setState(() {
          _isBirthday = isToday && !_bannerDismissed;
          _userName = name;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBirthday = false;
          _userName = name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          if (_isBirthday) _buildBirthdayBanner(isDark),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _checkBirthday();
        },
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayBanner(bool isDark) {
    final firstName = _userName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 20,
        right: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF4A2800), const Color(0xFF2A1800)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(isDark ? 0.3 : 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🎂', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Kusikuy punchawniykipi, $firstName!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color:
                    isDark ? Colors.orange[200] : const Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '¡Feliz cumpleaños! 🎉',
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                    isDark ? Colors.orange[100] : const Color(0xFFBF360C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isBirthday = false;
                _bannerDismissed = true; // No mostrar hasta que cambie la fecha
              });
            },
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? Colors.orange[200] : const Color(0xFFBF360C),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}