import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> testFirebaseConnection() async {
  try {
    // 1. Inicializar Firebase
    await Firebase.initializeApp();
    print('✅ Firebase inicializado correctamente');

    // 2. Obtener referencia a Storage
    final storage = FirebaseStorage.instance;
    print('✅ Firebase Storage conectado');

    // 3. Obtener referencia al bucket
    final bucket = storage.ref();
    print('✅ Bucket: ${bucket.bucket}');

    // 4. Listar carpetas (debería mostrar audio/, images/, models/)
    final result = await bucket.listAll();
    print('✅ Carpetas encontradas: ${result.prefixes.length}');
    for (var prefix in result.prefixes) {
      print('   📁 ${prefix.name}');
    }

    print('🎉 ¡Firebase Storage funcionando correctamente!');
  } catch (e) {
    print('❌ Error al conectar con Firebase: $e');
  }
}