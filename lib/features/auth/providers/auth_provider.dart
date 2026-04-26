import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/supabase/supabase_client.dart';
import '/core/models/models.dart';

// ─── AUTH STATE ───────────────────────────────────────────────────────────────

class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;
  UserRole get role => profile?.role ?? UserRole.user;

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        user: user ?? this.user,
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── AUTH NOTIFIER ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      _loadProfile(session.user);
    } else {
      state = const AuthState();
    }

    supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _loadProfile(user);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadProfile(User user) async {
    try {
      final data = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        state = AuthState(
          user: user,
          profile: UserProfile.fromJson(data),
        );
      } else {
        // Profilo non ancora creato
        state = AuthState(user: user);
      }
    } catch (e) {
      state = AuthState(user: user, error: e.toString());
    }
  }

  // ─── SIGN IN ──────────────────────────────────────────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('LOGIN OK: ${res.user?.email}'); // aggiungi questo
    } on AuthException catch (e) {
      print('LOGIN ERROR: ${e.message}'); // aggiungi questo
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      print('LOGIN GENERIC ERROR: $e'); // aggiungi questo
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ─── SIGN UP UTENTE ───────────────────────────────────────────────────────

  Future<void> signUpUser({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'user', 'full_name': fullName},
      );

      if (res.user != null) {
        await supabase.from('user_profiles').insert({
          'id': res.user!.id,
          'full_name': fullName,
          'role': 'user',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ─── SIGN UP SCUOLA ───────────────────────────────────────────────────────

  Future<void> signUpSchool({
    required String email,
    required String password,
    required String schoolName,
    required String schoolType,
    required String municipalityId,
    String? address,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'school', 'full_name': schoolName},
      );

      if (res.user != null) {
        // Crea profilo utente con ruolo school
        await supabase.from('user_profiles').insert({
          'id': res.user!.id,
          'full_name': schoolName,
          'role': 'school',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Crea record scuola
        await supabase.from('schools').insert({
          'user_id': res.user!.id,
          'name': schoolName,
          'school_type': schoolType,
          'municipality_id': municipalityId,
          'address': address,
          'phone': phone,
          'is_approved': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = const AuthState();
  }
}

// ─── PROVIDERS ───────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).isAuthenticated,
);

final currentUserRoleProvider = Provider<UserRole>(
  (ref) => ref.watch(authProvider).role,
);

final currentProfileProvider = Provider<UserProfile?>(
  (ref) => ref.watch(authProvider).profile,
);
