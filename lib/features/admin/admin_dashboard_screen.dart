import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import 'admin_provider.dart';
import '../auth/providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingSchoolsProvider);
    final allAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.forest,
            surfaceTintColor: Colors.transparent,
            /*leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),*/
            title: Text(
              'Pannello Admin',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.terracotta,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('In attesa'),
                      const SizedBox(width: 6),
                      pendingAsync.when(
                        data: (list) => list.isEmpty
                            ? const SizedBox.shrink()
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.terracotta,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${list.length}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const Tab(text: 'Tutte le scuole'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ─── TAB 1: In attesa ────────────────────────────────────
            pendingAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.forest),
              ),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (schools) => schools.isEmpty
                  ? _buildEmpty(
                      emoji: '✅',
                      title: 'Nessuna scuola in attesa',
                      subtitle: 'Tutte le scuole sono state gestite.',
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: () =>
                          ref.refresh(pendingSchoolsProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: schools.length,
                        itemBuilder: (ctx, i) => _PendingSchoolCard(
                          school: schools[i],
                          index: i,
                        ),
                      ),
                    ),
            ),

            // ─── TAB 2: Tutte le scuole ───────────────────────────────
            allAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.forest),
              ),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (schools) => schools.isEmpty
                  ? _buildEmpty(
                      emoji: '🏫',
                      title: 'Nessuna scuola',
                      subtitle: 'Non ci sono ancora scuole registrate.',
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: () => ref.refresh(allSchoolsProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: schools.length,
                        itemBuilder: (ctx, i) => _AllSchoolCard(
                          school: schools[i],
                          index: i,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
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
}

// ─── CARD SCUOLA IN ATTESA ────────────────────────────────────────────────────

class _PendingSchoolCard extends ConsumerWidget {
  final School school;
  final int index;
  const _PendingSchoolCard({required this.school, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
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
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        school.fullLocationLabel,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '⏳ In attesa',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _InfoChip(label: school.schoolType.label),
                if (school.address != null) _InfoChip(label: school.address!),
                if (school.phone != null) _InfoChip(label: school.phone!),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(80, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Rifiuta'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(context, ref),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approva'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 60))
        .slideY(begin: 0.1, end: 0);
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(adminProvider.notifier).approveSchool(school.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${school.name} approvata!'),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rifiuta scuola',
            style: Theme.of(ctx).textTheme.headlineSmall),
        content: Text(
          'Sei sicuro di voler rifiutare "${school.name}"? L\'account verrà eliminato.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Rifiuta', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminProvider.notifier).rejectSchool(school.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ ${school.name} rifiutata.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }
}

// ─── CARD TUTTE LE SCUOLE ─────────────────────────────────────────────────────

class _AllSchoolCard extends ConsumerWidget {
  final School school;
  final int index;
  const _AllSchoolCard({required this.school, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: school.isApproved
              ? AppColors.sage.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: school.isApproved
                  ? AppColors.sageLight.withOpacity(0.3)
                  : AppColors.cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(school.schoolType.emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
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
                Text(
                  school.fullLocationLabel,
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status + azione
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: school.isApproved
                      ? AppColors.sage.withOpacity(0.15)
                      : AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  school.isApproved ? '✅ Attiva' : '⏳ In attesa',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        school.isApproved ? AppColors.forest : AppColors.gold,
                  ),
                ),
              ),
              if (school.isApproved) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _revoke(context, ref),
                  child: Text(
                    'Revoca',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 40));
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Revoca approvazione',
            style: Theme.of(ctx).textTheme.headlineSmall),
        content: Text(
          'Vuoi revocare l\'approvazione a "${school.name}"? Non sarà più visibile agli utenti.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Revoca', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminProvider.notifier).revokeSchool(school.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ ${school.name} revocata.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
      ),
    );
  }
}
