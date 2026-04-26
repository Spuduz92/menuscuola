import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../screens/school_dashboard_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class MenuEditorScreen extends ConsumerStatefulWidget {
  final String? menuId;
  const MenuEditorScreen({super.key, this.menuId});

  @override
  ConsumerState<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends ConsumerState<MenuEditorScreen> {
  final _titleCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 20));
  bool _isLoading = false;
  bool _isSaving = false;
  File? _pickedPdf;
  String? _pdfFileName;

  // Local days being edited
  List<_DayDraft> _days = [];

  SchoolMenu? _existingMenu;

  @override
  void initState() {
    super.initState();
    if (widget.menuId != null)
      _loadExisting();
    else
      _generateDays();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final data = await supabase
        .from('menus')
        .select('*, menu_days(*, menu_courses(*))')
        .eq('id', widget.menuId!)
        .single();
    final menu = SchoolMenu.fromJson(data);
    setState(() {
      _existingMenu = menu;
      _titleCtrl.text = menu.title;
      _startDate = menu.startDate;
      _endDate = menu.endDate;
      _days = menu.days.map((d) => _DayDraft.fromMenuDay(d)).toList();
      _isLoading = false;
    });
  }

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

  void _generateDays() {
    final days = <_DayDraft>[];
    var current = _startDate;
    while (!current.isAfter(_endDate)) {
      // Skip weekends
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        days.add(_DayDraft(date: current));
      }
      current = current.add(const Duration(days: 1));
    }
    setState(() => _days = days);
  }

  Future<void> _save() async {
    final school = await ref.read(mySchoolProvider.future);
    if (school == null) return;

    setState(() => _isSaving = true);
    try {
      String menuId;

      if (_existingMenu != null) {
        await supabase.from('menus').update({
          'title': _titleCtrl.text.trim(),
          'start_date': _startDate.toIso8601String().substring(0, 10),
          'end_date': _endDate.toIso8601String().substring(0, 10),
        }).eq('id', _existingMenu!.id);
        menuId = _existingMenu!.id;

        // Upload PDF se selezionato
        String? pdfUrl = _existingMenu?.pdfUrl;
        if (_pickedPdf != null) {
          pdfUrl = await _uploadPdf(_existingMenu!.id);
        }

        await supabase.from('menus').update({
          'title': _titleCtrl.text.trim(),
          'start_date': _startDate.toIso8601String().substring(0, 10),
          'end_date': _endDate.toIso8601String().substring(0, 10),
          if (pdfUrl != null) 'pdf_url': pdfUrl,
        }).eq('id', _existingMenu!.id);
        menuId = _existingMenu!.id;
      } else {
        final res = await supabase
            .from('menus')
            .insert({
              'school_id': school.id,
              'title': _titleCtrl.text.trim().isEmpty
                  ? 'Menu'
                  : _titleCtrl.text.trim(),
              'start_date': _startDate.toIso8601String().substring(0, 10),
              'end_date': _endDate.toIso8601String().substring(0, 10),
              'is_active': true,
            })
            .select()
            .single();
        menuId = res['id'] as String;

        // Upload PDF
        if (_pickedPdf != null) {
          final pdfUrl = await _uploadPdf(menuId);
          if (pdfUrl != null) {
            await supabase
                .from('menus')
                .update({'pdf_url': pdfUrl}).eq('id', menuId);
          }
        }
      }

      // Save days and courses
      for (final day in _days) {
        if (day.courses.isEmpty) continue;

        String dayId;
        if (day.existingId != null) {
          dayId = day.existingId!;
          // Delete existing courses to re-insert
          await supabase.from('menu_courses').delete().eq('menu_day_id', dayId);
        } else {
          final dayRes = await supabase
              .from('menu_days')
              .insert({
                'menu_id': menuId,
                'day_date': day.date.toIso8601String().substring(0, 10),
              })
              .select()
              .single();
          dayId = dayRes['id'] as String;
        }

        for (int i = 0; i < day.courses.length; i++) {
          final c = day.courses[i];
          await supabase.from('menu_courses').insert({
            'menu_day_id': dayId,
            'course_type': c.type.name,
            'custom_label': c.customLabel,
            'description': c.description,
            'allergens': c.allergens,
            'sort_order': i,
          });
        }
      }

      ref.invalidate(myMenusProvider);
      if (mounted) context.pop();
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
        title: Text(widget.menuId != null ? 'Modifica menu' : 'Nuovo menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.forest))
                : Text('Salva',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, color: AppColors.forest)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Title
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Titolo menu (es. "Menu Maggio 2025")',
              prefixIcon:
                  Icon(Icons.label_outline_rounded, color: AppColors.muted),
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // Date range
          Row(
            children: [
              Expanded(
                  child: _DatePicker(
                label: 'Data inizio',
                date: _startDate,
                onPicked: (d) => setState(() {
                  _startDate = d;
                  _generateDays();
                }),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _DatePicker(
                label: 'Data fine',
                date: _endDate,
                onPicked: (d) => setState(() {
                  _endDate = d;
                  _generateDays();
                }),
              )),
            ],
          ).animate().fadeIn(delay: 100.ms),

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

          // Days
          Row(
            children: [
              Text('Giorni da compilare',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              Text(
                '${_days.where((d) => d.courses.isNotEmpty).length}/${_days.length}',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 12),

          ..._days.asMap().entries.map((e) => _DayEditor(
                day: e.value,
                index: e.key,
                onChanged: (updated) => setState(() => _days[e.key] = updated),
              )),
        ],
      ),
    );
  }
}

// ─── DAY DRAFT MODEL ─────────────────────────────────────────────────────────

class _CourseDraft {
  CourseType type;
  String? customLabel;
  String description;
  List<String> allergens;

  _CourseDraft({
    this.type = CourseType.primo,
    this.customLabel,
    this.description = '',
    this.allergens = const [],
  });
}

class _DayDraft {
  final DateTime date;
  final String? existingId;
  List<_CourseDraft> courses;
  bool isExpanded;

  _DayDraft({
    required this.date,
    this.existingId,
    List<_CourseDraft>? courses,
    this.isExpanded = false,
  }) : courses = courses ?? [];

  static _DayDraft fromMenuDay(MenuDay day) => _DayDraft(
        date: day.dayDate,
        existingId: day.id,
        courses: day.courses
            .map((c) => _CourseDraft(
                  type: c.courseType,
                  customLabel: c.customLabel,
                  description: c.description,
                  allergens: c.allergens,
                ))
            .toList(),
        isExpanded: day.isToday,
      );
}

// ─── DAY EDITOR WIDGET ────────────────────────────────────────────────────────

class _DayEditor extends StatefulWidget {
  final _DayDraft day;
  final int index;
  final void Function(_DayDraft) onChanged;

  const _DayEditor(
      {required this.day, required this.index, required this.onChanged});

  @override
  State<_DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<_DayEditor> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.day.isExpanded;
  }

  void _addCourse() {
    final updated = widget.day;
    updated.courses.add(_CourseDraft(
      type: _nextCourseType(updated.courses.length),
    ));
    widget.onChanged(updated);
    setState(() {});
  }

  CourseType _nextCourseType(int count) {
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
    final day = widget.day;
    final dateStr =
        DateFormat("EEE d MMM", 'it_IT').format(day.date).capitalize();
    final hasData = day.courses.isNotEmpty &&
        day.courses.any((c) => c.description.isNotEmpty);

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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasData
                    ? AppColors.sage.withOpacity(0.15)
                    : AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  hasData ? '✅' : '📝',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            title: Text(
              dateStr,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest),
            ),
            subtitle: Text(
              hasData
                  ? '${day.courses.length} portate'
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
                  ...day.courses.asMap().entries.map((e) => _CourseEditor(
                        course: e.value,
                        index: e.key,
                        onChanged: (c) {
                          setState(() => day.courses[e.key] = c);
                          widget.onChanged(day);
                        },
                        onDelete: () {
                          setState(() => day.courses.removeAt(e.key));
                          widget.onChanged(day);
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
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 30));
  }
}

// ─── COURSE EDITOR ────────────────────────────────────────────────────────────

class _CourseEditor extends StatefulWidget {
  final _CourseDraft course;
  final int index;
  final void Function(_CourseDraft) onChanged;
  final VoidCallback onDelete;

  const _CourseEditor({
    required this.course,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

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
              // Course type selector
              DropdownButton<CourseType>(
                value: widget.course.type,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: CourseType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text('${t.emoji} ${t.label}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forest)),
                        ))
                    .toList(),
                onChanged: (t) {
                  if (t != null) {
                    widget.onChanged(_CourseDraft(
                      type: t,
                      description: widget.course.description,
                      allergens: widget.course.allergens,
                    ));
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
            onChanged: (v) => widget.onChanged(_CourseDraft(
              type: widget.course.type,
              description: v,
              allergens: widget.course.allergens,
            )),
            decoration: InputDecoration(
              hintText: 'Descrizione (es. Pasta al pomodoro)',
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

          // Allergens
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
                          widget.onChanged(_CourseDraft(
                            type: widget.course.type,
                            description: widget.course.description,
                            allergens: allergens,
                          ));
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

          // Add allergen
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _allergenCtrl,
                  decoration: InputDecoration(
                    hintText: '+ Allergene',
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
                    widget.onChanged(_CourseDraft(
                      type: widget.course.type,
                      description: widget.course.description,
                      allergens: allergens,
                    ));
                    _allergenCtrl.clear();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── DATE PICKER WIDGET ───────────────────────────────────────────────────────

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

// ─── EXTENSION ────────────────────────────────────────────────────────────────

extension _StringX on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
