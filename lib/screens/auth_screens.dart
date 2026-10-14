import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

/// Double-bordered glass panel shared by the welcome and login screens.
class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .7), width: 1.5),
                  ),
                  child: GlassCard(
                    radius: 36,
                    padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
                    child: Column(children: children),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) => const Column(children: [
        Text('PortalAI',
            style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.primary)),
        SizedBox(height: 14),
        GlassCamera(width: 110),
        SizedBox(height: 26),
      ]);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthPanel(children: [
      const _Title(),
      Row(children: [
        Expanded(
            child: _RoleButton(
                label: 'RESIDENT',
                icon: Icons.person_outline_rounded,
                onTap: () => context.push('/login/resident'))),
        const SizedBox(width: 16),
        Expanded(
            child: _RoleButton(
                label: 'GUARDIAN',
                icon: Icons.shield_outlined,
                onTap: () => context.push('/login/guardian'))),
      ]),
    ]);
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .95,
      child: GlassCard(
        radius: 28,
        fill: AppColors.ivory.withValues(alpha: .9),
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .7),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x2A6877AD),
                    blurRadius: 10,
                    offset: Offset(0, 5)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: Icon(icon,
                size: 30, color: AppColors.primary.withValues(alpha: .8)),
          ),
          const SizedBox(height: 14),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 15)),
        ]),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  bool get _guardian => widget.role == UserRole.guardian;

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await ref
        .read(authProvider.notifier)
        .signIn(widget.role, _id.text.trim(), _email.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFB04060)),
      );
    }
    // On success the router redirect sends the user to /dashboard.
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final msg = await ref
        .read(authProvider.notifier)
        .signUp(widget.role, _id.text.trim(), _email.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (msg != null) {
      // Could be an info message (confirm email) or an error
      final isInfo = msg.toLowerCase().contains('confirm') ||
          msg.toLowerCase().contains('check your inbox');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isInfo ? const Color(0xFF3A8C6E) : const Color(0xFFB04060),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    // On immediate success (email confirm disabled) router redirects to /dashboard.
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPanel(children: [
      const _Title(),
      Form(
        key: _form,
        child: Column(children: [
          GlassTextField(
            controller: _id,
            hint: _guardian ? 'Guardian ID...' : 'Resident email or ID...',
            icon: _guardian ? Icons.shield_outlined : Icons.groups_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (_guardian
                    ? 'Enter your guardian ID'
                    : 'Enter your email or ID')
                : null,
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: _email,
            hint: 'your@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter a valid email address',
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: _pw,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => (v ?? '').length < 6
                ? 'Password must be at least 6 characters'
                : null,
          ),
          const SizedBox(height: 22),
          GlassButton(label: 'LOGIN', onPressed: _submit, loading: _busy),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _signUp,
            child: const Text(
              'No account? Sign Up',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            SupabaseService.instance.isAvailable
                ? 'Supabase Authentication active'
                : 'Demo sign-in · Supabase is not in this build (env.json)',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          TextButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/welcome'),
            child: const Text('Back'),
          ),
        ]),
      ),
    ]);
  }
}
