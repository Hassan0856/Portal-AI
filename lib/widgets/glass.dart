import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// ───────────────────────── Background ─────────────────────────

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  static Widget _glow({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required double opacity,
  }) =>
      Positioned(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return ColoredBox(
      color: AppColors.bg,
      child: Stack(fit: StackFit.expand, children: [
        _glow(
            left: -60,
            top: -60,
            size: 420,
            color: AppColors.glowBlue,
            opacity: .9),
        _glow(
            left: -170,
            top: h * .38,
            size: 380,
            color: AppColors.glowIndigo,
            opacity: .30),
        _glow(
            right: -110,
            top: 60,
            size: 360,
            color: AppColors.purple,
            opacity: .55),
        _glow(
            right: -90,
            bottom: -50,
            size: 430,
            color: AppColors.lavender,
            opacity: .6),
        _glow(
            left: 40,
            bottom: -130,
            size: 360,
            color: AppColors.palePink,
            opacity: .35),
        child,
      ]),
    );
  }
}

// ───────────────────────── Glass primitives ─────────────────────────

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 30,
    this.onTap,
    this.fill,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(borderRadius: br, boxShadow: const [
        BoxShadow(
            color: Color(0x1A6877AD), blurRadius: 24, offset: Offset(0, 8)),
      ]),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: fill ?? const Color(0xA9F8F9FF),
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .95), width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: .35),
                      Colors.white.withValues(alpha: 0)
                    ],
                    stops: const [0, .35],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconBadge extends StatelessWidget {
  const GlassIconBadge({
    super.key,
    required this.icon,
    this.size = 54,
    this.color = AppColors.iconBlue,
    this.background = AppColors.paleLavender,
  });
  final IconData icon;
  final double size;
  final Color color, background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.4, -.5),
          radius: 1,
          colors: [Colors.white.withValues(alpha: .9), background],
          stops: const [0, .75],
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x336877AD), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Icon(icon, size: size * .48, color: color),
    );
  }
}

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.suffix,
  });
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputAction? textInputAction;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: const TextStyle(color: AppColors.primary, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.secondary),
        prefixIcon: Icon(icon, color: const Color(0xFF6376B5)),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.ivory.withValues(alpha: .85),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: b(Colors.white),
        focusedBorder: b(AppColors.peri, 1.8),
        errorBorder: b(AppColors.high),
        focusedErrorBorder: b(AppColors.high, 1.8),
        errorStyle: const TextStyle(color: AppColors.high),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = false,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool gradient, loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: gradient ? null : AppColors.navy,
        gradient: gradient ? AppColors.buttonGradient : null,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: (gradient ? AppColors.peri : AppColors.navy)
                .withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .6)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class GlassToggleSwitch extends StatelessWidget {
  const GlassToggleSwitch(
      {super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          height: 32,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: value
                ? const LinearGradient(
                    colors: [AppColors.softBlue, AppColors.peri])
                : null,
            color: value ? null : const Color(0xFFD5DBEA),
          ),
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x33172451),
                    blurRadius: 4,
                    offset: Offset(0, 2))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassFilterTabs extends StatelessWidget {
  const GlassFilterTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: i == selected ? AppColors.buttonGradient : null,
                color:
                    i == selected ? null : Colors.white.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x146877AD),
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Text(labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: i == selected ? Colors.white : AppColors.secondary,
                  )),
            ),
          ),
        ),
      ],
    ]);
  }
}

class RiskScoreBadge extends StatelessWidget {
  const RiskScoreBadge({super.key, required this.score, this.large = false});
  final int score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = riskStyle(score);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: s.bg.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Text('$score/10',
          style: TextStyle(
              color: s.color,
              fontWeight: FontWeight.w700,
              fontSize: large ? 20 : 14)),
    );
  }
}

