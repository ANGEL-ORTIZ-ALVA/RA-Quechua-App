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
      version: 17,
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
    }

    // Migración a v17: corrige IDs de módulos desalineados por AUTOINCREMENT
    if (oldVersion < 17) {
      print('🔄 Migración v${oldVersion}→v17: Corrigiendo IDs de módulos + Quechua Chanka...');

      // Eliminar datos anteriores
      await db.delete('words');
      await db.delete('modules');

      // CLAVE: Resetear el autoincrement para que los IDs empiecen desde 1
      await db.execute("DELETE FROM sqlite_sequence WHERE name='modules'");
      await db.execute("DELETE FROM sqlite_sequence WHERE name='words'");

      // Re-poblar con IDs explícitos
      await _populateInitialData(db, onlyWords: false);

      print('✅ Migración v17 completada: 6 módulos (IDs 1-6), 60 palabras en Quechua Chanka');
    }
  }

  Future<void> _populateInitialData(Database db, {bool onlyWords = false}) async {
    if (!onlyWords) {
      // IMPORTANTE: Usamos 'id' explícito para garantizar alineación con module_id de words
      await db.insert('modules', {
        'id': 1,
        'name': 'Animales',
        'name_quechua': 'Uywakunakuna',
        'description': 'Aprende los nombres de animales en Quechua Chanka',
        'icon': 'pets',
        'order_index': 1,
      });
      await db.insert('modules', {
        'id': 2,
        'name': 'Naturaleza',
        'name_quechua': 'Pachamama',
        'description': 'Descubre elementos de la naturaleza',
        'icon': 'park',
        'order_index': 2,
      });
      await db.insert('modules', {
        'id': 3,
        'name': 'Familia y Cultura',
        'name_quechua': 'Ayllu',
        'description': 'Conoce sobre familia y objetos culturales',
        'icon': 'family_restroom',
        'order_index': 3,
      });
      await db.insert('modules', {
        'id': 4,
        'name': 'Numeros',
        'name_quechua': 'Yupay',
        'description': 'Aprende a contar en Quechua Chanka',
        'icon': 'pin',
        'order_index': 4,
      });
      await db.insert('modules', {
        'id': 5,
        'name': 'Saludos y Cortesia',
        'name_quechua': 'Napaykuy',
        'description': 'Expresiones basicas de saludo y cortesia',
        'icon': 'waving_hand',
        'order_index': 5,
      });
      await db.insert('modules', {
        'id': 6,
        'name': 'Colores',
        'name_quechua': 'Llinpikuna',
        'description': 'Aprende los colores en Quechua Chanka',
        'icon': 'palette',
        'order_index': 6,
      });
    }

    // ==========================================
    // MÓDULO 1: ANIMALES (Quechua Chanka)
    // ==========================================
    final animalesWords = [
      {
        'quechua': 'Alqo',
        'spanish': 'Perro',
        'phonetic': 'AL-qo',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPerro.jpg?alt=media&token=d8157b5d-93f9-44d0-a33b-da0a1becff3c',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Falqo.mp3?alt=media&token=3a47b687-0fc6-4b6b-b705-cd3e904d2d20',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fallqu.glb?alt=media&token=dc6ca802-5b9b-42ac-a216-93d1c83d281e',
      },
      {
        'quechua': 'Michi',
        'spanish': 'Gato',
        'phonetic': 'MI-chi',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGato.jpg?alt=media&token=05850973-8bf0-4fe7-954f-9332feddac57',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fmichi.mp3?alt=media&token=b56617be-49da-471c-98b7-73e926d40a4d',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fmichi.glb?alt=media&token=8f6b90d9-08f0-4d1b-b570-523d42a547d4',
      },
      {
        'quechua': 'Pisqo',
        'spanish': 'Pajaro',
        'phonetic': 'PIS-qo',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPajaro.jpg?alt=media&token=bb473960-9604-413d-8993-8732fd421344',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpisqo.mp3?alt=media&token=89ac0dfb-b8c9-4d3b-83c0-d023f65512c8',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpisqu.glb?alt=media&token=dbb370b1-fd42-415c-aea7-1db952c6c366',
      },
      {
        'quechua': 'Kawallu',
        'spanish': 'Caballo',
        'phonetic': 'ka-WA-llu',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FCaballo.jpg?alt=media&token=679f66d1-5c28-4cda-ba8d-e0390bf74d94',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkawallu.mp3?alt=media&token=0bb50ad2-62a8-4469-abfd-77399b1fce65',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkawallux.glb?alt=media&token=d5ee9747-1c60-4704-957a-8fd1ab590429',
      },
      {
        'quechua': 'Llama',
        'spanish': 'Llama',
        'phonetic': 'LLA-ma',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FLlama.jpg?alt=media&token=6c7d9b5d-e795-47e7-a334-88764f5854bc',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fllama.mp3?alt=media&token=ee24386f-8a31-4584-872d-1e4924962b0f',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fllama.glb?alt=media&token=d987879e-1318-42f5-ac74-d35be5b630a1',
      },
      {
        'quechua': 'Paqocha',
        'spanish': 'Alpaca',
        'phonetic': 'pa-QO-cha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FAlpaca.jpg?alt=media&token=93040399-2380-4eeb-955d-53ee1b76f520',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpaqocha.mp3?alt=media&token=954e3f29-7ea0-4c89-bb58-255e7f39bcca',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpaqocha.glb?alt=media&token=f44f2c31-ef44-4876-89f6-7bf2c7fac95a',
      },
      {
        'quechua': 'Kuntur',
        'spanish': 'Condor',
        'phonetic': 'KUN-tur',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FC%C3%B3ndor.jpg?alt=media&token=9fd31aa7-b3a9-415f-a333-bc938c1efb2b',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkuntur.mp3?alt=media&token=bf8495ff-1f8c-44d6-b3aa-6a01e2290e6b',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkuntur.glb?alt=media&token=89d97e06-133e-4546-be1f-5c48a9b9bbce',
      },
      {
        'quechua': 'Uwiha',
        'spanish': 'Oveja',
        'phonetic': 'u-WI-ha',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FOveja.jpg?alt=media&token=4d47b09f-f9b5-4b0c-82bb-51450ce016b5',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fuwiha.mp3?alt=media&token=1d342230-e64c-4a1b-a101-55870bae637f',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fuwiha.glb?alt=media&token=3fa51c64-26df-4c8c-b768-1f4d98869083',
      },
      {
        'quechua': 'Waka',
        'spanish': 'Vaca',
        'phonetic': 'WA-ka',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FVaca.jpg?alt=media&token=481ad086-6b39-4672-b1b2-f5a10b96e5f9',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwaka.mp3?alt=media&token=b253f4ec-818c-44de-91d4-7aada89a17ea',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwaka.glb?alt=media&token=68024947-25de-41e5-9dac-1a3c00693518',
      },
      {
        'quechua': 'Wallpa',
        'spanish': 'Gallina',
        'phonetic': 'WALL-pa',
        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGallina.jpg?alt=media&token=89015038-a6b2-4147-9890-113600eb4d35',
        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwallpa.mp3?alt=media&token=800d2faf-1101-4a9a-b4ff-8c538eb931e6',
        'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwallpa.glb?alt=media&token=3e99f380-8d00-473a-bc8d-3d123b57adf7',
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
    // MÓDULO 2: NATURALEZA (Quechua Chanka)
    // ==========================================
    final naturalezaWords = [
      {'quechua': 'Inti', 'spanish': 'Sol', 'phonetic': 'IN-ti', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FSol.jpg?alt=media&token=5c211b42-d40c-4735-bbf5-276f7de41af5', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Finti.mp3?alt=media&token=443566a4-5b84-4f3b-a589-293148e0d7ae', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Finti.glb?alt=media&token=31652247-040f-4f66-a2bd-8e64b7ed2626'},
      {'quechua': 'Killa', 'spanish': 'Luna', 'phonetic': 'KI-lla', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FLuna.jpg?alt=media&token=162d37ea-ad8c-4e74-92b3-f60cae76639b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fkilla.mp3?alt=media&token=04ac3569-e318-4f15-9223-981994fa9762', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fkilla.glb?alt=media&token=460ec4f0-b1d3-4623-a927-b5e1555b726f'},
      {'quechua': 'Urqu', 'spanish': 'Montaña', 'phonetic': 'UR-qu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FMonta%C3%B1a.jpg?alt=media&token=903d47f0-de4d-4dfb-870a-e9acee4409cf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Furqu.mp3?alt=media&token=8b3d1c90-6763-4276-9cf9-8549805d7d29', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Furqu.glb?alt=media&token=426d4b1f-7e75-4912-a597-a825653c44bd'},
      {'quechua': 'Yaku', 'spanish': 'Agua', 'phonetic': 'YA-ku', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FAgua.jpg?alt=media&token=9fe52f30-adea-4606-afb7-b7cd15374299', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fyaku.mp3?alt=media&token=abc4d7c5-29ca-4284-9ca4-f4ea20469f1e', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fyaku.glb?alt=media&token=bf32f02b-96d1-4fc6-b2a5-af6ff6430116'},
      {'quechua': 'Sacha', 'spanish': 'Arbol', 'phonetic': 'SA-cha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2F%C3%81rbol.jpg?alt=media&token=d46ee95e-3881-4714-84b0-b2b37a6e6398', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fsacha.mp3?alt=media&token=ab1b353c-0f12-4d01-bc9f-33cdb7a2fd8d', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fsacha.glb?alt=media&token=139b75d8-30a3-4d60-977d-dce4e2923ae7'},
      {'quechua': 'Tika', 'spanish': 'Flor', 'phonetic': 'TI-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFlor.jpg?alt=media&token=49b200e8-0833-498c-9c4d-fdf710401f85', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Ftika.mp3?alt=media&token=463c11cb-e46a-40ec-a157-842501495ce9', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Ftika.glb?alt=media&token=787ae11f-7986-469e-9c1f-d7d80bcc7cad'},
      {'quechua': 'Wayra', 'spanish': 'Viento', 'phonetic': 'WAY-ra', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FViento.jpg?alt=media&token=926fcfc7-906e-40cc-be17-30c49b4d95da', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fwayra.mp3?alt=media&token=b1efe051-cc3f-4534-86ce-4288ee343439', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fwayra.glb?alt=media&token=30498f1a-f4ed-45d9-af6d-67e466e4de1e'},
      {'quechua': 'Nina', 'spanish': 'Fuego', 'phonetic': 'NI-na', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFuego.jpg?alt=media&token=328d11e9-2016-4aea-8eed-6f6d93481e1c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fnina.mp3?alt=media&token=65747862-1f05-4885-9cf4-d71cfb651021', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fnina.glb?alt=media&token=25bc752d-eb0e-4c89-9aa9-161689fc2078'},
      {'quechua': 'Rumi', 'spanish': 'Piedra', 'phonetic': 'RU-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FPiedra.jpg?alt=media&token=15a202ec-e461-4b6b-aa6f-dd99f6fb4e40', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Frumi.mp3?alt=media&token=38f71841-b5b0-466e-8932-f0c2c42334a1', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Frumi.glb?alt=media&token=ff1fd739-8b1b-4800-b672-e951d1f44ee5'},
      {'quechua': 'Allpa', 'spanish': 'Tierra', 'phonetic': 'ALL-pa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FTierra.jpg?alt=media&token=6cb0eab2-17c4-4ac7-9807-28df444dc5af', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fallpa.mp3?alt=media&token=a21650fe-f73e-404a-b503-f4a22893c4cc', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fallpa.glb?alt=media&token=30817295-8380-4c74-ac52-67ba10cb7a76'},
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
    // MÓDULO 3: FAMILIA Y CULTURA (Quechua Chanka)
    // ==========================================
    final familiaWords = [
      {'quechua': 'Wasi', 'spanish': 'Casa', 'phonetic': 'WA-si', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCasa.jpg?alt=media&token=bd6b7ebc-866f-45e6-b635-580a0091d122', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fwasi.mp3?alt=media&token=28d96c27-2c3c-4f1a-b743-18e33612d046', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fwasi.glb?alt=media&token=453303fa-5756-4f3c-a35d-018c9262e34a'},
      {'quechua': 'Tanta', 'spanish': 'Pan', 'phonetic': 'TAN-ta', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FPan.jpg?alt=media&token=a9f7f95b-21ed-443b-8963-099c732c038c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Ftanta.mp3?alt=media&token=6bad7955-f613-4e5b-9b0f-72508d1462213', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Ftanta.glb?alt=media&token=74644c55-5532-42f1-b8dd-ebd1974613bc'},
      {'quechua': 'Unu', 'spanish': 'Vaso', 'phonetic': 'U-nu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FVaso.jpg?alt=media&token=fb993fb4-962a-4b51-bbbe-0c37278c897e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Funu.mp3?alt=media&token=55c9ebca-6148-4e4c-a68b-f369fb6c02bc', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Funu.glb?alt=media&token=52957fad-0a10-4d29-a6a6-854a9fe399cc'},
      {'quechua': 'Pacha', 'spanish': 'Ropa', 'phonetic': 'PA-cha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FRopa.jpg?alt=media&token=93cd4c7f-4cc8-4acb-9a72-b45da1dd25fa', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fpacha.mp3?alt=media&token=322c0a56-69d3-47b3-8c10-a31444724098', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fpacha.glb?alt=media&token=89f764fa-17e7-49fc-83d8-ca151bae0248'},
      {'quechua': 'Chuspa', 'spanish': 'Bolsa', 'phonetic': 'CHUS-pa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FBolsa.jpg?alt=media&token=776908ab-6d63-4085-991d-e4a7cff344dd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fchuspa.mp3?alt=media&token=02098a79-44dc-4641-9dce-d44a0c7ca3a4', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fchuspa.glb?alt=media&token=0cfac584-3cfe-4908-938d-c95a1cd52e80'},
      {'quechua': 'Charango', 'spanish': 'Charango', 'phonetic': 'cha-RAN-go', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCharango.jpg?alt=media&token=fdcd4af7-99e6-4df7-816f-c9288bc84602', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fcharango.mp3?alt=media&token=5a1b9fd7-7a73-41de-b614-2f03de71828f', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fcharango.glb?alt=media&token=85a1b697-1a55-4ad0-b9e3-e2c923d46850'},
      {'quechua': 'Quena', 'spanish': 'Quena', 'phonetic': 'QE-na', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FQuena.jpg?alt=media&token=e80a25c5-f8c8-4a37-aa6e-67d49b296643', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fquena.mp3?alt=media&token=f291901c-5681-42b9-9d77-6e1a208c59ff', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fquena.glb?alt=media&token=fc9d8381-c094-455c-93bc-1f004f9f65ae'},
      {'quechua': 'Punchu', 'spanish': 'Poncho', 'phonetic': 'PUN-chu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FPoncho.jpg?alt=media&token=6868024c-c3f0-4882-b63f-9cf70d6172f5', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fpunchu.mp3?alt=media&token=e517e374-b4e1-4107-81df-74e024963dc1', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fponcho.glb?alt=media&token=f8b72df0-479b-4b3e-a9a3-4529b907467f'},
      {'quechua': 'Llawtu', 'spanish': 'Corona andina', 'phonetic': 'LLAW-tu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCorona%20andina.jpg?alt=media&token=c740507d-56f3-4bf1-925b-4c4170015cc4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fllawtu.mp3?alt=media&token=97f923e9-b9b4-4dbb-8bbc-16b06d86c453', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fllawtu.glb?alt=media&token=6e744a3d-196d-4aa0-ba58-3aca7fcf97d2'},
      {'quechua': 'Mati', 'spanish': 'Calabaza', 'phonetic': 'MA-ti', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Ffamilia%2FCalabaza.jpg?alt=media&token=41824ca6-892f-481b-b008-d10d1e671c99', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Ffamilia%2Fmati.mp3?alt=media&token=74c5abf1-d367-44cd-aafe-f0fe3e88c881', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Ffamilia%2Fmate.glb?alt=media&token=9713202c-75af-491a-8f44-d2e81b107562'},
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

    // ==========================================
    // MÓDULO 4: NÚMEROS (sin modelo 3D)
    // ==========================================
    final numerosWords = [
      {'quechua': 'Huk', 'spanish': 'Uno', 'phonetic': 'HUK', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FHuk.jpg?alt=media&token=cddf6580-2a2a-40ed-827a-107188e48c84', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fhuk.mp3?alt=media&token=a91251e1-4b26-4d36-bfea-3196290c7d12'},
      {'quechua': 'Iskay', 'spanish': 'Dos', 'phonetic': 'IS-kay', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FIskay.jpg?alt=media&token=36fe3df3-e6a0-4cb1-b8df-a45d76326b5c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fiskay.mp3?alt=media&token=7bb41863-75c9-4622-80c3-6e338029c760'},
      {'quechua': 'Kimsa', 'spanish': 'Tres', 'phonetic': 'KIM-sa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FKimsa.jpg?alt=media&token=3a1ee1c6-e1ee-4bdb-96a0-897021f0b03b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fkimsa.mp3?alt=media&token=6f5b8f19-1c6c-44d7-a8ca-c1e0ac524d28'},
      {'quechua': 'Tawa', 'spanish': 'Cuatro', 'phonetic': 'TA-wa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FTawa.jpg?alt=media&token=73c1a9c4-9aee-439a-9a5a-b8840a423fee', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Ftawa.mp3?alt=media&token=b12d2f8c-c6bb-4dee-8744-a4f4559dcb1e'},
      {'quechua': 'Pichqa', 'spanish': 'Cinco', 'phonetic': 'PICH-qa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FPichqa.jpg?alt=media&token=cc5ce785-2945-4b97-a9ab-a9b2380e35d5', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fpichqa.mp3?alt=media&token=c1d125d5-6af9-46cc-9e87-7a6a707bd4f6'},
      {'quechua': 'Suqta', 'spanish': 'Seis', 'phonetic': 'SUQ-ta', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FSuqta.jpg?alt=media&token=7b4e2091-9c09-46b8-9261-8066bee233f0', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fsuqta.mp3?alt=media&token=93ce9f92-7e75-4a4d-9270-da1538d8d52a'},
      {'quechua': 'Qanchis', 'spanish': 'Siete', 'phonetic': 'QAN-chis', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FQanchis.jpg?alt=media&token=4fb2f830-1974-45c7-86db-0794c7f10541', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fqanchis.mp3?alt=media&token=884d297e-2058-4dd9-9055-c2a1e027daa5'},
      {'quechua': 'Pusaq', 'spanish': 'Ocho', 'phonetic': 'PU-saq', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FPusaq.jpg?alt=media&token=e3db6c0b-23d8-4930-99ef-931380d17a97', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fpusaq.mp3?alt=media&token=7f7ab42e-d04e-4a7e-922b-8cf9746a6fea'},
      {'quechua': 'Isqun', 'spanish': 'Nueve', 'phonetic': 'IS-qun', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FIsqun.jpg?alt=media&token=57151acf-6144-4dee-a7fa-28bbc7a5d3a8', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fisqun.mp3?alt=media&token=8cceaca1-18c2-4f38-be13-5d47ce9c28da'},
      {'quechua': 'Chunka', 'spanish': 'Diez', 'phonetic': 'CHUN-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FNumeros%2FChunka.jpg?alt=media&token=304d0d72-7324-4374-b7d0-58f249b124a8', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FNumeros%2Fchunka.mp3?alt=media&token=da54bb2c-8f33-40c5-a3d4-ddb68d885146'},
    ];
    for (var word in numerosWords) {
      await db.insert('words', {
        'module_id': 4,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': '',
      });
    }

    // ==========================================
    // MÓDULO 5: SALUDOS Y CORTESÍA (sin modelo 3D)
    // ==========================================
    final saludosWords = [
      {'quechua': 'Allin punchaw', 'spanish': 'Buenos dias', 'phonetic': 'a-LLIN PUN-chaw', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20punchaw.jpg?alt=media&token=a565ad07-fbaa-439c-a0d3-0c45c084b35d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_punchaw.mp3?alt=media&token=e679fd0c-cfb9-4ad2-9a5a-e5cee4fbbefa'},
      {'quechua': 'Allin chisi', 'spanish': 'Buenas tardes', 'phonetic': 'a-LLIN CHI-si', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20chisi.jpg?alt=media&token=b419b01d-9ad8-4354-860b-f1f7e9a3898d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_chisi.mp3?alt=media&token=bc0d1cef-8680-4313-8685-2543e4899fcc'},
      {'quechua': 'Allin tuta', 'spanish': 'Buenas noches', 'phonetic': 'a-LLIN TU-ta', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20tuta.jpg?alt=media&token=b6e9b9af-4f01-460b-93f0-d33878e83a24', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_tuta.mp3?alt=media&token=83b434e7-7808-41b9-9aa8-e5269d13c4c0'},
      {'quechua': 'Imaynalla kachkanki', 'spanish': 'Como estas?', 'phonetic': 'i-MAY-na-lla kach-KAN-ki', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FImaynalla%20kachkanki.jpg?alt=media&token=dd52bb11-3306-4087-bdbd-89eecc284f49', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fimaynalla_kachkanki.mp3?alt=media&token=1f26ad2e-5498-4dc9-ad6e-a0de30ac3bd4'},
      {'quechua': 'Allillanmi', 'spanish': 'Estoy bien', 'phonetic': 'a-LLI-llan-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllillanmi.jpg?alt=media&token=b33062ac-cf6b-4f36-bc43-bbe2e98b3744', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallillanmi.mp3?alt=media&token=9f10b582-ca49-4ab2-859d-face034a043e'},
      {'quechua': 'Anay', 'spanish': 'Gracias', 'phonetic': 'a-NAY', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FA%C3%B1ay.jpg?alt=media&token=1856a873-282e-4ab4-afcd-11d38f0f5dcc', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fa%C3%B1ay.mp3?alt=media&token=ff263cf8-d220-4cdd-93c0-e5daf9c81a4a'},
      {'quechua': 'Ama hina kaychu', 'spanish': 'Por favor', 'phonetic': 'A-ma HI-na KAY-chu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAma%20hina%20kaychu.jpg?alt=media&token=5fa3acb4-397b-40d0-84e0-1bfabbdd3161', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fama_hina_kaychu.mp3?alt=media&token=b8baf611-e87e-4a91-a7d1-de9c5cb1ee4d'},
      {'quechua': 'Tupananchiskama', 'spanish': 'Hasta luego', 'phonetic': 'tu-pa-NAN-chis-KA-ma', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FTupananchiskama.jpg?alt=media&token=e099f6b5-236c-4d85-80c2-3b86305de312', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Ftupananchiskama.mp3?alt=media&token=c0a4eb40-889a-427a-a0bf-46fef5d0d49d'},
      {'quechua': 'Paqarinkama', 'spanish': 'Hasta manana', 'phonetic': 'pa-qa-RIN-ka-ma', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FPaqarinkama.jpg?alt=media&token=f06e9466-19bc-4fbc-af29-3616b26f5a1e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fpaqarinkama.mp3?alt=media&token=51f1e9a3-4b96-4017-813a-859dd11926ec'},
      {'quechua': 'Imataq sutiyki', 'spanish': 'Como te llamas?', 'phonetic': 'i-MA-taq su-TIY-ki', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FImataq%20sutiyki.jpg?alt=media&token=27912077-a9b1-4e52-9af8-16a4a53e5c5a', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fimataq_sutiyki.mp3?alt=media&token=5c0efecd-bda6-4390-bc8a-375c848fcaf4'},
    ];
    for (var word in saludosWords) {
      await db.insert('words', {
        'module_id': 5,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': '',
      });
    }

    // ==========================================
    // MÓDULO 6: COLORES (sin modelo 3D)
    // ==========================================
    final coloresWords = [
      {'quechua': 'Puka', 'spanish': 'Rojo', 'phonetic': 'PU-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FPuka.jpg?alt=media&token=7b6a08e9-efaa-4cda-bc60-51e0439c053e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fpuka.mp3?alt=media&token=a8ef8ba2-3f01-49f4-9a89-e60d9500895b'},
      {'quechua': 'Qillu', 'spanish': 'Amarillo', 'phonetic': 'QI-llu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FQillu.jpg?alt=media&token=f9631e3f-6469-4b49-9bd4-79021296b347', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fqillu.mp3?alt=media&token=c3f0797f-7d60-48e9-a88d-ec42c22ff777'},
      {'quechua': 'Anqas', 'spanish': 'Azul', 'phonetic': 'AN-qas', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FAnqas.jpg?alt=media&token=06876634-d925-43c6-b7eb-3a76a689d546', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fanqas.mp3?alt=media&token=f7b56e58-0f40-4c32-a26e-a2a113372202'},
      {'quechua': 'Qumir', 'spanish': 'Verde', 'phonetic': 'QU-mir', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FQumir.jpg?alt=media&token=a2c8ac29-1b8d-40bb-88d2-a85092c7347a', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fqumir.mp3?alt=media&token=735e71ae-6661-4f3a-af35-79ea455be42b'},
      {'quechua': 'Yana', 'spanish': 'Negro', 'phonetic': 'YA-na', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FYana.jpg?alt=media&token=e4bb14e7-12d5-4400-959e-6f6e3993b117', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fyana.mp3?alt=media&token=90018990-50cb-4c65-9bcc-2e9b00771cdc'},
      {'quechua': 'Yuraq', 'spanish': 'Blanco', 'phonetic': 'YU-raq', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FYuraq.jpg?alt=media&token=5393cb76-db23-4b82-bc98-96f8ae14056a', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fyuraq.mp3?alt=media&token=8888c3d6-6aaf-4a2e-9fe9-430a4f29b029'},
      {'quechua': 'Uqi', 'spanish': 'Gris', 'phonetic': 'U-qi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FUqi.jpg?alt=media&token=dcf263f3-dcf8-4733-86cd-781b28c59745', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fuqi.mp3?alt=media&token=1a2a0a6a-5079-4bbb-9cec-55c92ed0cb8e'},
      {'quechua': 'Chumpi', 'spanish': 'Marron', 'phonetic': 'CHUM-pi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FChumpi.jpg?alt=media&token=260dc6b1-b9a8-4cd8-82b9-6f6de19175c4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fchumpi.mp3?alt=media&token=bccf595a-e652-4786-8784-c02b106b19e2'},
      {'quechua': 'Qillu puka', 'spanish': 'Naranja', 'phonetic': 'QI-llu PU-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FQillu%20puka.jpg?alt=media&token=7cecaaad-db73-4e63-9cf0-c506a5a1d1a4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fqillu_puka.mp3?alt=media&token=55ca4b1f-c13c-4f51-b49c-6db2879397e6'},
      {'quechua': 'Kulli', 'spanish': 'Morado', 'phonetic': 'KU-lli', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FKulli.jpg?alt=media&token=09fa3c9c-f5d8-4998-954a-a678c94bae78', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fkulli.mp3?alt=media&token=8f4c9cf7-6742-47f8-9774-e2f8803b712a'},
    ];
    for (var word in coloresWords) {
      await db.insert('words', {
        'module_id': 6,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'],
        'audio_path': word['audio_path'],
        'model_3d_path': '',
      });
    }
  }

  // CRUD de Words
  Future<List<WordModel>> getWordsByModule(int moduleId) async {
    final db = await database;
    final result = await db.query('words', where: 'module_id = ?', whereArgs: [moduleId]);
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
    final result = await db.query('evaluations', where: 'module_id = ?', whereArgs: [moduleId], orderBy: 'completed_at DESC');
    return result.map((map) => EvaluationModel.fromMap(map)).toList();
  }

  Future<List<EvaluationModel>> getAllEvaluations() async {
    final db = await database;
    final result = await db.query('evaluations', orderBy: 'completed_at DESC');
    return result.map((map) => EvaluationModel.fromMap(map)).toList();
  }

  Future<EvaluationModel?> getLastEvaluation(int moduleId) async {
    final db = await database;
    final result = await db.query('evaluations', where: 'module_id = ?', whereArgs: [moduleId], orderBy: 'completed_at DESC', limit: 1);
    if (result.isEmpty) return null;
    return EvaluationModel.fromMap(result.first);
  }

  /// Devuelve la mejor evaluación (mayor porcentaje) de un módulo
  Future<double> getBestEvaluationScore(int moduleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(percentage) as best FROM evaluations WHERE module_id = ? AND user_id = 1',
      [moduleId],
    );
    if (result.isEmpty || result.first['best'] == null) return 0.0;
    return (result.first['best'] as num).toDouble();
  }

  Future<bool> isWordLearned(int wordId) async {
    final db = await database;
    final result = await db.query('progress', where: 'word_id = ? AND user_id = 1', whereArgs: [wordId]);
    if (result.isEmpty) return false;
    return result.first['is_learned'] == 1;
  }

  Future<void> toggleWordLearned(int wordId, bool isLearned) async {
    final db = await database;
    final existing = await db.query('progress', where: 'word_id = ? AND user_id = 1', whereArgs: [wordId]);
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
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM progress p INNER JOIN words w ON p.word_id = w.id WHERE w.module_id = ? AND p.is_learned = 1 AND p.user_id = 1',
      [moduleId],
    );
    return result.first['count'] as int;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}