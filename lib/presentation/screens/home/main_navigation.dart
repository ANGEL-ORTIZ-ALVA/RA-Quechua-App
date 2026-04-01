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
  String _birthdayGreeting = '';

  final List<Widget> _screens = const [
    HomeScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkBirthday();
  }

  // ─── VERIFICAR CUMPLEAÑOS ───
  Future<void> _checkBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final birthdayStr = prefs.getString('user_birthday') ?? '';
    if (birthdayStr.isEmpty) return;

    try {
      final parts = birthdayStr.split('-'); // YYYY-MM-DD
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final now = DateTime.now();

      if (now.month == month && now.day == day) {
        final name = prefs.getString('user_name') ?? 'Usuario';
        setState(() {
          _birthdayGreeting =
          '🎂 ¡Kusikuy punchawniykipi, $name! ¡Feliz cumpleaños!';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Banner de cumpleaños
          if (_birthdayGreeting.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.secondary.withOpacity(isDark ? 0.3 : 0.15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _birthdayGreeting,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _birthdayGreeting = ''),
                    child: Icon(Icons.close,
                        size: 18,
                        color: isDark ? Colors.white54 : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
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
}