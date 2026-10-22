import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/n8n_api.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

class EventGalleryScreen extends ConsumerStatefulWidget {
  const EventGalleryScreen({super.key});
  @override
  ConsumerState<EventGalleryScreen> createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends ConsumerState<EventGalleryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // Pictures (Build Guide 9.1): only events that still have a photo.
    // "Score >= 4" = flagged photos (kept 7 days, or as evidence),
    // "Score < 4" = the 24-hour visitor log. Sample data has no photos.
    final events = ref.watch(eventsProvider);
    final all = SupabaseService.instance.isAvailable
        ? events.where((e) => e.hasLivePhoto).toList()
        : events;
    final list = switch (_tab) {
      1 => all.where((e) => e.snapshotKind == 'flagged' || (e.snapshotKind == null && e.score >= 4)).toList(),
      2 => all.where((e) => e.snapshotKind == 'visitor_log' || (e.snapshotKind == null && e.score < 4)).toList(),
      _ => all,
    };
    return PortalAppShell(
      tab: 1,
      child: PageBody(children: [
        const SectionLabel('Photos from the door camera'),
        GlassFilterTabs(
            labels: const ['All', 'Flagged', 'Visitors'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i)),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No photos here. Photos are only kept for flagged events and daytime visitors.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondary))))
        else
          Column(children: [
            for (final e in list) ...[
              _EventCard(e: e),
              const SizedBox(height: 14),
            ],
          ]),
        const RetentionNotice(),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.e});
  final SecurityEvent e;
  @override
  Widget build(BuildContext context) {
    final r = riskStyle(e.score);
    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/events/${e.id}'),
      child: Row(children: [
        SnapshotThumb(
            location: e.location,
            size: 84,
            tint: r.bg,
            imageUrl: e.hasLivePhoto ? e.snapshotUrl : null),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RiskScoreBadge(score: e.score, large: true),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(r.label,
                      style: TextStyle(
                          color: r.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15))),
            ]),
            const SizedBox(height: 8),
            Text(fmtStamp(e.timestamp),
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            if (photoCountdown(e) != null)
              Text(photoCountdown(e)!,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.secondary),
              const SizedBox(width: 3),
              Flexible(
                  child: Text(e.location,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.secondary))),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
      ]),
    );
  }
}

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  SecurityEvent? _fetched;
  bool _fetching = false;
  bool _busy = false;

  /// "Real concern" = confirm, "All fine" = dismiss (WF-02).
  Future<void> _answer(String action) async {
    setState(() => _busy = true);
    final res = await N8nApi.appAction(action, {'event_id': widget.id});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok
          ? (action == 'confirm'
              ? 'Saved as a real concern. The photo is kept as evidence.'
              : 'Saved as fine.')
          : res.message),
      backgroundColor: res.ok ? AppColors.success : AppColors.critical,
    ));
    // The live feed brings the new owner_response; refresh a fetched copy.
    if (res.ok && _fetched != null) {
      _fetched = await SupabaseService.instance.fetchEvent(widget.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final live =
        ref.watch(eventsProvider).where((x) => x.id == widget.id).firstOrNull;
    // An event older than the live list (e.g. from an old notification)
    if (live == null && _fetched == null && !_fetching) {
      _fetching = true;
      SupabaseService.instance.fetchEvent(widget.id).then((e) {
        if (mounted) setState(() => _fetched = e);
      });
    }
    final e = live ?? _fetched;
    return PortalAppShell(
      child: PageBody(children: [
        PageHeading(
            title: e == null ? 'Event' : e.location,
            description: e == null
                ? 'This event no longer exists.'
                : fmtStamp(e.timestamp)),
        if (e != null)
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: SnapshotThumb(
                      location: e.location,
                      size: 180,
                      tint: riskStyle(e.score).bg,
                      imageUrl: e.hasLivePhoto ? e.snapshotUrl : null)),
              if (photoCountdown(e) != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(photoCountdown(e)!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                RiskScoreBadge(score: e.score, large: true),
                const SizedBox(width: 10),
                Text(riskStyle(e.score).label,
                    style: TextStyle(
                        color: riskStyle(e.score).color,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
              ]),
              const SizedBox(height: 12),
              Text(
                  [
                    '${e.type} · ${e.location}',
                    ...e.tags,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 8),
              Text(e.description,
                  style: const TextStyle(fontSize: 16, height: 1.4)),
              if (e.reason != null &&
                  e.reason!.trim().isNotEmpty &&
                  e.reason != e.description) ...[
                const SizedBox(height: 8),
                Text(e.reason!,
                    style: const TextStyle(
                        color: AppColors.secondary, height: 1.4)),
              ],
              if (e.isPending) ...[
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: GlassButton(
                        label: 'Real concern',
                        loading: _busy,
                        onPressed: () => _answer('confirm')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                        label: 'All fine',
                        gradient: true,
                        loading: _busy,
                        onPressed: () => _answer('dismiss')),
                  ),
                ]),
              ] else if (e.snapshotKind == 'visitor_log' &&
                  e.hasLivePhoto &&
                  e.ownerResponse != 'confirmed') ...[
                const SizedBox(height: 18),
                GlassButton(
                    label: 'Keep as evidence',
                    loading: _busy,
                    onPressed: () => _answer('confirm')),
              ],
            ]),
          ),
      ]),
    );
  }
}
