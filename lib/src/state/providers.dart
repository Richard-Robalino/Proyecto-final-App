import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import '../data/repositories/supabase_repo.dart';

// Asegúrate de que estos providers estén definidos:
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseRepoProvider = Provider<SupabaseRepo>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseRepo(client);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((data) => data.session?.user);
});

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  return AppState(ref.read(supabaseClientProvider));
});


final technicianStatusProvider = FutureProvider.autoDispose<String>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.getCurrentTechnicianStatus();
});
