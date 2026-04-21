import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/evaluation_model.dart';
import 'results_screen.dart';

class EvaluationScreen extends StatefulWidget {
  final ModuleModel module;
  final QuestionType? filterType;

  const EvaluationScreen({
    super.key,
    required this.module,
    this.filterType,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  String _difficulty = 'Qallariq';
  int _optionsCount = 4;
  int _timerSeconds = 0;
  Timer? _questionTimer;
  int _remainingSeconds = 0;

  // Controller para fillInBlank (teclado)
  final TextEditingController _fillController = TextEditingController();
  final FocusNode _fillFocusNode = FocusNode();

  Color get _moduleColor => AppColors.getModuleColor(widget.module.id ?? 1);
  bool get _canGoBack => _timerSeconds <= 0;

  /// Módulos básicos de letras: solo permiten audioToSpanish
  bool get _isBasicLetterModule =>
      widget.module.id == 7 || widget.module.id == 8;

  // ================================================================
  // HELPERS
  // ================================================================

  /// Genera la pista de consonantes: "Qanchis" → "Q_nch_s"
  String _buildConsonantHint(String word) {
    final buffer = StringBuffer();
    final lower = word.toLowerCase();
    for (var i = 0; i < word.length; i++) {
      if ('aeiouáéíóú'.contains(lower[i])) {
        buffer.write('_');
      } else {
        buffer.write(word[i]);
      }
    }
    return buffer.toString();
  }

  bool _isWordSuitableForFillInBlank(String word) {
    if (word.length < 3 || word.length > 12) return false;
    if (word.contains(' ') || word.contains('-') || word.contains('_')) return false;
    if (!RegExp(r'^[a-zA-ZáéíóúñÑ]+$').hasMatch(word)) return false;
    final lower = word.toLowerCase();
    return lower.contains(RegExp(r'[aeiouáéíóú]'));
  }

  bool _isWordSuitableForScramble(String word) {
    if (word.length < 3 || word.length > 8) return false;
    if (word.contains(' ') || word.contains('-') || word.contains('_')) return false;
    return RegExp(r'^[a-zA-ZáéíóúñÑ]+$').hasMatch(word);
  }

  List<String> _scrambleChars(String word) {
    final random = Random();
    final chars = word.toLowerCase().split('');
    if (chars.length <= 1) return chars;
    chars.shuffle(random);
    int safety = 0;
    while (chars.join() == word.toLowerCase() && safety < 10) {
      chars.shuffle(random);
      safety++;
    }
    return chars;
  }

  /// ¿La pregunta actual necesita timer? (NO para escritura/ordenar)
  bool _shouldUseTimerForQuestion(QuestionType type) {
    return type != QuestionType.fillInBlank && type != QuestionType.scramble;
  }

  String _getFilterLabel() {
    switch (widget.filterType) {
      case QuestionType.quechuaToSpanish:
        return 'Q → E';
      case QuestionType.spanishToQuechua:
        return 'E → Q';
      case QuestionType.audioToSpanish:
        return 'Audio';
      case QuestionType.imageToQuechua:
        return 'Imagen';
      case QuestionType.fillInBlank:
        return 'Escribir';
      case QuestionType.scramble:
        return 'Ordenar';
      default:
        return 'Mixto';
    }
  }

  String _getDifficultyLabel() {
    switch (_difficulty) {
      case 'Yachaq':
        return 'Intermedio';
      case "Hamawt'a":
        return 'Difícil';
      default:
        return 'Fácil';
    }
  }

  IconData _getDifficultyIcon() {
    switch (_difficulty) {
      case 'Yachaq':
        return Icons.trending_up;
      case "Hamawt'a":
        return Icons.whatshot;
      default:
        return Icons.school;
    }
  }

  Color _getDifficultyColor() {
    switch (_difficulty) {
      case 'Yachaq':
        return AppColors.warning;
      case "Hamawt'a":
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDifficultyAndGenerate();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() => _isPlayingAudio = state == PlayerState.playing);
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _questionTimer?.cancel();
    _fillController.dispose();
    _fillFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDifficultyAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final userLevel = prefs.getString('user_level') ?? 'Qallariq';

    setState(() {
      _difficulty = userLevel;
      switch (userLevel) {
        case 'Yachaq':
          _optionsCount = 4;
          _timerSeconds = 15;
          break;
        case "Hamawt'a":
          _optionsCount = 5;
          _timerSeconds = 10;
          break;
        default:
          _optionsCount = 4;
          _timerSeconds = 0;
          break;
      }
    });

    await _generateQuestions();
  }

  void _startTimerIfApplicable() {
    _questionTimer?.cancel();
    if (_timerSeconds <= 0) return;

    // NO timer para escritura ni ordenar letras
    final currentType = _questions[_currentQuestionIndex].type;
    if (!_shouldUseTimerForQuestion(currentType)) {
      setState(() => _remainingSeconds = 0);
      return;
    }

    setState(() => _remainingSeconds = _timerSeconds);

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _remainingSeconds--);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (!_questions[_currentQuestionIndex].isAnswered) {
          _questions[_currentQuestionIndex].selectedAnswer = '__timeout__';
        }
        if (_currentQuestionIndex < _questions.length - 1) {
          setState(() => _currentQuestionIndex++);
          _startTimerIfApplicable();
        } else {
          _finishEvaluation();
        }
      }
    });
  }

  Future<void> _playQuestionAudio(String? audioUrl) async {
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
            content: const Text('Sin conexión. Conéctate a internet para escuchar el audio.'),
            backgroundColor: const Color(0xFF616161),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _generateQuestions() async {
    try {
      final words = await DatabaseHelper.instance.getWordsByModule(widget.module.id!);

      if (words.length < 4) {
        _showError('El módulo necesita al menos 4 palabras para evaluación');
        return;
      }

      final random = Random();

      final hasAudio = words.any((w) => w.audioPath != null && w.audioPath!.isNotEmpty);
      final hasImages = words.any((w) => w.imagePath != null && w.imagePath!.isNotEmpty);
      final hasFillInBlankCandidates = words.any((w) => _isWordSuitableForFillInBlank(w.wordQuechua));
      final hasScrambleCandidates = words.any((w) => _isWordSuitableForScramble(w.wordQuechua));

      bool isOnline = true;
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        isOnline = false;
      }

      final effectiveHasAudio = hasAudio && isOnline;
      final effectiveHasImages = hasImages && isOnline;

      List<QuestionType> availableTypes;

      if (widget.filterType != null) {
        if (!isOnline &&
            (widget.filterType == QuestionType.audioToSpanish ||
                widget.filterType == QuestionType.imageToQuechua)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Sin conexión. Se usarán preguntas de texto.'),
                backgroundColor: const Color(0xFF616161),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          availableTypes = [QuestionType.quechuaToSpanish, QuestionType.spanishToQuechua];
        } else if (widget.filterType == QuestionType.fillInBlank && !hasFillInBlankCandidates) {
          _showError('Este módulo no tiene palabras aptas para "Escribir"');
          return;
        } else if (widget.filterType == QuestionType.scramble && !hasScrambleCandidates) {
          _showError('Este módulo no tiene palabras aptas para "Ordenar"');
          return;
        } else {
          availableTypes = [widget.filterType!];
        }
      } else if (_isBasicLetterModule) {
        if (effectiveHasAudio) {
          availableTypes = [QuestionType.audioToSpanish];
        } else {
          availableTypes = [QuestionType.quechuaToSpanish];
        }
      } else {
        switch (_difficulty) {
          case "Hamawt'a":
            availableTypes = [
              QuestionType.spanishToQuechua,
              QuestionType.quechuaToSpanish,
              if (effectiveHasAudio) QuestionType.audioToSpanish,
              if (effectiveHasImages) QuestionType.imageToQuechua,
              if (hasFillInBlankCandidates) QuestionType.fillInBlank,
              if (hasFillInBlankCandidates) QuestionType.fillInBlank,
              if (hasScrambleCandidates) QuestionType.scramble,
              if (hasScrambleCandidates) QuestionType.scramble,
            ];
            break;
          case 'Yachaq':
            availableTypes = [
              QuestionType.quechuaToSpanish,
              QuestionType.spanishToQuechua,
              if (effectiveHasAudio) QuestionType.audioToSpanish,
              if (effectiveHasImages) QuestionType.imageToQuechua,
              if (hasFillInBlankCandidates) QuestionType.fillInBlank,
              if (hasScrambleCandidates) QuestionType.scramble,
            ];
            break;
          default:
            availableTypes = [
              QuestionType.quechuaToSpanish,
              QuestionType.quechuaToSpanish,
              QuestionType.spanishToQuechua,
              if (effectiveHasAudio) QuestionType.audioToSpanish,
              if (effectiveHasImages) QuestionType.imageToQuechua,
            ];
            break;
        }
      }

      if (availableTypes.isEmpty) {
        availableTypes = [QuestionType.quechuaToSpanish];
      }

      // Filtrar palabras según el tipo seleccionado
      List<WordModel> candidateWords;
      if (widget.filterType == QuestionType.fillInBlank) {
        candidateWords = words.where((w) => _isWordSuitableForFillInBlank(w.wordQuechua)).toList();
      } else if (widget.filterType == QuestionType.scramble) {
        candidateWords = words.where((w) => _isWordSuitableForScramble(w.wordQuechua)).toList();
      } else {
        candidateWords = List.from(words);
      }

      if (candidateWords.length < 4) {
        candidateWords = List.from(words);
      }

      candidateWords.shuffle(random);
      final questionCount = min(5, candidateWords.length);
      final selectedWords = candidateWords.take(questionCount).toList();

      final questions = <QuestionModel>[];

      for (var correctWord in selectedWords) {
        var type = availableTypes[random.nextInt(availableTypes.length)];

        if (type == QuestionType.imageToQuechua &&
            (correctWord.imagePath == null || correctWord.imagePath!.isEmpty)) {
          type = QuestionType.spanishToQuechua;
        }
        if (type == QuestionType.audioToSpanish &&
            (correctWord.audioPath == null || correctWord.audioPath!.isEmpty)) {
          type = QuestionType.quechuaToSpanish;
        }
        if (type == QuestionType.fillInBlank &&
            !_isWordSuitableForFillInBlank(correctWord.wordQuechua)) {
          type = QuestionType.spanishToQuechua;
        }
        if (type == QuestionType.scramble &&
            !_isWordSuitableForScramble(correctWord.wordQuechua)) {
          type = QuestionType.spanishToQuechua;
        }

        List<String> options;
        if (type == QuestionType.fillInBlank) {
          options = [];
        } else if (type == QuestionType.scramble) {
          options = _scrambleChars(correctWord.wordQuechua);
        } else {
          final incorrectWords = words.where((w) => w.id != correctWord.id).toList()
            ..shuffle(random);
          final distractorCount = _optionsCount - 1;
          final distractors = incorrectWords.take(distractorCount).toList();

          if (type == QuestionType.spanishToQuechua ||
              type == QuestionType.imageToQuechua) {
            options = [
              correctWord.wordQuechua,
              ...distractors.map((w) => w.wordQuechua),
            ]..shuffle(random);
          } else {
            options = [
              correctWord.wordSpanish,
              ...distractors.map((w) => w.wordSpanish),
            ]..shuffle(random);
          }
        }

        questions.add(QuestionModel(
          correctWord: correctWord,
          options: options,
          type: type,
        ));
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
      });

      _syncFillController();

      if (_timerSeconds > 0) {
        _startTimerIfApplicable();
      }
    } catch (e) {
      print('Error generating questions: $e');
      _showError('Error al cargar las preguntas');
    }
  }

  void _syncFillController() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentQuestionIndex];
    if (q.type == QuestionType.fillInBlank) {
      _fillController.text = q.selectedAnswer ?? '';
    }
  }

  void _selectAnswer(String answer) {
    if (_isPlayingAudio) _audioPlayer.stop();
    setState(() {
      _questions[_currentQuestionIndex].selectedAnswer = answer;
    });
  }

  void _appendLetter(String letter) {
    final q = _questions[_currentQuestionIndex];
    final current = q.selectedAnswer ?? '';
    if (current.length >= q.correctAnswer.length) return;
    setState(() {
      q.selectedAnswer = current + letter.toLowerCase();
    });
  }

  void _removeLastLetter() {
    final q = _questions[_currentQuestionIndex];
    final current = q.selectedAnswer ?? '';
    if (current.isEmpty) return;
    setState(() {
      q.selectedAnswer = current.substring(0, current.length - 1);
    });
  }

  void _nextQuestion() {
    if (_isPlayingAudio) _audioPlayer.stop();
    _fillFocusNode.unfocus();
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      _syncFillController();
      if (_timerSeconds > 0) _startTimerIfApplicable();
    } else {
      _finishEvaluation();
    }
  }

  void _previousQuestion() {
    if (!_canGoBack) return;
    if (_isPlayingAudio) _audioPlayer.stop();
    _fillFocusNode.unfocus();
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
      _syncFillController();
    }
  }

  Future<void> _finishEvaluation() async {
    if (_isPlayingAudio) _audioPlayer.stop();
    _fillFocusNode.unfocus();
    _questionTimer?.cancel();

    final correctAnswers = _questions.where((q) => q.isCorrect).length;
    final totalQuestions = _questions.length;
    final percentage = (correctAnswers / totalQuestions) * 100;

    final evaluation = EvaluationModel(
      moduleId: widget.module.id!,
      userId: 1,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      completedAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.insertEvaluation(evaluation);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          evaluation: evaluation,
          module: widget.module,
          questions: _questions,
          filterType: widget.filterType,
        ),
      ),
    );
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

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: Text('No hay preguntas disponibles')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final showTimer = _timerSeconds > 0 && _shouldUseTimerForQuestion(currentQuestion.type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _moduleColor,
        foregroundColor: AppColors.textLight,
        title: Text(
          widget.filterType != null
              ? '${widget.module.name}: ${_getFilterLabel()}'
              : 'Evaluación: ${widget.module.name}',
          style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildProgressBar(progress),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDifficultyBadge(showTimer),
                    const SizedBox(height: 12),
                    _buildQuestionCounter(),
                    const SizedBox(height: 24),
                    _buildQuestionCard(currentQuestion, isDark),
                    const SizedBox(height: 24),
                    _buildAnswerInteraction(currentQuestion, isDark),
                    const SizedBox(height: 32),
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInteraction(QuestionModel question, bool isDark) {
    switch (question.type) {
      case QuestionType.fillInBlank:
        return _buildFillInBlankUI(question, isDark);
      case QuestionType.scramble:
        return _buildScrambleUI(question, isDark);
      default:
        return _buildOptionsGrid(question, isDark);
    }
  }

  Widget _buildDifficultyBadge(bool showTimer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getDifficultyColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getDifficultyColor().withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getDifficultyIcon(), size: 14, color: _getDifficultyColor()),
              const SizedBox(width: 4),
              Text(
                _getDifficultyLabel(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: _getDifficultyColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (showTimer && _remainingSeconds > 0) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 5
                  ? AppColors.error.withOpacity(0.15)
                  : AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _remainingSeconds <= 5
                    ? AppColors.error.withOpacity(0.4)
                    : AppColors.info.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 14,
                    color: _remainingSeconds <= 5 ? AppColors.error : AppColors.info),
                const SizedBox(width: 4),
                Text(
                  '${_remainingSeconds}s',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _remainingSeconds <= 5 ? AppColors.error : AppColors.info,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!_canGoBack && showTimer) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 12, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Sin retroceso',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: _moduleColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pregunta ${_currentQuestionIndex + 1} de ${_questions.length}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight)),
              Text('${(progress * 100).toInt()}%',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (index) {
        final isAnswered = _questions[index].isAnswered;
        final isCurrent = index == _currentQuestionIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAnswered
                ? AppColors.success
                : isCurrent ? _moduleColor : AppColors.textSecondary.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, bool isDark) {
    return Card(
      elevation: 4,
      color: isDark ? Theme.of(context).cardColor : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _moduleColor.withOpacity(isDark ? 0.2 : 0.1),
              _moduleColor.withOpacity(isDark ? 0.1 : 0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _moduleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_getTypeChip(question.type),
                  style: AppTextStyles.bodySmall.copyWith(color: _moduleColor, fontWeight: FontWeight.w600, fontSize: 11)),
            ),
            const SizedBox(height: 16),
            Text(question.typeLabel,
                style: AppTextStyles.bodyLarge.copyWith(color: isDark ? Colors.white60 : AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _buildQuestionPrompt(question, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPrompt(QuestionModel question, bool isDark) {
    if (question.type == QuestionType.imageToQuechua) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 180, width: double.infinity,
          child: CachedNetworkImage(
            imageUrl: question.correctWord.imagePath ?? '',
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_moduleColor))),
            errorWidget: (context, url, error) => Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.image_not_supported, size: 40, color: _moduleColor.withOpacity(0.3)),
                const SizedBox(height: 8),
                Text('Imagen no disponible', style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary)),
              ]),
            ),
          ),
        ),
      );
    }

    if (question.type == QuestionType.audioToSpanish) {
      return Column(children: [
        GestureDetector(
          onTap: () => _playQuestionAudio(question.correctWord.audioPath),
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: _isPlayingAudio ? _moduleColor : _moduleColor.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: _isPlayingAudio ? [BoxShadow(color: _moduleColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)] : null,
            ),
            child: Icon(
              _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: _isPlayingAudio ? Colors.white : _moduleColor, size: 48,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(_isPlayingAudio ? 'Reproduciendo...' : 'Toca para escuchar',
            style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary)),
      ]);
    }

    if (question.type == QuestionType.fillInBlank ||
        question.type == QuestionType.scramble) {
      return Column(children: [
        Text(question.correctWord.wordSpanish,
            style: AppTextStyles.h1.copyWith(color: _moduleColor, fontSize: 36),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('en Quechua',
            style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary, fontStyle: FontStyle.italic)),
      ]);
    }

    if (question.type == QuestionType.spanishToQuechua) {
      return Text(question.correctWord.wordSpanish,
          style: AppTextStyles.h1.copyWith(color: _moduleColor, fontSize: 36),
          textAlign: TextAlign.center);
    }

    // Default: quechuaToSpanish
    return Column(children: [
      Text(question.correctWord.wordQuechua,
          style: AppTextStyles.h1.copyWith(color: _moduleColor),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(question.correctWord.phonetic,
          style: AppTextStyles.bodyMedium.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center),
    ]);
  }

  String _getTypeChip(QuestionType type) {
    switch (type) {
      case QuestionType.quechuaToSpanish: return 'Quechua → Español';
      case QuestionType.spanishToQuechua: return 'Español → Quechua';
      case QuestionType.audioToSpanish: return '🔊 Audio → Español';
      case QuestionType.imageToQuechua: return '🖼️ Imagen → Quechua';
      case QuestionType.fillInBlank: return '✏️ Escribir palabra';
      case QuestionType.scramble: return '🔀 Ordenar letras';
    }
  }

  // ================================================================
  // UI: MULTIPLE CHOICE
  // ================================================================
  Widget _buildOptionsGrid(QuestionModel question, bool isDark) {
    return Column(
      children: question.options.map((option) {
        final isSelected = question.selectedAnswer == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _selectAnswer(option),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? _moduleColor.withOpacity(isDark ? 0.2 : 0.1) : (isDark ? Theme.of(context).cardColor : AppColors.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? _moduleColor : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? _moduleColor : AppColors.textSecondary, width: 2),
                    color: isSelected ? _moduleColor : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(option,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _moduleColor : (isDark ? Colors.white : AppColors.textPrimary),
                      )),
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ================================================================
  // UI: ESCRIBIR PALABRA (fillInBlank con teclado)
  // Pistas según nivel de dificultad:
  //   Qallariq (Fácil):     pista consonantes + cantidad letras
  //   Yachaq (Intermedio):   solo cantidad de letras
  //   Hamawt'a (Avanzado):   sin pistas
  // ================================================================
  Widget _buildFillInBlankUI(QuestionModel question, bool isDark) {
    final word = question.correctAnswer;
    final hint = _buildConsonantHint(word);

    final showConsonantHint = _difficulty == 'Qallariq';
    final showLetterCount = _difficulty != "Hamawt'a";

    return Column(
      children: [
        // Pista — varía según dificultad
        if (showConsonantHint) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text('Pista:', style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              Text(hint,
                  style: AppTextStyles.h1.copyWith(color: isDark ? Colors.white70 : AppColors.textPrimary, fontSize: 28, letterSpacing: 6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${word.length} letras',
                  style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary, fontSize: 11)),
            ]),
          ),
        ] else if (showLetterCount) ...[
          // Yachaq: solo cantidad de letras
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('La palabra tiene ${word.length} letras',
                style: AppTextStyles.bodyMedium.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ],
        // Hamawt'a: sin pistas, nada arriba del campo

        const SizedBox(height: 24),

        // Campo de texto con teclado
        TextField(
          controller: _fillController,
          focusNode: _fillFocusNode,
          textCapitalization: TextCapitalization.sentences,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 24, letterSpacing: 2,
          ),
          decoration: InputDecoration(
            hintText: 'Escribe aquí...',
            hintStyle: AppTextStyles.bodyLarge.copyWith(color: isDark ? Colors.white24 : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _moduleColor.withOpacity(0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _moduleColor.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _moduleColor, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: _fillController.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, color: AppColors.textSecondary), onPressed: () {
              _fillController.clear();
              setState(() { _questions[_currentQuestionIndex].selectedAnswer = ''; });
            })
                : null,
          ),
          onChanged: (value) {
            setState(() { _questions[_currentQuestionIndex].selectedAnswer = value; });
          },
        ),
        const SizedBox(height: 12),

        Text('Tip: el Quechua Chanka solo tiene 3 vocales (a, i, u)',
            style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center),
      ],
    );
  }

  // ================================================================
  // UI: ORDENAR LETRAS (scramble con chips)
  // ================================================================
  Widget _buildScrambleUI(QuestionModel question, bool isDark) {
    final original = question.correctAnswer;
    final built = question.selectedAnswer ?? '';

    final usedIndices = <int>{};
    final availableChips = List<String>.from(question.options);
    for (var i = 0; i < built.length; i++) {
      final letter = built[i];
      for (var j = 0; j < availableChips.length; j++) {
        if (!usedIndices.contains(j) && availableChips[j].toLowerCase() == letter.toLowerCase()) {
          usedIndices.add(j);
          break;
        }
      }
    }

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _moduleColor.withOpacity(0.3), width: 2),
        ),
        child: Text(
          built.isEmpty ? '_' * original.length : built + ('_' * (original.length - built.length)),
          style: AppTextStyles.h1.copyWith(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 28, letterSpacing: 4),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 8),
      Text('${built.length}/${original.length} letras',
          style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary)),
      const SizedBox(height: 24),

      Wrap(
        spacing: 10, runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(availableChips.length, (idx) {
          final letter = availableChips[idx];
          final isUsed = usedIndices.contains(idx);
          return InkWell(
            onTap: isUsed ? null : () => _appendLetter(letter),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: isUsed ? Colors.grey.withOpacity(0.1) : _moduleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isUsed ? Colors.grey.withOpacity(0.3) : _moduleColor, width: 2),
              ),
              child: Center(
                child: Text(letter.toUpperCase(),
                    style: AppTextStyles.h3.copyWith(
                      color: isUsed ? Colors.grey : _moduleColor,
                      fontWeight: FontWeight.bold,
                      decoration: isUsed ? TextDecoration.lineThrough : null,
                    )),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 16),

      TextButton.icon(
        onPressed: built.isNotEmpty ? _removeLastLetter : null,
        icon: const Icon(Icons.backspace_outlined, size: 18),
        label: const Text('Borrar última'),
        style: TextButton.styleFrom(foregroundColor: built.isNotEmpty ? AppColors.error : Colors.grey),
      ),
    ]);
  }

  Widget _buildNavigationButtons() {
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    final isFirstQuestion = _currentQuestionIndex == 0;
    final canProceed = _questions[_currentQuestionIndex].isAnswered;
    final currentType = _questions[_currentQuestionIndex].type;
    final hasTimer = _timerSeconds > 0 && _shouldUseTimerForQuestion(currentType);

    return Column(children: [
      if (!canProceed)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hasTimer
                ? 'Completa la respuesta antes de que se agote el tiempo'
                : 'Completa la respuesta para continuar',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      if (canProceed) ...[
        Row(children: [
          if (!isFirstQuestion && _canGoBack)
            Expanded(
              child: SizedBox(height: 56,
                child: OutlinedButton.icon(
                  onPressed: _previousQuestion,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _moduleColor,
                    side: BorderSide(color: _moduleColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          if (!isFirstQuestion && _canGoBack) const SizedBox(width: 12),
          Expanded(
            child: SizedBox(height: 56,
              child: ElevatedButton.icon(
                onPressed: isLastQuestion ? _finishEvaluation : _nextQuestion,
                icon: Icon(isLastQuestion ? Icons.check : Icons.arrow_forward),
                label: Text(isLastQuestion ? 'Finalizar' : 'Siguiente', style: AppTextStyles.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _moduleColor,
                  foregroundColor: AppColors.textLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ]),
      ],
    ]);
  }
}