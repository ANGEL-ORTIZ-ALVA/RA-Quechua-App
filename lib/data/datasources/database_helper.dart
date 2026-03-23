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
      version: 15,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

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

    await _populateInitialData(db, onlyWords: false);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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

    if (oldVersion < 3) {
      print('🔄 Iniciando migración v2→v3: Agregando URLs de Firebase...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Palabras actualizadas con URLs de Firebase (migración v2→v3)');
    }

    if (oldVersion < 4) {
      print('🔄 Iniciando migración v3→v4: Actualizando URLs de imágenes...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ URLs de imágenes actualizadas (migración v3→v4)');
    }

    if (oldVersion < 5) {
      print('🔄 Iniciando migración v4→v5: Corrigiendo URL de Oveja...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ URL de Oveja corregida (migración v4→v5)');
    }

    if (oldVersion < 6) {
      print('🔄 Iniciando migración v5→v6: Verificando columna audio_path...');
      final tableInfo = await db.rawQuery('PRAGMA table_info(words)');
      final hasAudioPath = tableInfo.any((col) => col['name'] == 'audio_path');
      if (!hasAudioPath) {
        await db.execute('ALTER TABLE words ADD COLUMN audio_path TEXT');
        print('🔊 Columna audio_path agregada');
      }
      print('✅ Columna audio_path verificada (migración v5→v6)');
    }

    if (oldVersion < 7) {
      print('🔄 Iniciando migración v6→v7: Agregando audios de pronunciación...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Audios de pronunciación agregados (migración v6→v7)');
    }

    if (oldVersion < 8) {
      print('🔄 Iniciando migración v7→v8: Agregando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D agregados (migración v7→v8)');
    }
    if (oldVersion < 9) {
      print('🔄 Iniciando migración v8→v9: Actualizando URLs de modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ URLs de modelos 3D actualizadas (migración v8→v9)');
    }
    if (oldVersion < 10) {
      print('🔄 Iniciando migración v9→v10: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v9→v10)');
    }
    if (oldVersion < 11) {
      print('🔄 Iniciando migración v10→v11: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v10→v11)');
    }
    if (oldVersion < 12) {
      print('🔄 Iniciando migración v11→v12: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v11→v12)');
    }
    if (oldVersion < 13) {
      print('🔄 Iniciando migración v12→v13: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v12→v13)');
    }
    if (oldVersion < 14) {
      print('🔄 Iniciando migración v13→v14: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v13→v14)');
    }
    if (oldVersion < 15) {
      print('🔄 Iniciando migración v14→v15: Actualizando modelos 3D...');
      await db.delete('words');
      await _populateInitialData(db, onlyWords: true);
      print('✅ Modelos 3D actualizados (migración v14→v15)');
    }
  }

  Future<void> _populateInitialData(Database db, {bool onlyWords = false}) async {
    if (!onlyWords) {
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
    }

    // ==========================================
    // MÓDULO 1: ANIMALES
    // ==========================================
    // └─────────────────────────────────────────────────────────────────┘
    final animalesWords = [
      {
        'quechua': 'Allqu',
        'spanish': 'Perro',
        'phonetic': 'ALL-ku',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPerro.jpg?alt=media&token=d8157b5d-93f9-44d0-a33b-da0a1becff3c',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fallqu.mp3?alt=media&token=7431d28c-e0f9-4baa-916d-6935e0046b2b',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fallqu.glb?alt=media&token=dc6ca802-5b9b-42ac-a216-93d1c83d281e', // TODO: Reemplazar con URL de Firebase del modelo allqu.glb
      },
      {
        'quechua': 'Michi',
        'spanish': 'Gato',
        'phonetic': 'MI-chi',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGato.jpg?alt=media&token=05850973-8bf0-4fe7-954f-9332feddac57',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fmichi.mp3?alt=media&token=b56617be-49da-471c-98b7-73e926d40a4d',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fmichi.glb?alt=media&token=8f6b90d9-08f0-4d1b-b570-523d42a547d4', // TODO: Reemplazar con URL de Firebase del modelo michi.glb
      },
      {
        'quechua': 'Pisqu',
        'spanish': 'Pájaro',
        'phonetic': 'PIS-ku',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPajaro.jpg?alt=media&token=bb473960-9604-413d-8993-8732fd421344',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpisqu.mp3?alt=media&token=9c0d6c42-2d71-4669-8d69-68d519dd10c4',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpisqu.glb?alt=media&token=dbb370b1-fd42-415c-aea7-1db952c6c366', // TODO: Reemplazar con URL de Firebase del modelo pisqu.glb
      },
      {
        'quechua': 'Kawallux',
        'spanish': 'Caballo',
        'phonetic': 'ka-WA-llush',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FCaballo.jpg?alt=media&token=679f66d1-5c28-4cda-ba8d-e0390bf74d94',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkawallux.mp3?alt=media&token=4f8b581a-11c5-46ab-8402-6e6d143c6fc5',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkawallux.glb?alt=media&token=d5ee9747-1c60-4704-957a-8fd1ab590429', // TODO: Reemplazar con URL de Firebase del modelo kawallux.glb
      },
      {
        'quechua': 'Llama',
        'spanish': 'Llama',
        'phonetic': 'LLA-ma',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FLlama.jpg?alt=media&token=6c7d9b5d-e795-47e7-a334-88764f5854bc',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fllama.mp3?alt=media&token=ee24386f-8a31-4584-872d-1e4924962b0f',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fllama.glb?alt=media&token=d987879e-1318-42f5-ac74-d35be5b630a1', // TODO: Reemplazar con URL de Firebase del modelo llama.glb
      },
      {
        'quechua': 'Paqocha',
        'spanish': 'Alpaca',
        'phonetic': 'pa-KO-cha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FAlpaca.jpg?alt=media&token=93040399-2380-4eeb-955d-53ee1b76f520',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpaqocha.mp3?alt=media&token=954e3f29-7ea0-4c89-bb58-255e7f39bcca',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpaqocha.glb?alt=media&token=f44f2c31-ef44-4876-89f6-7bf2c7fac95a', // TODO: Reemplazar con URL de Firebase del modelo paqocha.glb
      },
      {
        'quechua': 'Kuntur',
        'spanish': 'Cóndor',
        'phonetic': 'KUN-tur',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FC%C3%B3ndor.jpg?alt=media&token=9fd31aa7-b3a9-415f-a333-bc938c1efb2b',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkuntur.mp3?alt=media&token=bf8495ff-1f8c-44d6-b3aa-6a01e2290e6b',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkuntur.glb?alt=media&token=89d97e06-133e-4546-be1f-5c48a9b9bbce', // TODO: Reemplazar con URL de Firebase del modelo kuntur.glb
      },
      {
        'quechua': 'Uwiha',
        'spanish': 'Oveja',
        'phonetic': 'u-WI-ha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FOveja.jpg?alt=media&token=4d47b09f-f9b5-4b0c-82bb-51450ce016b5',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fuwiha.mp3?alt=media&token=1d342230-e64c-4a1b-a101-55870bae637f',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fuwiha.glb?alt=media&token=3fa51c64-26df-4c8c-b768-1f4d98869083', // TODO: Reemplazar con URL de Firebase del modelo uwiha.glb
      },
      {
        'quechua': 'Waka',
        'spanish': 'Vaca',
        'phonetic': 'WA-ka',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FVaca.jpg?alt=media&token=481ad086-6b39-4672-b1b2-f5a10b96e5f9',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwaka.mp3?alt=media&token=b253f4ec-818c-44de-91d4-7aada89a17ea',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwaka.glb?alt=media&token=68024947-25de-41e5-9dac-1a3c00693518', // TODO: Reemplazar con URL de Firebase del modelo waka.glb
      },
      {
        'quechua': 'Wallpa',
        'spanish': 'Gallina',
        'phonetic': 'WALL-pa',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGallina.jpg?alt=media&token=89015038-a6b2-4147-9890-113600eb4d35',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwallpa.mp3?alt=media&token=800d2faf-1101-4a9a-b4ff-8c538eb931e6',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwallpa.glb?alt=media&token=3e99f380-8d00-473a-bc8d-3d123b57adf7', // TODO: Reemplazar con URL de Firebase del modelo wallpa.glb
      },
    ];

    for (var word in animalesWords) {
      await db.insert('words', {
        'module_id': 1,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': word['model_3d_path'],
      });
    }

    // ==========================================
    // MÓDULO 2: NATURALEZA
    // ==========================================
    final naturalezaWords = [
      {
        'quechua': 'Inti',
        'spanish': 'Sol',
        'phonetic': 'IN-ti',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FSol.jpg?alt=media&token=5c211b42-d40c-4735-bbf5-276f7de41af5',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Finti.mp3?alt=media&token=443566a4-5b84-4f3b-a589-293148e0d7ae',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Finti.glb?alt=media&token=31652247-040f-4f66-a2bd-8e64b7ed2626', // TODO: Reemplazar con URL de Firebase del modelo inti.glb
      },
      {
        'quechua': 'Killa',
        'spanish': 'Luna',
        'phonetic': 'KI-lla',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FLuna.jpg?alt=media&token=162d37ea-ad8c-4e74-92b3-f60cae76639b',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fkilla.mp3?alt=media&token=04ac3569-e318-4f15-9223-981994fa9762',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fkilla.glb?alt=media&token=460ec4f0-b1d3-4623-a927-b5e1555b726f', // TODO: Reemplazar con URL de Firebase del modelo killa.glb
      },
      {
        'quechua': 'Urqu',
        'spanish': 'Montaña',
        'phonetic': 'UR-ku',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FMonta%C3%B1a.jpg?alt=media&token=903d47f0-de4d-4dfb-870a-e9acee4409cf',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Furqu.mp3?alt=media&token=8b3d1c90-6763-4276-9cf9-8549805d7d29',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Furqu.glb?alt=media&token=426d4b1f-7e75-4912-a597-a825653c44bd', // TODO: Reemplazar con URL de Firebase del modelo urqu.glb
      },
      {
        'quechua': 'Yaku',
        'spanish': 'Agua',
        'phonetic': 'YA-ku',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FAgua.jpg?alt=media&token=9fe52f30-adea-4606-afb7-b7cd15374299',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fyaku.mp3?alt=media&token=abc4d7c5-29ca-4284-9ca4-f4ea20469f1e',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fyaku.glb?alt=media&token=bf32f02b-96d1-4fc6-b2a5-af6ff6430116', // TODO: Reemplazar con URL de Firebase del modelo yaku.glb
      },
      {
        'quechua': "Sach'a",
        'spanish': 'Árbol',
        'phonetic': 'SA-cha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2F%C3%81rbol.jpg?alt=media&token=d46ee95e-3881-4714-84b0-b2b37a6e6398',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fsacha.mp3?alt=media&token=7320d2ba-78fb-4902-b968-9eab3471a16d',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fsacha.glb?alt=media&token=139b75d8-30a3-4d60-977d-dce4e2923ae7', // TODO: Reemplazar con URL de Firebase del modelo sacha.glb
      },
      {
        'quechua': "T'ika",
        'spanish': 'Flor',
        'phonetic': 'TI-ka',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFlor.jpg?alt=media&token=49b200e8-0833-498c-9c4d-fdf710401f85',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Ftika.mp3?alt=media&token=3665f3fc-2018-43d0-b915-05e5fea692be',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Ftika.glb?alt=media&token=787ae11f-7986-469e-9c1f-d7d80bcc7cad', // TODO: Reemplazar con URL de Firebase del modelo tika.glb
      },
      {
        'quechua': 'Wayra',
        'spanish': 'Viento',
        'phonetic': 'WAY-ra',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FViento.jpg?alt=media&token=926fcfc7-906e-40cc-be17-30c49b4d95da',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fwayra.mp3?alt=media&token=b1efe051-cc3f-4534-86ce-4288ee343439',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fwayra.glb?alt=media&token=30498f1a-f4ed-45d9-af6d-67e466e4de1e', // TODO: Reemplazar con URL de Firebase del modelo wayra.glb
      },
      {
        'quechua': 'Nina',
        'spanish': 'Fuego',
        'phonetic': 'NI-na',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFuego.jpg?alt=media&token=328d11e9-2016-4aea-8eed-6f6d93481e1c',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fnina.mp3?alt=media&token=65747862-1f05-4885-9cf4-d71cfb651021',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fnina.glb?alt=media&token=25bc752d-eb0e-4c89-9aa9-161689fc2078', // TODO: Reemplazar con URL de Firebase del modelo nina.glb
      },
      {
        'quechua': 'Rumi',
        'spanish': 'Piedra',
        'phonetic': 'RU-mi',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FPiedra.jpg?alt=media&token=15a202ec-e461-4b6b-aa6f-dd99f6fb4e40',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Frumi.mp3?alt=media&token=38f71841-b5b0-466e-8932-f0c2c42334a1',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Frumi.glb?alt=media&token=ff1fd739-8b1b-4800-b672-e951d1f44ee5', // TODO: Reemplazar con URL de Firebase del modelo rumi.glb
      },
      {
        'quechua': 'Allpa',
        'spanish': 'Tierra',
        'phonetic': 'ALL-pa',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FTierra.jpg?alt=media&token=6cb0eab2-17c4-4ac7-9807-28df444dc5af',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fallpa.mp3?alt=media&token=a21650fe-f73e-404a-b503-f4a22893c4cc',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fallpa.glb?alt=media&token=30817295-8380-4c74-ac52-67ba10cb7a76', // TODO: Reemplazar con URL de Firebase del modelo allpa.glb
      },
    ];

    for (var word in naturalezaWords) {
      await db.insert('words', {
        'module_id': 2,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': word['model_3d_path'],
      });
    }

    // ==========================================
    // MÓDULO 3: FAMILIA Y CULTURA
    // ==========================================
    final familiaWords = [
      {
        'quechua': 'Wasi',
        'spanish': 'Casa',
        'phonetic': 'WA-si',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCasa.jpg?alt=media&token=bd6b7ebc-866f-45e6-b635-580a0091d122',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fwasi.mp3?alt=media&token=28d96c27-2c3c-4f1a-b743-18e33612d046',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fwasi.glb?alt=media&token=453303fa-5756-4f3c-a35d-018c9262e34a', // TODO: Reemplazar con URL de Firebase del modelo wasi.glb
      },
      {
        'quechua': 'Tanta',
        'spanish': 'Pan',
        'phonetic': 'TAN-ta',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FPan.jpg?alt=media&token=a9f7f95b-21ed-443b-8963-099c732c038c',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Ftanta.mp3?alt=media&token=6bad7955-f613-4e5b-9b0f-72508d1462213',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Ftanta.glb?alt=media&token=74644c55-5532-42f1-b8dd-ebd1974613bc', // TODO: Reemplazar con URL de Firebase del modelo tanta.glb
      },
      {
        'quechua': 'Unu',
        'spanish': 'Vaso',
        'phonetic': 'U-nu',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FVaso.jpg?alt=media&token=fb993fb4-962a-4b51-bbbe-0c37278c897e',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Funu.mp3?alt=media&token=55c9ebca-6148-4e4c-a68b-f369fb6c02bc',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Funu.glb?alt=media&token=52957fad-0a10-4d29-a6a6-854a9fe399cc', // TODO: Reemplazar con URL de Firebase del modelo unu.glb
      },
      {
        'quechua': "P'acha",
        'spanish': 'Ropa',
        'phonetic': 'PA-cha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FRopa.jpg?alt=media&token=93cd4c7f-4cc8-4acb-9a72-b45da1dd25fa',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fpacha.mp3?alt=media&token=8f923b66-0c18-457a-a592-72cfb9968a50',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fpacha.glb?alt=media&token=89f764fa-17e7-49fc-83d8-ca151bae0248', // TODO: Reemplazar con URL de Firebase del modelo pacha.glb
      },
      {
        'quechua': 'Chuspa',
        'spanish': 'Bolsa',
        'phonetic': 'CHUS-pa',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FBolsa.jpg?alt=media&token=776908ab-6d63-4085-991d-e4a7cff344dd',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fchuspa.mp3?alt=media&token=02098a79-44dc-4641-9dce-d44a0c7ca3a4',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fchuspa.glb?alt=media&token=0cfac584-3cfe-4908-938d-c95a1cd52e80', // TODO: Reemplazar con URL de Firebase del modelo chuspa.glb
      },
      {
        'quechua': 'Charango',
        'spanish': 'Charango',
        'phonetic': 'cha-RAN-go',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCharango.jpg?alt=media&token=fdcd4af7-99e6-4df7-816f-c9288bc84602',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fcharango.mp3?alt=media&token=5a1b9fd7-7a73-41de-b614-2f03de71828f',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fcharango.glb?alt=media&token=85a1b697-1a55-4ad0-b9e3-e2c923d46850', // TODO: Reemplazar con URL de Firebase del modelo charango.glb
      },
      {
        'quechua': 'Quena',
        'spanish': 'Quena',
        'phonetic': 'KE-na',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FQuena.jpg?alt=media&token=e80a25c5-f8c8-4a37-aa6e-67d49b296643',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fquena.mp3?alt=media&token=f291901c-5681-42b9-9d77-6e1a208c59ff',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fquena.glb?alt=media&token=fc9d8381-c094-455c-93bc-1f004f9f65ae', // TODO: Reemplazar con URL de Firebase del modelo quena.glb
      },
      {
        'quechua': 'Poncho',
        'spanish': 'Poncho',
        'phonetic': 'PON-cho',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FPoncho.jpg?alt=media&token=6868024c-c3f0-4882-b63f-9cf70d6172f5',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fponcho.mp3?alt=media&token=d5e57421-a58e-4fbe-ab09-7f1a9c0a4e72',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fponcho.glb?alt=media&token=f8b72df0-479b-4b3e-a9a3-4529b907467f', // TODO: Reemplazar con URL de Firebase del modelo poncho.glb
      },
      {
        'quechua': "Llawt'u",
        'spanish': 'Corona andina',
        'phonetic': 'LLAWTU',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCorona%20andina.jpg?alt=media&token=c740507d-56f3-4bf1-925b-4c4170015cc4',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fllawtu.mp3?alt=media&token=3e48f801-3cdb-41d0-bd59-ee3f8437e529',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fllawtu.glb?alt=media&token=6e744a3d-196d-4aa0-ba58-3aca7fcf97d2', // TODO: Reemplazar con URL de Firebase del modelo llawtu.glb
      },
      {
        'quechua': 'Mate',
        'spanish': 'Calabaza',
        'phonetic': 'MA-te',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCalabaza.jpg?alt=media&token=41824ca6-892f-481b-b008-d10d1e671c99',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fmate.mp3?alt=media&token=427320bd-2cdf-44c3-b5f4-abf9fecd3229',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fmate.glb?alt=media&token=9713202c-75af-491a-8f44-d2e81b107562', // TODO: Reemplazar con URL de Firebase del modelo mate.glb
      },
    ];

    for (var word in familiaWords) {
      await db.insert('words', {
        'module_id': 3,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': word['model_3d_path'],
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

  Future<bool> isWordLearned(int wordId) async {
    final db = await database;
    final result = await db.query(
      'progress',
      where: 'word_id = ? AND user_id = 1',
      whereArgs: [wordId],
    );

    if (result.isEmpty) return false;
    return result.first['is_learned'] == 1;
  }

  Future<void> toggleWordLearned(int wordId, bool isLearned) async {
    final db = await database;

    final existing = await db.query(
      'progress',
      where: 'word_id = ? AND user_id = 1',
      whereArgs: [wordId],
    );

    if (existing.isEmpty) {
      await db.insert('progress', {
        'user_id': 1,
        'word_id': wordId,
        'is_learned': isLearned ? 1 : 0,
        'times_reviewed': 1,
        'last_review': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'progress',
        {
          'is_learned': isLearned ? 1 : 0,
          'times_reviewed': (existing.first['times_reviewed'] as int) + 1,
          'last_review': DateTime.now().toIso8601String(),
        },
        where: 'word_id = ? AND user_id = 1',
        whereArgs: [wordId],
      );
    }
  }

  Future<int> getLearnedWordsCount(int moduleId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COUNT(*) as count 
    FROM progress p
    INNER JOIN words w ON p.word_id = w.id
    WHERE w.module_id = ? AND p.is_learned = 1 AND p.user_id = 1
  ''', [moduleId]);

    return result.first['count'] as int;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}