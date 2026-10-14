import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/app_router.dart';
import '../models/models.dart';

// Push notifications through Firebase Cloud Messaging (Build Guide v4, 4.4,
// 4.5, 9.2 and 9.5). n8n WF-00 sends to topics; the app only subscribes.
//
//   portal_resident  resident login: ordinary notifications
//   portal_guardian  guardian login: ordinary notifications, plus a data-only
//                    SOS message for Stage 2 alerts and inactivity
//   portal_status    optional: sensor offline   (Settings: "System updates")
//   portal_digest    optional: daily digest     (Settings: "Activity alerts")
//
// Firebase is used for push only. Push, the SOS alarm and the flashlight are
// Android-only; on web every method here returns without doing anything.

const kTopicResident = 'portal_resident';
const kTopicGuardian = 'portal_guardian';
const kTopicStatus = 'portal_status';
const kTopicDigest = 'portal_digest';

const kSosId = 999;

const kAlertsChannel = AndroidNotificationChannel(
  'portal_alerts',
  'Door alerts',
  description: 'Unusual door activity, inactivity and sensor problems',
  importance: Importance.max,
);

const kGeneralChannel = AndroidNotificationChannel(
  'portal_general',
  'Digests and sensor status',
  importance: Importance.defaultImportance,
);

// Channel settings are fixed once created on a phone. If you change the
// sound or importance, uninstall the app (or rename the id) before testing.
const kSosChannel = AndroidNotificationChannel(
  'portal_sos',
  'SOS alarm (guardians)',
  description: 'Loud alarm for alerts over the threshold',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('sos_alarm'), // res/raw/sos_alarm.*
  audioAttributesUsage: AudioAttributesUsage.alarm, // rings even on silent
);

/// Runs in a background isolate when a push arrives and the app is in the
/// background or closed. Ordinary notifications are drawn by Android itself.
/// SOS messages carry data only, so the app rings the alarm itself.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['sos'] == '1') await showSosAlarm(message.data);
}

/// Shows the full-screen, looping SOS alarm notification.
/// Works in the background isolate too.
Future<void> showSosAlarm(Map<String, dynamic> data) async {
  if (kIsWeb) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kSosChannel);
  await plugin.show(
    id: kSosId,
    title: 'SOS · ${data['title'] ?? 'Door alert'}',
    body: data['body'] as String?,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        kSosChannel.id,
        kSosChannel.name,
        channelDescription: kSosChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true, // opens over the lock screen
        sound: const RawResourceAndroidNotificationSound('sos_alarm'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: loop
        ongoing: true,
        autoCancel: false,
      ),
    ),
    payload: _sosPayload(data),
  );
}

/// The notification payload carries the SOS data so a tap can rebuild it.
String _sosPayload(Map<String, dynamic> data) => [
      '${data['event_id'] ?? ''}',
      '${data['title'] ?? ''}',
      '${data['body'] ?? ''}',
      '${data['image_url'] ?? ''}',
    ].join('\u001f');

