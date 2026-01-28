import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import '../data/repositories/supabase_repo.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  return AppState(ref.read(supabaseClientProvider));
});

final supabaseRepoProvider = Provider<SupabaseRepo>((ref) {
  return SupabaseRepo(ref.read(supabaseClientProvider));
});
