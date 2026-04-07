import 'package:shared_preferences/shared_preferences.dart';

class StreakHelper {
  /// Llamar cuando el usuario practica (aprende palabra o completa evaluación).
  /// Retorna el nuevo streak count.
  static Future<int> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _dateToString(DateTime.now());
    final lastActiveDate = prefs.getString('last_active_date') ?? '';
    final currentStreak = prefs.getInt('streak_count') ?? 0;

    // Ya practicó hoy → no incrementar
    if (lastActiveDate == todayStr) {
      return currentStreak;
    }

    final yesterdayStr =
    _dateToString(DateTime.now().subtract(const Duration(days: 1)));

    int newStreak;
    if (lastActiveDate == yesterdayStr) {
      // Día consecutivo → incrementar
      newStreak = currentStreak + 1;
    } else {
      // Primer día o se perdió la racha → empezar en 1
      newStreak = 1;
    }

    await prefs.setString('last_active_date', todayStr);
    await prefs.setInt('streak_count', newStreak);
    return newStreak;
  }

  /// Lee la racha actual y detecta si se perdió.
  /// Retorna: {streak, isActive, wasLost, previousStreak}
  static Future<Map<String, dynamic>> getStreakInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStreak = prefs.getInt('streak_count') ?? 0;
    final lastActiveDate = prefs.getString('last_active_date') ?? '';

    if (lastActiveDate.isEmpty) {
      return {
        'streak': 0,
        'isActive': false,
        'wasLost': false,
        'previousStreak': 0,
      };
    }

    final todayStr = _dateToString(DateTime.now());
    final yesterdayStr =
    _dateToString(DateTime.now().subtract(const Duration(days: 1)));

    final isActiveToday = lastActiveDate == todayStr;
    final isAtRisk = lastActiveDate == yesterdayStr;
    final wasLost = !isActiveToday && !isAtRisk && currentStreak > 0;

    if (wasLost) {
      // La racha se perdió → guardar el valor anterior y resetear
      final previousStreak = currentStreak;
      await prefs.setInt('streak_count', 0);
      return {
        'streak': 0,
        'isActive': false,
        'wasLost': true,
        'previousStreak': previousStreak,
      };
    }

    return {
      'streak': currentStreak,
      'isActive': isActiveToday,
      'wasLost': false,
      'previousStreak': 0,
    };
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}