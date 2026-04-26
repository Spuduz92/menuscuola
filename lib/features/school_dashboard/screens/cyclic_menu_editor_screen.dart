import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/models/cyclic_models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/italian_holidays.dart';
import '../screens/school_dashboard_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class CyclicMenuEditorScreen extends ConsumerStatefulWidget {
  final String? menuId; // aggiungi
  const CyclicMenuEditorScreen({super.key, this.menuId}); // aggiungi

  @override
  ConsumerState<CyclicMenuEditorScreen> createState() =>
      _CyclicMenuEditorScreenState();
}

class _CyclicMenuEditorScreenState extends ConsumerState<CyclicMenuEditorScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  // Step 0: configurazione, Step 1: editor settimane
  int _step = 0;

  final _titleCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime(DateTime.now().year + 1, 6, 30);
  int _cycleWeeks = 3;

  File? _pickedPdf;
  String? _pdfFileName;

  List<CyclicWeek> _weeks = [];
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _cycleWeeks, vsync: this);
    if (widget.menuId != null) {
      _loadExisting(); // aggiungi
    } else {
      _buildWeeks();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _buildWeeks() {
    _weeks = List.generate(
      _cycleWeeks,
      (i) => CyclicWeek(weekNumber: i + 1),
    );
    _tabCtrl.dispose();
    _tabCtrl = TabController(length: _cycleWeeks, vsync: this);
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase.from('menus').select('''
          *,
          cycle_weeks (
            *,
            cycle_days (
              *,
              cycle_courses (*)
            )
          )
        ''').eq('id', widget.menuId!).single();

      final menu = SchoolMenu.fromJson(data);
      final loadedWeeks = (data['cycle_weeks'] as List<dynamic>?)
              ?.map((e) => CyclicWeek.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      loadedWeeks.sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

      // ← NUOVO: assicura che ogni settimana abbia tutti e 5 i giorni
      final completeWeeks = loadedWeeks.map((week) {
        final existingDays = {for (var d in week.days) d.dayOfWeek: d};
        final allDays = List.generate(5, (i) {
          final dow = i + 1;
          return existingDays[dow] ??
              CyclicDay(dayOfWeek: dow); // giorno vuoto se mancante
        });
        return CyclicWeek(
          id: week.id,
          weekNumber: week.weekNumber,
          days: allDays,
        );
      }).toList();

      setState(() {
        _titleCtrl.text = menu.title;
        _startDate = menu.startDate;
        _endDate = menu.endDate;
        _cycleWeeks = completeWeeks.isNotEmpty ? completeWeeks.length : 1;
        _weeks = completeWeeks.isNotEmpty
            ? completeWeeks
            : List.generate(_cycleWeeks, (i) => CyclicWeek(weekNumber: i + 1));
        _tabCtrl = TabController(length: _cycleWeeks, vsync: this);
        _isLoading = false;
        _step = 1;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Preview giorni generati
  int get _totalWorkingDays {
    return ItalianHolidays.getWorkingDays(_startDate, _endDate).length;
  }

  Future<void> _save() async {
    final school = await ref.read(mySchoolProvider.future);
    if (school == null) return;
    setState(() => _isSaving = true);

    try {
      String menuId;
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowStr = tomorrow.toIso8601String().substring(0, 10);

      if (widget.menuId != null) {
        // ─── MODIFICA menu esistente ─────────────────────────────
        menuId = widget.menuId!;

        // Aggiorna dati base menu
        await supabase.from('menus').update({
          'title': _titleCtrl.text.trim().isEmpty
              ? 'Menu ciclico $_cycleWeeks settimane'
              : _titleCtrl.text.trim(),
          'start_date': _startDate.toIso8601String().substring(0, 10),
          'end_date': _endDate.toIso8601String().substring(0, 10),
          'cycle_weeks': _cycleWeeks,
        }).eq('id', menuId);

        // Elimina solo il ciclo (template), riscritto completamente
        await supabase.from('cycle_weeks').delete().eq('menu_id', menuId);

        // Elimina solo i giorni reali FUTURI (da domani in poi)
        // Oggi e il passato restano intoccati
        await supabase
            .from('menu_days')
            .delete()
            .eq('menu_id', menuId)
            .gte('day_date', tomorrowStr);

        if (_pickedPdf != null) {
          final pdfUrl = await _uploadPdf(menuId);
          if (pdfUrl != null) {
            await supabase
                .from('menus')
                .update({'pdf_url': pdfUrl}).eq('id', menuId);
          }
        }
      } else {
        // ─── NUOVO menu ───────────────────────────────────────────
        final menuRes = await supabase
            .from('menus')
            .insert({
              'school_id': school.id,
              'title': _titleCtrl.text.trim().isEmpty
                  ? 'Menu ciclico $_cycleWeeks settimane'
                  : _titleCtrl.text.trim(),
              'start_date': _startDate.toIso8601String().substring(0, 10),
              'end_date': _endDate.toIso8601String().substring(0, 10),
              'is_active': true,
              'menu_type': 'cyclic',
              'cycle_weeks': _cycleWeeks,
            })
            .select()
            .single();

        menuId = menuRes['id'] as String;

        // Upload PDF se selezionato
        if (_pickedPdf != null) {
          final pdfUrl = await _uploadPdf(menuId);
          if (pdfUrl != null) {
            await supabase
                .from('menus')
                .update({'pdf_url': pdfUrl}).eq('id', menuId);
          }
        }
      }

      // ─── Salva settimane ciclo (template) ────────────────────────
      for (final week in _weeks) {
        final weekRes = await supabase
            .from('cycle_weeks')
            .insert({
              'menu_id': menuId,
              'week_number': week.weekNumber,
            })
            .select()
            .single();
        final weekId = weekRes['id'] as String;

        for (final day in week.days) {
          if (day.courses.isEmpty) continue;
          if (day.courses.every((c) => c.description.trim().isEmpty)) continue;

          final dayRes = await supabase
              .from('cycle_days')
              .insert({
                'cycle_week_id': weekId,
                'day_of_week': day.dayOfWeek,
              })
              .select()
              .single();
          final dayId = dayRes['id'] as String;

          for (int i = 0; i < day.courses.length; i++) {
            final c = day.courses[i];
            if (c.description.trim().isEmpty) continue;
            await supabase.from('cycle_courses').insert({
              'cycle_day_id': dayId,
              'course_type': c.courseType.name,
              'custom_label': c.customLabel,
              'description': c.description,
              'allergens': c.allergens,
              'sort_order': i,
            });
          }
        }
      }

      // ─── Genera calendario dall'inizio originale ─────────────────
      // Il ciclo è sempre calcolato dalla data inizio del menu
      // così la settimana corrente è sempre coerente
      final allAssignments = ItalianHolidays.generateCyclicCalendar(
        startDate: _startDate,
        endDate: _endDate,
        totalCycleWeeks: _cycleWeeks,
      );

      // In modifica: inserisci solo i giorni da domani in poi
      // In creazione: inserisci tutto
      final assignmentsToInsert = widget.menuId != null
          ? allAssignments.where((a) => a.date.isAfter(today)).toList()
          : allAssignments;

      // ─── Inserisci i giorni reali ─────────────────────────────────
      for (final assignment in assignmentsToInsert) {
        final week = _weeks.firstWhere(
          (w) => w.weekNumber == assignment.cycleWeekNumber,
          orElse: () => _weeks.first,
        );
        final day = week.days.firstWhere(
          (d) => d.dayOfWeek == assignment.dayOfWeek,
          orElse: () => CyclicDay(dayOfWeek: assignment.dayOfWeek),
        );

        if (day.courses.isEmpty) continue;
        if (day.courses.every((c) => c.description.trim().isEmpty)) continue;

        final realDayRes = await supabase
            .from('menu_days')
            .insert({
              'menu_id': menuId,
              'day_date': assignment.date.toIso8601String().substring(0, 10),
            })
            .select()
            .single();
        final realDayId = realDayRes['id'] as String;

        for (int i = 0; i < day.courses.length; i++) {
          final c = day.courses[i];
          if (c.description.trim().isEmpty) continue;
          await supabase.from('menu_courses').insert({
            'menu_day_id': realDayId,
            'course_type': c.courseType.name,
            'custom_label': c.customLabel,
            'description': c.description,
            'allergens': c.allergens,
            'sort_order': i,
          });
        }
      }

      ref.invalidate(myMenusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            widget.menuId != null
                ? '✅ Menu aggiornato! ${assignmentsToInsert.length} giorni futuri rigenerati.'
                : '✅ Menu creato! ${allAssignments.length} giorni generati.',
          ),
          backgroundColor: AppColors.sage,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _uploadPdf(String menuId) async {
    if (_pickedPdf == null) return null;
    try {
      final bytes = await _pickedPdf!.readAsBytes();
      final path = 'menus/$menuId.pdf';

      // Rimuovi se esiste già
      try {
        await supabase.storage.from('menu-pdfs').remove([path]);
      } catch (_) {}

      // Carica
      await supabase.storage.from('menu-pdfs').uploadBinary(
            path,
            bytes,
          );

      return supabase.storage.from('menu-pdfs').getPublicUrl(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore upload PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(_step == 0 ? 'Menu ciclico' : 'Compila il ciclo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_step == 1)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.forest),
                    )
                  : Text('Salva',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest)),
            ),
        ],
        bottom: _step == 1
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: AppColors.terracotta,
                labelColor: AppColors.forest,
                unselectedLabelColor: AppColors.muted,
                labelStyle: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: _weeks.map((w) => Tab(text: w.label)).toList(),
              )
            : null,
      ),
      body: _step == 0 ? _buildConfig() : _buildEditor(),
    );
  }

  // ─── STEP 0: Configurazione ──────────────────────────────────────────────
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPdf = File(result.files.single.path!);
        _pdfFileName = result.files.single.name;
      });
    }
  }

  Widget _buildConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spiegazione
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sageLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sage.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔄', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Inserisci il ciclo una volta sola. L\'app lo spalmerà automaticamente su tutti i giorni lavorativi del periodo, escludendo weekend e festivi italiani.',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: AppColors.forest),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Titolo menu (opzionale)',
              prefixIcon:
                  Icon(Icons.label_outline_rounded, color: AppColors.muted),
            ),
          ).animate().fadeIn(delay: 100.ms),

          //const SizedBox(height: 16),

          // PDF upload — aggiungi prima del bottone Salva
          const SizedBox(height: 24),
          Text('PDF menu (opzionale)',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Carica il PDF ufficiale della tua scuola',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _pickedPdf != null ? AppColors.sage : AppColors.border,
                  width: _pickedPdf != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _pickedPdf != null
                          ? AppColors.sage.withOpacity(0.15)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _pickedPdf != null ? '✅' : '📄',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedPdf != null ? _pdfFileName! : 'Seleziona PDF',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _pickedPdf != null
                                ? AppColors.forest
                                : AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _pickedPdf != null
                              ? 'Tocca per cambiare'
                              : 'Formato .pdf',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (_pickedPdf != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.muted, size: 18),
                      onPressed: () => setState(() {
                        _pickedPdf = null;
                        _pdfFileName = null;
                      }),
                    ),
                ],
              ),
            ),
          ),

          // Date
          Row(
            children: [
              Expanded(
                child: _DatePicker(
                  label: 'Data inizio',
                  date: _startDate,
                  onPicked: (d) => setState(() => _startDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePicker(
                  label: 'Data fine',
                  date: _endDate,
                  onPicked: (d) => setState(() => _endDate = d),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 24),

          // Numero settimane ciclo
          Text('Settimane del ciclo',
                  style: Theme.of(context).textTheme.headlineSmall)
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 4),
          Text(
            'Quante settimane si ripetono prima di ricominciare?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ).animate().fadeIn(delay: 220.ms),

          const SizedBox(height: 16),

          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              final isSelected = _cycleWeeks == n;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _cycleWeeks = n;
                    _buildWeeks();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.forest : AppColors.warmWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.forest : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$n',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.forest,
                          ),
                        ),
                        Text(
                          n == 1 ? 'sett.' : 'sett.',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            color:
                                isSelected ? Colors.white70 : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 24),

          // Preview
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Anteprima',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 10),
                _PreviewRow(
                    label: 'Periodo',
                    value: '${_fmt(_startDate)} → ${_fmt(_endDate)}'),
                _PreviewRow(
                    label: 'Ciclo',
                    value:
                        '$_cycleWeeks settiman${_cycleWeeks == 1 ? 'a' : 'e'}'),
                _PreviewRow(
                    label: 'Giorni lavorativi',
                    value: '$_totalWorkingDays giorni'),
                _PreviewRow(
                    label: 'Giorni da compilare',
                    value:
                        '${_cycleWeeks * 5} (${_cycleWeeks} sett. × 5 giorni)'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Compila il ciclo →'),
            ),
          ).animate().fadeIn(delay: 350.ms),
        ],
      ),
    );
  }

  // ─── STEP 1: Editor settimane ────────────────────────────────────────────

  Widget _buildEditor() {
    return TabBarView(
      controller: _tabCtrl,
      children: _weeks.asMap().entries.map((e) {
        final weekIndex = e.key;
        final week = e.value;
        return _WeekEditor(
          week: week,
          onChanged: (updated) => setState(() => _weeks[weekIndex] = updated),
        );
      }).toList(),
    );
  }

  String _fmt(DateTime d) => DateFormat('d MMM yyyy', 'it_IT').format(d);
}

