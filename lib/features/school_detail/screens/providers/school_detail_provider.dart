import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

final schoolDetailProvider =
    FutureProvider.family<School?, String>((ref, schoolId) async {
  final data = await supabase.from('schools').select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''').eq('id', schoolId).maybeSingle();
  if (data == null) return null;
  return School.fromJson(data);
});
