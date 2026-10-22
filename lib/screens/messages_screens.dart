import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/glass.dart';

class _Accent {
  const _Accent(this.icon, this.color, this.bg);
  final IconData icon;
  final Color color, bg;
}

_Accent accentFor(MessageKind k) => switch (k) {
      MessageKind.highRisk => const _Accent(Icons.notifications_active_outlined,
          AppColors.high, Color(0xFFF3BBD0)),
      MessageKind.activity => const _Accent(
          Icons.directions_run_rounded, Color(0xFFD9A93A), Color(0xFFF8EDB7)),
      MessageKind.system => const _Accent(Icons.system_update_alt_rounded,
          AppColors.iconBlue, Color(0xFFC8D9FF)),
      MessageKind.lowRisk => const _Accent(Icons.check_circle_outline_rounded,
          AppColors.success, Color(0xFFC9F0DE)),
      MessageKind.general => const _Accent(Icons.chat_bubble_outline_rounded,
          AppColors.lavender, AppColors.paleLavender),
    };

class MessageHistoryScreen extends ConsumerStatefulWidget {
  const MessageHistoryScreen({super.key});
  @override
  ConsumerState<MessageHistoryScreen> createState() =>
      _MessageHistoryScreenState();
}

class _MessageHistoryScreenState extends ConsumerState<MessageHistoryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(messagesProvider);
    final list = switch (_tab) {
      1 => all.where((m) => m.isHighRisk).toList(),
      2 => all.where((m) => !m.isHighRisk).toList(),
      _ => all,
    };
    return PortalAppShell(
      tab: 2,
      child: PageBody(children: [
        const SectionLabel('Notifications from the last 30 days'),
        GlassFilterTabs(
            labels: const ['All', 'Alerts', 'Other'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i)),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No messages in this category.',
                      style: TextStyle(color: AppColors.secondary))))
        else
          Column(children: [
            for (final m in list) ...[
              _MessageCard(m: m),
              const SizedBox(height: 14),
            ],
          ]),
      ]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.m});
  final AppMessage m;
  @override
  Widget build(BuildContext context) {
    final a = accentFor(m.kind);
    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.all(14),
      // A notification about an event opens the event (Build Guide 9.1)
      onTap: () => context.push(
          m.eventId == null ? '/messages/${m.id}' : '/events/${m.eventId}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassIconBadge(
            icon: a.icon, size: 46, color: a.color, background: a.bg),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(m.title,
                      style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: m.isHighRisk
                              ? AppColors.high
                              : AppColors.primary))),
              if (m.score != null) RiskScoreBadge(score: m.score!),
            ]),
            const SizedBox(height: 4),
            Text(fmtWhen(m.timestamp),
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            if (m.location != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 3),
                  Text(m.location!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.secondary)),
                ]),
              ),
            const SizedBox(height: 6),
            Text(m.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.secondary, height: 1.35)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
      ]),
    );
  }
}

class MessageDetailScreen extends ConsumerWidget {
  const MessageDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(messagesProvider).where((x) => x.id == id).firstOrNull;
    return PortalAppShell(
      child: PageBody(children: [
        PageHeading(
            title: m?.title ?? 'Message',
            description: m == null
                ? 'This message no longer exists.'
                : fmtStamp(m.timestamp)),
        if (m != null)
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.score != null) ...[
                Row(children: [
                  RiskScoreBadge(score: m.score!, large: true),
                  const SizedBox(width: 10),
                  Text(riskStyle(m.score!).label,
                      style: const TextStyle(fontWeight: FontWeight.w600))
                ]),
                const SizedBox(height: 12),
              ],
              if (m.location != null)
                Text('Location: ${m.location}',
                    style: const TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 8),
              Text(m.description,
                  style: const TextStyle(fontSize: 16, height: 1.4)),
            ]),
          ),
      ]),
    );
  }
}
