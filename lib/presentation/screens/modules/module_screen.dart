import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import 'lesson_screen.dart';
import '../evaluation/evaluation_screen.dart';
import '../evaluation/memory_game_screen.dart';
import '../../../data/models/question_model.dart';

class ModuleScreen extends StatefulWidget {
  final ModuleModel module;

  const ModuleScreen({
    super.key,
    required this.module,
  });

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  List<WordModel> _words = [];
  bool _isLoading = true;
  Map<int, bool> _learnedStatus = {};
  double _bestEvalScore = 0.0;

  int get _learnedCount => _learnedStatus.values.where((v) => v).length;
  int get _totalWords => _words.length;

  bool get _isCompleted => _learnedCount >= _totalWords && _bestEvalScore >= 70;

  bool get _hasAudioContent => _words.any((w) =>
  w.audioPath != null && w.audioPath!.isNotEmpty && w.audioPath!.startsWith('http'));

  bool get _hasImageContent => _words.any((w) =>
  w.imagePath != null && w.imagePath!.isNotEmpty && w.imagePath!.startsWith('http'));

  bool get _canEvaluate => _words.length >= 4;

  /// Módulos básicos de letras: solo audio
  bool get _isBasicLetterModule =>
      widget.module.id == 7 || widget.module.id == 8;

  bool get _hasFillInBlankCandidates => _words.any((w) {
    final word = w.wordQuechua;
    if (word.length < 3 || word.length > 12) return false;
    if (word.contains(' ') || word.contains('-') || word.contains('_')) return false;
    if (!RegExp(r'^[a-zA-ZáéíóúñÑ]+$').hasMatch(word)) return false;
    return word.toLowerCase().contains(RegExp(r'[aeiouáéíóú]'));
  });

  bool get _hasScrambleCandidates => _words.any((w) {
    final word = w.wordQuechua;
    if (word.length < 3 || word.length > 8) return false;
    if (word.contains(' ') || word.contains('-') || word.contains('_')) return false;
    return RegExp(r'^[a-zA-ZáéíóúñÑ]+$').hasMatch(word);
  });

