import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/evaluation_model.dart';

/// Estados posibles de una carta
enum _CardState { faceDown, faceUp, matched }

/// Representa una carta del juego de memoria
class _MemoryCard {
  final int id;
  final String content;       // Texto a mostrar (Quechua o Español)
  final bool isQuechua;       // True si es Quechua, false si es Español
  final int pairId;           // Identifica el par (mismo pairId = par)
  _CardState state;

  _MemoryCard({
    required this.id,
    required this.content,
    required this.isQuechua,
    required this.pairId,
    this.state = _CardState.faceDown,
  });
}

/// Juego de memoria: encuentra los pares Quechua ↔ Español
class MemoryGameScreen extends StatefulWidget {
  final ModuleModel module;

  const MemoryGameScreen({super.key, required this.module});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  List<_MemoryCard> _cards = [];
  int _totalPairs = 0;
  int _matchedPairs = 0;
  int _moves = 0;
  int? _firstSelectedIdx;
  int? _secondSelectedIdx;
  bool _isProcessing = false;
  bool _isLoading = true;

  // Timer para tracking del tiempo
  Timer? _gameTimer;
  int _elapsedSeconds = 0;
  bool _gameStarted = false;

  Color get _moduleColor => AppColors.getModuleColor(widget.module.id ?? 1);

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGame() async {
    try {
      final words = await DatabaseHelper.instance.getWordsByModule(widget.module.id!);

      if (words.length < 4) {
        _showError('El módulo necesita al menos 4 palabras para el juego de memoria');
        return;
      }

      // Filtrar palabras que NO son demasiado largas (para que quepan en cartas)
      final suitableWords = words.where((w) =>
      w.wordQuechua.length <= 14 && w.wordSpanish.length <= 16
      ).toList();

      if (suitableWords.length < 4) {
        _showError('Este módulo no tiene palabras aptas para memoria');
        return;
      }

      // Seleccionar 4-6 pares según disponibilidad
      suitableWords.shuffle(Random());
      final pairCount = min(6, suitableWords.length);
      final selectedWords = suitableWords.take(pairCount).toList();

      // Crear cartas: 1 Quechua + 1 Español por palabra
      final cards = <_MemoryCard>[];
      int idCounter = 0;
      for (var i = 0; i < selectedWords.length; i++) {
        final word = selectedWords[i];
        cards.add(_MemoryCard(
          id: idCounter++,
          content: word.wordQuechua,
          isQuechua: true,
          pairId: i,
        ));
        cards.add(_MemoryCard(
          id: idCounter++,
          content: word.wordSpanish,
          isQuechua: false,
          pairId: i,
        ));
      }
      cards.shuffle(Random());

      setState(() {
        _cards = cards;
        _totalPairs = pairCount;
        _matchedPairs = 0;
        _moves = 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading memory game: $e');
      _showError('Error al cargar el juego');
    }
  }

  void _startTimerIfNeeded() {
    if (_gameStarted) return;
    _gameStarted = true;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _onCardTap(int idx) {
    if (_isProcessing) return;
    final card = _cards[idx];
    if (card.state != _CardState.faceDown) return;

    _startTimerIfNeeded();

    setState(() {
      card.state = _CardState.faceUp;
    });

    if (_firstSelectedIdx == null) {
      _firstSelectedIdx = idx;
      return;
    }

    // Segunda carta seleccionada
    _secondSelectedIdx = idx;
    setState(() => _moves++);

    final firstCard = _cards[_firstSelectedIdx!];
    final secondCard = _cards[idx];

    if (firstCard.pairId == secondCard.pairId &&
        firstCard.isQuechua != secondCard.isQuechua) {
      // ¡Match!
      setState(() {
        firstCard.state = _CardState.matched;
        secondCard.state = _CardState.matched;
        _matchedPairs++;
      });
      _firstSelectedIdx = null;
      _secondSelectedIdx = null;

      if (_matchedPairs == _totalPairs) {
        _gameTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 600), _onGameComplete);
      }
    } else {
      // No match: voltear de vuelta
      setState(() => _isProcessing = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          firstCard.state = _CardState.faceDown;
          secondCard.state = _CardState.faceDown;
          _firstSelectedIdx = null;
          _secondSelectedIdx = null;
          _isProcessing = false;
        });
      });
    }
  }

  Future<void> _onGameComplete() async {
    // Calcular eficiencia: ideal sería 2 movimientos por par (uno cada carta)
    // Si user hizo más, eficiencia baja
    final perfectMoves = _totalPairs;
    final efficiency = (perfectMoves / _moves).clamp(0.0, 1.0);
    final percentage = (efficiency * 100).clamp(0.0, 100.0);

    // Guardar en evaluations
    final evaluation = EvaluationModel(
      moduleId: widget.module.id!,
      userId: 1,
      correctAnswers: _totalPairs,
      totalQuestions: _totalPairs,
      percentage: percentage,
      completedAt: DateTime.now().toIso8601String(),
    );
    await DatabaseHelper.instance.insertEvaluation(evaluation);

    if (!mounted) return;
    _showCompletionDialog(percentage);
  }

  void _showCompletionDialog(double percentage) {
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 50;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              isExcellent ? Icons.emoji_events : (isGood ? Icons.thumb_up : Icons.psychology),
              size: 64,
              color: isExcellent
                  ? Colors.amber
                  : (isGood ? AppColors.success : _moduleColor),
            ),
            const SizedBox(height: 12),
            Text(
              isExcellent ? '¡Excelente!' : (isGood ? '¡Bien hecho!' : '¡Sigue practicando!'),
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(Icons.check_circle, 'Pares encontrados', '$_matchedPairs / $_totalPairs'),
            const SizedBox(height: 8),
            _buildStatRow(Icons.touch_app, 'Movimientos', '$_moves'),
            const SizedBox(height: 8),
            _buildStatRow(Icons.timer, 'Tiempo', _formatTime(_elapsedSeconds)),
            const SizedBox(height: 8),
            _buildStatRow(Icons.percent, 'Eficiencia', '${percentage.toInt()}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // cerrar dialog
              Navigator.pop(context); // volver a module screen
            },
            child: Text('Salir', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // cerrar dialog
              _resetGame();
            },
            icon: const Icon(Icons.replay),
            label: const Text('Jugar otra vez'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _moduleColor,
              foregroundColor: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _moduleColor),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.bodyMedium),
          ],
        ),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _resetGame() {
    _gameTimer?.cancel();
    setState(() {
      _isLoading = true;
      _gameStarted = false;
      _elapsedSeconds = 0;
    });
    _loadGame();
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _moduleColor,
        foregroundColor: AppColors.textLight,
        title: Text(
          'Memoria: ${widget.module.name}',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar',
            onPressed: _resetGame,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(isDark),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, idx) => _buildCard(_cards[idx], idx, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _moduleColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip(Icons.check_circle, '$_matchedPairs/$_totalPairs', 'Pares'),
          _buildStatChip(Icons.touch_app, '$_moves', 'Movimientos'),
          _buildStatChip(Icons.timer, _formatTime(_elapsedSeconds), 'Tiempo'),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_MemoryCard card, int idx, bool isDark) {
    final isFaceDown = card.state == _CardState.faceDown;
    final isMatched = card.state == _CardState.matched;

    return GestureDetector(
      onTap: () => _onCardTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isFaceDown
              ? _moduleColor
              : (isMatched
              ? AppColors.success.withOpacity(isDark ? 0.3 : 0.15)
              : (isDark ? Theme.of(context).cardColor : Colors.white)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMatched
                ? AppColors.success
                : (isFaceDown ? _moduleColor : _moduleColor.withOpacity(0.5)),
            width: isMatched ? 2.5 : 1.5,
          ),
          boxShadow: isFaceDown
              ? [
            BoxShadow(
              color: _moduleColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: isFaceDown
              ? Icon(
            Icons.help_outline,
            size: 32,
            color: AppColors.textLight.withOpacity(0.7),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                card.isQuechua ? Icons.translate : Icons.language,
                size: 14,
                color: isMatched
                    ? AppColors.success
                    : _moduleColor.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  card.content,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isMatched
                        ? AppColors.success
                        : (isDark ? Colors.white : AppColors.textPrimary),
                    fontWeight: card.isQuechua ? FontWeight.bold : FontWeight.normal,
                    fontSize: card.content.length > 10 ? 10 : 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}