import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/link_service.dart';
import '../widgets/glass.dart';

/// Family links. A resident shares a 6-digit code; a guardian enters it.
/// Only linked guardians see the resident's door activity and get alerts.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});
  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _code = TextEditingController();
  String? _shared;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _snack(String text, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: ok ? AppColors.success : AppColors.critical,
    ));
  }

  Future<void> _makeCode() async {
    setState(() => _busy = true);
    final r = await LinkService.instance.createCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _shared = r.code ?? _shared;
    });
    if (r.error != null) _snack(r.error!, ok: false);
  }

  Future<void> _redeem() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final err = await LinkService.instance.redeemCode(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return _snack(err, ok: false);
    _code.clear();
    ref.invalidate(linksProvider);
    _snack('Linked. You will now see this resident’s activity and alerts.');
  }

  Future<void> _remove(LinkedPerson p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${p.displayName}?'),
        content: Text(p.role == UserRole.resident
            ? 'You will stop seeing ${p.displayName}’s activity and alerts.'
            : '${p.displayName} will stop seeing your activity and alerts.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (yes != true) return;
    final err = await LinkService.instance.remove(p.userId);
    if (!mounted) return;
    if (err != null) return _snack(err, ok: false);
    ref.invalidate(linksProvider);
    _snack('Removed.');
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = ref.watch(authProvider) == UserRole.guardian;
    final links = ref.watch(linksProvider);
    return PortalAppShell(
      child: PageBody(children: [
        PageHeading(
          title: 'Family links',
          description: isGuardian
              ? 'The residents whose door you look after.'
              : 'The guardians who get your alerts.',
          icon: Icons.family_restroom_rounded,
        ),
        if (isGuardian) _enterCode() else _shareCode(),
        SectionLabel(isGuardian ? 'Linked residents' : 'Linked guardians'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: links.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'Could not load your links. If this keeps happening, the '
                  'linking SQL has not been run in Supabase yet.',
                  style: const TextStyle(color: AppColors.secondary)),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        isGuardian
                            ? 'No residents yet. Enter a code above.'
                            : 'No guardians yet. Share a code with a family member.',
                        style: const TextStyle(color: AppColors.secondary)),
                  )
                : Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const GlassDivider(),
                      GlassListRow(
                        icon: Icons.person_outline_rounded,
                        title: list[i].displayName,
                        subtitle: list[i].role == UserRole.resident
                            ? 'Resident'
                            : 'Guardian',
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.link_off_rounded,
                              color: AppColors.secondary),
                          onPressed: () => _remove(list[i]),
                        ),
                      ),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _shareCode() => GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add a guardian',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Make a code and give it to your family member. They enter it '
              'in their guardian app. The code works once, for 24 hours.',
              style: TextStyle(color: AppColors.secondary, height: 1.4)),
          if (_shared != null) ...[
            const SizedBox(height: 16),
            Center(
              child: SelectableText(
                  '${_shared!.substring(0, 3)} ${_shared!.substring(3)}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.primary)),
            ),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _shared!));
                  _snack('Code copied.');
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          GlassButton(
            label: _shared == null ? 'Make a code' : 'Make a new code',
            icon: Icons.pin_outlined,
            gradient: true,
            loading: _busy,
            onPressed: _makeCode,
          ),
        ]),
      );

  Widget _enterCode() => GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Link to a resident',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Enter the 6-digit code from the resident’s app '
              '(Settings → Family links).',
              style: TextStyle(color: AppColors.secondary, height: 1.4)),
          const SizedBox(height: 14),
          GlassTextField(
            controller: _code,
            hint: '6-digit code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _redeem(),
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'Link',
            icon: Icons.link_rounded,
            gradient: true,
            loading: _busy,
            onPressed: _redeem,
          ),
        ]),
      );
}
