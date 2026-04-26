import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../home/providers/home_provider.dart';

// ─── SEARCH PROVIDERS ─────────────────────────────────────────────────────────

final regionsProvider = FutureProvider<List<Region>>((ref) async {
  final data =
      await supabase.from('regions').select().order('name', ascending: true);
  return (data as List).map((e) => Region.fromJson(e)).toList();
});

final provincesProvider =
    FutureProvider.family<List<Province>, String>((ref, regionId) async {
  final data = await supabase
      .from('provinces')
      .select()
      .eq('region_id', regionId)
      .order('name', ascending: true);
  return (data as List).map((e) => Province.fromJson(e)).toList();
});

final municipalitiesProvider =
    FutureProvider.family<List<Municipality>, String>((ref, provinceId) async {
  final data = await supabase
      .from('municipalities')
      .select()
      .eq('province_id', provinceId)
      .order('name', ascending: true);
  return (data as List).map((e) => Municipality.fromJson(e)).toList();
});

final schoolsSearchProvider =
    FutureProvider.family<List<School>, String>((ref, municipalityId) async {
  final data = await supabase
      .from('schools')
      .select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''')
      .eq('municipality_id', municipalityId)
      .eq('is_approved', true)
      .order('name', ascending: true);
  return (data as List).map((e) => School.fromJson(e)).toList();
});

final schoolNameSearchProvider =
    FutureProvider.family<List<School>, String>((ref, query) async {
  if (query.length < 2) return [];
  final data = await supabase
      .from('schools')
      .select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''')
      .ilike('name', '%$query%')
      .eq('is_approved', true)
      .limit(20)
      .order('name', ascending: true);
  return (data as List).map((e) => School.fromJson(e)).toList();
});

// ─── SEARCH SCREEN ────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Region? _selectedRegion;
  Province? _selectedProvince;
  Municipality? _selectedMunicipality;

  bool get _isGeographicSearch => _searchQuery.isEmpty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cerca', style: Theme.of(context).textTheme.displaySmall)
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 4),
                  Text(
                    'Per nome o per zona geografica',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 20),

                  // Search field
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cerca per nome scuola…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.muted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.muted),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                ],
              ),
            ),

            if (_isGeographicSearch) ...[
              // Geographic filters
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.filter_list_rounded,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          'Filtra per zona',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGeoFilters(),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _isGeographicSearch
                  ? _buildGeographicResults()
                  : _buildNameResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoFilters() {
    final regionsAsync = ref.watch(regionsProvider);

    return Column(
      children: [
        // Regione
        regionsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Errore: $e'),
          data: (regions) => _FilterDropdown<Region>(
            label: 'Regione',
            value: _selectedRegion,
            items: regions,
            itemLabel: (r) => r.name,
            onChanged: (r) => setState(() {
              _selectedRegion = r;
              _selectedProvince = null;
              _selectedMunicipality = null;
            }),
          ),
        ),

        if (_selectedRegion != null) ...[
          const SizedBox(height: 10),
          ref.watch(provincesProvider(_selectedRegion!.id)).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore: $e'),
                data: (provinces) => InkWell(
                  onTap: () async {
                    final provinces = await ref.read(
                      provincesProvider(_selectedRegion!.id).future,
                    );

                    final result = await showSearchPicker<Province>(
                      context: context,
                      title: 'Seleziona provincia',
                      items: provinces,
                      label: (p) => p.name,
                    );

                    if (result != null) {
                      setState(() {
                        _selectedProvince = result;
                        _selectedMunicipality = null;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Provincia'),
                    child:
                        Text(_selectedProvince?.name ?? 'Seleziona provincia'),
                  ),
                ),
              ),
        ],

        if (_selectedProvince != null) ...[
          const SizedBox(height: 10),
          ref.watch(municipalitiesProvider(_selectedProvince!.id)).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore: $e'),
                data: (municipalities) => InkWell(
                  onTap: () async {
                    final municipalities = await ref.read(
                      municipalitiesProvider(_selectedProvince!.id).future,
                    );

                    final result = await showSearchPicker<Municipality>(
                      context: context,
                      title: 'Seleziona comune',
                      items: municipalities,
                      label: (m) => m.name,
                    );

                    if (result != null) {
                      setState(() => _selectedMunicipality = result);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Comune'),
                    child:
                        Text(_selectedMunicipality?.name ?? 'Seleziona comune'),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildGeographicResults() {
    if (_selectedMunicipality == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗺', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Seleziona una zona\nper vedere le scuole',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ref.watch(schoolsSearchProvider(_selectedMunicipality!.id)).when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest)),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (schools) => _buildSchoolList(schools),
        );
  }

  Widget _buildNameResults() {
    if (_searchQuery.length < 2) {
      return Center(
        child: Text(
          'Digita almeno 2 caratteri',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
      );
    }

    return ref.watch(schoolNameSearchProvider(_searchQuery)).when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest)),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (schools) => _buildSchoolList(schools),
        );
  }

  Widget _buildSchoolList(List<School> schools) {
    if (schools.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏫', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Nessuna scuola trovata',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'La tua scuola non è ancora registrata.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: schools.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final school = schools[i];
        final favoritesAsync = ref.watch(favoritesProvider);
        final isFav =
            favoritesAsync.valueOrNull?.any((s) => s.id == school.id) ?? false;

        return GestureDetector(
          onTap: () => context.push('/school/${school.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.sageLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(school.schoolType.emoji,
                        style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        school.fullLocationLabel,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sageLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          school.schoolType.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? AppColors.gold : AppColors.muted,
                    size: 22,
                  ),
                  onPressed: () => ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(school.id),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 50)),
        );
      },
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabel(item)),
              ))
          .toList(),
      onChanged: onChanged,
      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
    );
  }
}

Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) label,
}) {
  final controller = TextEditingController();
  ValueNotifier<String> query = ValueNotifier('');

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Cerca...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => query.value = v,
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: query,
                    builder: (_, q, __) {
                      final filtered = items
                          .where((e) =>
                              label(e).toLowerCase().contains(q.toLowerCase()))
                          .toList();

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          return ListTile(
                            title: Text(label(item)),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
