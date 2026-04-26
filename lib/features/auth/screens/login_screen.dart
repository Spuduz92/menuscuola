import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
    } on AuthException catch (e) {
      if (mounted) {
        // Messaggio specifico per email non verificata
        final msg = e.message.contains('Email not confirmed')
            ? 'Controlla la tua email e clicca il link di conferma prima di accedere.'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Password dimenticata',
                    style: Theme.of(ctx).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'Inserisci la tua email e ti manderemo un link per reimpostare la password.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            if (emailCtrl.text.trim().isEmpty) return;
                            setModalState(() => isSending = true);
                            try {
                              await supabase.auth.resetPasswordForEmail(
                                emailCtrl.text.trim(),
                                redirectTo: 'menuscuola://reset-password',
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        '✅ Email inviata! Controlla la tua casella.'),
                                    backgroundColor: AppColors.sage,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Errore: $e'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              setModalState(() => isSending = false);
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Invia link di reset'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'OggiA',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forest,
                      ),
                    ),
                    TextSpan(
                      text: 'Mensa',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),

              const SizedBox(height: 8),

              Text(
                'Bentornato! Accedi al tuo account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

              const SizedBox(height: 48),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppColors.muted),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Inserisci la tua email';
                        if (!v.contains('@')) return 'Email non valida';
                        return null;
                      },
                    )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 500.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
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
                        .fadeIn(delay: 200.ms, duration: 500.ms)
                        .slideY(begin: 0.1, end: 0),

                    // Dopo il campo password, prima del bottone login
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPassword(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'Password dimenticata?',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.muted),
                        ),
                      ),
                    ).animate().fadeIn(delay: 230.ms),

                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accedi'),
                      ),
                    ).animate().fadeIn(delay: 250.ms, duration: 500.ms),

                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('oppure',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                    const SizedBox(height: 24),

                    // Register user
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Crea account famiglia'),
                      ),
                    ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

                    const SizedBox(height: 12),

                    // Register school
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/register-school'),
                        icon: const Text('🏫', style: TextStyle(fontSize: 16)),
                        label: const Text('Registra la tua scuola'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.terracotta,
                          side: const BorderSide(
                              color: AppColors.terracotta, width: 1.5),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
