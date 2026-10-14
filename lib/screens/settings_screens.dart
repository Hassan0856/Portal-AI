import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final role = ref.watch(authProvider);
    return PortalAppShell(
      child: PageBody(children: [
        const PageHeading(
            title: 'Settings',
            description: 'Manage your notifications and security preferences.'),
        if (role == UserRole.guardian)
          GlassCard(
            onTap: () => context.push('/settings/resident-emails'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const GlassIconBadge(icon: Icons.alternate_email_rounded),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resident Email Management',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                        'Manage contact email addresses for authorized residents.',
                        style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 15,
                            height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondary),
            ]),
          ),
        GlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _RowHead(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                desc: 'Get alerts for important activity and system updates.'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white),
              ),
              child: Column(children: [
                _ToggleRow(
                    icon: Icons.settings_outlined,
                    label: 'System updates',
                    value: s.systemUpdates,
                    onChanged: n.setSystemUpdates),
                Divider(
                    height: 1, color: AppColors.muted.withValues(alpha: .25)),
                _ToggleRow(
                    icon: Icons.directions_run_rounded,
                    label: 'Activity alerts (1–3)',
                    value: s.activityAlerts,
                    onChanged: n.setActivityAlerts),
              ]),
            ),
          ]),
        ),
        GlassCard(
          onTap: () => context.push('/settings/picture-recognition'),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const GlassIconBadge(icon: Icons.visibility_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Flexible(
                          child: Text('Picture Recognition',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.heat[0],
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('Required',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3F8F7C))),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Upload your photo manually.',
                        style: TextStyle(
                            color: AppColors.secondary, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text(
                        'Cannot be disabled as it’s essential for detecting and analysing activity.',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13.5,
                            height: 1.35)),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
          ]),
        ),
        GlassCard(
          onTap: () => context.push('/settings/privacy'),
          child: const Row(children: [
            GlassIconBadge(icon: Icons.storage_rounded),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Privacy & Storage',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('View data retention policies and storage details.',
                        style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 15,
                            height: 1.35)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
          ]),
        ),
      ]),
    );
  }
}

class _RowHead extends StatelessWidget {
  const _RowHead({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title, desc;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassIconBadge(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(desc,
                style: const TextStyle(
                    color: AppColors.secondary, fontSize: 15, height: 1.35)),
          ]),
        ),
      ]);
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: AppColors.iconBlue),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600))),
          GlassToggleSwitch(value: value, onChanged: onChanged),
        ]),
      );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage(
      {required this.title,
      required this.description,
      required this.icon,
      required this.children});
  final String title, description;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PortalAppShell(
        child: PageBody(children: [
          PageHeading(title: title, description: description, icon: icon),
          ...children,
        ]),
      );
}

class PictureRecognitionScreen extends ConsumerStatefulWidget {
  const PictureRecognitionScreen({super.key});
  @override
  ConsumerState<PictureRecognitionScreen> createState() =>
      _PictureRecognitionScreenState();
}

/// Adds the resident's reference photo through WF-02 add_face (Build Guide
/// 9.4). This is also the setup gate: the dashboard opens here until a
/// reference photo with the role "resident" exists.
class _PictureRecognitionScreenState
    extends ConsumerState<PictureRecognitionScreen> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      // Small JPEG (max 512 px), as known_faces.ref_b64 expects
      final image = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
      if (image == null) {
        setState(() => _uploading = false);
        return;
      }

      final bytes = await image.readAsBytes();
      final res = await SupabaseService.instance.addReferencePhoto(bytes);
      if (res.ok) ref.invalidate(residentFaceProvider);

      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.ok
                ? 'Reference photo saved. Recognition will use it from the next event.'
                : 'Upload failed: ${res.message}'),
            backgroundColor: res.ok ? AppColors.success : AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'Picture Recognition',
        description: 'Required for detecting and analysing activity.',
        icon: Icons.visibility_outlined,
        children: [
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your reference photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                  'Picture Recognition compares snapshots with the photo you provide. It cannot be turned off.',
                  style: TextStyle(color: AppColors.secondary, height: 1.4)),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Upload photo',
                icon: Icons.upload_rounded,
                gradient: true,
                loading: _uploading,
                onPressed: _uploading ? () {} : _pickAndUpload,
              ),
            ]),
          ),
        ],
      );
}

class PrivacyStorageScreen extends StatelessWidget {
  const PrivacyStorageScreen({super.key});
  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'Privacy & Storage',
        description: 'View data retention policies and storage details.',
        icon: Icons.storage_rounded,
        children: [
          GlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Retention policy',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  Text(
                      '• Daytime visitor photos are deleted after 24 hours.\n• Flagged photos (score 4 or more) are deleted after 7 days, unless you mark them "Real concern".\n• The resident\u2019s own comings and goings are kept as text, never as photos.\n• Messages are deleted 30 days after they arrive.',
                      style:
                          TextStyle(color: AppColors.secondary, height: 1.6)),
                  SizedBox(height: 10),
                  Text(
                      'Deletion runs every hour on the server (WF-07). Reference photos never leave the server.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
                ]),
          ),
          const RetentionNotice(),
        ],
      );
}
