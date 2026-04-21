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
      version: 21,
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
      await db.delete('words');
      await db.delete('modules');
      await db.execute("DELETE FROM sqlite_sequence WHERE name='modules'");
      await db.execute("DELETE FROM sqlite_sequence WHERE name='words'");
      await _populateInitialData(db, onlyWords: false);
      print('✅ Migración v17 completada');
    }

    // Migración a v18: Reestructuración pedagógica — 5 nuevos módulos + reordenamiento
    if (oldVersion >= 17 && oldVersion < 18) {
      print('🔄 Migración v17→v18: Reestructuración pedagógica por niveles...');

      await db.update('modules', {'order_index': 3}, where: 'id = ?', whereArgs: [1]);
      await db.update('modules', {'order_index': 4}, where: 'id = ?', whereArgs: [2]);
      await db.update('modules', {'order_index': 5}, where: 'id = ?', whereArgs: [3]);
      await db.update('modules', {'order_index': 1}, where: 'id = ?', whereArgs: [4]);
      await db.update('modules', {'order_index': 2}, where: 'id = ?', whereArgs: [5]);
      await db.update('modules', {'order_index': 6}, where: 'id = ?', whereArgs: [6]);

      await db.insert('modules', {'id': 7, 'name': 'Vocales', 'name_quechua': 'Uyariykuna', 'description': 'Las 3 vocales y reglas foneticas del Quechua Chanka', 'icon': 'record_voice_over', 'order_index': 7});
      await db.insert('modules', {'id': 8, 'name': 'Alfabeto', 'name_quechua': 'Achahala', 'description': 'Las 18 letras del alfabeto Quechua Chanka', 'icon': 'abc', 'order_index': 8});
      await db.insert('modules', {'id': 9, 'name': 'Figuras', 'name_quechua': "Siq'ikuna", 'description': 'Figuras geometricas 2D y 3D en Quechua', 'icon': 'category', 'order_index': 9});
      await db.insert('modules', {'id': 10, 'name': 'Frases', 'name_quechua': 'Rimaykuna', 'description': 'Frases cotidianas combinando vocabulario', 'icon': 'chat_bubble', 'order_index': 10});
      await db.insert('modules', {'id': 11, 'name': 'Oraciones', 'name_quechua': 'Rimariykuna', 'description': 'Oraciones completas en Quechua Chanka', 'icon': 'menu_book', 'order_index': 11});

      await _populateNewModulesV18(db);

      print('✅ Migración v18 completada: 11 módulos, ~107 items');
    }

    // Migración a v19: Módulo de Gramática (sufijos esenciales)
    if (oldVersion >= 18 && oldVersion < 19) {
      print('🔄 Migración v18→v19: Agregando módulo de Gramática...');

      await db.update('words',
        {'word_quechua': 'Añay', 'phonetic': 'a-ÑAY'},
        where: "module_id = 5 AND word_quechua = 'Anay'",
      );

      await db.insert('modules', {'id': 12, 'name': 'Gramatica', 'name_quechua': 'Simikuna Kamachiy', 'description': 'Sufijos esenciales del Quechua Chanka', 'icon': 'rule', 'order_index': 12});

      await _populateGrammarModule(db);

      print('✅ Migración v19 completada: 12 módulos, ~119 items');
    }

    // Migración a v20: Corrige URLs vacías en módulos 8-11
    // Bug: los INSERT usaban strings vacíos en vez de las URLs de Firebase
    if (oldVersion >= 19 && oldVersion < 20) {
      print('🔄 Migración v19→v20: Corrigiendo URLs de Firebase en módulos 8-11...');
      await _fixUrlsV20(db);
      print('✅ Migración v20 completada: URLs de audio/imagen corregidas');
    }
    // Migración a v21: Correcciones ortográficas + URLs gramática
    if (oldVersion >= 20 && oldVersion < 21) {
      print('🔄 Migración v20→v21: Correcciones ortográficas...');
      await _fixOrthographyV21(db);
      print('✅ Migración v21 completada');
    }
  }

  // ================================================================
  // FIX v20: Actualiza URLs vacías → URLs reales de Firebase
  // ================================================================
  Future<void> _fixUrlsV20(Database db) async {
    // ─── MÓDULO 8: ALFABETO — fix image_path + audio_path ───
    final alfabetoFixes = [
      {'quechua': 'A',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FA.jpg?alt=media&token=a09e3c3a-7d92-4f70-8cc2-1cf44e33e8dd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fa.mp3?alt=media&token=bf7cc58f-c297-4342-bdc2-e2aef0e9b666'},
      {'quechua': 'CH', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FCH.png?alt=media&token=5cdc1a2e-23ab-4f7e-abb3-8ba95b9f1734', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fch.mp3?alt=media&token=e7d91a39-9239-42d3-bf56-9c1972bb852f'},
      {'quechua': 'H',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FH.jpg?alt=media&token=010c8144-057f-4766-9d0b-3034eae24862', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fh.mp3?alt=media&token=33b73a13-2e75-4d90-818d-a61d1e8f4cce'},
      {'quechua': 'I',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FI.jpg?alt=media&token=107ad6b2-2db7-454e-ac76-46949a12da70', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fi.mp3?alt=media&token=30a91dee-f843-4190-8888-f6d7bab9d722'},
      {'quechua': 'K',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FK.jpg?alt=media&token=fe7a40a2-ad0d-4e24-a18f-43b99d594bf2', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fk.mp3?alt=media&token=8e3d5924-af69-4081-b1c8-b9170bb63661'},
      {'quechua': 'L',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FL.jpg?alt=media&token=fee97961-4d1f-4a87-9434-a1017c35105c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fl.mp3?alt=media&token=ca23b818-3dc5-4b68-b010-0366ac6619c7'},
      {'quechua': 'LL', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FLL.png?alt=media&token=0ad38b38-82ae-4f73-a5a9-45ef53894903', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fll.mp3?alt=media&token=8b11b606-c825-4977-9533-dfe18bfab7a8'},
      {'quechua': 'M',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FM.jpg?alt=media&token=7e747bb4-87aa-4a12-a97b-f27255bfab8f', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fm.mp3?alt=media&token=ad9959ea-ccc7-4c51-9eac-3f1db8626096'},
      {'quechua': 'N',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FN.jpg?alt=media&token=4c4cb4db-109b-449f-8f4c-d5affa8c4bfa', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fn.mp3?alt=media&token=855edf47-7c62-465b-9d91-f44c3b76cc7f'},
      {'quechua': 'Ñ',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2F%C3%91.jpg?alt=media&token=99646b38-64a1-405b-ad98-ee3460072f8d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fny.mp3?alt=media&token=2a22a0de-7574-47e0-90b7-37ea45eedecb'},
      {'quechua': 'P',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FP.jpg?alt=media&token=2716c18d-8890-46a5-aa20-917c3d4b2f2e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fp.mp3?alt=media&token=f32dd6eb-5a16-4eb4-9b13-27a48832bc92'},
      {'quechua': 'Q',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FQ.jpg?alt=media&token=4fc34996-7ef2-46de-965e-5ee7146391d7', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fq.mp3?alt=media&token=e2298335-f8e9-4c90-b01c-87a7acbad1b3'},
      {'quechua': 'R',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FR.jpg?alt=media&token=a911c4c7-5b3d-4c6b-a599-0bb3c99aa1b8', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fr.mp3?alt=media&token=f95ea35d-b75b-4291-a8df-230424f7716c'},
      {'quechua': 'S',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FS.jpg?alt=media&token=3fc23486-1de9-438c-8ce7-4b3a10e75ecd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fs.mp3?alt=media&token=c28b077c-ad9a-4f1c-99a8-3d7ecc692f70'},
      {'quechua': 'T',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FT.jpg?alt=media&token=891dc974-9594-4aca-aa4b-dfc55091becf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Ft.mp3?alt=media&token=6dfb270e-c29f-489d-b1b3-3bdf068ecc1a'},
      {'quechua': 'U',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FU.jpg?alt=media&token=56271a88-5532-45f9-a8ac-3d5d69eaccd4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fu_suena_o.mp3?alt=media&token=645638e0-b7ad-4e44-a559-f343d5fd7ae8'},
      {'quechua': 'W',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FW.jpg?alt=media&token=b492c981-4ca9-4dc3-989f-061879901934', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fw.mp3?alt=media&token=133a2506-154a-4c81-bc7a-554b06b8e27f'},
      {'quechua': 'Y',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FY.jpg?alt=media&token=54947626-49b6-4661-be17-c962a5c27779', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fy.mp3?alt=media&token=76d71cc8-df4b-41fd-9b5d-12e1ddd3eafd'},
    ];
    for (var fix in alfabetoFixes) {
      await db.update('words',
        {'image_path': fix['image_path'], 'audio_path': fix['audio_path']},
        where: "module_id = 8 AND word_quechua = ?",
        whereArgs: [fix['quechua']],
      );
    }

    // ─── MÓDULO 9: FIGURAS — fix image_path + audio_path ───
    final figurasFixes = [
      {'quechua': 'Muyu',        'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCirculo.jpg?alt=media&token=da3c29be-1e97-4d0d-945b-12dd6e53621b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fmuyu.mp3?alt=media&token=12cff0a0-0dd7-4054-808a-728cb7a5380f'},
      {'quechua': 'Kimsa kuchu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FTriangulo.jpg?alt=media&token=9ee05d9e-7b92-431f-b58f-8efb56f097c3', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fkimsa_kuchu.mp3?alt=media&token=1de46ef7-97dc-4648-ac94-1586fab09ab5'},
      {'quechua': 'Tawa kuchu',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCuadrado.jpg?alt=media&token=c4190fa0-cc7e-4e91-8b86-8588dc798adf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Ftawa_kuchu.mp3?alt=media&token=001a7ed2-3298-4d75-8630-ba8183cb2d69'},
      {'quechua': 'Pichqa kuchu','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FPentagono.jpg?alt=media&token=a7413d99-6d7d-4f24-8647-3cd7bd1188a9', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fpichqa_kuchu.mp3?alt=media&token=6545e5a5-fb83-4199-82f8-a98fec58eff7'},
      {'quechua': 'Ruyru',       'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fruyru.mp3?alt=media&token=5703c762-d5ef-4f23-a568-f74fad09cf7c'},
      {'quechua': 'Machina',     'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fmachina.mp3?alt=media&token=eb7b8c6b-66e1-49e7-bef0-fc8d5e6bf096'},
      {'quechua': 'Chuqu',       'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fchuqu.mp3?alt=media&token=29c75b82-fe49-455f-8701-a20012806b8d'},
      {'quechua': 'Tuquru',      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Ftuquru.mp3?alt=media&token=8ab9d284-51a7-45d5-bf5a-318d66db9ed3'},
    ];
    for (var fix in figurasFixes) {
      final updates = <String, Object>{};
      if (fix.containsKey('image_path')) updates['image_path'] = fix['image_path']!;
      if (fix.containsKey('audio_path')) updates['audio_path'] = fix['audio_path']!;
      await db.update('words', updates,
        where: "module_id = 9 AND word_quechua = ?",
        whereArgs: [fix['quechua']],
      );
    }

    // ─── MÓDULO 10: FRASES — fix audio_path ───
    final frasesFixes = [
      {'quechua': 'Huk puka tika', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FHuk%20puka%20tika.jpg?alt=media&token=cd6a56da-73c7-4fa1-bdbb-587b5ed5114b',           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fhuk_puka_tika.mp3?alt=media&token=2da8cd57-1097-4c53-ac69-79517b8e4b9f'},
      {'quechua': 'Iskay yana allqu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FIskay%20yana%20allqu.jpg?alt=media&token=5827ce25-0289-4d81-9924-10d7b550ae0f',        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fiskay_yana_allqu.mp3?alt=media&token=78acc57d-c36a-4df5-8f06-fcc8a1a28cef'},
      {'quechua': 'Taytay hatunmi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FTaytay%20hatunmi.jpg?alt=media&token=f11bd3e9-20e2-4392-89f7-d4b5daa91c17',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Ftaytay_hatunmi.mp3?alt=media&token=52ef3ae4-b0ae-4237-acd0-8b4c72b3ae5f'},
      {'quechua': 'Sutiyqa ___mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FSutiyqa.jpg?alt=media&token=63db5a2c-0bb4-4c88-ae50-f5c3ce0e63d6',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fsutiyqa_mi.mp3?alt=media&token=d39e13ba-0608-48d3-904d-45cdb92a1e3c'},
      {'quechua': 'Maymantan kanki?', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FMaymantan%20kanki.jpg?alt=media&token=8f5cdccf-05b8-4b8b-a34e-3f8d30e8bb29',       'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fmaymantan_kanki.mp3?alt=media&token=7ef26716-f57b-47f0-b5d1-2644cdde3642'},
      {'quechua': 'Ñuqap wasiymi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2F%C3%91uqap%20wasiymi.jpg?alt=media&token=6fc6fd06-04a6-4ecf-af06-a424e5f126c7',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fnuqap_wasiymi.mp3?alt=media&token=187da551-4447-456c-88a7-81afbdd7550c'},
      {'quechua': 'Kimsa yuraq urpi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FKimsa%20yuraq%20urpi.jpg?alt=media&token=caaa76bc-2074-4b35-bb4b-9b9a43cd8b9b',       'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fkimsa_yuraq_urpi.mp3?alt=media&token=180bc68f-aecb-4c40-b9eb-1fbe20a5488e'},
      {'quechua': 'Pichqa qillu tika', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FPichqa%20qillu%20tika.jpg?alt=media&token=e3af2b35-859e-4455-b209-a623efbde423',      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fpichqa_qillu_tika.mp3?alt=media&token=61dd9248-b4d3-4a55-aa1f-f0865085c5f1'},
      {'quechua': 'Allqu hatunmi',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FAllqu%20hatunmi.jpg?alt=media&token=d768b66b-461d-477c-9f36-3102de73bf2e',         'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fallqu_hatunmi.mp3?alt=media&token=f85ada7b-89b2-4ad1-9191-a47ce9f9aa32'},
      {'quechua': 'Yaku sumaqmi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FYaku%20sumaqmi.jpg?alt=media&token=3478e7ca-eab6-4d4c-a790-ae573dc861f5',           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fyaku_sumaqmi.mp3?alt=media&token=0f7d17b3-5718-4e05-b9bd-8138921f5681'},
    ];
    for (var fix in frasesFixes) {
      await db.update('words',
        {'audio_path': fix['audio_path']},
        where: "module_id = 10 AND word_quechua = ?",
        whereArgs: [fix['quechua']],
      );
    }

    // ─── MÓDULO 11: ORACIONES — fix audio_path ───
    final oracionesFixes = [
      {'quechua': 'Allquy pukllachkan wasipa patanpi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FAllquy%20pukllachkan%20wasipa%20patanpi.jpg?alt=media&token=b22d9bf7-f23c-48aa-8ea2-7fef96748147',     'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fallquy_pukllachkan.mp3?alt=media&token=d57237e9-5916-45d1-8c87-7ca0df4808ed'},
      {'quechua': 'Taytay chakranpi llankachkan', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FTaytay%20chakranpi%20llankachkan.jpg?alt=media&token=c7a04ed5-81c8-4a14-b6b9-ff4f9568c8fb',            'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Ftaytay_llankachkan.mp3?alt=media&token=943653e3-8913-4867-8e5e-6b292d09bbaf'},
      {'quechua': 'Mamay mikuyta waykuchkan',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FMamay%20mikuyta%20waykuchkan.jpg?alt=media&token=0c188b54-2750-4eff-ae70-ad9459e87ede',               'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fmamay_waykuchkan.mp3?alt=media&token=e5287f2d-34b6-473c-9186-5386db6622e6'},
      {'quechua': 'Kunturqa hanaq pachapi phawachkan',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKunturqa%20hanaq%20pachapi%20phawachkan.jpg?alt=media&token=d38390f7-7a8e-44a2-86b5-83f8f5b36e57',      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkunturqa_phawachkan.mp3?alt=media&token=153944a0-6dc7-4433-bc5b-ff346570394f'},
      {'quechua': 'Inti lluqsimuchkan urqu patamanta',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FInti%20lluqsimuchkan%20urqu%20patamanta.jpg?alt=media&token=6db551b0-f9c8-47e4-872f-2fe3d318a5cf',      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Finti_lluqsimuchkan.mp3?alt=media&token=784ceef4-d712-4e3d-a498-4eaf4f2512ec'},
      {'quechua': 'Yakuta apamuy wasiyman',       'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FYakuta%20apamuy%20wasiyman.jpg?alt=media&token=9da6ef00-1aba-4a1b-aaf1-a04c3edeb66e',            'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fyakuta_apamuy.mp3?alt=media&token=fa03face-c762-465b-8e0c-707d441e54a2'},
      {'quechua': 'Kay rumiqa hatunmi',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKay%20rumiqa%20hatunmi.jpg?alt=media&token=ff9ce8f4-7008-45e6-9f36-1c5b96202b25',                     'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkay_rumiqa_hatunmi.mp3?alt=media&token=a42a7842-3c5f-4c19-9d7f-8036ff4c0a3d'},
      {'quechua': 'Kimsa yuraq urpi tiyachkan sachapi',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKimsa%20yuraq%20urpi%20tiyachkan%20sachapi.jpg?alt=media&token=eadea1d5-e6b0-4ffe-8b0a-db2962168913',     'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkimsa_urpi_sachapi.mp3?alt=media&token=27dad0df-ed40-4cca-8795-2ca9d605d2bb'},
    ];
    for (var fix in oracionesFixes) {
      await db.update('words',
        {'audio_path': fix['audio_path']},
        where: "module_id = 11 AND word_quechua = ?",
        whereArgs: [fix['quechua']],
      );
    }
  }
  // ================================================================
  // FIX v21: Correcciones ortográficas + ajustes de URLs de gramática
  // ================================================================
  Future<void> _fixOrthographyV21(Database db) async {
    // Correcciones ortográficas puntuales
    final orthographyFixes = [
      {
        'module_id': 5,
        'old_quechua': 'Anay',
        'new_quechua': 'Añay',
        'new_phonetic': 'a-ÑAY',
      },
    ];

    for (final fix in orthographyFixes) {
      final updates = <String, Object>{};

      if (fix['new_quechua'] != null) {
        updates['word_quechua'] = fix['new_quechua'] as String;
      }
      if (fix['new_phonetic'] != null) {
        updates['phonetic'] = fix['new_phonetic'] as String;
      }

      if (updates.isNotEmpty) {
        await db.update(
          'words',
          updates,
          where: 'module_id = ? AND word_quechua = ?',
          whereArgs: [
            fix['module_id'],
            fix['old_quechua'],
          ],
        );
      }
    }

    // Si luego quieres agregar más correcciones de gramática/URLs, van aquí.
  }
  // ================================================================
  // DATOS NUEVOS v18: Módulos 7-11
  // ================================================================
  Future<void> _populateNewModulesV18(Database db) async {
    // ─── MÓDULO 7: VOCALES (5 items) ───
    final vocalesWords = [
      {'quechua': 'A', 'spanish': 'Vocal A', 'phonetic': 'a (como en español)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FA.jpg?alt=media&token=a09e3c3a-7d92-4f70-8cc2-1cf44e33e8dd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fa.mp3?alt=media&token=bf7cc58f-c297-4342-bdc2-e2aef0e9b666'},
      {'quechua': 'I', 'spanish': 'Vocal I', 'phonetic': 'i (como en español)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FI.jpg?alt=media&token=107ad6b2-2db7-454e-ac76-46949a12da70', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fi.mp3?alt=media&token=30a91dee-f843-4190-8888-f6d7bab9d722'},
      {'quechua': 'U', 'spanish': 'Vocal U', 'phonetic': 'u (como en español)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FU.jpg?alt=media&token=56271a88-5532-45f9-a8ac-3d5d69eaccd4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fu.mp3?alt=media&token=f469b93f-78f4-4939-96b9-ab592f4d4d93'},
      {'quechua': 'I = E', 'spanish': 'I suena como E junto a Q', 'phonetic': 'Qillu se dice "Qellu"', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FQi.jpg?alt=media&token=26a7f006-85f6-4c8b-99b4-5e1b3ba8b86b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fi_suena_e.mp3?alt=media&token=86d05d88-110d-4bbd-873d-9d3c6d2d2578'},
      {'quechua': 'U = O', 'spanish': 'U suena como O junto a Q', 'phonetic': 'Qucha se dice "Qocha"', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FQu.jpg?alt=media&token=c168f272-5a48-44dd-9ed3-f0c82a5f9226', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fu_suena_o.mp3?alt=media&token=645638e0-b7ad-4e44-a559-f343d5fd7ae8'},
    ];
    for (var word in vocalesWords) {
      await db.insert('words', {
        'module_id': 7,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': word['model_3d_path'] ?? '',
      });
    }

    // ─── MÓDULO 8: ALFABETO / ACHAHALA (18 items) ───
    // Fuente: RM 1218-85-ED, Simi Qullqa (MINEDU, 2014)
    final alfabetoWords = [
      {'quechua': 'A',  'spanish': 'Letra A - Vocal',         'phonetic': 'a',   'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FA.jpg?alt=media&token=a09e3c3a-7d92-4f70-8cc2-1cf44e33e8dd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fa.mp3?alt=media&token=bf7cc58f-c297-4342-bdc2-e2aef0e9b666'},
      {'quechua': 'CH', 'spanish': 'Letra CH - Consonante',   'phonetic': 'cha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FCH.png?alt=media&token=5cdc1a2e-23ab-4f7e-abb3-8ba95b9f1734', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fch.mp3?alt=media&token=e7d91a39-9239-42d3-bf56-9c1972bb852f'},
      {'quechua': 'H',  'spanish': 'Letra H - Consonante',    'phonetic': 'ha (como J suave)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FH.jpg?alt=media&token=010c8144-057f-4766-9d0b-3034eae24862', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fh.mp3?alt=media&token=33b73a13-2e75-4d90-818d-a61d1e8f4cce'},
      {'quechua': 'I',  'spanish': 'Letra I - Vocal',         'phonetic': 'i',   'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FI.jpg?alt=media&token=107ad6b2-2db7-454e-ac76-46949a12da70', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fi.mp3?alt=media&token=30a91dee-f843-4190-8888-f6d7bab9d722'},
      {'quechua': 'K',  'spanish': 'Letra K - Consonante',    'phonetic': 'ka',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FK.jpg?alt=media&token=fe7a40a2-ad0d-4e24-a18f-43b99d594bf2', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fk.mp3?alt=media&token=8e3d5924-af69-4081-b1c8-b9170bb63661'},
      {'quechua': 'L',  'spanish': 'Letra L - Consonante',    'phonetic': 'la',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FL.jpg?alt=media&token=fee97961-4d1f-4a87-9434-a1017c35105c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fl.mp3?alt=media&token=ca23b818-3dc5-4b68-b010-0366ac6619c7'},
      {'quechua': 'LL', 'spanish': 'Letra LL - Consonante',   'phonetic': 'lla', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FLL.png?alt=media&token=0ad38b38-82ae-4f73-a5a9-45ef53894903', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fll.mp3?alt=media&token=8b11b606-c825-4977-9533-dfe18bfab7a8'},
      {'quechua': 'M',  'spanish': 'Letra M - Consonante',    'phonetic': 'ma',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FM.jpg?alt=media&token=7e747bb4-87aa-4a12-a97b-f27255bfab8f', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fm.mp3?alt=media&token=ad9959ea-ccc7-4c51-9eac-3f1db8626096'},
      {'quechua': 'N',  'spanish': 'Letra N - Consonante',    'phonetic': 'na',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FN.jpg?alt=media&token=4c4cb4db-109b-449f-8f4c-d5affa8c4bfa', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fn.mp3?alt=media&token=855edf47-7c62-465b-9d91-f44c3b76cc7f'},
      {'quechua': 'Ñ',  'spanish': 'Letra Ñ - Consonante',    'phonetic': 'ña',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2F%C3%91.jpg?alt=media&token=99646b38-64a1-405b-ad98-ee3460072f8d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fny.mp3?alt=media&token=2a22a0de-7574-47e0-90b7-37ea45eedecb'},
      {'quechua': 'P',  'spanish': 'Letra P - Consonante',    'phonetic': 'pa',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FP.jpg?alt=media&token=2716c18d-8890-46a5-aa20-917c3d4b2f2e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fp.mp3?alt=media&token=f32dd6eb-5a16-4eb4-9b13-27a48832bc92'},
      {'quechua': 'Q',  'spanish': 'Letra Q - Consonante',    'phonetic': 'qa (como J fuerte)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FQ.jpg?alt=media&token=4fc34996-7ef2-46de-965e-5ee7146391d7', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fq.mp3?alt=media&token=e2298335-f8e9-4c90-b01c-87a7acbad1b3'},
      {'quechua': 'R',  'spanish': 'Letra R - Consonante',    'phonetic': 'ra (R simple, nunca RR)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FR.jpg?alt=media&token=a911c4c7-5b3d-4c6b-a599-0bb3c99aa1b8', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fr.mp3?alt=media&token=f95ea35d-b75b-4291-a8df-230424f7716c'},
      {'quechua': 'S',  'spanish': 'Letra S - Consonante',    'phonetic': 'sa',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FS.jpg?alt=media&token=3fc23486-1de9-438c-8ce7-4b3a10e75ecd', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fs.mp3?alt=media&token=c28b077c-ad9a-4f1c-99a8-3d7ecc692f70'},
      {'quechua': 'T',  'spanish': 'Letra T - Consonante',    'phonetic': 'ta',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FT.jpg?alt=media&token=891dc974-9594-4aca-aa4b-dfc55091becf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Ft.mp3?alt=media&token=6dfb270e-c29f-489d-b1b3-3bdf068ecc1a'},
      {'quechua': 'U',  'spanish': 'Letra U - Vocal',         'phonetic': 'u',   'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FVocales%2FU.jpg?alt=media&token=56271a88-5532-45f9-a8ac-3d5d69eaccd4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FVocales%2Fu.mp3?alt=media&token=f469b93f-78f4-4939-96b9-ab592f4d4d93'},
      {'quechua': 'W',  'spanish': 'Letra W - Semiconsonante','phonetic': 'wa',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FW.jpg?alt=media&token=b492c981-4ca9-4dc3-989f-061879901934', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fw.mp3?alt=media&token=133a2506-154a-4c81-bc7a-554b06b8e27f'},
      {'quechua': 'Y',  'spanish': 'Letra Y - Semiconsonante','phonetic': 'ya',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FAbecedario%2FY.jpg?alt=media&token=54947626-49b6-4661-be17-c962a5c27779', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FAbecedario%2Fy.mp3?alt=media&token=76d71cc8-df4b-41fd-9b5d-12e1ddd3eafd'},
    ];
    for (var word in alfabetoWords) {
      await db.insert('words', {
        'module_id': 8,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': '',
      });
    }

    // ─── MÓDULO 9: FIGURAS / SIQ'IKUNA (8 items) ───
    // Fuente: Yachakuqkunapa Simi Qullqa (MINEDU, 2014)
    final figurasWords = [
      // Figuras 2D (sin modelo 3D)
      {'quechua': 'Muyu',        'spanish': 'Círculo',    'phonetic': 'MU-yu',           'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCirculo.jpg?alt=media&token=da3c29be-1e97-4d0d-945b-12dd6e53621b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fmuyu.mp3?alt=media&token=12cff0a0-0dd7-4054-808a-728cb7a5380f'},
      {'quechua': 'Kimsa kuchu', 'spanish': 'Triángulo',  'phonetic': 'KIM-sa KU-chu',   'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FTriangulo.jpg?alt=media&token=9ee05d9e-7b92-431f-b58f-8efb56f097c3', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fkimsa_kuchu.mp3?alt=media&token=1de46ef7-97dc-4648-ac94-1586fab09ab5'},
      {'quechua': 'Tawa kuchu',  'spanish': 'Cuadrado',   'phonetic': 'TA-wa KU-chu',    'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCuadrado.jpg?alt=media&token=c4190fa0-cc7e-4e91-8b86-8588dc798adf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Ftawa_kuchu.mp3?alt=media&token=001a7ed2-3298-4d75-8630-ba8183cb2d69'},
      {'quechua': 'Pichqa kuchu','spanish': 'Pentágono',  'phonetic': 'PICH-qa KU-chu',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FPentagono.jpg?alt=media&token=a7413d99-6d7d-4f24-8647-3cd7bd1188a9', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fpichqa_kuchu.mp3?alt=media&token=6545e5a5-fb83-4199-82f8-a98fec58eff7'},
      // Figuras 3D (CON modelo 3D para AR)
      {'quechua': 'Ruyru',       'spanish': 'Esfera',     'phonetic': 'RUY-ru', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FEsfera.jpg?alt=media&token=2565ddae-f10f-46f8-8c57-df96ca05320b',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fruyru.mp3?alt=media&token=5703c762-d5ef-4f23-a568-f74fad09cf7c',  'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2FFiguras%2FEsfera.glb?alt=media&token=f059842f-899d-46ea-86e7-7968ba9f48da'},
      {'quechua': 'Machina',     'spanish': 'Cubo',       'phonetic': 'ma-CHI-na','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCubo.jpg?alt=media&token=159f91da-65be-4f9b-9e71-9d2b8560aee5',        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fmachina.mp3?alt=media&token=eb7b8c6b-66e1-49e7-bef0-fc8d5e6bf096',  'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2FFiguras%2FCubo.glb?alt=media&token=05aee70d-47c7-4a06-921b-f7710e6bd29d'},
      {'quechua': 'Chuqu',       'spanish': 'Cono',       'phonetic': 'CHU-qu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCono.jpg?alt=media&token=4961d2cc-7be1-40cc-b329-addfc5ed5c13',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Fchuqu.mp3?alt=media&token=29c75b82-fe49-455f-8701-a20012806b8d',  'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2FFiguras%2FCono.glb?alt=media&token=cd88ccec-ce02-48dd-ab29-246fec768b92'},
      {'quechua': 'Tuquru',      'spanish': 'Cilindro',   'phonetic': 'tu-QU-ru', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFiguras%2FCilindro.jpg?alt=media&token=a72efccd-3f0d-4b93-9112-50ef85efab99',        'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFiguras%2Ftuquru.mp3?alt=media&token=8ab9d284-51a7-45d5-bf5a-318d66db9ed3',  'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2FFiguras%2FCilindro.glb?alt=media&token=426d75fe-bd22-4923-81a5-05b4c660ea51'},
    ];
    for (var word in figurasWords) {
      await db.insert('words', {
        'module_id': 9,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': word['model_3d_path'] ?? '',
      });
    }

    // ─── MÓDULO 10: FRASES / RIMAYKUNA (10 items) ───
    final frasesWords = [
      {'quechua': 'Huk puka tika',           'spanish': 'Una flor roja',          'phonetic': 'huk PU-ka TI-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FHuk%20puka%20tika.jpg?alt=media&token=cd6a56da-73c7-4fa1-bdbb-587b5ed5114b',                  'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fhuk_puka_tika.mp3?alt=media&token=2da8cd57-1097-4c53-ac69-79517b8e4b9f'},
      {'quechua': 'Iskay yana allqu',        'spanish': 'Dos perros negros',          'phonetic': 'IS-kay YA-na ALL-qu','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FIskay%20yana%20allqu.jpg?alt=media&token=5827ce25-0289-4d81-9924-10d7b550ae0f',              'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fiskay_yana_allqu.mp3?alt=media&token=78acc57d-c36a-4df5-8f06-fcc8a1a28cef'},
      {'quechua': 'Taytay hatunmi',          'spanish': 'Mi padre es grande',         'phonetic': 'TAY-tay ha-TUN-mi','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FTaytay%20hatunmi.jpg?alt=media&token=f11bd3e9-20e2-4392-89f7-d4b5daa91c17',                'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Ftaytay_hatunmi.mp3?alt=media&token=52ef3ae4-b0ae-4237-acd0-8b4c72b3ae5f'},
      {'quechua': 'Sutiyqa ___mi',           'spanish': 'Mi nombre es ___',           'phonetic': 'su-TIY-qa ___-mi','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FSutiyqa.jpg?alt=media&token=63db5a2c-0bb4-4c88-ae50-f5c3ce0e63d6',                 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fsutiyqa_mi.mp3?alt=media&token=d39e13ba-0608-48d3-904d-45cdb92a1e3c'},
      {'quechua': 'Maymantan kanki?',        'spanish': '¿De dónde eres?',             'phonetic': 'MAY-man-tan KAN-ki', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FMaymantan%20kanki.jpg?alt=media&token=8f5cdccf-05b8-4b8b-a34e-3f8d30e8bb29',               'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fmaymantan_kanki.mp3?alt=media&token=7ef26716-f57b-47f0-b5d1-2644cdde3642'},
      {'quechua': 'Ñuqap wasiymi',           'spanish': 'Es mi casa',                'phonetic': 'ÑU-qap WA-siy-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2F%C3%91uqap%20wasiymi.jpg?alt=media&token=6fc6fd06-04a6-4ecf-af06-a424e5f126c7',                'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fnuqap_wasiymi.mp3?alt=media&token=187da551-4447-456c-88a7-81afbdd7550c'},
      {'quechua': 'Kimsa yuraq urpi',        'spanish': 'Tres palomas blancas',       'phonetic': 'KIM-sa YU-raq UR-pi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FKimsa%20yuraq%20urpi.jpg?alt=media&token=caaa76bc-2074-4b35-bb4b-9b9a43cd8b9b',             'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fkimsa_yuraq_urpi.mp3?alt=media&token=180bc68f-aecb-4c40-b9eb-1fbe20a5488e'},
      {'quechua': 'Pichqa qillu tika',       'spanish': 'Cinco flores amarillas',     'phonetic': 'PICH-qa QI-llu TI-ka',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FPichqa%20qillu%20tika.jpg?alt=media&token=e3af2b35-859e-4455-b209-a623efbde423',           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fpichqa_qillu_tika.mp3?alt=media&token=61dd9248-b4d3-4a55-aa1f-f0865085c5f1'},
      {'quechua': 'Allqu hatunmi',           'spanish': 'El perro es grande',         'phonetic': 'ALL-qu ha-TUN-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FAllqu%20hatunmi.jpg?alt=media&token=d768b66b-461d-477c-9f36-3102de73bf2e',                 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fallqu_hatunmi.mp3?alt=media&token=f85ada7b-89b2-4ad1-9191-a47ce9f9aa32'},
      {'quechua': 'Yaku sumaqmi',            'spanish': 'El agua es bonita',          'phonetic': 'YA-ku SU-maq-mi',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FFrases%2FYaku%20sumaqmi.jpg?alt=media&token=3478e7ca-eab6-4d4c-a790-ae573dc861f5',                 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FFrases%2Fyaku_sumaqmi.mp3?alt=media&token=0f7d17b3-5718-4e05-b9bd-8138921f5681'},
    ];
    for (var word in frasesWords) {
      await db.insert('words', {
        'module_id': 10,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': '',
      });
    }

    // ─── MÓDULO 11: ORACIONES / RIMARIYKUNA (8 items) ───
    // ⚠️ REQUIEREN VALIDACIÓN por quechuahablante nativo
    final oracionesWords = [
      {'quechua': 'Allquy pukllachkan wasipa patanpi',      'spanish': 'Mi perro está jugando encima de la casa',          'phonetic': 'ALL-quy pu-KLLA-chkan WA-si-pa PA-tan-pi','image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FAllquy%20pukllachkan%20wasipa%20patanpi.jpg?alt=media&token=b22d9bf7-f23c-48aa-8ea2-7fef96748147',           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fallquy_pukllachkan.mp3?alt=media&token=d57237e9-5916-45d1-8c87-7ca0df4808ed'},
      {'quechua': 'Taytay chakranpi llankachkan',            'spanish': 'Mi padre está trabajando en su chacra',            'phonetic': 'TAY-tay CHAK-ran-pi LLAN-ka-chkan', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FTaytay%20chakranpi%20llankachkan.jpg?alt=media&token=c7a04ed5-81c8-4a14-b6b9-ff4f9568c8fb',                  'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Ftaytay_llankachkan.mp3?alt=media&token=943653e3-8913-4867-8e5e-6b292d09bbaf'},
      {'quechua': 'Mamay mikuyta waykuchkan',                'spanish': 'Mi mamá está cocinando la comida',                 'phonetic': 'MA-may mi-KUY-ta WAY-ku-chkan', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FMamay%20mikuyta%20waykuchkan.jpg?alt=media&token=0c188b54-2750-4eff-ae70-ad9459e87ede',                      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fmamay_waykuchkan.mp3?alt=media&token=e5287f2d-34b6-473c-9186-5386db6622e6'},
      {'quechua': 'Kunturqa hanaq pachapi phawachkan',       'spanish': 'El cóndor está volando en el cielo',               'phonetic': 'kun-TUR-qa HA-naq PA-cha-pi PHA-wa-chkan', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKunturqa%20hanaq%20pachapi%20phawachkan.jpg?alt=media&token=d38390f7-7a8e-44a2-86b5-83f8f5b36e57',           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkunturqa_phawachkan.mp3?alt=media&token=153944a0-6dc7-4433-bc5b-ff346570394f'},
      {'quechua': 'Inti lluqsimuchkan urqu patamanta',       'spanish': 'El sol está saliendo desde la cima del cerro',     'phonetic': 'IN-ti LLUQ-si-much-kan UR-qu PA-ta-man-ta', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FInti%20lluqsimuchkan%20urqu%20patamanta.jpg?alt=media&token=6db551b0-f9c8-47e4-872f-2fe3d318a5cf',          'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Finti_lluqsimuchkan.mp3?alt=media&token=784ceef4-d712-4e3d-a498-4eaf4f2512ec'},
      {'quechua': 'Yakuta apamuy wasiyman',                  'spanish': 'Trae agua a mi casa',                              'phonetic': 'YA-ku-ta a-PA-muy WA-siy-man',  'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FYakuta%20apamuy%20wasiyman.jpg?alt=media&token=9da6ef00-1aba-4a1b-aaf1-a04c3edeb66e',                      'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fyakuta_apamuy.mp3?alt=media&token=fa03face-c762-465b-8e0c-707d441e54a2'},
      {'quechua': 'Kay rumiqa hatunmi',                      'spanish': 'Esta piedra es grande',                             'phonetic': 'kay RU-mi-qa ha-TUN-mi',   'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKay%20rumiqa%20hatunmi.jpg?alt=media&token=ff9ce8f4-7008-45e6-9f36-1c5b96202b25',                           'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkay_rumiqa_hatunmi.mp3?alt=media&token=a42a7842-3c5f-4c19-9d7f-8036ff4c0a3d'},
      {'quechua': 'Kimsa yuraq urpi tiyachkan sachapi',      'spanish': 'Tres palomas blancas están posadas en el arbol',    'phonetic': 'KIM-sa YU-raq UR-pi ti-YA-chkan SA-cha-pi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FOraciones%2FKimsa%20yuraq%20urpi%20tiyachkan%20sachapi.jpg?alt=media&token=eadea1d5-e6b0-4ffe-8b0a-db2962168913',         'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FOraciones%2Fkimsa_urpi_sachapi.mp3?alt=media&token=27dad0df-ed40-4cca-8795-2ca9d605d2bb'},
    ];
    for (var word in oracionesWords) {
      await db.insert('words', {
        'module_id': 11,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': '',
      });
    }
  }

  // ================================================================
  // DATOS INICIALES (instalación fresca)
  // ================================================================
  Future<void> _populateInitialData(Database db, {bool onlyWords = false}) async {
    if (!onlyWords) {
      // ─── 12 MÓDULOS con IDs explícitos ───
      await db.insert('modules', {'id': 1, 'name': 'Animales', 'name_quechua': 'Uywakunakuna', 'description': 'Aprende los nombres de animales en Quechua Chanka', 'icon': 'pets', 'order_index': 3});
      await db.insert('modules', {'id': 2, 'name': 'Naturaleza', 'name_quechua': 'Pachamama', 'description': 'Descubre elementos de la naturaleza', 'icon': 'park', 'order_index': 4});
      await db.insert('modules', {'id': 3, 'name': 'Familia y Cultura', 'name_quechua': 'Ayllu', 'description': 'Conoce sobre familia y objetos culturales', 'icon': 'family_restroom', 'order_index': 5});
      await db.insert('modules', {'id': 4, 'name': 'Números', 'name_quechua': 'Yupay', 'description': 'Aprende a contar en Quechua Chanka', 'icon': 'pin', 'order_index': 1});
      await db.insert('modules', {'id': 5, 'name': 'Saludos y Cortesia', 'name_quechua': 'Napaykuy', 'description': 'Expresiones basicas de saludo y cortesia', 'icon': 'waving_hand', 'order_index': 2});
      await db.insert('modules', {'id': 6, 'name': 'Colores', 'name_quechua': 'Llimpikuna', 'description': 'Aprende los colores en Quechua Chanka', 'icon': 'palette', 'order_index': 6});
      await db.insert('modules', {'id': 7, 'name': 'Vocales', 'name_quechua': 'Uyariykuna', 'description': 'Las 3 vocales y reglas foneticas del Quechua Chanka', 'icon': 'record_voice_over', 'order_index': 7});
      await db.insert('modules', {'id': 8, 'name': 'Alfabeto', 'name_quechua': 'Achahala', 'description': 'Las 18 letras del alfabeto Quechua Chanka', 'icon': 'abc', 'order_index': 8});
      await db.insert('modules', {'id': 9, 'name': 'Figuras', 'name_quechua': "Siq'ikuna", 'description': 'Figuras geometricas 2D y 3D en Quechua', 'icon': 'category', 'order_index': 9});
      await db.insert('modules', {'id': 10, 'name': 'Frases', 'name_quechua': 'Rimaykuna', 'description': 'Frases cotidianas combinando vocabulario', 'icon': 'chat_bubble', 'order_index': 10});
      await db.insert('modules', {'id': 11, 'name': 'Oraciones', 'name_quechua': 'Rimariykuna', 'description': 'Oraciones completas en Quechua Chanka', 'icon': 'menu_book', 'order_index': 11});
      await db.insert('modules', {'id': 12, 'name': 'Gramática', 'name_quechua': 'Simikuna Kamachiy', 'description': 'Sufijos esenciales del Quechua Chanka', 'icon': 'rule', 'order_index': 12});
    }

    // ==========================================
    // MÓDULO 1: ANIMALES (Quechua Chanka)
    // ==========================================
    final animalesWords = [
      {'quechua': 'Allqu', 'spanish': 'Perro', 'phonetic': 'ALL-qu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPerro.jpg?alt=media&token=d8157b5d-93f9-44d0-a33b-da0a1becff3c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Falqo.mp3?alt=media&token=3a47b687-0fc6-4b6b-b705-cd3e904d2d20', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fallqu.glb?alt=media&token=dc6ca802-5b9b-42ac-a216-93d1c83d281e'},
      {'quechua': 'Michi', 'spanish': 'Gato', 'phonetic': 'MI-chi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGato.jpg?alt=media&token=05850973-8bf0-4fe7-954f-9332feddac57', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fmichi.mp3?alt=media&token=b56617be-49da-471c-98b7-73e926d40a4d', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fmichi.glb?alt=media&token=8f6b90d9-08f0-4d1b-b570-523d42a547d4'},
      {'quechua': 'Pisqu', 'spanish': 'Pájaro', 'phonetic': 'PIS-qu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FPajaro.jpg?alt=media&token=bb473960-9604-413d-8993-8732fd421344', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpisqo.mp3?alt=media&token=89ac0dfb-b8c9-4d3b-83c0-d023f65512c8', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpisqu.glb?alt=media&token=dbb370b1-fd42-415c-aea7-1db952c6c366'},
      {'quechua': 'Kawallu', 'spanish': 'Caballo', 'phonetic': 'ka-WA-llu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FCaballo.jpg?alt=media&token=679f66d1-5c28-4cda-ba8d-e0390bf74d94', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkawallu.mp3?alt=media&token=0bb50ad2-62a8-4469-abfd-77399b1fce65', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkawallux.glb?alt=media&token=d5ee9747-1c60-4704-957a-8fd1ab590429'},
      {'quechua': 'Llama', 'spanish': 'Llama', 'phonetic': 'LLA-ma', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FLlama.jpg?alt=media&token=6c7d9b5d-e795-47e7-a334-88764f5854bc', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fllama.mp3?alt=media&token=ee24386f-8a31-4584-872d-1e4924962b0f', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fllama.glb?alt=media&token=d987879e-1318-42f5-ac74-d35be5b630a1'},
      {'quechua': 'Paqocha', 'spanish': 'Alpaca', 'phonetic': 'pa-QO-cha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FAlpaca.jpg?alt=media&token=93040399-2380-4eeb-955d-53ee1b76f520', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fpaqocha.mp3?alt=media&token=954e3f29-7ea0-4c89-bb58-255e7f39bcca', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fpaqocha.glb?alt=media&token=f44f2c31-ef44-4876-89f6-7bf2c7fac95a'},
      {'quechua': 'Kuntur', 'spanish': 'Cóndor', 'phonetic': 'KUN-tur', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FC%C3%B3ndor.jpg?alt=media&token=9fd31aa7-b3a9-415f-a333-bc938c1efb2b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fkuntur.mp3?alt=media&token=bf8495ff-1f8c-44d6-b3aa-6a01e2290e6b', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fkuntur.glb?alt=media&token=89d97e06-133e-4546-be1f-5c48a9b9bbce'},
      {'quechua': 'Uwiha', 'spanish': 'Oveja', 'phonetic': 'u-WI-ha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FOveja.jpg?alt=media&token=4d47b09f-f9b5-4b0c-82bb-51450ce016b5', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fuwiha.mp3?alt=media&token=1d342230-e64c-4a1b-a101-55870bae637f', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fuwiha.glb?alt=media&token=3fa51c64-26df-4c8c-b768-1f4d98869083'},
      {'quechua': 'Waka', 'spanish': 'Vaca', 'phonetic': 'WA-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FVaca.jpg?alt=media&token=481ad086-6b39-4672-b1b2-f5a10b96e5f9', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwaka.mp3?alt=media&token=b253f4ec-818c-44de-91d4-7aada89a17ea', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwaka.glb?alt=media&token=68024947-25de-41e5-9dac-1a3c00693518'},
      {'quechua': 'Wallpa', 'spanish': 'Gallina', 'phonetic': 'WALL-pa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fanimales%2FGallina.jpg?alt=media&token=89015038-a6b2-4147-9890-113600eb4d35', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fanimales%2Fwallpa.mp3?alt=media&token=800d2faf-1101-4a9a-b4ff-8c538eb931e6', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fanimales%2Fwallpa.glb?alt=media&token=3e99f380-8d00-473a-bc8d-3d123b57adf7'},
    ];
    for (var word in animalesWords) {
      await db.insert('words', {'module_id': 1, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': word['model_3d_path']});
    }

    // ==========================================
    // MÓDULO 2: NATURALEZA (Quechua Chanka)
    // ==========================================
    final naturalezaWords = [
      {'quechua': 'Inti', 'spanish': 'Sol', 'phonetic': 'IN-ti', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FSol.jpg?alt=media&token=5c211b42-d40c-4735-bbf5-276f7de41af5', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Finti.mp3?alt=media&token=443566a4-5b84-4f3b-a589-293148e0d7ae', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Finti.glb?alt=media&token=31652247-040f-4f66-a2bd-8e64b7ed2626'},
      {'quechua': 'Killa', 'spanish': 'Luna', 'phonetic': 'KI-lla', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FLuna.jpg?alt=media&token=162d37ea-ad8c-4e74-92b3-f60cae76639b', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fkilla.mp3?alt=media&token=04ac3569-e318-4f15-9223-981994fa9762', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fkilla.glb?alt=media&token=460ec4f0-b1d3-4623-a927-b5e1555b726f'},
      {'quechua': 'Urqu', 'spanish': 'Montaña', 'phonetic': 'UR-qu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FMonta%C3%B1a.jpg?alt=media&token=903d47f0-de4d-4dfb-870a-e9acee4409cf', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Furqu.mp3?alt=media&token=8b3d1c90-6763-4276-9cf9-8549805d7d29', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Furqu.glb?alt=media&token=426d4b1f-7e75-4912-a597-a825653c44bd'},
      {'quechua': 'Yaku', 'spanish': 'Agua', 'phonetic': 'YA-ku', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FAgua.jpg?alt=media&token=9fe52f30-adea-4606-afb7-b7cd15374299', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fyaku.mp3?alt=media&token=abc4d7c5-29ca-4284-9ca4-f4ea20469f1e', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fyaku.glb?alt=media&token=bf32f02b-96d1-4fc6-b2a5-af6ff6430116'},
      {'quechua': 'Sacha', 'spanish': 'Árbol', 'phonetic': 'SA-cha', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2F%C3%81rbol.jpg?alt=media&token=d46ee95e-3881-4714-84b0-b2b37a6e6398', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fsacha.mp3?alt=media&token=ab1b353c-0f12-4d01-bc9f-33cdb7a2fd8d', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fsacha.glb?alt=media&token=139b75d8-30a3-4d60-977d-dce4e2923ae7'},
      {'quechua': 'Tika', 'spanish': 'Flor', 'phonetic': 'TI-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFlor.jpg?alt=media&token=49b200e8-0833-498c-9c4d-fdf710401f85', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Ftika.mp3?alt=media&token=463c11cb-e46a-40ec-a157-842501495ce9', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Ftika.glb?alt=media&token=787ae11f-7986-469e-9c1f-d7d80bcc7cad'},
      {'quechua': 'Wayra', 'spanish': 'Viento', 'phonetic': 'WAY-ra', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FViento.jpg?alt=media&token=926fcfc7-906e-40cc-be17-30c49b4d95da', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fwayra.mp3?alt=media&token=b1efe051-cc3f-4534-86ce-4288ee343439', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fwayra.glb?alt=media&token=30498f1a-f4ed-45d9-af6d-67e466e4de1e'},
      {'quechua': 'Nina', 'spanish': 'Fuego', 'phonetic': 'NI-na', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FFuego.jpg?alt=media&token=328d11e9-2016-4aea-8eed-6f6d93481e1c', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fnina.mp3?alt=media&token=65747862-1f05-4885-9cf4-d71cfb651021', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fnina.glb?alt=media&token=25bc752d-eb0e-4c89-9aa9-161689fc2078'},
      {'quechua': 'Rumi', 'spanish': 'Piedra', 'phonetic': 'RU-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FPiedra.jpg?alt=media&token=15a202ec-e461-4b6b-aa6f-dd99f6fb4e40', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Frumi.mp3?alt=media&token=38f71841-b5b0-466e-8932-f0c2c42334a1', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Frumi.glb?alt=media&token=ff1fd739-8b1b-4800-b672-e951d1f44ee5'},
      {'quechua': 'Allpa', 'spanish': 'Tierra', 'phonetic': 'ALL-pa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2Fnaturaleza%2FTierra.jpg?alt=media&token=6cb0eab2-17c4-4ac7-9807-28df444dc5af', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2Fnaturaleza%2Fallpa.mp3?alt=media&token=a21650fe-f73e-404a-b503-f4a22893c4cc', 'model_3d_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/models%2Fnaturaleza%2Fallpa.glb?alt=media&token=30817295-8380-4c74-ac52-67ba10cb7a76'},
    ];
    for (var word in naturalezaWords) {
      await db.insert('words', {'module_id': 2, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': word['model_3d_path']});
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
      await db.insert('words', {'module_id': 3, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': word['model_3d_path']});
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
      await db.insert('words', {'module_id': 4, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': ''});
    }

    // ==========================================
    // MÓDULO 5: SALUDOS Y CORTESÍA (sin modelo 3D)
    // ==========================================
    final saludosWords = [
      {'quechua': 'Allin punchaw', 'spanish': 'Buenos días', 'phonetic': 'a-LLIN PUN-chaw', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20punchaw.jpg?alt=media&token=a565ad07-fbaa-439c-a0d3-0c45c084b35d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_punchaw.mp3?alt=media&token=e679fd0c-cfb9-4ad2-9a5a-e5cee4fbbefa'},
      {'quechua': 'Allin chisi', 'spanish': 'Buenas tardes', 'phonetic': 'a-LLIN CHI-si', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20chisi.jpg?alt=media&token=b419b01d-9ad8-4354-860b-f1f7e9a3898d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_chisi.mp3?alt=media&token=bc0d1cef-8680-4313-8685-2543e4899fcc'},
      {'quechua': 'Allin tuta', 'spanish': 'Buenas noches', 'phonetic': 'a-LLIN TU-ta', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllin%20tuta.jpg?alt=media&token=b6e9b9af-4f01-460b-93f0-d33878e83a24', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallin_tuta.mp3?alt=media&token=83b434e7-7808-41b9-9aa8-e5269d13c4c0'},
      {'quechua': 'Imaynalla kachkanki', 'spanish': '¿Cómo estás?', 'phonetic': 'i-MAY-na-lla kach-KAN-ki', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FImaynalla%20kachkanki.jpg?alt=media&token=dd52bb11-3306-4087-bdbd-89eecc284f49', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fimaynalla_kachkanki.mp3?alt=media&token=1f26ad2e-5498-4dc9-ad6e-a0de30ac3bd4'},
      {'quechua': 'Allillanmi', 'spanish': 'Estoy bien', 'phonetic': 'a-LLI-llan-mi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAllillanmi.jpg?alt=media&token=b33062ac-cf6b-4f36-bc43-bbe2e98b3744', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fallillanmi.mp3?alt=media&token=9f10b582-ca49-4ab2-859d-face034a043e'},
      {'quechua': 'Añay', 'spanish': 'Gracias', 'phonetic': 'a-ÑAY', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FA%C3%B1ay.jpg?alt=media&token=1856a873-282e-4ab4-afcd-11d38f0f5dcc', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fa%C3%B1ay.mp3?alt=media&token=ff263cf8-d220-4cdd-93c0-e5daf9c81a4a'},
      {'quechua': 'Ama hina kaychu', 'spanish': 'Por favor', 'phonetic': 'A-ma HI-na KAY-chu', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FAma%20hina%20kaychu.jpg?alt=media&token=5fa3acb4-397b-40d0-84e0-1bfabbdd3161', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fama_hina_kaychu.mp3?alt=media&token=b8baf611-e87e-4a91-a7d1-de9c5cb1ee4d'},
      {'quechua': 'Tupananchiskama', 'spanish': 'Hasta luego', 'phonetic': 'tu-pa-NAN-chis-KA-ma', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FTupananchiskama.jpg?alt=media&token=e099f6b5-236c-4d85-80c2-3b86305de312', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Ftupananchiskama.mp3?alt=media&token=c0a4eb40-889a-427a-a0bf-46fef5d0d49d'},
      {'quechua': 'Paqarinkama', 'spanish': 'Hasta mañana', 'phonetic': 'pa-qa-RIN-ka-ma', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FPaqarinkama.jpg?alt=media&token=f06e9466-19bc-4fbc-af29-3616b26f5a1e', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fpaqarinkama.mp3?alt=media&token=51f1e9a3-4b96-4017-813a-859dd11926ec'},
      {'quechua': 'Imataq sutiyki', 'spanish': '¿Cómo te llamas?', 'phonetic': 'i-MA-taq su-TIY-ki', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FSaludos%20y%20Cortes%C3%ADa%2FImataq%20sutiyki.jpg?alt=media&token=27912077-a9b1-4e52-9af8-16a4a53e5c5a', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FSaludos%2Fimataq_sutiyki.mp3?alt=media&token=5c0efecd-bda6-4390-bc8a-375c848fcaf4'},
    ];
    for (var word in saludosWords) {
      await db.insert('words', {'module_id': 5, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': ''});
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
      {'quechua': 'Chumpi', 'spanish': 'Marrón', 'phonetic': 'CHUM-pi', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FChumpi.jpg?alt=media&token=260dc6b1-b9a8-4cd8-82b9-6f6de19175c4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fchumpi.mp3?alt=media&token=bccf595a-e652-4786-8784-c02b106b19e2'},
      {'quechua': 'Qillu puka', 'spanish': 'Naranja', 'phonetic': 'QI-llu PU-ka', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FQillu%20puka.jpg?alt=media&token=7cecaaad-db73-4e63-9cf0-c506a5a1d1a4', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fqillu_puka.mp3?alt=media&token=55ca4b1f-c13c-4f51-b49c-6db2879397e6'},
      {'quechua': 'Kulli', 'spanish': 'Morado', 'phonetic': 'KU-lli', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FColores%2FKulli.jpg?alt=media&token=09fa3c9c-f5d8-4998-954a-a678c94bae78', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FColores%2Fkulli.mp3?alt=media&token=8f4c9cf7-6742-47f8-9774-e2f8803b712a'},
    ];
    for (var word in coloresWords) {
      await db.insert('words', {'module_id': 6, 'word_quechua': word['quechua'], 'word_spanish': word['spanish'], 'phonetic': word['phonetic'], 'image_path': word['image_path'], 'audio_path': word['audio_path'], 'model_3d_path': ''});
    }

    // ==========================================
    // MÓDULOS 7-11: NUEVOS (v18) — URLs corregidas en v20
    // ==========================================
    await _populateNewModulesV18(db);

    // ==========================================
    // MÓDULO 12: GRAMÁTICA (v19)
    // ==========================================
    await _populateGrammarModule(db);
  }

  // ================================================================
  // DATOS v19: Módulo 12 — Gramática / Sufijos esenciales
  // Fuentes: aprenderde.com (Quechua Chanka), Simi Qullqa (MINEDU)
  // ================================================================
  Future<void> _populateGrammarModule(Database db) async {
    final gramaticaWords = [
      {'quechua': '-mi / -m', 'spanish': 'Validador (certeza)', 'phonetic': 'Hatunmi = Es grande (estoy seguro)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fmi.jpg?alt=media&token=7ace39de-4f47-4f25-b161-b3c19c8b766d', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fmi_validador.mp3?alt=media&token=956177ac-2847-46d5-bc25-5fc932bd6fc4'},
      {'quechua': '-qa', 'spanish': 'Topicalizador (tema)', 'phonetic': 'Kunturqa = El cóndor (en cuanto a)', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fqa.jpg?alt=media&token=12ae57ff-03d2-4e93-bbbe-6938f44408f1', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fqa_topicalizador.mp3?alt=media&token=c4c0184f-32a1-4811-accd-20ca4eccb505'},
      {'quechua': '-kuna', 'spanish': 'Plural', 'phonetic': 'Wasikuna = Casas', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fkuna.jpg?alt=media&token=451a8662-ec92-49d8-876c-3bb05772dcda', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fkuna_plural.mp3?alt=media&token=023d5809-aa78-4658-946c-d4f95752271c'},
      {'quechua': '-y / -yki / -n', 'spanish': 'Posesivo (mi/tu/su)', 'phonetic': 'Wasiy=mi casa, Wasiyki=tu casa, Wasin=su casa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fy.jpg?alt=media&token=f9104451-b306-4d93-88ef-1f087a6c4264', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fposesivos.mp3?alt=media&token=7381f7a6-d5b1-4505-bbb0-9e21f39c5734'},
      {'quechua': '-ta', 'spanish': 'Objeto directo (a, al)', 'phonetic': 'Yakuta upyani = Bebo agua', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fta.jpg?alt=media&token=9ccf3647-5b53-461b-a0e9-3497f8b58e85', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fta_objeto.mp3?alt=media&token=2377fcf8-45a2-4f1c-bc6a-608912b9b260'},
      {'quechua': '-pi', 'spanish': 'Locativo (en)', 'phonetic': 'Wasipi = En la casa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fpi.jpg?alt=media&token=b8b73a1c-a902-4c89-9da2-612098bf1ef1', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fpi_locativo.mp3?alt=media&token=dee674e1-b1d8-4469-bb23-17aee1e2c764'},
      {'quechua': '-manta', 'spanish': 'Origen (de, desde)', 'phonetic': 'Limamanta = De Lima / Desde Lima', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fmanta.jpg?alt=media&token=63d2f2f1-43a5-4823-8e16-4a27a8263885', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fmanta_origen.mp3?alt=media&token=b8c3e803-43e9-4118-9149-e260de1f3b24'},
      {'quechua': '-man', 'spanish': 'Dirección (hacia, a)', 'phonetic': 'Wasiman = Hacia la casa', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fman.jpg?alt=media&token=f29eadd3-abd0-4369-af32-d64b471b5546', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fman_direccion.mp3?alt=media&token=c2701b97-1ed5-44b0-92fc-02d0ada3a31b'},
      {'quechua': '-wan', 'spanish': 'Compañía (con)', 'phonetic': 'Mamaywan = Con mi mamá', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fwan.jpg?alt=media&token=3d4839f7-fe3c-4a6c-9b4c-4564de6e7b79', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fwan_compania.mp3?alt=media&token=5a0cc073-a4f1-40cb-938f-9d34858fdafb'},
      {'quechua': '-chkan', 'spanish': 'Progresivo (está haciendo)', 'phonetic': 'Mikuchkan = Está comiendo', 'image_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/images%2FGramatica%2Fchkan.jpg?alt=media&token=49edefb9-e6fd-446e-a5a9-db8beeadb3ed', 'audio_path': 'https://firebasestorage.googleapis.com/v0/b/ra-quechua-app.firebasestorage.app/o/audio%2FGramatica%2Fchkan_progresivo.mp3?alt=media&token=d85cc1ec-6216-4f6c-b658-30fdfb285e7b'},
    ];
    for (var word in gramaticaWords) {
      await db.insert('words', {
        'module_id': 12,
        'word_quechua': word['quechua'],
        'word_spanish': word['spanish'],
        'phonetic': word['phonetic'],
        'image_path': word['image_path'] ?? '',
        'audio_path': word['audio_path'] ?? '',
        'model_3d_path': '',
      });
    }
  }

  // ================================================================
  // CRUD DE DATOS
  // ================================================================

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

  /// Devuelve el total de palabras en un módulo
  Future<int> getTotalWordsInModule(int moduleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE module_id = ?',
      [moduleId],
    );
    return result.first['count'] as int;
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