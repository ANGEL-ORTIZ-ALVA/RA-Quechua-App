import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/datasources/database_helper.dart';
import '../../../data/models/word_model.dart';
import '../../../data/models/module_model.dart';
import 'lesson_screen.dart';
import '../evaluation/evaluation_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words = await DatabaseHelper.instance.getWordsByModule(widget.module.id!);
      setState(() {
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading words: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.module.name,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textLight,
              ),
            ),
            Text(
              widget.module.nameQuechua,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight.withOpacity(0.9),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EvaluationScreen(
                    module: widget.module,
                  ),
                ),
              );
            },
            tooltip: 'Iniciar Evaluación',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _words.length,
              itemBuilder: (context, index) {
                return _buildWordCard(_words[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
                Icons.book,
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
                    'Toca una palabra para aprender más',
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

  Widget _buildWordCard(WordModel word, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonScreen(
                word: word,
                moduleColor: _getModuleColor(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Número de orden
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getModuleColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.h3.copyWith(
                      color: _getModuleColor(),
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
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.wordSpanish,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.phonetic,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _getModuleColor(),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Iconos de acción
              Column(
                children: [
                  Icon(
                    Icons.visibility,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textSecondary,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay palabras disponibles',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          Text(
            'Este módulo está vacío',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getModuleColor() {
    switch (widget.module.id) {
      case 1:
        return AppColors.primary;
      case 2:
        return AppColors.secondary;
      case 3:
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }
}