  bool get _hasMemoryCandidates =>
      _words.where((w) => w.wordQuechua.length <= 14 && w.wordSpanish.length <= 16).length >= 4;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words = await DatabaseHelper.instance.getWordsByModule(widget.module.id!);
      Map<int, bool> learnedMap = {};
      for (var word in words) {
        final isLearned = await DatabaseHelper.instance.isWordLearned(word.id!);
        learnedMap[word.id!] = isLearned;
      }
      final bestScore = await DatabaseHelper.instance
          .getBestEvaluationScore(widget.module.id!);
      setState(() {
        _words = words;
        _learnedStatus = learnedMap;
        _bestEvalScore = bestScore;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading words: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshLearnedStatus() async {
    Map<int, bool> learnedMap = {};
    for (var word in _words) {
      final isLearned = await DatabaseHelper.instance.isWordLearned(word.id!);
      learnedMap[word.id!] = isLearned;
    }
    final bestScore = await DatabaseHelper.instance
        .getBestEvaluationScore(widget.module.id!);
    setState(() {
      _learnedStatus = learnedMap;
      _bestEvalScore = bestScore;
    });
  }

  Color get _moduleColor => AppColors.getModuleColor(widget.module.id ?? 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _moduleColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.module.name, style: AppTextStyles.h3.copyWith(color: AppColors.textLight)),
            Text(widget.module.nameQuechua, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight.withOpacity(0.9))),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
          ? _buildEmptyState(isDark)
          : Column(
        children: [
          _buildHeader(),
          if (_isCompleted) _buildCelebrationBanner(isDark),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _words.length,
              itemBuilder: (context, index) => _buildWordCard(_words[index], index, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoading || _words.isEmpty ? null : _buildEvaluationButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _moduleColor,
        boxShadow: [BoxShadow(color: _moduleColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(AppColors.getModuleIcon(widget.module.icon), color: AppColors.textLight, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_totalWords palabras', style: AppTextStyles.h3.copyWith(color: AppColors.textLight)),
                  Text(
                    _learnedCount > 0 ? '$_learnedCount aprendidas · Toca para aprender más' : 'Toca una palabra para aprender más',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationBanner(bool isDark) {
    final messages = {
      1: '¡Dominas los animales en quechua! Ahora podrás nombrar la fauna andina.',
      2: '¡La naturaleza habla en quechua para ti! Conecta con la Pachamama.',
      3: '¡Conoces la familia y cultura andina! El Ayllu te da la bienvenida.',
      4: '¡Ya sabes contar en quechua! Los números son la base del comercio andino.',
      5: '¡Saludas como un hablante nativo! La cortesía abre puertas.',
      6: '¡Los colores del arcoíris andino son tuyos! Sigue aprendiendo.',
      7: '¡Dominas las vocales del quechua! La fonética es tu base.',
      8: '¡Conoces el Achahala completo! Las 18 letras son tuyas.',
      9: '¡Las figuras geométricas en quechua! Conecta con la RA.',
      10: '¡Armas frases en quechua! La comunicación crece.',
      11: '¡Formas oraciones completas! Eres un verdadero Hamawt\'a.',
      12: '¡Dominas los sufijos! La gramática quechua es tu herramienta.',
    };
    final message = messages[widget.module.id] ?? '¡Felicidades! Has completado este módulo.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.success.withOpacity(0.15) : AppColors.success.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: AppColors.success.withOpacity(0.3), width: 1)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white70 : AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_moduleColor, _moduleColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _moduleColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _canEvaluate
              ? () => _showEvaluationTypeDialog(context)
              : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('El módulo necesita al menos 4 palabras para evaluación'),
                backgroundColor: const Color(0xFF616161),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz, color: AppColors.textLight, size: 28),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Listo para practicar?', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                    Text('Evaluaciones y juegos', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight.withOpacity(0.9))),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward, color: AppColors.textLight, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEvaluationTypeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── SECCIÓN: EVALUACIONES ───
                Row(
                  children: [
                    Icon(Icons.quiz, size: 18, color: _moduleColor),
                    const SizedBox(width: 8),
                    Text('Evaluaciones', style: AppTextStyles.h3.copyWith(color: isDark ? Colors.white : null)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isBasicLetterModule
                      ? 'Practica identificando sonidos'
                      : 'Elige cómo quieres practicar',
                  style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                if (_isBasicLetterModule) ...[
                  // ─── MÓDULOS BÁSICOS: SOLO AUDIO ───
                  if (_hasAudioContent)
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.volume_up_rounded,
                      label: 'Audio → Español',
                      subtitle: 'Escucha el sonido e identifica la letra',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.audioToSpanish),
                    )
                  else
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.translate,
                      label: 'Quechua → Español',
                      subtitle: 'Identifica el significado',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.quechuaToSpanish),
                    ),
                ] else ...[
                  // ─── MÓDULOS NORMALES: TODAS LAS OPCIONES ───

                  // Mixto
                  _buildTypeOption(
                    ctx: ctx, icon: Icons.shuffle,
                    label: 'Mixto',
                    subtitle: 'Combina todos los tipos de pregunta',
                    color: _moduleColor, isDark: isDark,
                    onTap: () => _navigateToEvaluation(ctx, filterType: null),
                  ),
                  const SizedBox(height: 10),

                  // Q → E
                  _buildTypeOption(
                    ctx: ctx, icon: Icons.translate,
                    label: 'Quechua → Español',
                    subtitle: 'Lee en quechua, elige el significado',
                    color: _moduleColor, isDark: isDark,
                    onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.quechuaToSpanish),
                  ),
                  const SizedBox(height: 10),

                  // E → Q
                  _buildTypeOption(
                    ctx: ctx, icon: Icons.swap_horiz,
                    label: 'Español → Quechua',
                    subtitle: 'Lee en español, elige la palabra quechua',
                    color: _moduleColor, isDark: isDark,
                    onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.spanishToQuechua),
                  ),
                  const SizedBox(height: 10),

                  // Audio
                  if (_hasAudioContent) ...[
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.volume_up_rounded,
                      label: 'Audio → Español',
                      subtitle: 'Escucha la pronunciación, elige el significado',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.audioToSpanish),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Imagen
                  if (_hasImageContent) ...[
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.image,
                      label: 'Imagen → Quechua',
                      subtitle: 'Mira la imagen, elige la palabra en quechua',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.imageToQuechua),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Escribir palabra
                  if (_hasFillInBlankCandidates) ...[
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.keyboard,
                      label: 'Escribir Palabra',
                      subtitle: 'Escribe la palabra quechua con tu teclado',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.fillInBlank),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Ordenar letras
                  if (_hasScrambleCandidates) ...[
                    _buildTypeOption(
                      ctx: ctx, icon: Icons.sort_by_alpha,
                      label: 'Ordenar Letras',
                      subtitle: 'Ordena las letras desordenadas',
                      color: _moduleColor, isDark: isDark,
                      onTap: () => _navigateToEvaluation(ctx, filterType: QuestionType.scramble),
                    ),
                  ],
                ],

                // ─── SECCIÓN: JUEGOS ───
                if (_hasMemoryCandidates) ...[
                  const SizedBox(height: 20),
                  Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.videogame_asset, size: 18, color: _moduleColor),
                      const SizedBox(width: 8),
                      Text('Juegos', style: AppTextStyles.h3.copyWith(color: isDark ? Colors.white : null)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aprende jugando',
                    style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _buildTypeOption(
                    ctx: ctx, icon: Icons.grid_view_rounded,
                    label: 'Juego de Memoria',
                    subtitle: 'Encuentra los pares Quechua ↔ Español',
                    color: _moduleColor, isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MemoryGameScreen(module: widget.module)),
                      ).then((_) => _refreshLearnedStatus());
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToEvaluation(BuildContext ctx, {QuestionType? filterType}) {
    Navigator.pop(ctx);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(module: widget.module, filterType: filterType),
      ),
    ).then((_) => _refreshLearnedStatus());
  }

  Widget _buildTypeOption({
    required BuildContext ctx, required IconData icon,
    required String label, required String subtitle,
    required Color color, required bool isDark, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : null)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white38 : AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white24 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(WordModel word, int index, bool isDark) {
    final isLearned = _learnedStatus[word.id] ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLearned ? 1 : 2,
      color: isDark ? Theme.of(context).cardColor : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLearned ? BorderSide(color: AppColors.success.withOpacity(0.5), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => LessonScreen(word: word, moduleColor: _moduleColor)));
          _refreshLearnedStatus();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: isLearned ? BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.success.withOpacity(isDark ? 0.08 : 0.04)) : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isLearned ? AppColors.success.withOpacity(0.15) : _moduleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isLearned
                      ? Icon(Icons.check, color: AppColors.success, size: 22)
                      : Text('${index + 1}', style: AppTextStyles.h3.copyWith(color: _moduleColor)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.wordQuechua, style: AppTextStyles.h3.copyWith(color: isDark ? Colors.white : null), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(word.wordSpanish, style: AppTextStyles.bodyMedium.copyWith(color: isDark ? Colors.white60 : AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(word.phonetic, style: AppTextStyles.bodySmall.copyWith(color: _moduleColor, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(isLearned ? Icons.visibility : Icons.visibility_outlined, color: isLearned ? AppColors.success : (isDark ? Colors.white38 : AppColors.textSecondary), size: 20),
                  const SizedBox(height: 8),
                  Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white38 : AppColors.textSecondary, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white38 : AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('No hay palabras disponibles', style: AppTextStyles.h3.copyWith(color: isDark ? Colors.white : null)),
          const SizedBox(height: 8),
          Text('Este módulo está vacío', style: AppTextStyles.bodyMedium.copyWith(color: isDark ? Colors.white54 : AppColors.textSecondary)),
        ],
      ),
    );
  }
}