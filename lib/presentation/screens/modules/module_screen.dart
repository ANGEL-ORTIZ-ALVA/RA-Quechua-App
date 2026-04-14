import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import 'lesson_screen.dart';
import '../evaluation/evaluation_screen.dart';
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
  bool get _isCompleted => _learnedCount >= 10 && _bestEvalScore >= 70;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words =
      await DatabaseHelper.instance.getWordsByModule(widget.module.id!);

      Map<int, bool> learnedMap = {};
      for (var word in words) {
        final isLearned =
        await DatabaseHelper.instance.isWordLearned(word.id!);
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

  /// Color centralizado desde AppColors
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
            Text(
              widget.module.name,
              style: AppTextStyles.h3.copyWith(color: AppColors.textLight),
            ),
            Text(
              widget.module.nameQuechua,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight.withOpacity(0.9),
              ),
            ),
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
              itemBuilder: (context, index) {
                return _buildWordCard(
                    _words[index], index, isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoading || _words.isEmpty
          ? null
          : _buildEvaluationButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    final learnedCount =
        _learnedStatus.values.where((v) => v).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _moduleColor,
        boxShadow: [
          BoxShadow(
            color: _moduleColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppColors.getModuleIcon(widget.module.icon),
                color: AppColors.textLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_words.length} palabras',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    learnedCount > 0
                        ? '$learnedCount aprendidas · Toca para aprender más'
                        : 'Toca una palabra para aprender más',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BANNER DE FELICITACIÓN POR MÓDULO COMPLETADO ───
  Widget _buildCelebrationBanner(bool isDark) {
    final messages = {
      1: '¡Dominas los animales en quechua! Ahora podrás nombrar la fauna andina.',
      2: '¡La naturaleza habla en quechua para ti! Conecta con la Pachamama.',
      3: '¡Conoces la familia y cultura andina! El Ayllu te da la bienvenida.',
      4: '¡Ya sabes contar en quechua! Los números son la base del comercio andino.',
      5: '¡Saludas como un hablante nativo! La cortesía abre puertas.',
      6: '¡Los colores del arcoíris andino son tuyos! Sigue aprendiendo.',
    };

    final message = messages[widget.module.id] ??
        '¡Felicidades! Has completado este módulo. Sigue practicando.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withOpacity(0.15)
            : AppColors.success.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.success.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white70 : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTÓN DE EVALUACIÓN CON SELECTOR DE TIPO ───
  Widget _buildEvaluationButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _moduleColor,
            _moduleColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _moduleColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEvaluationTypeDialog(context),
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
                    Text(
                      '¿Listo para la evaluación?',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Pon a prueba lo que aprendiste',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward,
                    color: AppColors.textLight, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── TARJETA DE PALABRA CON INDICADOR DE APRENDIDA ───
  // ─── DIÁLOGO SELECTOR DE TIPO DE EVALUACIÓN ───
  void _showEvaluationTypeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de arrastre
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tipo de evaluación',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige cómo quieres practicar',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Opción: Mixto (por defecto)
                _buildTypeOption(
                  ctx: ctx,
                  icon: Icons.shuffle,
                  label: 'Mixto',
                  subtitle: 'Combina todos los tipos de pregunta',
                  color: _moduleColor,
                  isDark: isDark,
                  filterType: null,
                ),
                const SizedBox(height: 10),

                // Opción: Quechua → Español
                _buildTypeOption(
                  ctx: ctx,
                  icon: Icons.translate,
                  label: 'Quechua → Español',
                  subtitle: 'Lee en quechua, elige el significado',
                  color: _moduleColor,
                  isDark: isDark,
                  filterType: QuestionType.quechuaToSpanish,
                ),
                const SizedBox(height: 10),

                // Opción: Español → Quechua
                _buildTypeOption(
                  ctx: ctx,
                  icon: Icons.swap_horiz,
                  label: 'Español → Quechua',
                  subtitle: 'Lee en español, elige la palabra quechua',
                  color: _moduleColor,
                  isDark: isDark,
                  filterType: QuestionType.spanishToQuechua,
                ),
                const SizedBox(height: 10),

                // Opción: Audio
                _buildTypeOption(
                  ctx: ctx,
                  icon: Icons.volume_up_rounded,
                  label: 'Audio → Español',
                  subtitle: 'Escucha la pronunciación, elige el significado',
                  color: _moduleColor,
                  isDark: isDark,
                  filterType: QuestionType.audioToSpanish,
                ),
                const SizedBox(height: 10),

                // Opción: Imagen → Quechua
                _buildTypeOption(
                  ctx: ctx,
                  icon: Icons.image,
                  label: 'Imagen → Quechua',
                  subtitle: 'Mira la imagen, elige la palabra en quechua',
                  color: _moduleColor,
                  isDark: isDark,
                  filterType: QuestionType.imageToQuechua,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isDark,
    required QuestionType? filterType,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx); // cerrar bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EvaluationScreen(
              module: widget.module,
              filterType: filterType,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? Colors.white38 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white24 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ─── TARJETA DE PALABRA CON INDICADOR DE APRENDIDA ───
  Widget _buildWordCard(WordModel word, int index, bool isDark) {
    final isLearned = _learnedStatus[word.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLearned ? 1 : 2,
      color: isDark ? Theme.of(context).cardColor : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLearned
            ? BorderSide(color: AppColors.success.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonScreen(
                word: word,
                moduleColor: _moduleColor,
              ),
            ),
          );
          // Recargar estado al volver
          _refreshLearnedStatus();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: isLearned
              ? BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.success.withOpacity(isDark ? 0.08 : 0.04),
          )
              : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Número / Check
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLearned
                      ? AppColors.success.withOpacity(0.15)
                      : _moduleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isLearned
                      ? Icon(Icons.check, color: AppColors.success, size: 22)
                      : Text(
                    '${index + 1}',
                    style: AppTextStyles.h3.copyWith(
                      color: _moduleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.wordQuechua,
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.wordSpanish,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.phonetic,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _moduleColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador visual
              Column(
                children: [
                  Icon(
                    isLearned
                        ? Icons.visibility
                        : Icons.visibility_outlined,
                    color: isLearned
                        ? AppColors.success
                        : (isDark ? Colors.white38 : AppColors.textSecondary),
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                    size: 16,
                  ),
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
          Icon(Icons.error_outline,
              size: 64,
              color: isDark ? Colors.white38 : AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No hay palabras disponibles',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este módulo está vacío',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}