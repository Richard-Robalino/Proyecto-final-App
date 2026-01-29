import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart'; // Asegúrate de actualizar este archivo con el listener

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar localizaciones de fecha
  await initializeDateFormatting('es', null);

  // Cargar variables de entorno
  await dotenv.load(fileName: "assets/.env");

  await Supabase.initialize(
    url: dotenv.env["SUPABASE_URL"] ?? "",
    anonKey: dotenv.env["SUPABASE_ANON_KEY"] ?? "",
  );

  runApp(const ProviderScope(child: TecniGoApp()));
}