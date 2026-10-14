import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torch_light/torch_light.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/firebase_service.dart';
import '../services/n8n_api.dart';
import '../widgets/glass.dart';

/// Guardian SOS screen (Build Guide 9.5): shown over the lock screen when an
/// alert reaches the threshold. The alarm loops and the flashlight blinks
/// about twice a second until "I've seen it", "All fine" or "Real concern".
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, required this.data});

  /// FCM data: event_id, title, body, image_url
  final Map<String, dynamic> data;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  Timer? _blink;
  bool _on = false;
  bool _stopped = false;
  bool _busy = false;

  String get _eventId => '${widget.data['event_id'] ?? ''}';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _blink = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        _on = !_on;
        try {
          _on ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
        } catch (_) {/* no torch, or the camera is busy */}
      });
    }
  }

  Future<void> _stop() async {
    if (_stopped) return;
    _stopped = true;
    _blink?.cancel();
    if (!kIsWeb) {
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
    }
    await FirebaseService.instance.stopSosAlarm(); // stops the looping sound
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _leave({bool openEvent = false}) {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
    if (openEvent && _eventId.isNotEmpty) {
      FirebaseService.instance.openEvent(_eventId);
    }
  }

  Future<void> _answer(String action) async {
    setState(() => _busy = true);
    await _stop();
    final res = await N8nApi.appAction(action, {'event_id': _eventId});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok
          ? (action == 'confirm'
              ? 'Marked as a real concern. The photo is kept as evidence.'
              : 'Marked as fine.')
          : res.message),
      backgroundColor: res.ok ? null : AppColors.critical,
    ));
    if (res.ok) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final event = ref
        .watch(eventsProvider)
        .where((e) => e.id == _eventId)
        .firstOrNull;
    final imageUrl = '${widget.data['image_url'] ?? ''}'.isNotEmpty
        ? '${widget.data['image_url']}'
        : (event?.hasLivePhoto == true ? event!.snapshotUrl : null);
    final title = '${widget.data['title'] ?? ''}'.isNotEmpty
        ? '${widget.data['title']}'
        : 'Door alert';
    final body = '${widget.data['body'] ?? ''}'.isNotEmpty
        ? '${widget.data['body']}'
        : (event?.reason ?? event?.description ?? '');

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.critical, AppColors.coral],
            ),
          ),
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 12),
              const Icon(Icons.warning_amber_rounded,
                  size: 84, color: Colors.white),
              const Center(
                child: Text('SOS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4)),
              ),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SnapshotThumb(
                            location: event?.location ?? 'Front door',
                            imageUrl: imageUrl,
                            size: 220,
                            tint: riskStyle(event?.score ?? 10).bg),
                      ),
                      const SizedBox(height: 14),
                      if (event != null) ...[
                        Row(children: [
                          RiskScoreBadge(score: event.score, large: true),
                          const SizedBox(width: 10),
                          Text(riskStyle(event.score).label,
                              style: TextStyle(
                                  color: riskStyle(event.score).color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17)),
                        ]),
                        const SizedBox(height: 10),
                      ],
                      if (body.isNotEmpty)
                        Text(body,
                            style: const TextStyle(fontSize: 16, height: 1.4)),
                    ]),
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: "I'VE SEEN IT",
                icon: Icons.check_rounded,
                loading: _busy,
                onPressed: () async {
                  await _stop();
                  _leave(openEvent: true);
                },
              ),
              if (_eventId.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GlassButton(
                        label: 'All fine',
                        gradient: true,
                        onPressed: _busy ? null : () => _answer('dismiss')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                        label: 'Real concern',
                        onPressed: _busy ? null : () => _answer('confirm')),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
