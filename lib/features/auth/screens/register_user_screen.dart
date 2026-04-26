import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../app/theme.dart';

class RegisterUserScreen extends ConsumerStatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  ConsumerState<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends ConsumerState<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    print('TENTATIVO REGISTRAZIONE: ${_emailCtrl.text.trim()}'); // aggiungi
    try {
      await ref.read(authProvider.notifier).signUpUser(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            fullName: _nameCtrl.text.trim(),
          );
      print('REGISTRAZIONE OK'); // aggiungi
    } catch (e) {
      print('REGISTRAZIONE ERROR: $e'); // aggiungi
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
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sageLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '👨‍👩‍👧 Account famiglia',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.forest,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              Text(
                'Crea il tuo\naccount',
                style: Theme.of(context).textTheme.displaySmall,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 8),
              Text(
                'Gratuito, sempre.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: 36),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(
                      ctrl: _nameCtrl,
                      label: 'Nome completo',
                      icon: Icons.person_outline_rounded,
                      delay: 200,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Campo obbligatorio'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      ctrl: _emailCtrl,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                      delay: 250,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Inserisci la tua email';
                        if (!v.contains('@')) return 'Email non valida';
                        return null;
                      },
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
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Inserisci la password';
                        if (v.length < 6) return 'Minimo 6 caratteri';
                        return null;
                      },
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passConfirmCtrl,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Conferma password',
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            color: AppColors.muted),
                      ),
                      validator: (v) {
                        if (v != _passCtrl.text)
                          return 'Le password non coincidono';
                        return null;
                      },
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Crea account'),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text.rich(
                        TextSpan(
                          text: 'Hai già un account? ',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.muted),
                          children: [
                            TextSpan(
                              text: 'Accedi',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required int delay,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted),
      ),
      validator: validator,
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}
