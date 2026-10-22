import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

/// Home: is everything all right, what needs an answer, and what happened
/// lately. Nothing else.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _recentCount = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider);
    final events = ref.watch(eventsProvider);
    final links = ref.watch(linksProvider);
    final pending = events.where((e) => e.isPending).toList();
    final recent = events.take(_recentCount).toList();

    // A guardian only sees a household after linking to its resident.
    final needsLink = role == UserRole.guardian &&
        SupabaseService.instance.isAvailable &&
        links.hasValue &&
        links.value!.isEmpty;

    return PortalAppShell(
      tab: 0,
      child: PageBody(children: [
        if (needsLink)
          const _LinkPrompt()
        else
          _StatusCard(pending: pending.length, last: events.firstOrNull),
        if (pending.isNotEmpty) ...[
          const SectionLabel('Needs your answer'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [
              for (var i = 0; i < pending.length; i++) ...[
                if (i > 0) const GlassDivider(),
                EventRow(e: pending[i]),
              ],
            ]),
          ),
        ],
        if (!needsLink) ...[
          SectionLabel('Recent activity',
              action: 'Pictures', onAction: () => context.go('/gallery')),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: recent.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No door activity yet.',
                          style: TextStyle(color: AppColors.secondary)),
                    ),
                  )
                : Column(children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const GlassDivider(),
                      EventRow(e: recent[i]),
                    ],
                  ]),
          ),
        ],
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.pending, required this.last});
  final int pending;
  final SecurityEvent? last;

  @override
  Widget build(BuildContext context) {
    final alert = pending > 0;
    return GlassCard(
      child: Row(children: [
        GlassIconBadge(
          icon: alert ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
          color: alert ? AppColors.high : AppColors.success,
          background: alert ? const Color(0xFFF3BBD0) : const Color(0xFFC9F0DE),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                alert
                    ? '$pending alert${pending == 1 ? '' : 's'} to answer'
                    : 'All quiet',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: alert ? AppColors.high : AppColors.primary)),
            const SizedBox(height: 4),
            Text(
                last == null
                    ? 'No door activity recorded yet.'
                    : 'Last activity ${fmtWhen(last!.timestamp)} · ${last!.location}',
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.secondary, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _LinkPrompt extends StatelessWidget {
  const _LinkPrompt();
  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            GlassIconBadge(icon: Icons.link_rounded),
            SizedBox(width: 16),
            Expanded(
              child: Text('Link to a resident',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          const Text(
              'Ask the resident for the 6-digit code in their app '
              '(Settings → Family links). You will then see their door '
              'activity and get their alerts.',
              style: TextStyle(color: AppColors.secondary, height: 1.4)),
          const SizedBox(height: 16),
          GlassButton(
            label: 'Enter code',
            icon: Icons.pin_outlined,
            gradient: true,
            onPressed: () => context.push('/settings/family'),
          ),
        ]),
      );
}
