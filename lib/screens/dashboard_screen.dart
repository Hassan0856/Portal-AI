import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/emergency_widgets.dart';
import '../widgets/glass.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _query = TextEditingController();
  DateTime? _from, _to;
  String _type = 'All types';
  int _minScore = 1;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime(2026, 10, 12),
      firstDate: DateTime(2026),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked == null || !mounted) return;
    final f = isFrom ? picked : _from;
    final t = isFrom ? _to : picked;
    if (f != null && t != null && f.isAfter(t)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The start date must be on or before the end date.')));
      return;
    }
    setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _pickType() async {
    final v = await showGlassSheet<String>(
        context,
        (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Event type',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final t in eventTypes)
                ListTile(
                  title: Text(t),
                  trailing: t == _type
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.iconBlue)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(t),
                ),
            ]));
    if (v != null) setState(() => _type = v);
  }

  Future<void> _pickScore() async {
    final v = await showGlassSheet<int>(
        context,
        (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Minimum risk score',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var n = 1; n <= 10; n++)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: n == _minScore,
                    onSelected: (_) => Navigator.of(ctx).pop(n),
                  ),
              ]),
            ]));
    if (v != null) setState(() => _minScore = v);
  }

  List<SecurityEvent> _filtered() {
    final q = _query.text.trim().toLowerCase();
    return ref.read(eventsProvider).where((e) {
      final day =
          DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      return (q.isEmpty ||
              e.location.toLowerCase().contains(q) ||
              e.type.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q)) &&
          (_from == null || !day.isBefore(_from!)) &&
          (_to == null || !day.isAfter(_to!)) &&
          (_type == 'All types' || e.type == _type) &&
          e.score >= _minScore;
    }).toList();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final hits = _filtered();
    showGlassSheet<void>(
        context,
        (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${hits.length} matching event${hits.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Flexible(
                child: hits.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No events match these filters. Try a wider date range or a lower minimum score.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.secondary)))
                    : ListView(shrinkWrap: true, children: [
                        for (final e in hits)
                          ListTile(
                            leading:
                                SnapshotThumb(location: e.location, size: 46),
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
            ]));
  }

  void _filterOptions() {
    showGlassSheet<void>(
        context,
        (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Filter options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Reset filters',
                gradient: true,
                onPressed: () {
                  setState(() {
                    _query.clear();
                    _from = _to = null;
                    _type = 'All types';
                    _minScore = 1;
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final isGuardian = ref.watch(authProvider) == UserRole.guardian;
    return PortalAppShell(
      child: PageBody(children: [
        if (isGuardian) const EmergencyBanner(),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _CardHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Routine Activity Heatmap',
              description:
                  'Shows how often activity is detected in each time slot.\n(Not related to AI risk score.)',
            ),
            const SizedBox(height: 18),
            ActivityHeatmap(levels: ref.watch(heatmapProvider)),
            const SizedBox(height: 14),
            const ActivityLegend(),
          ]),
        ),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _CardHeader(
              icon: Icons.filter_alt_outlined,
              title: 'Advanced Event Filters',
              description: 'Search and filter events using multiple criteria.',
            ),
            const SizedBox(height: 18),
            GlassTextField(
              controller: _query,
              hint: 'Search events...',
              icon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              suffix: IconButton(
                tooltip: 'Filter options',
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF6376B5)),
                onPressed: _filterOptions,
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: FilterControl(
                      icon: Icons.calendar_today_outlined,
                      label: 'From',
                      value: _from == null ? 'Select date' : fmtDate(_from!),
                      isSet: _from != null,
                      onTap: () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilterControl(
                      icon: Icons.calendar_today_outlined,
                      label: 'To',
                      value: _to == null ? 'Select date' : fmtDate(_to!),
                      isSet: _to != null,
                      onTap: () => _pickDate(false))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: FilterControl(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Event type',
                      value: _type,
                      isSet: _type != 'All types',
                      onTap: _pickType)),
              const SizedBox(width: 12),
              Expanded(
                  child: FilterControl(
                      icon: Icons.speed_rounded,
                      label: 'Min score',
                      value: '$_minScore – 10',
                      isSet: _minScore > 1,
                      onTap: _pickScore)),
            ]),
            const SizedBox(height: 18),
            GlassButton(
                label: 'Search',
                icon: Icons.search_rounded,
                gradient: true,
                onPressed: _search),
          ]),
        ),
        LayoutBuilder(builder: (context, c) {
          final cards = [for (final s in stats) StatisticCard(item: s)];
          if (c.maxWidth >= 640) {
            return Row(children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: cards[i]),
              ],
            ]);
          }
          return Column(children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              cards[i],
            ],
          ]);
        }),
      ]),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(
      {required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GlassIconBadge(icon: icon),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  fontSize: 14.5, color: AppColors.secondary, height: 1.35)),
        ]),
      ),
    ]);
  }
}
