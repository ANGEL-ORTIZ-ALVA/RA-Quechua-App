import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/datasources/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  int _selectedAvatar = 0;
  String _birthday = '';
  bool _isLoading = true;

  // ─── AVATARES PREDEFINIDOS (temática andina) ───
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
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _selectedAvatar = prefs.getInt('user_avatar') ?? 0;
      _birthday = prefs.getString('user_birthday') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveAvatar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_avatar', index);
    setState(() => _selectedAvatar = index);
    _showSnackBar('Avatar actualizado', AppColors.success);
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    setState(() => _userName = name);
    _showSnackBar('Nombre actualizado', AppColors.success);
  }

  Future<void> _saveBirthday(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await prefs.setString('user_birthday', dateStr);
    setState(() => _birthday = dateStr);
    _showSnackBar('Fecha de nacimiento guardada', AppColors.success);
  }

  Future<void> _resetProgress() async {
    final db = await DatabaseHelper.instance.database;

    // Eliminar progreso y evaluaciones
    await db.delete('progress');
    await db.delete('evaluations');

    // Resetear racha
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_count', 0);
    await prefs.remove('last_active_date');

    if (mounted) {
      _showSnackBar('Progreso reiniciado', AppColors.info);
    }
  }

  /// Getter público para que MainNavigation lea el avatar
  static Future<int> getAvatarIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_avatar') ?? 0;
  }

  static String getAvatarEmoji(int index) {
    if (index >= 0 && index < _avatarEmojis.length) {
      return _avatarEmojis[index];
    }
    return _avatarEmojis[0];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi Perfil',
                style: AppTextStyles.h1.copyWith(
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 32),

              // Avatar + nombre
              _buildProfileHeader(isDark),
              const SizedBox(height: 32),

              // Selector de avatar
              _buildSection('Elige tu avatar', isDark),
              const SizedBox(height: 12),
              _buildAvatarGrid(isDark),
              const SizedBox(height: 32),

              // Cambiar nombre
              _buildSection('Nombre', isDark),
              const SizedBox(height: 12),
              _buildNameField(isDark),
              const SizedBox(height: 32),

              // Fecha de nacimiento
              _buildSection('Fecha de nacimiento', isDark),
              const SizedBox(height: 12),
              _buildBirthdayField(isDark),
              const SizedBox(height: 40),

              // Zona de peligro
              _buildDangerZone(isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Center(
      child: Column(
        children: [
          // Avatar grande
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
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
          const SizedBox(height: 16),
          Text(
            _userName,
            style: AppTextStyles.h2.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
          if (_birthday.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '🎂 $_birthday',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white38 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool isDark) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: isDark ? Colors.white : null,
        fontSize: 16,
      ),
    );
  }

  Widget _buildAvatarGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _avatarEmojis.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedAvatar == index;

        return GestureDetector(
          onTap: () => _saveAvatar(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(isDark ? 0.3 : 0.15)
                  : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
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
                style: TextStyle(fontSize: isSelected ? 28 : 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameField(bool isDark) {
    final controller = TextEditingController(text: _userName);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
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
              fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.length >= 3) {
              _saveName(name);
              FocusScope.of(context).unfocus();
            } else {
              _showSnackBar(
                  'El nombre debe tener al menos 3 caracteres', AppColors.warning);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildBirthdayField(bool isDark) {
    return InkWell(
      onTap: () async {
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
          _saveBirthday(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              _birthday.isNotEmpty
                  ? _formatBirthday(_birthday)
                  : 'Seleccionar fecha',
              style: AppTextStyles.bodyLarge.copyWith(
                color: _birthday.isNotEmpty
                    ? (isDark ? Colors.white : AppColors.textPrimary)
                    : (isDark ? Colors.white38 : AppColors.textSecondary),
              ),
            ),
            const Spacer(),
            Icon(Icons.calendar_today,
                size: 18,
                color: isDark ? Colors.white38 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatBirthday(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final months = [
        '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      return '${parts[2]} de ${months[int.parse(parts[1])]} de ${parts[0]}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildDangerZone(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Zona de reinicio',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Esto eliminará todas las palabras aprendidas, evaluaciones y racha. Tu nombre y avatar se mantienen.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showResetConfirmation(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reiniciar progreso'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '¿Reiniciar todo el progreso?',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
          content: Text(
            'Se eliminarán todas las palabras aprendidas, evaluaciones y racha de días. Esta acción no se puede deshacer.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetProgress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reiniciar'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}