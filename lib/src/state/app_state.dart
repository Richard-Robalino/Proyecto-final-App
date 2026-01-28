import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { client, technician, admin }

UserRole? roleFromString(String? value) {
  if (value == null) return null;
  return UserRole.values.where((e) => e.name == value).cast<UserRole?>().first;
}

class AppState extends ChangeNotifier {
  AppState(this.supabase) {
    _session = supabase.auth.currentSession;
    _bindAuthListener();
    _loadProfile();
  }

  final SupabaseClient supabase;

  Session? _session;
  StreamSubscription<AuthState>? _authSub;

  bool _loading = false;
  String? _fullName;
  UserRole? _role;

  // Solo para técnicos
  String? _verificationStatus; // pending/approved/rejected

  Session? get session => _session;
  bool get isLoggedIn => _session != null;

  bool get loading => _loading;

  String? get fullName => _fullName;
  UserRole? get role => _role;
  String? get verificationStatus => _verificationStatus;

  String? get userId => _session?.user.id;

  void _bindAuthListener() {
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      _fullName = null;
      _role = null;
      _verificationStatus = null;
      notifyListeners();
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    if (_session == null) return;
    _loading = true;
    notifyListeners();

    try {
      final uid = _session!.user.id;
      final profile =
          await supabase.from('profiles').select('full_name, role').eq('id', uid).single();

      _fullName = (profile['full_name'] as String?)?.trim();
      _role = roleFromString(profile['role'] as String?);

      if (_role == UserRole.technician) {
        final tech = await supabase
            .from('technician_profiles')
            .select('verification_status')
            .eq('id', uid)
            .single();
        _verificationStatus = tech['verification_status'] as String?;
      }
    } catch (_) {
      // Si falla, igual dejamos navegar. En demo suele ser por RLS o falta de data.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
