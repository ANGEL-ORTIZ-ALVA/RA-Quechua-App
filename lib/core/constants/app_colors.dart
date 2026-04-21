import 'package:flutter/material.dart';

class AppColors {
  // Colores principales - Tema Quechua (inspirado en textiles andinos)
  static const Color primary = Color(0xFFD32F2F); // Rojo andino
  static const Color primaryDark = Color(0xFF9A0007);
  static const Color primaryLight = Color(0xFFFF6659);

  static const Color secondary = Color(0xFFFFA726); // Naranja/dorado
  static const Color secondaryDark = Color(0xFFC77800);
  static const Color secondaryLight = Color(0xFFFFD95B);

  static const Color accent = Color(0xFF00897B); // Verde esmeralda

  // Colores de fondo
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF424242);

  // Colores de texto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);

  // Colores de estado
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Colores para progreso
  static const Color progressBackground = Color(0xFFE0E0E0);
  static const Color progressFill = Color(0xFF4CAF50);

  // ─── COLORES POR MÓDULO (centralizado) ───
  // IDs: 1=Animales, 2=Naturaleza, 3=Familia, 4=Números, 5=Saludos, 6=Colores,
  //       7=Vocales, 8=Alfabeto, 9=Figuras, 10=Frases, 11=Oraciones
  static const List<Color> moduleColors = [
    Color(0xFFC62828), // 1 Animales     — rojo intenso
    Color(0xFF2E7D32), // 2 Naturaleza   — verde bosque
    Color(0xFF00838F), // 3 Familia      — teal
    Color(0xFF1565C0), // 4 Números      — azul
    Color(0xFF6A1B9A), // 5 Saludos      — púrpura
    Color(0xFFAD1457), // 6 Colores      — rosa
    Color(0xFFE65100), // 7 Vocales      — naranja intenso
    Color(0xFF4527A0), // 8 Alfabeto     — índigo
    Color(0xFF00695C), // 9 Figuras      — verde azulado
    Color(0xFF37474F), // 10 Frases      — gris azulado
    Color(0xFF880E4F), // 11 Oraciones   — magenta oscuro
    Color(0xFF546E7A), // 12 Gramática   — gris azul slate
  ];

  /// Devuelve el color del módulo según su ID (1-based).
  static Color getModuleColor(int moduleId) {
    if (moduleId >= 1 && moduleId <= moduleColors.length) {
      return moduleColors[moduleId - 1];
    }
    return primary;
  }

  /// Mapea el string del ícono (almacenado en la BD) a IconData
  static IconData getModuleIcon(String iconName) {
    switch (iconName) {
      case 'pets':
        return Icons.pets;
      case 'park':
        return Icons.park;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'pin':
        return Icons.tag;
      case 'waving_hand':
        return Icons.waving_hand;
      case 'palette':
        return Icons.palette;
      case 'record_voice_over':
        return Icons.record_voice_over;
      case 'abc':
        return Icons.abc;
      case 'category':
        return Icons.category;
      case 'chat_bubble':
        return Icons.chat_bubble_outline;
      case 'menu_book':
        return Icons.menu_book;
      case 'rule':
        return Icons.rule;
      default:
        return Icons.book;
    }
  }
}