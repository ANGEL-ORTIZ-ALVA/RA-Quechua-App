import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/word_model.dart';
import 'dart:io';
import 'dart:async';

class ArViewScreen extends StatefulWidget {
  final WordModel word;
  final Color moduleColor;

  const ArViewScreen({
    super.key,
    required this.word,
    required this.moduleColor,
  });

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  // ─── Estado de conectividad para el modelo 3D ───
  bool _isOffline = false;
  bool _isRetrying = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
    _checkFirstTimeAr();
    _initialConnectivityCheck();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  // ─── CONECTIVIDAD ───
  Future<void> _initialConnectivityCheck() async {
    final online = await _checkConnectivity();
    if (!online && mounted) {
      setState(() => _isOffline = true);
      _startConnectivityCheck();
    }
  }

  void _startConnectivityCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _recheckConnectivity(),
    );
  }

  Future<void> _recheckConnectivity() async {
    final online = await _checkConnectivity();
    if (online && _isOffline && mounted) {
      _connectivityTimer?.cancel();
      setState(() {
        _isOffline = false;
        _isRetrying = false;
      });
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _retryConnection() async {
    setState(() => _isRetrying = true);
    final online = await _checkConnectivity();
    if (mounted) {
      if (online) {
        _connectivityTimer?.cancel();
        setState(() {
          _isOffline = false;
          _isRetrying = false;
        });
      } else {
        setState(() => _isRetrying = false);
        _startConnectivityCheck();
      }
    }
  }

  // ─── TUTORIAL AR (primera vez) ───
  Future<void> _checkFirstTimeAr() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('ar_tutorial_seen') ?? false;

    if (!hasSeenTutorial && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showArTutorial();
      });
    }
  }

  void _showArTutorial() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: widget.moduleColor.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.view_in_ar,
                  color: widget.moduleColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¿Cómo usar la Realidad Aumentada?',
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildTutorialStep(
                icon: Icons.touch_app,
                title: 'Explora el modelo 3D',
                description: 'Arrastra para rotar y pellizca para hacer zoom',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTutorialStep(
                icon: Icons.view_in_ar,
                title: 'Activa la Realidad Aumentada',
                description:
                'Toca el ícono del cubo en la esquina inferior derecha',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTutorialStep(
                icon: Icons.phone_android,
                title: 'Apunta a una superficie',
                description:
                'Enfoca una mesa o el suelo y mueve lentamente el celular',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTutorialStep(
                icon: Icons.ads_click,
                title: 'Coloca el modelo',
                description:
                'Toca la pantalla para posicionar el objeto en el espacio',
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Para mejores resultados, usa un lugar bien iluminado con una superficie plana visible.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color:
                          isDark ? Colors.white70 : AppColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('ar_tutorial_seen', true);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.moduleColor,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('¡Entendido!'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTutorialStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.moduleColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: widget.moduleColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── AUDIO ───
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

  Future<void> _playAudio() async {
    final audioUrl = widget.word.audioPath;
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        return;
      }
      setState(() => _isPlayingAudio = true);

      final file = await DefaultCacheManager()
          .getSingleFile(audioUrl)
          .timeout(const Duration(seconds: 10));
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Sin conexión. Conéctate a internet para escuchar el audio.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : AppColors.background,
      appBar: AppBar(
        backgroundColor: widget.moduleColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Text(
          'Modelo 3D - ${widget.word.wordQuechua}',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showArTutorial,
            tooltip: 'Cómo usar AR',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWordInfoBar(),
          Expanded(child: _buildModelViewer(isDark)),
          _buildBottomControls(isDark),
        ],
      ),
    );
  }

  Widget _buildWordInfoBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.word.wordQuechua,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.word.wordSpanish}  •  ${widget.word.phonetic}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textLight.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (widget.word.audioPath != null &&
              widget.word.audioPath!.isNotEmpty)
            GestureDetector(
              onTap: _playAudio,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingAudio
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                  color: AppColors.textLight,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── MODELO 3D CON DETECCIÓN DE CONECTIVIDAD ───
  Widget _buildModelViewer(bool isDark) {
    final modelUrl = widget.word.model3dPath;

    if (modelUrl == null || modelUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_in_ar_outlined,
              size: 100,
              color: widget.moduleColor.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Modelo 3D no disponible aún',
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'El modelo 3D de "${widget.word.wordQuechua}" estará disponible próximamente.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Si está offline, mostrar mensaje con reintentar
    if (_isOffline) {
      return _buildOfflineMessage(isDark);
    }

    // Online: mostrar modelo
    return ModelViewer(
      key: ValueKey('model_${widget.word.id}_$_isOffline'),
      src: modelUrl,
      alt: 'Modelo 3D de ${widget.word.wordQuechua}',
      ar: true,
      arModes: const ['scene-viewer', 'webxr', 'quick-look'],
      autoRotate: true,
      autoRotateDelay: 0,
      rotationPerSecond: '30deg',
      cameraControls: true,
      disableZoom: false,
      backgroundColor:
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      arScale: ArScale.fixed,
      arPlacement: ArPlacement.floor,
      cameraOrbit: '0deg 75deg 105%',
      fieldOfView: '30deg',
      shadowIntensity: 0.5,
      loading: Loading.eager,
    );
  }

  Widget _buildOfflineMessage(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: widget.moduleColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin conexión a internet',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Conéctate a internet para cargar el modelo 3D y usar la Realidad Aumentada',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _isRetrying
              ? SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              valueColor:
              AlwaysStoppedAnimation<Color>(widget.moduleColor),
              strokeWidth: 3,
            ),
          )
              : OutlinedButton.icon(
            onPressed: _retryConnection,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.moduleColor,
              side: BorderSide(color: widget.moduleColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    final hasModel = widget.word.model3dPath != null &&
        widget.word.model3dPath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.moduleColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.moduleColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: widget.moduleColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasModel
                        ? 'Arrastra para rotar • Pellizca para zoom\nToca el ícono AR y apunta a una superficie plana (mesa o suelo)'
                        : 'El modelo 3D estará disponible próximamente',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.word.audioPath != null &&
              widget.word.audioPath!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playAudio,
                icon: Icon(
                  _isPlayingAudio
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                ),
                label: Text(
                  _isPlayingAudio
                      ? 'Detener pronunciación'
                      : 'Escuchar "${widget.word.wordQuechua}"',
                ),
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
        ],
      ),
    );
  }
}