Map<String, String> _sosFromPayload(String? payload) {
  final p = (payload ?? '').split('\u001f');
  String at(int i) => i < p.length ? p[i] : '';
  return {
    'sos': '1',
    'event_id': at(0),
    'title': at(1),
    'body': at(2),
    'image_url': at(3),
  };
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  /// Shows a SnackBar for pushes that arrive while the app is open
  /// (Android does not draw them then).
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;
  bool get isAvailable => !kIsWeb && _initialized;

  final _local = FlutterLocalNotificationsPlugin();

  /// Starts Firebase from android/app/google-services.json, creates the three
  /// notification channels and listens for pushes. Never throws: without
  /// Firebase the rest of the app still works.
  Future<void> initialize() async {
    if (kIsWeb) return; // FCM topics and the alarm are Android-only
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('[FirebaseService] Firebase did not start. Is '
          'android/app/google-services.json the real file from your '
          'Firebase project? $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(kAlertsChannel);
      await android?.createNotificationChannel(kGeneralChannel);
      await android?.createNotificationChannel(kSosChannel);

      await _local.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          if (r.id == kSosId) openSos(_sosFromPayload(r.payload));
        },
      );

      await FirebaseMessaging.instance.requestPermission(); // Android 13+

      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      FirebaseMessaging.onMessage.listen((m) {
        if (m.data['sos'] == '1') {
          // Guardian, app open: ring and show the SOS screen right away
          showSosAlarm(m.data);
          openSos(m.data);
        } else {
          messengerKey.currentState?.showSnackBar(SnackBar(
            content: Text(m.notification?.title ?? 'New door event'),
            action: (m.data['event_id'] ?? '').toString().isEmpty
                ? null
                : SnackBarAction(
                    label: 'Open',
                    onPressed: () => openEvent('${m.data['event_id']}')),
          ));
        }
      });
    } catch (e) {
      debugPrint('[FirebaseService] Push set-up note: $e');
    }
  }

  /// Call once after the first frame: opens the event or SOS screen when a
  /// notification started the app from closed.
  Future<void> handleLaunch() async {
    if (!isAvailable) return;
    try {
      final launch = await _local.getNotificationAppLaunchDetails();
      final r = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && r?.id == kSosId) {
        openSos(_sosFromPayload(r!.payload));
        return;
      }
      _openFromMessage(await FirebaseMessaging.instance.getInitialMessage());
    } catch (e) {
      debugPrint('[FirebaseService] Launch details note: $e');
    }
  }

  void _openFromMessage(RemoteMessage? m) {
    if (m == null) return;
    if (m.data['sos'] == '1') {
      openSos(m.data);
    } else {
      final id = '${m.data['event_id'] ?? ''}';
      if (id.isNotEmpty) openEvent(id);
    }
  }

  void openEvent(String eventId) => appRouter?.push('/events/$eventId');

  void openSos(Map<String, dynamic> data) =>
      appRouter?.push('/sos', extra: Map<String, dynamic>.from(data));

  // ───────────────────────── Topics (9.2, 9.4) ─────────────────────────

  /// Subscribes to exactly one role topic, plus the optional topics the
  /// user switched on. A signed-out phone (role null) gets nothing.
  Future<void> applyRoleTopics(UserRole? role,
      {bool status = true, bool digest = true}) async {
    if (!isAvailable) return;
    final fcm = FirebaseMessaging.instance;
    try {
      await fcm.unsubscribeFromTopic(kTopicResident);
      await fcm.unsubscribeFromTopic(kTopicGuardian);
      if (role == null) {
        await fcm.unsubscribeFromTopic(kTopicStatus);
        await fcm.unsubscribeFromTopic(kTopicDigest);
        return;
      }
      await fcm.subscribeToTopic(
          role == UserRole.guardian ? kTopicGuardian : kTopicResident);
      await setTopic(kTopicStatus, status);
      await setTopic(kTopicDigest, digest);
      if (role == UserRole.guardian) await _askGuardianPermissions();
    } catch (e) {
      debugPrint('[FirebaseService] Topic update failed: $e');
    }
  }

  Future<void> setTopic(String topic, bool on) async {
    if (!isAvailable) return;
    try {
      on
          ? await FirebaseMessaging.instance.subscribeToTopic(topic)
          : await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FirebaseService] $topic: $e');
    }
  }

  /// Android 14+: the SOS screen over the lock screen needs this permission.
  Future<void> _askGuardianPermissions() async {
    try {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  // ───────────────────────── SOS alarm (9.5) ─────────────────────────

  /// "Test SOS alarm": plays the guardian alarm on this phone only.
  /// Needs no Firebase (it is a local notification). Throws on web, so the
  /// UI never fakes success.
  Future<void> testSosAlarm() async {
    if (kIsWeb) {
      throw StateError('The SOS alarm works only in the Android app.');
    }
    final data = {
      'sos': '1',
      'event_id': '',
      'title': 'Test alarm',
      'body': 'This is how an SOS alert sounds on this phone.',
      'image_url': '',
    };
    await showSosAlarm(data);
    openSos(data);
  }

  /// Stops the looping alarm sound.
  Future<void> stopSosAlarm() async {
    if (kIsWeb) return;
    try {
      await _local.cancel(id: kSosId);
    } catch (_) {}
  }
}
