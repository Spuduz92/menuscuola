import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_client.dart';

class RegisterSchoolScreen extends ConsumerStatefulWidget {
  const RegisterSchoolScreen({super.key});

  @override
  ConsumerState<RegisterSchoolScreen> createState() =>
      _RegisterSchoolScreenState();
}

class _RegisterSchoolScreenState extends ConsumerState<RegisterSchoolScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Selections
  SchoolType _selectedType = SchoolType.primaria;
  Region? _selectedRegion;
  Province? _selectedProvince;
  Municipality? _selectedMunicipality;

  // Data
  List<Region> _regions = [];
  List<Province> _provinces = [];
  List<Municipality> _municipalities = [];

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    final data =
        await supabase.from('regions').select().order('name', ascending: true);
    setState(() {
      _regions = (data as List).map((e) => Region.fromJson(e)).toList();
    });
  }

  Future<void> _loadProvinces(String regionId) async {
    final data = await supabase
        .from('provinces')
        .select()
        .eq('region_id', regionId)
        .order('name', ascending: true);
    setState(() {
      _provinces = (data as List).map((e) => Province.fromJson(e)).toList();
      _selectedProvince = null;
      _selectedMunicipality = null;
      _municipalities = [];
    });
  }

  Future<void> _loadMunicipalities(String provinceId) async {
    final data = await supabase
        .from('municipalities')
        .select()
        .eq('province_id', provinceId)
        .order('name', ascending: true);
    setState(() {
      _municipalities =
          (data as List).map((e) => Municipality.fromJson(e)).toList();
      _selectedMunicipality = null;
    });
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedMunicipality == null) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signUpSchool(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            schoolName: _nameCtrl.text.trim(),
            schoolType: _selectedType.name,
            municipalityId: _selectedMunicipality!.id,
            address: _addressCtrl.text.trim().isEmpty
                ? null
                : _addressCtrl.text.trim(),
            phone:
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _currentStep == 0 ? () => context.go('/login') : _prevStep,
        ),
        title: Text('Registra la scuola',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: Column(
        children: [
          // Progress steps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: List.generate(3, (i) {
                final isActive = i <= _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.forest : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                      if (i < 2)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 2,
                            color: i < _currentStep
                                ? AppColors.forest
                                : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 1: Dati scuola ─────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dati della scuola',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text('Come si chiama e di che tipo è?',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome della scuola',
              prefixIcon: Icon(Icons.school_outlined, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 20),
          Text('Tipo di scuola', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: SchoolType.values.map((type) {
              final isSelected = _selectedType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.forest : AppColors.warmWhite,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected ? AppColors.forest : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        type.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Indirizzo (opzionale)',
              prefixIcon:
                  Icon(Icons.location_on_outlined, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefono (opzionale)',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nameCtrl.text.isEmpty ? null : _nextStep,
              child: const Text('Avanti'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 2: Posizione geografica ────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dove si trova?',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text('Regione, provincia e comune.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 32),

          // Regione
          _buildDropdown<Region>(
            label: 'Regione',
            value: _selectedRegion,
            items: _regions,
            itemLabel: (r) => r.name,
            onChanged: (r) {
              setState(() => _selectedRegion = r);
              if (r != null) _loadProvinces(r.id);
            },
          ),

          const SizedBox(height: 14),

          // Provincia
          _buildDropdown<Province>(
            label: 'Provincia',
            value: _selectedProvince,
            items: _provinces,
            itemLabel: (p) => p.name,
            enabled: _selectedRegion != null,
            onChanged: (p) {
              setState(() => _selectedProvince = p);
              if (p != null) _loadMunicipalities(p.id);
            },
          ),

          const SizedBox(height: 14),

          // Comune
          _buildDropdown<Municipality>(
            label: 'Comune',
            value: _selectedMunicipality,
            items: _municipalities,
            itemLabel: (m) => m.name,
            enabled: _selectedProvince != null,
            onChanged: (m) => setState(() => _selectedMunicipality = m),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedMunicipality != null ? _nextStep : null,
              child: const Text('Avanti'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: Credenziali accesso ────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accesso alla\ndashboard',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text('Le credenziali per gestire il menu.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email della scuola',
              prefixIcon:
                  Icon(Icons.mail_outline_rounded, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.muted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⏳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dopo la registrazione, la scuola sarà visibile agli utenti solo dopo l\'approvazione da parte dell\'amministratore.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Registra la scuola 🏫'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabel(item)),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
    );
  }
}
