import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum UserRole { resident, guardian }

enum MessageKind { highRisk, activity, system, lowRisk, general }

class RiskStyle {
  const RiskStyle(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;
}

RiskStyle riskStyle(int score) {
  if (score >= 10) {
    return const RiskStyle('Critical', AppColors.critical, Color(0xFFF3BBD0));
  }
  if (score >= 7) {
    return const RiskStyle('High Risk', AppColors.high, Color(0xFFF3BBD0));
  }
  if (score >= 4) {
    return const RiskStyle('Moderate', Color(0xFFD9A93A), Color(0xFFF8EDB7));
  }
  return const RiskStyle('Low', AppColors.success, Color(0xFFC9F0DE));
}

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.score,
    required this.location,
    required this.timestamp,
    required this.type,
    required this.description,
    this.eventType = 'motion',
    this.reason,
    this.recommendedAction,
    this.knownLabels,
    this.ruleFlags,
    this.residentPresent,
    this.hasVisitor,
    this.snapshotKind,
    this.snapshotUrl,
    this.snapshotExpiresAt,
    this.ownerResponse = 'none',
    this.isSimulated = false,
  });
  final String id;
  final int score;
  final String location;
  final DateTime timestamp;
  final String type;
  final String description;

  // v4 `events` columns (Build Guide 3.1). Optional so the sample data still works.
  final String eventType; // motion | inactivity | device_offline
  final String? reason;
  final String? recommendedAction;
  final String? knownLabels;
  final String? ruleFlags;
  final bool? residentPresent;
  final bool? hasVisitor;
  final String? snapshotKind; // flagged | visitor_log
  final String? snapshotUrl;
  final DateTime? snapshotExpiresAt;
  final String ownerResponse; // none | pending | confirmed | dismissed
  final bool isSimulated;

  bool get isPending => ownerResponse == 'pending';

  /// A photo that can still be shown (the hourly cleanup may not have run yet).
  bool get hasLivePhoto =>
      snapshotUrl != null &&
      (snapshotExpiresAt == null ||
          snapshotExpiresAt!.isAfter(DateTime.now()));

  /// Tags from the v4 spec: Resident, known people, Visitor, rule flags, simulated.
  List<String> get tags => [
        if (residentPresent == true) 'Resident',
        if (knownLabels != null && knownLabels!.trim().isNotEmpty)
          knownLabels!.trim(),
        if (hasVisitor == true) 'Visitor',
        if (ruleFlags != null)
          for (final f in ruleFlags!.split(','))
            if (f.trim().isNotEmpty) f.trim().replaceAll('_', ' '),
        if (isSimulated) 'simulated',
      ];
}

/// "Deletes in 13 h" / "Kept as evidence" for a photo, or null without one.
String? photoCountdown(SecurityEvent e) {
  if (e.snapshotUrl == null) return null;
  if (e.ownerResponse == 'confirmed') return 'Kept as evidence';
  final exp = e.snapshotExpiresAt;
  if (exp == null) return null;
  final left = exp.difference(DateTime.now());
  if (left.isNegative) return 'Deleting now';
  if (left.inHours >= 48) return 'Deletes in ${left.inDays} days';
  if (left.inHours >= 1) return 'Deletes in ${left.inHours} h';
  return 'Deletes in ${left.inMinutes} min';
}

class AppMessage {
  const AppMessage({
    required this.id,
    required this.kind,
    required this.title,
    required this.timestamp,
    required this.description,
    this.score,
    this.location,
    this.eventId,
  });
  final String id;
  final MessageKind kind;
  final String title;
  final DateTime timestamp;
  final String description;
  final int? score;
  final String? location;

  /// The event this notification was about (messages.event_id), if any.
  final String? eventId;
  bool get isHighRisk => kind == MessageKind.highRisk;
}

class AppSettings {
  const AppSettings({this.systemUpdates = true, this.activityAlerts = true});
  final bool systemUpdates;
  final bool activityAlerts;
  AppSettings copyWith({bool? systemUpdates, bool? activityAlerts}) =>
      AppSettings(
        systemUpdates: systemUpdates ?? this.systemUpdates,
        activityAlerts: activityAlerts ?? this.activityAlerts,
      );
}

class StatItem {
  const StatItem({
    required this.label,
    required this.value,
    required this.trend,
    required this.positive,
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
  });
  final String label, value, trend;
  final bool positive;
  final IconData icon;
  final Color badgeColor, iconColor;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String fmtStamp(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${fmtDate(d)} · ${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ap';
}
