import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';

// ─── SCHOOL DATA PROVIDER ─────────────────────────────────────────────────────

final mySchoolProvider = FutureProvider<School?>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;

  final data = await supabase.from('schools').select('''
        *,
        municipalities (
          name,
          provinces ( name, regions ( name ) )
        )
      ''').eq('user_id', user.id).maybeSingle();

  if (data == null) return null;
  return School.fromJson(data);
});

final myMenusProvider = FutureProvider<List<SchoolMenu>>((ref) async {
  final school = await ref.watch(mySchoolProvider.future);
  if (school == null) return [];

  final data = await supabase
      .from('menus')
      .select('*, menu_days(*, menu_courses(*))')
      .eq('school_id', school.id)
      .order('created_at', ascending: false);

  return (data as List).map((e) => SchoolMenu.fromJson(e)).toList();
});

// ─── DASHBOARD SCREEN ─────────────────────────────────────────────────────────

class SchoolDashboardScreen extends ConsumerWidget {
  const SchoolDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(mySchoolProvider);
    final menusAsync = ref.watch(myMenusProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: schoolAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest)),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (school) {
            if (school == null) {
              return const Center(child: Text('Scuola non trovata'));
            }
            return CustomScrollView(
              slivers: [
                _buildHeader(context, ref, school, profile),
                _buildApprovalBanner(context, school),
                _buildStats(context, menusAsync),
                _buildMenuList(context, menusAsync),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
      // ✅ Dopo — due bottoni
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'cyclic',
            onPressed: () =>
                context.push('/school-dashboard/cyclic-menu-editor'),
            backgroundColor: AppColors.forest,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: Text('Menu ciclico',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'standard',
            onPressed: () => context.push('/school-dashboard/menu-editor'),
            backgroundColor: AppColors.terracotta,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Menu standard',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, School school,
      UserProfile? profile) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.forest, AppColors.forestLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white60,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        school.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon:
                      const Icon(Icons.more_vert_rounded, color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onSelected: (v) {
                    if (v == 'logout')
                      ref.read(authProvider.notifier).signOut();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 10),
                        const Text('Modifica profilo'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(children: [
                        const Icon(Icons.logout_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('Esci', style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // School info chips
            Wrap(
              spacing: 8,
              children: [
                _InfoChip(
                    text: school.schoolType.label,
                    emoji: school.schoolType.emoji),
                _InfoChip(text: school.municipalityName),
                _InfoChip(text: school.provinceName),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildApprovalBanner(BuildContext context, School school) {
    if (school.isApproved)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Text('⏳', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'La tua scuola è in attesa di approvazione. Sarai visibile agli utenti non appena approvata dall\'amministratore.',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildStats(
      BuildContext context, AsyncValue<List<SchoolMenu>> menusAsync) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panoramica',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            menusAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (menus) {
                final activeMenus = menus.where((m) => m.isActive).length;
                final totalDays =
                    menus.fold(0, (sum, m) => sum + m.days.length);

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '📋',
                        value: '$activeMenus',
                        label: 'Menu attivi',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '📅',
                        value: '$totalDays',
                        label: 'Giorni caricati',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '✅',
                        value: menus.isNotEmpty ? 'Attiva' : 'Nessuno',
                        label: 'Stato',
                        highlight: menus.isNotEmpty,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ).animate().fadeIn(delay: 250.ms),
    );
  }

  Widget _buildMenuList(
      BuildContext context, AsyncValue<List<SchoolMenu>> menusAsync) {
    return menusAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
            child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.forest),
        )),
      ),
      error: (e, _) => SliverToBoxAdapter(child: Text('Errore: $e')),
      data: (menus) {
        if (menus.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text('🍽', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('Nessun menu ancora',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Crea il primo menu della tua scuola\ncon il pulsante qui sotto.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text('I tuoi menu',
                      style: Theme.of(context).textTheme.headlineSmall),
                );
              }
              final menu = menus[i - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: _MenuCard(menu: menu),
              ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 60));
            },
            childCount: menus.length + 1,
          ),
        );
      },
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String text;
  final String? emoji;
  const _InfoChip({required this.text, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        emoji != null ? '$emoji $text' : text,
        style: GoogleFonts.dmSans(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool highlight;
  const _StatCard(
      {required this.emoji,
      required this.value,
      required this.label,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.sage : AppColors.forest,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends ConsumerWidget {
  final SchoolMenu menu;
  const _MenuCard({required this.menu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = (DateTime d) => '${d.day}/${d.month}/${d.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: menu.isActive
              ? AppColors.sage.withOpacity(0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  menu.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              if (menu.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '✅ Attivo',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fmt(menu.startDate)} → ${fmt(menu.endDate)}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${menu.days.length} giorni caricati',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
              ),
              if (menu.pdfUrl != null) ...[
                const SizedBox(width: 10),
                Text('• 📄 PDF disponibile',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.muted)),
              ],
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (menu.menuType == 'cyclic') {
                    context.push(
                        '/school-dashboard/cyclic-menu-editor?menuId=${menu.id}');
                  } else {
                    context.push(
                        '/school-dashboard/menu-editor?menuId=${menu.id}');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Modifica'),
              ),
              TextButton(
                onPressed: () async {
                  // Prendi l'id della scuola
                  final school = await ref.read(mySchoolProvider.future);
                  if (school != null && context.mounted) {
                    context.push('/school/${school.id}');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Anteprima'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
