import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../services/firebase_service.dart';
import 'glass.dart';

/// "Test SOS alarm" (Settings, guardians): hold SOS to hear the alarm.
Future<void> showSosSheet(BuildContext context) =>
    showGlassSheet<void>(context, (_) => const _SosPanel());

class _SosPanel extends StatefulWidget {
  const _SosPanel();
  @override
  State<_SosPanel> createState() => _SosPanelState();
}

class _SosPanelState extends State<_SosPanel>
    with SingleTickerProviderStateMixin {
  static const _holdTime = Duration(seconds: 2);
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: _holdTime)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed && !_sent && !_loading) {
            _handleSosCompleted();
          }
        });
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _start() {
    if (_sent || _loading) return;
    HapticFeedback.mediumImpact();
    _hold.forward();
  }

  void _release() {
    if (!_sent && !_loading) _hold.reverse();
  }

  /// v4 has no manual SOS: guardian alarms are rung by n8n (WF-00) when an
  /// alert reaches the threshold. Holding SOS here is the "Test SOS alarm"
  /// from Build Guide 9.1: it plays the alarm on this phone only.
  Future<void> _handleSosCompleted() async {
    HapticFeedback.heavyImpact();
    setState(() => _sent = true);
    final messenger = ScaffoldMessenger.of(context);
    // Close this sheet first; the test alarm opens the SOS screen.
    Navigator.of(context).pop();
    try {
      await FirebaseService.instance.testSosAlarm();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'Test alarm failed: $e'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Emergency',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        _sent
            ? 'Test alarm started on this phone.'
            : (_loading
                ? 'Starting the test alarm...'
                : 'Press and hold SOS for 2 seconds to test the alarm.'),
        textAlign: TextAlign.center,
        style: TextStyle(
            color: _sent ? AppColors.success : AppColors.secondary,
            fontSize: 15,
            fontWeight: _sent ? FontWeight.w600 : FontWeight.w400),
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _release(),
        onLongPressCancel: _release,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (_, __) => SizedBox(
            width: 170,
            height: 170,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: _sent ? 1 : _hold.value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.heat[3].withValues(alpha: .5),
                  color: _sent ? AppColors.success : AppColors.critical,
                ),
              ),
              Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _sent
                      ? const LinearGradient(
                          colors: [AppColors.success, Color(0xFF9ADBCB)])
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.critical, AppColors.coral]),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (_sent ? AppColors.success : AppColors.critical)
                          .withValues(alpha: .35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: _sent
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 60)
                      : const Text('SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        FirebaseService.instance.isAvailable
            ? 'Real SOS alarms ring by themselves when an alert reaches the threshold.'
            : 'Push is not set up in this build, so real SOS alarms cannot arrive yet.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 14),
      GlassButton(
        label: _sent ? 'Done' : 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ]);
  }
}
