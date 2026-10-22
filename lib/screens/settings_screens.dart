import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/supabase_service.dart';
import '../widgets/emergency_widgets.dart';
import '../widgets/glass.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final isGuardian = ref.watch(authProvider) == UserRole.guardian;
    final links = ref.watch(linksProvider).valueOrNull;
    return PortalAppShell(
      tab: 3,
      child: PageBody(children: [
        const SectionLabel('Family'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            GlassListRow(
              icon: Icons.family_restroom_rounded,
              title: 'Family links',
              subtitle: links == null
                  ? (isGuardian
                      ? 'Residents you look after'
                      : 'Guardians who get your alerts')
                  : '${links.length} linked',
              onTap: () => context.push('/settings/family'),
            ),
            if (isGuardian) ...[
              const GlassDivider(),
              GlassListRow(
                icon: Icons.alternate_email_rounded,
                title: 'Contact emails',
                subtitle: 'Email addresses for your residents',
                onTap: () => context.push('/settings/resident-emails'),
              ),
            ],
          ]),
        ),
        const SectionLabel('Notifications'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            const GlassListRow(
              icon: Icons.notifications_active_outlined,
              title: 'Door alerts',
              subtitle: 'Always on',
              trailing: Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.muted),
            ),
            const GlassDivider(),
            GlassListRow(
              icon: Icons.sensors_rounded,
              title: 'Sensor status',
              subtitle: 'When the door sensor goes offline',
              trailing: GlassToggleSwitch(
                  value: s.systemUpdates, onChanged: n.setSystemUpdates),
            ),
            const GlassDivider(),
            GlassListRow(
              icon: Icons.summarize_outlined,
              title: 'Daily digest',
              subtitle: 'A short summary every evening',
              trailing: GlassToggleSwitch(
                  value: s.activityAlerts, onChanged: n.setActivityAlerts),
            ),
            if (isGuardian) ...[
              const GlassDivider(),
              GlassListRow(
                icon: Icons.campaign_outlined,
                title: 'Test SOS alarm',
                subtitle: 'Hear the alarm on this phone',
                onTap: () => showSosSheet(context),
              ),
            ],
          ]),
        ),
        const SectionLabel('Privacy and help'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            GlassListRow(
              icon: Icons.face_retouching_natural_outlined,
              title: 'Picture recognition',
              subtitle: 'The resident’s reference photo',
              onTap: () => context.push('/settings/picture-recognition'),
            ),
            const GlassDivider(),
            GlassListRow(
              icon: Icons.storage_rounded,
              title: 'Privacy & storage',
              subtitle: 'How long photos and messages are kept',
              onTap: () => context.push('/settings/privacy'),
            ),
            const GlassDivider(),
            GlassListRow(
              icon: Icons.help_outline_rounded,
              title: 'Help & About',
              subtitle: 'How Portal AI works and the risk scale',
              onTap: () => context.push('/help'),
            ),
          ]),
        ),
        GlassButton(
          label: 'Log out',
          icon: Icons.logout_rounded,
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
      ]),
    );
  }
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
        ],
      );
}
