import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../widgets/glass.dart';

// Text from Build Guide v4, 9.6.
const _aboutText =
    'Portal AI watches one door. A motion sensor wakes a small camera, which takes one picture. An AI describes the picture in words and compares it with the household\u2019s usual routine. You only get a notification when something is unusual.\n\n'
    'Two kinds of login. Resident: the person who lives at home; sees everything and gets ordinary notifications. Guardian: children or relatives; sees everything, and alerts at or above the threshold also ring an SOS alarm with a flashing light until you tap "I\u2019ve seen it".';
const _howText =
    'Motion is detected → one picture is taken → the AI describes it in words and compares it with the usual routine → you get a notification only when something is unusual.\n\n'
    'What raises the score: door activity in quiet hours (at least 6; 8 in Shop mode); loitering, 3 or more triggers within 10 minutes by someone other than the resident (at least 5); a visitor at an hour when the routine normally has none (at least 4).';
const _privacyText =
    'The camera faces the doorway only. The resident\u2019s own comings and goings are kept as text, never as photos. Daytime visitor photos are kept for 24 hours, then deleted, with no notification. Flagged photos are deleted after 7 days unless you tap "Real concern". Recognition only answers "same person as a reference photo: yes or no"; it never guesses who anyone else is, and you can delete a reference photo any time. Messages are deleted 30 days after they arrive.';

// Card previews (the full text opens on tap)
const _aboutShort =
    'Portal AI watches one door and only notifies you when something is unusual.';
const _howShort =
    'Motion is detected → one picture is taken → the AI compares it with the usual routine → you get an alert (if needed).';
const _privacyShort =
    'Visitor photos are kept 24 hours, flagged photos 7 days. Messages are deleted after 30 days.';

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

  void _detail(BuildContext context, String title, Widget body) {
    showGlassSheet<void>(
      context,
      (ctx) => SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              body,
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const scale = [
      ('1–3', 'Low', 0, 'Normal. Matches the routine. Logged as text. No notification.'),
      (
        '4–6',
        'Moderate',
        1,
        'Unusual. Photo kept for 7 days in Pictures. Notification from 5 (4 in Shop mode).'
      ),
      ('7–9', 'High', 2, 'Concern. Notification with photo. "Please call" when it looks urgent.'),
      ('10', 'Critical', 3, 'Emergency, for example a person on the floor or a forced door.'),
    ];
    return PortalAppShell(
      child: PageBody(children: [
        const PageHeading(
          title: 'Help & About',
          description:
              'Learn how PORTAL AI works, what the risk scale means, and more.',
          icon: Icons.help_outline_rounded,
        ),
        _InfoCard(
          icon: Icons.info_outline_rounded,
          title: 'About PORTAL AI',
          text: _aboutShort,
          onTap: () => _detail(context, 'About PORTAL AI',
              const Text(_aboutText, style: TextStyle(height: 1.45))),
        ),
        _InfoCard(
          icon: Icons.settings_suggest_outlined,
          title: 'How It Works',
          text: _howShort,
          onTap: () => _detail(context, 'How It Works',
              const Text(_howText, style: TextStyle(height: 1.45))),
        ),
        _InfoCard(
          icon: Icons.shield_outlined,
          title: 'Understanding the Risk Scale',
          text: 'Learn what each score means and see real examples.',
          onTap: () => _detail(
            context,
            'Understanding the Risk Scale',
            Column(children: [
              for (final s in scale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    _ScoreChip(range: s.$1, level: s.$3),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('${s.$2}: ${s.$4}',
                            style: const TextStyle(height: 1.35))),
                  ]),
                ),
            ]),
          ),
          extra: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in scale)
                _ScoreChip(range: s.$1, label: s.$2, level: s.$3),
            ]),
          ),
        ),
        _InfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy & Data Retention',
          text: _privacyShort,
          onTap: () => _detail(context, 'Privacy & Data Retention',
              const Text(_privacyText, style: TextStyle(height: 1.45))),
        ),
        const RetentionNotice(),
      ]),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.range, required this.level, this.label});
  final String range;
  final String? label;
  final int level;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.heat[level],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Text(label == null ? range : '$range · $label',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.onTap,
      this.extra});
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  final Widget? extra;
  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassIconBadge(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(text,
                  style: const TextStyle(
                      color: AppColors.secondary, fontSize: 14.5, height: 1.4)),
              if (extra != null) extra!,
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
        ]),
      );
}
