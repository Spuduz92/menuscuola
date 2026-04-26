import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/school_dashboard_screen.dart';
import 'package:storage_client/storage_client.dart';

class SchoolProfileScreen extends ConsumerStatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  ConsumerState<SchoolProfileScreen> createState() =>
      _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends ConsumerState<SchoolProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  File? _pickedLogo;
  bool _isSaving = false;
  School? _school;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final school = await ref.read(mySchoolProvider.future);
    if (school != null && mounted) {
      setState(() {
        _school = school;
        _nameCtrl.text = school.name;
        _addressCtrl.text = school.address ?? '';
        _phoneCtrl.text = school.phone ?? '';
      });
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _pickedLogo = File(picked.path));
  }

  Future<void> _save() async {
    if (_school == null) return;
    setState(() => _isSaving = true);
    try {
      String? logoUrl = _school!.logoUrl;

      // Upload logo se cambiato
      if (_pickedLogo != null) {
        final bytes = await _pickedLogo!.readAsBytes();
        final path = 'logos/${_school!.id}.jpg';

        try {
          await supabase.storage.from('school-logos').remove([path]);
        } catch (_) {}

        await supabase.storage.from('school-logos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        logoUrl = supabase.storage.from('school-logos').getPublicUrl(path);
      }

      await supabase.from('schools').update({
        'name': _nameCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        if (logoUrl != null) 'logo_url': logoUrl,
      }).eq('id', _school!.id);

      ref.invalidate(mySchoolProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profilo aggiornato ✅'),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Profilo scuola'),
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
                        strokeWidth: 2, color: AppColors.forest),
                  )
                : Text(
                    'Salva',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, color: AppColors.forest),
                  ),
          ),
        ],
      ),
      body: _school == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.sageLight.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.border, width: 2),
                            ),
                            child: ClipOval(
                              child: _pickedLogo != null
                                  ? Image.file(_pickedLogo!, fit: BoxFit.cover)
                                  : _school!.logoUrl != null
                                      ? Image.network(_school!.logoUrl!,
                                          fit: BoxFit.cover)
                                      : Center(
                                          child: Text(
                                            _school!.schoolType.emoji,
                                            style:
                                                const TextStyle(fontSize: 40),
                                          ),
                                        ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.forest,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tocca per cambiare il logo',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Stato approvazione
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _school!.isApproved
                          ? AppColors.sage.withOpacity(0.1)
                          : AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _school!.isApproved
                            ? AppColors.sage.withOpacity(0.4)
                            : AppColors.gold.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _school!.isApproved ? '✅' : '⏳',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _school!.isApproved
                                    ? 'Scuola approvata'
                                    : 'In attesa di approvazione',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forest,
                                ),
                              ),
                              Text(
                                _school!.isApproved
                                    ? 'Sei visibile agli utenti e puoi pubblicare menu.'
                                    : 'L\'amministratore deve approvare la tua scuola.',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // Read-only info
                  _SectionLabel(label: 'Informazioni (non modificabili)'),
                  const SizedBox(height: 12),

                  _InfoRow(
                      label: 'Tipo',
                      value:
                          '${_school!.schoolType.emoji} ${_school!.schoolType.label}'),
                  _InfoRow(label: 'Comune', value: _school!.municipalityName),
                  _InfoRow(label: 'Provincia', value: _school!.provinceName),
                  _InfoRow(label: 'Regione', value: _school!.regionName),

                  const SizedBox(height: 24),

                  // Editable fields
                  _SectionLabel(label: 'Dati modificabili'),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome della scuola',
                      prefixIcon:
                          Icon(Icons.school_outlined, color: AppColors.muted),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Indirizzo',
                      prefixIcon: Icon(Icons.location_on_outlined,
                          color: AppColors.muted),
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon:
                          Icon(Icons.phone_outlined, color: AppColors.muted),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 32),

                  // Danger zone
                  _SectionLabel(label: 'Zona pericolosa'),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Disconnetti account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),
                ],
              ),
            ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Disconnetti', style: Theme.of(ctx).textTheme.headlineSmall),
        content: Text(
          'Sei sicuro di voler uscire dall\'account della scuola?',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: Text('Esci', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 1,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.forest),
            ),
          ),
        ],
      ),
    );
  }
}
