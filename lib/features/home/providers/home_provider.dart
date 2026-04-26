import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';

// ─── FAVORITES ────────────────────────────────────────────────────────────────

class FavoritesNotifier extends AsyncNotifier<List<School>> {
  @override
  Future<List<School>> build() => _fetchFavorites();

  Future<List<School>> _fetchFavorites() async {
    final user = ref.read(authProvider).user;
    if (user == null) return [];

    final data = await supabase
        .from('user_favorites')
        .select('''
          schools (
            *,
            municipalities (
              name,
              provinces (
                name,
                regions ( name )
              )
            )
          )
        ''')
        .eq('user_id', user.id);

    return (data as List)
        .map((e) => School.fromJson(e['schools'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleFavorite(String schoolId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final current = state.valueOrNull ?? [];
    final isFav = current.any((s) => s.id == schoolId);

    if (isFav) {
      await supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('school_id', schoolId);
    } else {
      await supabase.from('user_favorites').insert({
        'user_id': user.id,
        'school_id': schoolId,
      });
    }

    ref.invalidateSelf();
  }

  bool isFavorite(String schoolId) {
    return state.valueOrNull?.any((s) => s.id == schoolId) ?? false;
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<School>>(
  FavoritesNotifier.new,
);

// ─── SCHOOL MENU ─────────────────────────────────────────────────────────────

final schoolMenuProvider = FutureProvider.family<SchoolMenu?, String>((ref, schoolId) async {
  final today = DateTime.now();
  final data = await supabase
      .from('menus')
      .select('''
        *,
        menu_days (
          *,
          menu_courses ( * )
        )
      ''')
      .eq('school_id', schoolId)
      .eq('is_active', true)
      .lte('start_date', today.toIso8601String().substring(0, 10))
      .gte('end_date', today.toIso8601String().substring(0, 10))
      .maybeSingle();

  if (data == null) return null;
  return SchoolMenu.fromJson(data);
});

// ─── TODAY MENU PER SCUOLA PREFERITA ─────────────────────────────────────────

final todayMenuForSchoolProvider = FutureProvider.family<MenuDay?, String>((ref, schoolId) async {
  final menu = await ref.watch(schoolMenuProvider(schoolId).future);
  return menu?.todayMenu;
});