// ─── WEEK EDITOR ─────────────────────────────────────────────────────────────

class _WeekEditor extends StatelessWidget {
  final CyclicWeek week;
  final void Function(CyclicWeek) onChanged;

  const _WeekEditor({required this.week, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: week.days.length,
      itemBuilder: (ctx, i) {
        final day = week.days[i];
        return _DayEditor(
          day: day,
          index: i,
          onChanged: (updatedDay) {
            final newDays = [...week.days];
            newDays[i] = updatedDay;
            onChanged(CyclicWeek(
              id: week.id,
              weekNumber: week.weekNumber,
              days: newDays,
            ));
          },
        );
      },
    );
  }
}

// ─── DAY EDITOR ──────────────────────────────────────────────────────────────

class _DayEditor extends StatefulWidget {
  final CyclicDay day;
  final int index;
  final void Function(CyclicDay) onChanged;

  const _DayEditor(
      {required this.day, required this.index, required this.onChanged});

  @override
  State<_DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<_DayEditor> {
  bool _expanded = false;

  void _addCourse() {
    final courses = [...widget.day.courses];
    final nextType = _nextType(courses.length);
    courses.add(CyclicCourse(courseType: nextType));
    widget.onChanged(CyclicDay(
        id: widget.day.id, dayOfWeek: widget.day.dayOfWeek, courses: courses));
    setState(() {});
  }

  CourseType _nextType(int count) {
    final order = [
      CourseType.primo,
      CourseType.secondo,
      CourseType.contorno,
      CourseType.frutta,
    ];
    return count < order.length ? order[count] : CourseType.custom;
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.day.courses.isNotEmpty &&
        widget.day.courses.any((c) => c.description.isNotEmpty);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasData
              ? AppColors.sage.withOpacity(0.5)
              : _expanded
                  ? AppColors.forest.withOpacity(0.3)
                  : AppColors.border,
          width: (_expanded || hasData) ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hasData
                    ? AppColors.sage.withOpacity(0.15)
                    : AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(widget.day.dayEmoji,
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            title: Text(
              widget.day.dayName,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest),
            ),
            subtitle: Text(
              hasData
                  ? '${widget.day.courses.length} portate'
                  : 'Tocca per aggiungere',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  ...widget.day.courses
                      .asMap()
                      .entries
                      .map((e) => _CourseEditor(
                            course: e.value,
                            onChanged: (updated) {
                              final courses = [...widget.day.courses];
                              courses[e.key] = updated;
                              widget.onChanged(CyclicDay(
                                  id: widget.day.id,
                                  dayOfWeek: widget.day.dayOfWeek,
                                  courses: courses));
                            },
                            onDelete: () {
                              final courses = [...widget.day.courses]
                                ..removeAt(e.key);
                              widget.onChanged(CyclicDay(
                                  id: widget.day.id,
                                  dayOfWeek: widget.day.dayOfWeek,
                                  courses: courses));
                              setState(() {});
                            },
                          )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addCourse,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Aggiungi portata'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: AppColors.forest,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 50));
  }
}

// ─── COURSE EDITOR ────────────────────────────────────────────────────────────

class _CourseEditor extends StatefulWidget {
  final CyclicCourse course;
  final void Function(CyclicCourse) onChanged;
  final VoidCallback onDelete;

  const _CourseEditor(
      {required this.course, required this.onChanged, required this.onDelete});

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  late TextEditingController _descCtrl;
  late TextEditingController _allergenCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.course.description);
    _allergenCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _allergenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<CourseType>(
                value: widget.course.courseType,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: CourseType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            '${t.emoji} ${t.label}',
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest),
                          ),
                        ))
                    .toList(),
                onChanged: (t) {
                  if (t != null) {
                    widget.onChanged(widget.course.copyWith(courseType: t));
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.muted, size: 18),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            onChanged: (v) =>
                widget.onChanged(widget.course.copyWith(description: v)),
            decoration: InputDecoration(
              hintText: 'Descrizione portata…',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.forest, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.warmWhite,
            ),
          ),
          if (widget.course.allergens.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: widget.course.allergens
                  .map((a) => Chip(
                        label: Text(a, style: GoogleFonts.dmSans(fontSize: 10)),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () {
                          final allergens = [...widget.course.allergens]
                            ..remove(a);
                          widget.onChanged(
                              widget.course.copyWith(allergens: allergens));
                        },
                        padding: const EdgeInsets.all(0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.terracotta.withOpacity(0.1),
                        side: BorderSide.none,
                        labelStyle: GoogleFonts.dmSans(
                            fontSize: 10, color: AppColors.terracotta),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _allergenCtrl,
            decoration: InputDecoration(
              hintText: '+ Aggiungi allergene',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.forest),
              ),
              filled: true,
              fillColor: AppColors.warmWhite,
            ),
            style: GoogleFonts.dmSans(fontSize: 12),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              final allergens = [...widget.course.allergens, v.trim()];
              widget.onChanged(widget.course.copyWith(allergens: allergens));
              _allergenCtrl.clear();
            },
          ),
        ],
      ),
    );
  }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest)),
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onPicked;

  const _DatePicker(
      {required this.label, required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.forest,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.muted)),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
