class WordModel {
  final int? id;
  final int moduleId;
  final String wordQuechua;
  final String wordSpanish;
  final String phonetic;
  final String? imagePath;
  final String? model3dPath;
  final String? audioPath;

  WordModel({
    this.id,
    required this.moduleId,
    required this.wordQuechua,
    required this.wordSpanish,
    required this.phonetic,
    this.imagePath,
    this.model3dPath,
    this.audioPath,
  });

  // Convertir de Map (desde SQLite) a WordModel
  factory WordModel.fromMap(Map<String, dynamic> map) {
    return WordModel(
      id: map['id'] as int?,
      moduleId: map['module_id'] as int,
      wordQuechua: map['word_quechua'] as String,
      wordSpanish: map['word_spanish'] as String,
      phonetic: map['phonetic'] as String,
      imagePath: map['image_path'] as String?,
      model3dPath: map['model_3d_path'] as String?,
      audioPath: map['audio_path'] as String?,
    );
  }

  // Convertir de WordModel a Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'module_id': moduleId,
      'word_quechua': wordQuechua,
      'word_spanish': wordSpanish,
      'phonetic': phonetic,
      'image_path': imagePath,
      'model_3d_path': model3dPath,
      'audio_path': audioPath,
    };
  }

  // Método copyWith para crear copias modificadas
  WordModel copyWith({
    int? id,
    int? moduleId,
    String? wordQuechua,
    String? wordSpanish,
    String? phonetic,
    String? imagePath,
    String? model3dPath,
    String? audioPath,
  }) {
    return WordModel(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      wordQuechua: wordQuechua ?? this.wordQuechua,
      wordSpanish: wordSpanish ?? this.wordSpanish,
      phonetic: phonetic ?? this.phonetic,
      imagePath: imagePath ?? this.imagePath,
      model3dPath: model3dPath ?? this.model3dPath,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  @override
  String toString() {
    return 'WordModel{id: $id, wordQuechua: $wordQuechua, wordSpanish: $wordSpanish}';
  }
}