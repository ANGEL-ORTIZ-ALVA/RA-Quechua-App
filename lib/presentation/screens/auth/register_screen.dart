// lib/presentation/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _selectedAvatar = 0;
  String _birthday = '';

  // ─── MISMOS AVATARES QUE ProfileScreen ───
  static const List<String> _avatarEmojis = [
    '🦙', // Llama
    '🏔️', // Montaña
    '🌞', // Inti/Sol
    '🦅', // Cóndor
    '🌽', // Maíz
    '🎵', // Música
    '🌈', // Arcoíris
    '🪶', // Pluma
    '🏺', // Cerámica
    '⭐', // Estrella
    '🔥', // Nina/Fuego
    '🌺', // Tika/Flor
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday.isNotEmpty
          ? DateTime.tryParse(_birthday) ?? DateTime(2000)
          : DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final dateStr =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _birthday = dateStr);
    }
  }

  String _formatBirthday(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final months = [
        '',
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre'
      ];
      return '${parts[2]} de ${months[int.parse(parts[1])]} de ${parts[0]}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setInt('user_avatar', _selectedAvatar);
      await prefs.setString('user_level', 'Qallariq');
      await prefs.setBool('is_registered', true);
      await prefs.setInt('words_learned', 0);

      // Guardar birthday solo si se seleccionó
      if (_birthday.isNotEmpty) {
        await prefs.setString('user_birthday', _birthday);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── TÍTULO ───
                Text(
                  '¡Crea tu perfil!',
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Personaliza tu experiencia de aprendizaje en Quechua Chanka',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // ─── AVATAR PREVIEW + SELECTOR ───
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withOpacity(isDark ? 0.3 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.5),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _avatarEmojis[_selectedAvatar],
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Elige tu avatar',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _avatarEmojis.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedAvatar == index;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedAvatar = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              .withOpacity(isDark ? 0.3 : 0.15)
                              : (isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.transparent),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _avatarEmojis[index],
                            style: TextStyle(
                                fontSize: isSelected ? 28 : 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // ─── CAMPO DE NOMBRE ───
                Text(
                  '¿Cómo te llamas?',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tu nombre',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : null,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu nombre';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ─── FECHA DE NACIMIENTO (OPCIONAL) ───
                Text(
                  'Fecha de nacimiento (opcional)',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthday,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _birthday.isNotEmpty
                                ? _formatBirthday(_birthday)
                                : 'Seleccionar fecha',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: _birthday.isNotEmpty
                                  ? (isDark
                                  ? Colors.white
                                  : AppColors.textPrimary)
                                  : (isDark
                                  ? Colors.white38
                                  : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        Icon(Icons.calendar_today,
                            size: 18,
                            color: isDark
                                ? Colors.white38
                                : AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ─── INFO SOBRE NIVELES ───
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.info.withOpacity(0.15)
                        : AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Comenzarás como Qallariq (principiante) y avanzarás a Yachaq y Hamawt\'a según tu progreso',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? Colors.white70
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── BOTÓN CONTINUAR ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveUserData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Comenzar a Aprender',
                      style: AppTextStyles.button,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}