class RetentionNotice extends StatelessWidget {
  const RetentionNotice({super.key});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(children: [
        Icon(Icons.schedule_rounded, color: AppColors.iconBlue),
        SizedBox(width: 12),
        Expanded(
          child: Text(
              'Visitor photos are deleted after 24 hours, flagged photos after 7 days.',
              style: TextStyle(
                  color: AppColors.secondary, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

/// A captured snapshot. Shows the photo from [imageUrl] (the signed link n8n
/// stored in events.snapshot_url) inside the same frame, or the icon
/// stand-in when there is no photo. Photos are never saved to the phone.
class SnapshotThumb extends StatelessWidget {
  const SnapshotThumb(
      {super.key,
      required this.location,
      this.size = 72,
      this.tint,
      this.imageUrl});
  final String location;
  final double size;
  final Color? tint;
  final String? imageUrl;

  static IconData iconFor(String loc) {
    final l = loc.toLowerCase();
    if (l.contains('living')) return Icons.weekend_outlined;
    if (l.contains('stair')) return Icons.stairs_outlined;
    if (l.contains('balcony')) return Icons.balcony_outlined;
    return Icons.door_front_door_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final c = tint ?? AppColors.paleLavender;
    final icon = Center(
      child: Icon(iconFor(location),
          size: size * .42, color: AppColors.iconBlue.withValues(alpha: .8)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        border: Border.all(color: Colors.white, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, AppColors.glowBlue],
        ),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? icon
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * .24 - 1.5),
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => icon,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : icon,
              ),
            ),
    );
  }
}

// ───────────────────────── Camera ─────────────────────────

class GlassCamera extends StatelessWidget {
  const GlassCamera({super.key, this.width = 120});
  final double width;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * .8), painter: _CameraPainter());
}

class _CameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .04, h * .24, w * .92, h * .68),
        Radius.circular(h * .2));
    final vf = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .2, h * .08, w * .24, h * .2),
        Radius.circular(h * .07));

    canvas.drawRRect(
      body.shift(Offset(0, h * .05)),
      Paint()
        ..color = const Color(0x286877AD)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .38),
          const Color(0xFFB7A5F1).withValues(alpha: .16)
        ],
      ).createShader(body.outerRect);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: .85);

    canvas.drawRRect(vf, fill);
    canvas.drawRRect(vf, edge);
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, edge);

    final c = Offset(w * .5, h * .58);
    final r = h * .29;
    // Lens rings are annuli, so the centre stays genuinely transparent.
    for (final (outer, inner, a) in [
      (r, r * .78, .22),
      (r * .7, r * .5, .16)
    ]) {
      final ring = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: outer)),
        Path()..addOval(Rect.fromCircle(center: c, radius: inner)),
      );
      canvas.drawPath(
          ring, Paint()..color = const Color(0xFF8D9AD6).withValues(alpha: a));
      canvas.drawPath(ring, edge..strokeWidth = 1.2);
    }
    canvas.drawCircle(
        c,
        r * .3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: .7));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * .88),
        3.5,
        1.0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: .9));
    canvas.drawCircle(Offset(w * .83, h * .38), h * .035,
        Paint()..color = Colors.white.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ───────────────────────── Header, drawer, shell ─────────────────────────

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => _curve(s);
  static Path _curve(Size s) => Path()
    ..lineTo(0, s.height - 30)
    ..quadraticBezierTo(s.width / 2, s.height + 12, s.width, s.height - 30)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> o) => false;
}

class _EdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, s.height - 31)
      ..quadraticBezierTo(s.width / 2, s.height + 10, s.width, s.height - 31);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .65),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
                color: Color(0x336877AD), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: AppColors.iconBlue, size: 22),
      ),
    );
  }
}

class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.onMenu,
    required this.onSearch,
    required this.onProfile,
    required this.roleLabel,
  });
  final VoidCallback onMenu, onSearch;
  final ValueChanged<String> onProfile;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _CurveClipper(),
      child: CustomPaint(
        foregroundPainter: _EdgePainter(),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, top + 10, 16, 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.softBlue,
                AppColors.lavender,
                AppColors.purple
              ],
            ),
          ),
          child: Row(children: [
            Semantics(
              button: true,
              label: 'Open menu',
              child: GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in [24.0, 18.0, 24.0]) ...[
                          Container(
                              width: w,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 4.5),
                        ],
                      ]),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text('PortalAI',
                      style: TextStyle(
                          color: Color(0xFFF8F8FF),
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.3)),
                ]),
              ),
            ),
            _CircleBtn(icon: Icons.search_rounded, onTap: onSearch),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: onProfile,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: AppColors.coolWhite,
              itemBuilder: (_) => [
                PopupMenuItem(
                    enabled: false,
                    child: Text(roleLabel,
                        style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600))),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
                const PopupMenuItem(
                    value: 'logout',
                    child: Text('Logout',
                        style: TextStyle(color: AppColors.high))),
              ],
              child: const _CircleBtn(icon: Icons.person_outline_rounded),
            ),
          ]),
        ),
      ),
    );
  }
}

