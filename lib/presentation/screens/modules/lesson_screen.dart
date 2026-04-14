import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/streak_helper.dart';
import '../../../core/utils/achievements_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/datasources/database_helper.dart';
import '../ar_view/ar_view_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class LessonScreen extends StatefulWidget {
  final WordModel word;
  final Color moduleColor;

  const LessonScreen({
    super.key,
    required this.word,
    required this.moduleColor,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _isLearned = false;
  bool _isLoading = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  bool get _hasModel3D =>
      widget.word.model3dPath != null && widget.word.model3dPath!.isNotEmpty;

  bool get _hasAudio =>
      widget.word.audioPath != null && widget.word.audioPath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLearnedStatus();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() => _isPlayingAudio = state == PlayerState.playing);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLearnedStatus() async {
    final isLearned =
    await DatabaseHelper.instance.isWordLearned(widget.word.id!);
    setState(() {
      _isLearned = isLearned;
      _isLoading = false;
    });
  }

  Future<void> _toggleLearned() async {
    final newStatus = !_isLearned;
    setState(() => _isLearned = newStatus);
    await DatabaseHelper.instance.toggleWordLearned(widget.word.id!, newStatus);

    if (newStatus) {
      await StreakHelper.recordActivity();
      // Verificar y notificar logros nuevos
      if (mounted) {
        await AchievementsHelper.checkAndNotify(context);
      }
    }

    _showLearnedFeedback();
  }

  Future<void> _playAudio() async {
    final audioUrl = widget.word.audioPath;
    if (audioUrl == null || audioUrl.isEmpty) {
      _showSnackBar('Audio no disponible para esta palabra', AppColors.warning);
      return;
    }

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        return;
      }
      setState(() => _isPlayingAudio = true);

      // Descargar/cachear el audio primero, luego reproducir local
      final file = await DefaultCacheManager()
          .getSingleFile(audioUrl)
          .timeout(const Duration(seconds: 10));
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
        _showSnackBar(
          'Sin conexión. Conéctate a internet para escuchar el audio.',
          const Color(0xFF616161),
        );
      }
    }
  }
  void _openArView() {
    if (_isPlayingAudio) _audioPlayer.stop();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArViewScreen(
          word: widget.word,
          moduleColor: widget.moduleColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: widget.moduleColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Text(
          'Lección',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _isLearned ? Icons.check_circle : Icons.check_circle_outline,
                color: AppColors.textLight,
              ),
              onPressed: _toggleLearned,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor:
          AlwaysStoppedAnimation<Color>(widget.moduleColor),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMainCard(isDark),
            const SizedBox(height: 16),
            _buildPhoneticCard(isDark),
            const SizedBox(height: 16),
            _buildLearnedButton(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildInfoSection(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: widget.moduleColor,
        boxShadow: [
          BoxShadow(
            color: widget.moduleColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Text(
              widget.word.wordQuechua,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.textLight,
                fontSize: 36,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.word.wordSpanish,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textLight.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 4,
        color: isDark ? Theme.of(context).cardColor : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.moduleColor.withOpacity(isDark ? 0.2 : 0.1),
                widget.moduleColor.withOpacity(isDark ? 0.1 : 0.05),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.word.imagePath != null &&
                widget.word.imagePath!.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: widget.word.imagePath!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      widget.moduleColor),
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off,
                        size: 48,
                        color: widget.moduleColor.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'Sin conexión',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Conéctate a internet para ver la imagen',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined,
                      size: 100,
                      color: widget.moduleColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Imagen no disponible',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildPhoneticCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 2,
        color: isDark ? Theme.of(context).cardColor : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.record_voice_over,
                  color: widget.moduleColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pronunciación',
                      style: AppTextStyles.bodySmall.copyWith(
                        color:
                        isDark ? Colors.white54 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.word.phonetic,
                      style: AppTextStyles.h3.copyWith(
                        color: widget.moduleColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildMiniAudioButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniAudioButton() {
    return GestureDetector(
      onTap: _hasAudio ? _playAudio : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isPlayingAudio
              ? widget.moduleColor
              : widget.moduleColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
          color:
          _isPlayingAudio ? AppColors.textLight : widget.moduleColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLearnedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _toggleLearned,
        icon: Icon(
          _isLearned ? Icons.check_circle : Icons.check_circle_outline,
        ),
        label: Text(
            _isLearned ? '¡Palabra aprendida!' : 'Marcar como aprendida'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLearned
              ? AppColors.success
              : widget.moduleColor.withOpacity(0.2),
          foregroundColor:
          _isLearned ? AppColors.textLight : widget.moduleColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
              _isLearned ? AppColors.success : widget.moduleColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _hasAudio ? _playAudio : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up,
                  key: ValueKey<bool>(_isPlayingAudio),
                ),
              ),
              label: Text(_isPlayingAudio ? 'Detener' : 'Escuchar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPlayingAudio
                    ? AppColors.error.withOpacity(0.9)
                    : widget.moduleColor,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_hasModel3D) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openArView,
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Ver en RA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    final infoText = _hasModel3D
        ? 'Presiona "Escuchar" para oír la pronunciación en quechua. '
        'Presiona "Ver en RA" para explorar el modelo 3D e interactuar con realidad aumentada.'
        : 'Presiona "Escuchar" para oír la pronunciación en quechua.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sobre esta palabra',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
              icon: Icons.translate,
              title: 'Quechua',
              content: widget.word.wordQuechua,
              isDark: isDark),
          const SizedBox(height: 8),
          _buildInfoItem(
              icon: Icons.language,
              title: 'Español',
              content: widget.word.wordSpanish,
              isDark: isDark),
          const SizedBox(height: 8),
          _buildInfoItem(
              icon: Icons.text_fields,
              title: 'Pronunciación fonética',
              content: widget.word.phonetic,
              isDark: isDark),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
              widget.moduleColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.moduleColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: widget.moduleColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    infoText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color:
                      isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: widget.moduleColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                    isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLearnedFeedback() {
    _showSnackBar(
      _isLearned
          ? '¡Palabra marcada como aprendida!'
          : 'Desmarcada como aprendida',
      _isLearned ? AppColors.success : AppColors.info,
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}