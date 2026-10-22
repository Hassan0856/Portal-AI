/// Sample data, shown only when the build has no Supabase (demo mode).
import '../models/models.dart';

final mockEvents = <SecurityEvent>[
  SecurityEvent(
    id: '1',
    score: 9,
    location: 'Living Room',
    timestamp: DateTime(2026, 10, 12, 21, 42),
    type: 'Visitor',
    description:
        'An unrecognised person was detected inside the living room. Check the snapshot and contact your guardian if needed.',
  ),
  SecurityEvent(
    id: '2',
    score: 5,
    location: 'Main Entrance',
    timestamp: DateTime(2026, 10, 12, 21, 18),
    type: 'Visitor',
    description: 'A person lingered at the main entrance for several seconds.',
  ),
  SecurityEvent(
    id: '3',
    score: 2,
    location: 'Staircase',
    timestamp: DateTime(2026, 10, 12, 21, 12),
    type: 'Motion',
    description: 'Routine movement on the staircase.',
  ),
  SecurityEvent(
    id: '4',
    score: 2,
    location: 'Balcony',
    timestamp: DateTime(2026, 10, 12, 21, 42),
    type: 'Motion',
    description: 'Light movement on the balcony, consistent with wind.',
  ),
];

final mockMessages = <AppMessage>[
  AppMessage(
    id: 'm1',
    kind: MessageKind.highRisk,
    title: 'High Risk Alert',
    score: 9,
    location: 'Front Door',
    timestamp: DateTime(2026, 10, 12, 21, 42),
    description:
        'Unusual activity detected at your door. Please check the snapshot.',
  ),
  AppMessage(
    id: 'm2',
    kind: MessageKind.activity,
    title: 'Activity Detected',
    score: 5,
    location: 'Main Entrance',
    timestamp: DateTime(2026, 10, 12, 19, 18),
    description: 'Motion detected. No immediate threat.',
  ),
  AppMessage(
    id: 'm3',
    kind: MessageKind.system,
    title: 'System Update',
    timestamp: DateTime(2026, 10, 11, 11, 5),
    description: 'The app has been updated to version 2.1.0.',
  ),
  AppMessage(
    id: 'm4',
    kind: MessageKind.lowRisk,
    title: 'Low Risk Alert',
    score: 2,
    location: 'Staircase',
    timestamp: DateTime(2026, 10, 11, 16, 12),
    description: 'Routine activity detected.',
  ),
  AppMessage(
    id: 'm5',
    kind: MessageKind.general,
    title: 'General Message',
    timestamp: DateTime(2026, 10, 10, 9, 20),
    description: 'Welcome to PORTAL AI. Stay safe!',
  ),
];