class PortalNavigationDrawer extends ConsumerWidget {
  const PortalNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      (Icons.photo_library_outlined, 'Event Gallery', '/gallery'),
      (Icons.chat_bubble_outline_rounded, 'Message History', '/messages'),
      (Icons.help_outline_rounded, 'Help & About', '/help'),
      (Icons.settings_outlined, 'Settings', '/settings'),
    ];
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width.clamp(0, 340) * 1.0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: const Color(0xE8F4F7FF),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    const GlassIconBadge(icon: Icons.shield_outlined, size: 46),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('PortalAI',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                    IconButton.filled(
                      tooltip: 'Close menu',
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .8),
                          foregroundColor: AppColors.secondary),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  for (final it in items) ...[
                    GlassCard(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(it.$3);
                      },
                      child: Row(children: [
                        GlassIconBadge(icon: it.$1, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(it.$2,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600))),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.secondary),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Spacer(),
                  GlassCard(
                    radius: 28,
                    fill: const Color(0x99F3BBD0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onTap: () {
                      Navigator.of(context).pop();
                      ref.read(authProvider.notifier).logout();
                    },
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.high),
                          SizedBox(width: 10),
                          Text('Logout',
                              style: TextStyle(
                                  color: AppColors.high,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17)),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PortalAppShell extends ConsumerWidget {
  const PortalAppShell({
    super.key,
    required this.child,
    this.floatingActionButton,
  });
  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider);
    return Scaffold(
      drawer: const PortalNavigationDrawer(),
      resizeToAvoidBottomInset: true,
      floatingActionButton: floatingActionButton,
      body: AmbientBackground(
        child: Column(children: [
          Builder(
            builder: (ctx) => GlassHeader(
              roleLabel: role == UserRole.guardian ? 'Guardian' : 'Resident',
              onMenu: () => Scaffold.of(ctx).openDrawer(),
              onSearch: () => showGlobalSearch(ctx, ref),
              onProfile: (v) {
                if (v == 'settings') ctx.go('/settings');
                if (v == 'logout') ref.read(authProvider.notifier).logout();
              },
            ),
          ),
          Expanded(child: SafeArea(top: false, child: child)),
        ]),
      ),
    );
  }
}

// ───────────────────────── Shared page pieces ─────────────────────────

class BackNavigationButton extends StatelessWidget {
  const BackNavigationButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .75),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x266877AD),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ],
          ),
          child:
              const Icon(Icons.arrow_back_rounded, color: AppColors.iconBlue),
        ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(
      {super.key, required this.title, required this.description, this.icon});
  final String title, description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const BackNavigationButton(),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.secondary, height: 1.35)),
        ]),
      ),
      if (icon != null) ...[
        const SizedBox(width: 10),
        GlassIconBadge(icon: icon!, size: 50)
      ],
    ]);
  }
}

/// Standard scrolling page body used by every authenticated screen.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            children[i],
          ],
        ],
      );
}

Future<T?> showGlassSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xF4F8F8FC),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

void showGlobalSearch(BuildContext context, WidgetRef ref) {
  final events = ref.read(eventsProvider);
  showGlassSheet<void>(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      var q = '';
      return StatefulBuilder(builder: (ctx, set2) {
        final hits = events
            .where((e) =>
                q.isEmpty ||
                e.location.toLowerCase().contains(q) ||
                e.type.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q))
            .toList();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          GlassTextField(
            hint: 'Search events...',
            icon: Icons.search_rounded,
            onChanged: (v) => set2(() => q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: hits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No events match your search.',
                        style: TextStyle(color: AppColors.secondary)))
                : ListView(shrinkWrap: true, children: [
                    for (final e in hits)
                      ListTile(
                        leading: SnapshotThumb(location: e.location, size: 44),
                        title: Text('${e.location} · ${e.type}'),
                        subtitle: Text(fmtStamp(e.timestamp)),
                        trailing: RiskScoreBadge(score: e.score),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.push('/events/${e.id}');
                        },
                      ),
                  ]),
          ),
        ]);
      });
    });
  });
}
