import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word_model.dart';
import '../models/module_model.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';
import '../models/evaluation_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('quechua_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,  // ← VERSION 2 (incrementado)
      onCreate: _createDB,
      onUpgrade: _upgradeDB,  // ← AGREGAR ESTO
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla de módulos
    await db.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_quechua TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');

    // Tabla de palabras
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module_id INTEGER NOT NULL,
        word_quechua TEXT NOT NULL,
        word_spanish TEXT NOT NULL,
        phonetic TEXT NOT NULL,
        image_path TEXT,
        model_3d_path TEXT,
        audio_path TEXT,
        FOREIGN KEY (module_id) REFERENCES modules (id)
      )
    ''');

    // Tabla de progreso
    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        is_learned INTEGER DEFAULT 0,
        times_reviewed INTEGER DEFAULT 0,
        last_review TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (word_id) REFERENCES words (id)
      )
    ''');

    await db.execute('''
    CREATE TABLE evaluations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      module_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      correct_answers INTEGER NOT NULL,
      total_questions INTEGER NOT NULL,
      percentage REAL NOT NULL,
      completed_at TEXT NOT NULL,
      FOREIGN KEY (module_id) REFERENCES modules (id),
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  ''');

    // Poblar con datos iniciales
    await _populateInitialData(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migración de versión 1 a 2: Agregar tabla evaluations
      await db.execute('''
        CREATE TABLE evaluations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          module_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          correct_answers INTEGER NOT NULL,
          total_questions INTEGER NOT NULL,
          percentage REAL NOT NULL,
          completed_at TEXT NOT NULL,
          FOREIGN KEY (module_id) REFERENCES modules (id),
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
      print('📊 Tabla evaluations creada (migración v1→v2)');
    }
  }

  Future<void> _populateInitialData(Database db) async {
    // Insertar módulos
    await db.insert('modules', {
      'name': 'Animales',
      'name_quechua': 'Uywakunakuna',
      'description': 'Aprende los nombres de animales en quechua',
      'icon': 'pets',
      'order_index': 1,
    });

    await db.insert('modules', {
      'name': 'Naturaleza',
      'name_quechua': 'Pachamama',
      'description': 'Descubre elementos de la naturaleza',
      'icon': 'park',
      'order_index': 2,
    });

    await db.insert('modules', {
      'name': 'Familia y Cultura',
      'name_quechua': 'Ayllu',
      'description': 'Conoce sobre familia y objetos culturales',
      'icon': 'family_restroom',
      'order_index': 3,
    });

    // Insertar palabras del Módulo 1: Animales
    final animalesWords = [
      {'quechua': 'Allqu', 'spanish': 'Perro', 'phonetic': 'ALL-ku'},
      {'quechua': 'Michi', 'spanish': 'Gato', 'phonetic': 'MI-chi'},
      {'quechua': 'Pisqu', 'spanish': 'Pájaro', 'phonetic': 'PIS-ku'},
      {'quechua': 'Kawallux', 'spanish': 'Caballo', 'phonetic': 'ka-WA-llush'},
      {'quechua': 'Llama', 'spanish': 'Llama', 'phonetic': 'LLA-ma'},
      {'quechua': 'Paqocha', 'spanish': 'Alpaca', 'phonetic': 'pa-KO-cha'},
      {'quechua': 'Kuntur', 'spanish': 'Cóndor', 'phonetic': 'KUN-tur'},
      {'quechua': 'Uwiha', 'spanish': 'Oveja', 'phonetic': 'u-WI-ha'},
      {'quechua': 'Waka', 'spanish': 'Vaca', 'phonetic': 'WA-ka'},
      {'quechua': 'Wallpa', 'spanish': 'Gallina', 'phonetic': 'WALL-pa'},
    ];

    for (var word in animalesWords) {
      await db.insert('words', {
        'module_id': 1,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
      });
    }

    // Insertar palabras del Módulo 2: Naturaleza
    final naturalezaWords = [
      {'quechua': 'Inti', 'spanish': 'Sol', 'phonetic': 'IN-ti'},
      {'quechua': 'Killa', 'spanish': 'Luna', 'phonetic': 'KI-lla'},
      {'quechua': 'Urqu', 'spanish': 'Montaña', 'phonetic': 'UR-ku'},
      {'quechua': 'Yaku', 'spanish': 'Agua', 'phonetic': 'YA-ku'},
      {'quechua': "Sach'a", 'spanish': 'Árbol', 'phonetic': 'SA-cha'},
      {'quechua': "T'ika", 'spanish': 'Flor', 'phonetic': 'TI-ka'},
      {'quechua': 'Wayra', 'spanish': 'Viento', 'phonetic': 'WAY-ra'},
      {'quechua': 'Nina', 'spanish': 'Fuego', 'phonetic': 'NI-na'},
      {'quechua': 'Rumi', 'spanish': 'Piedra', 'phonetic': 'RU-mi'},
      {'quechua': 'Allpa', 'spanish': 'Tierra', 'phonetic': 'ALL-pa'},
    ];

    for (var word in naturalezaWords) {
      await db.insert('words', {
        'module_id': 2,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
      });
    }

    // Insertar palabras del Módulo 3: Familia y Cultura
    final familiaWords = [
      {'quechua': 'Wasi', 'spanish': 'Casa', 'phonetic': 'WA-si'},
      {'quechua': 'Tanta', 'spanish': 'Pan', 'phonetic': 'TAN-ta'},
      {'quechua': 'Unu', 'spanish': 'Vaso', 'phonetic': 'U-nu'},
      {'quechua': "P'acha", 'spanish': 'Ropa', 'phonetic': 'PA-cha'},
      {'quechua': 'Chuspa', 'spanish': 'Bolsa', 'phonetic': 'CHUS-pa'},
      {'quechua': 'Charango', 'spanish': 'Charango', 'phonetic': 'cha-RAN-go'},
      {'quechua': 'Quena', 'spanish': 'Quena', 'phonetic': 'KE-na'},
      {'quechua': 'Poncho', 'spanish': 'Poncho', 'phonetic': 'PON-cho'},
      {'quechua': "Llawt'u", 'spanish': 'Corona andina', 'phonetic': 'LLAWTU'},
      {'quechua': 'Mate', 'spanish': 'Calabaza', 'phonetic': 'MA-te'},
    ];

    for (var word in familiaWords) {
      await db.insert('words', {
        'module_id': 3,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
      });
    }
  }

  // CRUD de Words
  Future<List<WordModel>> getWordsByModule(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: 'module_id = ?',
      whereArgs: [moduleId],
    );
    return result.map((map) => WordModel.fromMap(map)).toList();
  }

  Future<List<ModuleModel>> getAllModules() async {
    final db = await database;
    final result = await db.query('modules', orderBy: 'order_index');
    return result.map((map) => ModuleModel.fromMap(map)).toList();
  }

  // CRUD de Evaluaciones
  Future<int> insertEvaluation(EvaluationModel evaluation) async {
    final db = await database;
    return await db.insert('evaluations', evaluation.toMap());
  }

  Future<List<EvaluationModel>> getEvaluationsByModule(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'evaluations',
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'completed_at DESC',
    );
    return result.map((map) => EvaluationModel.fromMap(map)).toList();
  }

  Future<List<EvaluationModel>> getAllEvaluations() async {
    final db = await database;
    final result = await db.query('evaluations', orderBy: 'completed_at DESC');
    return result.map((map) => EvaluationModel.fromMap(map)).toList();
  }

  Future<EvaluationModel?> getLastEvaluation(int moduleId) async {
    final db = await database;
    final result = await db.query(
      'evaluations',
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'completed_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return EvaluationModel.fromMap(result.first);
  }

  // Cerrar base de datos
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}