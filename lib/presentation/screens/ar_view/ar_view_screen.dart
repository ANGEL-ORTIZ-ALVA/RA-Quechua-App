import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/word_model.dart';

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
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: widget.moduleColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Text(
          'Modelo 3D - ${widget.word.wordQuechua}',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tarjeta de información de la palabra
          _buildWordInfoBar(),

          // Visor 3D
          Expanded(
            child: _buildModelViewer(),
          ),

          // Controles inferiores
          _buildBottomControls(),
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
          // Botón de audio
          if (widget.word.audioPath != null && widget.word.audioPath!.isNotEmpty)
            GestureDetector(
              onTap: _playAudio,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: AppColors.textLight,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModelViewer() {
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
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'El modelo 3D de "${widget.word.wordQuechua}" estará disponible próximamente.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ModelViewer(
      src: modelUrl,
      alt: 'Modelo 3D de ${widget.word.wordQuechua}',
      ar: true,
      arModes: const ['scene-viewer', 'webxr', 'quick-look'],
      autoRotate: true,
      autoRotateDelay: 0,
      rotationPerSecond: '30deg',
      cameraControls: true,
      disableZoom: false,
      backgroundColor: const Color(0xFFF5F5F5),
      arScale: ArScale.auto,
      arPlacement: ArPlacement.floor,
      cameraOrbit: '0deg 75deg 105%',
    );
  }
  Widget _buildBottomControls() {
    final hasModel = widget.word.model3dPath != null && widget.word.model3dPath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          // Instrucciones
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.moduleColor.withOpacity(0.1),
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
                        ? 'Arrastra para rotar • Pellizca para zoom • Presiona el ícono AR para ver en tu espacio'
                        : 'El modelo 3D estará disponible próximamente',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Botón de audio grande
          if (widget.word.audioPath != null && widget.word.audioPath!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playAudio,
                icon: Icon(
                  _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
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