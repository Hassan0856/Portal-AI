import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/models.dart';
import '../providers/guardian_email_provider.dart';
import '../providers/providers.dart';
import '../services/guardian_email_service.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

class GuardianEmailScreen extends ConsumerStatefulWidget {
  const GuardianEmailScreen({super.key});

  @override
  ConsumerState<GuardianEmailScreen> createState() =>
      _GuardianEmailScreenState();
}

class _GuardianEmailScreenState extends ConsumerState<GuardianEmailScreen> {
  final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider);
    final user = SupabaseService.instance.currentUser;

    // Strict access control: guardian role AND active session required
    final isAuthorized = role == UserRole.guardian && user != null;

    if (!isAuthorized) {
      return PortalAppShell(
        child: PageBody(
          children: [
            const PageHeading(
              title: 'Access Restricted',
              description: 'This section is reserved exclusively for guardians.',
              icon: Icons.lock_outline_rounded,
            ),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 56,
                      color: AppColors.high,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Guardian Access Only',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You do not have permission to access resident email management.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      label: 'Return to Dashboard',
                      gradient: true,
                      onPressed: () => context.go('/dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final state = ref.watch(guardianEmailProvider);
    final notifier = ref.read(guardianEmailProvider.notifier);

    return PortalAppShell(
      // FEATURE 1: Floating Action Button in the bottom-right corner
      floatingActionButton: state.residents.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 8, right: 4),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.peri.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () => _openAddEmailSheet(context),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Add Email',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      child: PageBody(
        children: [
          const PageHeading(
            title: 'Resident Emails',
            description:
                'Manage contact email addresses for your authorized residents.',
            icon: Icons.alternate_email_rounded,
          ),

          // Error Banner if present when residents ARE loaded
          if (state.errorMessage != null && state.residents.isNotEmpty)
            GlassCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fill: const Color(0x33F87171),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.high, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.high,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Resident Selector (if multiple residents) or Header Card
          if (state.isLoadingResidents)
            const GlassCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.peri),
                ),
              ),
            )
          else if (state.errorMessage != null && state.residents.isEmpty)
            GlassCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.high,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Connection / Backend Error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: () => notifier.loadResidents(),
                    ),
                  ],
                ),
              ),
            )
          else if (state.residents.isEmpty)
            // FEATURE 3: Helpful empty state explaining how to link a resident
            GlassCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.7),
                        border: Border.all(color: Colors.white),
                      ),
                      child: const Icon(
                        Icons.supervisor_account_outlined,
                        size: 34,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Linked Residents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You do not have any authorized resident relationships registered in your guardian account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.softBlue.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline_rounded,
                                  color: AppColors.iconBlue, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'How to Link an Authorized Resident',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Email management is strictly restricted to authorized residents.\n'
                            '• An administrator or resident must establish your guardian relationship in the system.\n'
                            '• Once an authorized link is active, their profile will appear here automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Refresh',
                            icon: Icons.refresh_rounded,
                            onPressed: () => notifier.loadResidents(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40),
                                onTap: () => context.push('/help'),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.help_outline_rounded,
                                          color: AppColors.secondary, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Help & About',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Resident Picker
            _ResidentSelectorCard(
              residents: state.residents,
              selectedResident: state.selectedResident,
              onSelected: (resident) => notifier.selectResident(resident),
              onRefresh: () => notifier.loadResidents(),
            ),

            // FEATURE 1: Email List Header with prominent "Add Email +" button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Addresses (${state.emails.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => _openAddEmailSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Email +',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peri,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    elevation: 2,
                  ),
                ),
              ],
            ),

            // Email list cards
            if (state.isLoadingEmails)
              const GlassCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.peri),
                  ),
                ),
              )
            else if (state.emails.isEmpty)
              GlassCard(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 44,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Contact Emails Yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add an email address for ${state.selectedResident?.displayName ?? 'this resident'} to receive emergency alerts and updates.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.secondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassButton(
                        label: 'Add Contact Email',
                        icon: Icons.add_rounded,
                        gradient: true,
                        onPressed: () => _openAddEmailSheet(context),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...state.emails.map((email) => _EmailCard(
                    email: email,
                    onEditLabel: () => _openEditLabelSheet(context, email),
                    onDelete: () => _confirmDeleteEmail(context, email),
                  )),
          ],
        ],
      ),
    );
  }

  // FEATURE 2: Add Email Form Dialog / Bottom Sheet
  void _openAddEmailSheet(BuildContext context) {
    final state = ref.read(guardianEmailProvider);

    if (state.residents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No authorized residents linked. Establish a relationship before adding emails.'),
          backgroundColor: AppColors.high,
        ),
      );
      return;
    }

    final emailController = TextEditingController();
    final labelController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;
    String? formError;
    LinkedResident chosenResident =
        state.selectedResident ?? state.residents.first;

    const labelSuggestions = [
      'Family',
      'Emergency Contact',
      'Relative',
      'Doctor',
      'Caregiver'
    ];

    showGlassSheet<void>(context, (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Resident Email',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Save a notification email for this resident. No login account or credentials are created.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.secondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resident Selector (if multiple) or Resident Info Badge
                  if (state.residents.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Authorized Resident',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<LinkedResident>(
                              value: chosenResident,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppColors.peri),
                              onChanged: (r) {
                                if (r != null) {
                                  setSheetState(() => chosenResident = r);
                                }
                              },
                              items: state.residents.map((r) {
                                return DropdownMenuItem<LinkedResident>(
                                  value: r,
                                  child: Text(
                                    r.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              color: AppColors.iconBlue, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resident',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  chosenResident.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (formError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x33F87171),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        formError!,
                        style: const TextStyle(
                          color: AppColors.high,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  GlassTextField(
                    hint: 'Email address (e.g. contact@example.com)',
                    icon: Icons.email_outlined,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email address is required.';
                      }
                      final trimmed = v.trim().toLowerCase();
                      if (!_emailRegex.hasMatch(trimmed)) {
                        return 'Please enter a valid email address.';
                      }
                      // Client-side duplicate check
                      final currentEmails = ref
                          .read(guardianEmailProvider)
                          .emails;
                      if (currentEmails.any((e) =>
                          e.email.toLowerCase() == trimmed)) {
                        return 'This email address is already added for this resident.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Label Suggestions Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: labelSuggestions.map((suggestion) {
                      final isSelected = labelController.text == suggestion;
                      return ActionChip(
                        label: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? AppColors.peri
                            : Colors.white.withValues(alpha: 0.8),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.peri
                              : Colors.white,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        onPressed: () {
                          setSheetState(() {
                            labelController.text = suggestion;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  GlassTextField(
                    hint: 'Optional label (e.g. Family, Emergency Contact)',
                    icon: Icons.label_outline_rounded,
                    controller: labelController,
                  ),
                  const SizedBox(height: 22),

                  // Cancel and Save Email Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white),
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: submitting
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          label: 'Save Email',
                          gradient: true,
                          loading: submitting,
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() {
                                    submitting = true;
                                    formError = null;
                                  });

                                  final err = await ref
                                      .read(guardianEmailProvider.notifier)
                                      .addEmail(
                                        residentId: chosenResident.userId,
                                        email: emailController.text.trim(),
                                        label: labelController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : labelController.text.trim(),
                                      );

                                  if (!ctx.mounted) return;

                                  if (err != null) {
                                    setSheetState(() {
                                      submitting = false;
                                      formError = err;
                                    });
                                  } else {
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Email address saved successfully.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _openEditLabelSheet(BuildContext context, ContactEmail email) {
    final labelController = TextEditingController(text: email.label ?? '');
    var submitting = false;
    String? formError;

    showGlassSheet<void>(context, (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Label',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (formError != null) ...[
                  Text(
                    formError!,
                    style: const TextStyle(
                      color: AppColors.high,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GlassTextField(
                  hint: 'Contact Label (e.g. Primary, Family)',
                  icon: Icons.label_outline_rounded,
                  controller: labelController,
                ),
                const SizedBox(height: 20),
                GlassButton(
                  label: 'Update Label',
                  gradient: true,
                  loading: submitting,
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheetState(() {
                            submitting = true;
                            formError = null;
                          });

                          final err = await ref
                              .read(guardianEmailProvider.notifier)
                              .updateLabel(
                                emailId: email.id,
                                label: labelController.text.trim(),
                              );

                          if (!ctx.mounted) return;

                          if (err != null) {
                            setSheetState(() {
                              submitting = false;
                              formError = err;
                            });
                          } else {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Label updated successfully.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _confirmDeleteEmail(BuildContext context, ContactEmail email) {
    final state = ref.read(guardianEmailProvider);
    final residentName = state.selectedResident?.displayName ?? 'this resident';

    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Remove Email Address?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove ${email.email}? This address will no longer receive notifications for $residentName.',
          style: const TextStyle(color: AppColors.secondary, fontSize: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.high,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.of(dlgCtx).pop();
              final err = await ref
                  .read(guardianEmailProvider.notifier)
                  .deleteEmail(email.id);

              if (!context.mounted) return;

              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err),
                    backgroundColor: AppColors.critical,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email removed successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ResidentSelectorCard extends StatelessWidget {
  const _ResidentSelectorCard({
    required this.residents,
    required this.selectedResident,
    required this.onSelected,
    required this.onRefresh,
  });

  final List<LinkedResident> residents;
  final LinkedResident? selectedResident;
  final ValueChanged<LinkedResident> onSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (residents.length == 1) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const GlassIconBadge(icon: Icons.person_rounded, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Managing Resident',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedResident?.displayName ?? residents.first.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.secondary, size: 22),
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const GlassIconBadge(icon: Icons.supervisor_account_rounded, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Resident',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<LinkedResident>(
                    value: selectedResident,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.peri),
                    onChanged: (resident) {
                      if (resident != null) onSelected(resident);
                    },
                    items: residents.map((r) {
                      return DropdownMenuItem<LinkedResident>(
                        value: r,
                        child: Text(
                          r.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.secondary, size: 22),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({
    required this.email,
    required this.onEditLabel,
    required this.onDelete,
  });

  final ContactEmail email;
  final VoidCallback onEditLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isVerified = email.status.toLowerCase() == 'verified';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softBlue.withValues(alpha: .5),
              border: Border.all(color: Colors.white),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: AppColors.iconBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        email.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge: 'Saved' or 'Verified'
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0x3334D399)
                            : AppColors.heat[0],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        email.status.isNotEmpty
                            ? email.status[0].toUpperCase() +
                                email.status.substring(1)
                            : 'Saved',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isVerified
                              ? const Color(0xFF059669)
                              : const Color(0xFF3F8F7C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (email.label != null && email.label!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.peri.withValues(alpha: .3)),
                        ),
                        child: Text(
                          email.label!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.peri,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'Added ${_formatDate(email.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit label',
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.secondary, size: 20),
            onPressed: onEditLabel,
          ),
          IconButton(
            tooltip: 'Remove email',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.high, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
