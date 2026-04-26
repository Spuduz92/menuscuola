import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';

// ─── SCUOLE IN ATTESA ─────────────────────────────────────────────────────────

final pendingSchoolsProvider = FutureProvider<List<School>>((ref) async {
  final data = await supabase.from('schools').select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''').eq('is_approved', false).order('created_at', ascending: true);

  return (data as List).map((e) => School.fromJson(e)).toList();
});

// ─── TUTTE LE SCUOLE ──────────────────────────────────────────────────────────

final allSchoolsProvider = FutureProvider<List<School>>((ref) async {
  final data = await supabase.from('schools').select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''').order('created_at', ascending: false);

  return (data as List).map((e) => School.fromJson(e)).toList();
});

// ─── ADMIN ACTIONS ────────────────────────────────────────────────────────────

class AdminNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> approveSchool(String schoolId) async {
    await supabase
        .from('schools')
        .update({'is_approved': true}).eq('id', schoolId);

    ref.invalidate(pendingSchoolsProvider);
    ref.invalidate(allSchoolsProvider);
  }

  Future<void> rejectSchool(String schoolId) async {
    await supabase.from('schools').delete().eq('id', schoolId);

    ref.invalidate(pendingSchoolsProvider);
    ref.invalidate(allSchoolsProvider);
  }

  Future<void> revokeSchool(String schoolId) async {
    await supabase
        .from('schools')
        .update({'is_approved': false}).eq('id', schoolId);

    ref.invalidate(pendingSchoolsProvider);
    ref.invalidate(allSchoolsProvider);
  }
}

final adminProvider = AsyncNotifierProvider<AdminNotifier, void>(
  AdminNotifier.new,
);
