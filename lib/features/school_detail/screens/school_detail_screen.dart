import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../home/providers/home_provider.dart';
import '../../school_detail/screens/providers/school_detail_provider.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/pdf_generator.dart';
import 'package:go_router/go_router.dart';

// ─── SCHOOL DETAIL PROVIDER ───────────────────────────────────────────────────

/*final schoolMenuProvider =
    FutureProvider.family<SchoolMenu?, String>((ref, schoolId) async {
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
});*/

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class SchoolDetailScreen extends ConsumerWidget {
  final String schoolId;
  const SchoolDetailScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(schoolDetailProvider(schoolId));
    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav =
        favoritesAsync.valueOrNull?.any((s) => s.id == schoolId) ?? false;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: schoolAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.forest)),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (school) {
          if (school == null)
            return const Center(child: Text('Scuola non trovata'));
          return _SchoolDetailBody(school: school, isFav: isFav);
        },
      ),
    );
  }
}

class _SchoolDetailBody extends ConsumerStatefulWidget {
  final School school;
  final bool isFav;
  const _SchoolDetailBody({required this.school, required this.isFav});

  @override
  ConsumerState<_SchoolDetailBody> createState() => _SchoolDetailBodyState();
}

class _SchoolDetailBodyState extends ConsumerState<_SchoolDetailBody>
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
    final menuAsync = ref.watch(schoolMenuProvider(widget.school.id));

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.forest,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                widget.isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: widget.isFav ? AppColors.gold : Colors.white,
              ),
              onPressed: () => ref
                  .read(favoritesProvider.notifier)
                  .toggleFavorite(widget.school.id),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.forest, AppColors.forestLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.school.schoolType.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              widget.school.schoolType.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.school.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.school.fullLocationLabel,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.terracotta,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle:
                GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Oggi'),
              Tab(text: 'Prossimi giorni'),
            ],
          ),
        ),
      ],
      body: menuAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.forest)),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (menu) => TabBarView(
          controller: _tabCtrl,
          children: [
            _TodayTab(menu: menu, school: widget.school),
            _WeekTab(menu: menu, school: widget.school),
          ],
        ),
      ),
    );
  }
}

// ─── TODAY TAB ────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  final SchoolMenu? menu;
  final School school; // aggiungi
  const _TodayTab({required this.menu, required this.school}); // aggiungi

  @override
  Widget build(BuildContext context) {
    if (menu == null) {
      return _EmptyMenu(message: 'Nessun menu attivo per questa scuola.');
    }

    final today = menu!.todayMenu;
    if (today == null) {
      return _EmptyMenu(
          message: 'Menu non disponibile per oggi.\nRicontrolla domani!');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.sageLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              DateFormat("EEEE d MMMM yyyy", 'it_IT')
                  .format(today.dayDate)
                  .capitalize(),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.forest,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Courses
          ...today.courses
              .sorted((a, b) => _courseOrder(a.courseType)
                  .compareTo(_courseOrder(b.courseType)))
              .asMap()
              .entries
              .map((e) => _CourseCard(course: e.value, index: e.key)),

          // PDF download if available
          if (menu!.pdfUrl != null || true) ...[
            // sempre mostra il generatore
            const SizedBox(height: 24),
            _PdfDownloadButton(school: school, menu: menu!), // passa school
          ],
        ],
      ),
    );
  }
}

// ─── WEEK TAB ─────────────────────────────────────────────────────────────────

class _WeekTab extends StatelessWidget {
  final SchoolMenu? menu;
  final School school; // aggiungi
  const _WeekTab({required this.menu, required this.school}); // aggiungi

  @override
  Widget build(BuildContext context) {
    if (menu == null || menu!.upcomingDays.isEmpty) {
      return _EmptyMenu(message: 'Nessun giorno disponibile.');
    }

    final days = menu!.upcomingDays;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: days.length + (menu!.pdfUrl != null ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == days.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PdfDownloadButton(school: school, menu: menu!),
          );
        }
        final day = days[i];
        return _DayAccordion(day: day, index: i);
      },
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final MenuCourse course;
  final int index;
  const _CourseCard({required this.course, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.sageLight.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(course.courseType.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.displayLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.description,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.forest,
                  ),
                ),
                if (course.allergens.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: course.allergens
                        .map((a) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.terracotta.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color:
                                        AppColors.terracotta.withOpacity(0.3)),
                              ),
                              child: Text(
                                '⚠️ $a',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppColors.terracotta,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 + index * 60))
        .slideY(begin: 0.1, end: 0);
  }
}

class _DayAccordion extends StatefulWidget {
  final MenuDay day;
  final int index;
  const _DayAccordion({required this.day, required this.index});

  @override
  State<_DayAccordion> createState() => _DayAccordionState();
}

class _DayAccordionState extends State<_DayAccordion> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.day.isToday;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("EEEE d MMM", 'it_IT')
        .format(widget.day.dayDate)
        .capitalize();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _expanded ? AppColors.warmWhite : AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _expanded ? AppColors.forest.withOpacity(0.3) : AppColors.border,
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              children: [
                if (widget.day.isToday)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.terracotta,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Oggi',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Text(
                  dateStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
            subtitle: !_expanded
                ? Text(
                    '${widget.day.courses.length} portate',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.muted),
                  )
                : null,
            trailing: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: widget.day.courses
                    .sorted((a, b) => _courseOrder(a.courseType)
                        .compareTo(_courseOrder(b.courseType)))
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(c.courseType.emoji,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Text(
                                '${c.displayLabel}  ',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                              Expanded(
                                child: Text(
                                  c.description,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 50));
  }
}

/*class _PdfDownloadButton extends StatelessWidget {
  final String pdfUrl;
  const _PdfDownloadButton({required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.terracotta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Center(child: Text('📄', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu completo',
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest),
                ),
                Text(
                  'Scarica il PDF del mese',
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: open PDF viewer or download
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.terracotta),
            child: const Text('Scarica'),
          ),
        ],
      ),
    );
  }
}
*/
class _EmptyMenu extends StatelessWidget {
  final String message;
  const _EmptyMenu({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              message,
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
}

class _PdfDownloadButton extends ConsumerWidget {
  final School school;
  final SchoolMenu menu;

  const _PdfDownloadButton({required this.school, required this.menu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // PDF generato dall'app
        _PdfRow(
          emoji: '🤖',
          title: 'Menu generato da app',
          subtitle: 'Generato dai dati inseriti',
          onTap: () => _generateAndOpen(context),
        ),

        // PDF della scuola (se disponibile)
        if (menu.pdfUrl != null) ...[
          const SizedBox(height: 10),
          _PdfRow(
            emoji: '🏫',
            title: 'Menu ufficiale scuola',
            subtitle: 'Caricato dalla scuola',
            onTap: () => context.push('/pdf-viewer',
                extra: {'url': menu.pdfUrl!, 'title': 'Menu ufficiale'}),
          ),
        ],
      ],
    );
  }

  Future<void> _generateAndOpen(BuildContext context) async {
    try {
      final bytes = await MenuPdfGenerator.generate(
        school: school,
        menu: menu,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore generazione PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _PdfRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PdfRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.terracotta.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest)),
                  Text(subtitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.download_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── EXTENSIONS ───────────────────────────────────────────────────────────────

extension _StringX on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

extension _ListX<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

int _courseOrder(CourseType type) {
  switch (type) {
    case CourseType.primo:
      return 0;
    case CourseType.secondo:
      return 1;
    case CourseType.contorno:
      return 2;
    case CourseType.frutta:
      return 3;
    case CourseType.dessert:
      return 4;
    case CourseType.custom:
      return 5;
  }
}
