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

/// Log in or sign up for the chosen role. Log in is email + password; the
/// name is asked once, at sign up.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role, this.signUp = false});
  final UserRole role;

  /// Open on the Sign up tab.
  final bool signUp;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  late bool _signUp = widget.signUp;
  bool _busy = false;

  /// Email waiting for its confirmation link (shows the check-email panel).
  String? _pendingEmail;

  /// Message shown inside the card: an error, or info when [_infoOk].
  String? _notice;
  bool _infoOk = false;

  /// The last login failed because the email isn't confirmed.
  bool _unconfirmed = false;

  bool get _guardian => widget.role == UserRole.guardian;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (_busy || signUp == _signUp) return;
    setState(() {
      _signUp = signUp;
      _notice = null;
      _unconfirmed = false;
    });
  }

  Future<void> _logIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _notice = null;
      _unconfirmed = false;
    });
    final err = await ref
        .read(authProvider.notifier)
        .signIn(widget.role, _email.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = err;
      _infoOk = false;
      _unconfirmed = err == SupabaseService.emailNotConfirmedMessage;
    });
    // On success the router redirect sends the user to /dashboard.
  }

  Future<void> _createAccount() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final res = await ref.read(authProvider.notifier).signUp(
        widget.role, _name.text.trim(), _email.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (res.outcome) {
        case SignUpOutcome.checkEmail:
          _pendingEmail = _email.text.trim();
        case SignUpOutcome.error:
          _notice = res.message;
          _infoOk = false;
        case SignUpOutcome.signedIn:
          break; // the router redirect takes over
      }
    });
  }

  Future<void> _resend(String email) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    final err =
        await ref.read(authProvider.notifier).resendConfirmation(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _infoOk = err == null;
      _notice = err ?? 'Email sent again to $email.';
    });
  }

  Widget _noticeBox() => _notice == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            radius: 20,
            fill: (_infoOk ? const Color(0xFF3A8C6E) : const Color(0xFFB04060))
                .withValues(alpha: .12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(
                  _infoOk
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color: _infoOk
                      ? const Color(0xFF3A8C6E)
                      : const Color(0xFFB04060)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_notice!,
                    style: const TextStyle(fontSize: 13.5, height: 1.35)),
              ),
            ]),
          ),
        );

  Widget _back() => TextButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/welcome'),
        child: const Text('Back'),
      );

  @override
  Widget build(BuildContext context) {
    final pending = _pendingEmail;
    if (pending != null) return _checkEmail(pending);

    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return _AuthPanel(children: [
      const _Title(),
      Text(_guardian ? 'Guardian' : 'Resident',
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 15,
              color: AppColors.secondary)),
      const SizedBox(height: 14),
      GlassFilterTabs(
        labels: const ['Log in', 'Sign up'],
        selected: _signUp ? 1 : 0,
        onChanged: (i) => _setMode(i == 1),
      ),
      const SizedBox(height: 20),
      Form(
        key: _form,
        child: Column(children: [
          if (_signUp) ...[
            GlassTextField(
              controller: _name,
              hint: 'Your name',
              icon: _guardian ? Icons.shield_outlined : Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
          ],
          GlassTextField(
            controller: _email,
            hint: 'your@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => emailOk.hasMatch((v ?? '').trim())
                ? null
                : 'Enter a valid email address',
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: _pw,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction:
                _signUp ? TextInputAction.next : TextInputAction.done,
            onSubmitted: _signUp ? null : (_) => _logIn(),
            validator: (v) => (v ?? '').length < 6
                ? 'Password must be at least 6 characters'
                : null,
          ),
          if (_signUp) ...[
            const SizedBox(height: 14),
            GlassTextField(
              controller: _pw2,
              hint: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createAccount(),
              validator: (v) =>
                  v != _pw.text ? 'Passwords do not match' : null,
            ),
          ],
          const SizedBox(height: 22),
          _noticeBox(),
          if (_unconfirmed && !_signUp) ...[
            TextButton(
              onPressed: _busy ? null : () => _resend(_email.text.trim()),
              child: const Text('Resend confirmation email'),
            ),
            const SizedBox(height: 6),
          ],
          GlassButton(
            label: _signUp ? 'SIGN UP' : 'LOG IN',
            onPressed: _signUp ? _createAccount : _logIn,
            loading: _busy,
          ),
          const SizedBox(height: 10),
          Text(
            SupabaseService.instance.isAvailable
                ? 'Supabase Authentication active'
                : 'Demo sign-in · Supabase is not in this build (env.json)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          _back(),
        ]),
      ),
    ]);
  }

  /// After sign up with "Confirm email" on.
  Widget _checkEmail(String email) {
    return _AuthPanel(children: [
      const _Title(),
      const Icon(Icons.mark_email_unread_outlined,
          size: 44, color: AppColors.primary),
      const SizedBox(height: 14),
      const Text('Check your email',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text(
        'We sent a link to $email. Open it on this phone and tap the link '
        'to finish. PortalAI opens and signs you in.',
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: AppColors.secondary, fontSize: 14.5, height: 1.4),
      ),
      const SizedBox(height: 22),
      _noticeBox(),
      GlassButton(
        label: 'RESEND EMAIL',
        icon: Icons.refresh_rounded,
        loading: _busy,
        onPressed: () => _resend(email),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _pendingEmail = null;
                  _signUp = false;
                  _notice = null;
                }),
        child: const Text('Back to Log in'),
      ),
    ]);
  }
}
