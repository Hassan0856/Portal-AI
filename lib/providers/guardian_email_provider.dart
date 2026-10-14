import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/guardian_email_service.dart';

class GuardianEmailState {
  const GuardianEmailState({
    this.isLoadingResidents = false,
    this.isLoadingEmails = false,
    this.isSubmitting = false,
    this.residents = const [],
    this.selectedResident,
    this.emails = const [],
    this.errorMessage,
  });

  final bool isLoadingResidents;
  final bool isLoadingEmails;
  final bool isSubmitting;
  final List<LinkedResident> residents;
  final LinkedResident? selectedResident;
  final List<ContactEmail> emails;
  final String? errorMessage;

  GuardianEmailState copyWith({
    bool? isLoadingResidents,
    bool? isLoadingEmails,
    bool? isSubmitting,
    List<LinkedResident>? residents,
    LinkedResident? Function()? selectedResident,
    List<ContactEmail>? emails,
    String? Function()? errorMessage,
  }) {
    return GuardianEmailState(
      isLoadingResidents: isLoadingResidents ?? this.isLoadingResidents,
      isLoadingEmails: isLoadingEmails ?? this.isLoadingEmails,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      residents: residents ?? this.residents,
      selectedResident: selectedResident != null
          ? selectedResident()
          : this.selectedResident,
      emails: emails ?? this.emails,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

final guardianEmailProvider =
    NotifierProvider<GuardianEmailNotifier, GuardianEmailState>(
        GuardianEmailNotifier.new);

class GuardianEmailNotifier extends Notifier<GuardianEmailState> {
  GuardianEmailService get _service => GuardianEmailService.instance;

  @override
  GuardianEmailState build() {
    // Initial fetch of residents when provider is initialized
    Future.microtask(() => loadResidents());
    return const GuardianEmailState(isLoadingResidents: true);
  }

  Future<void> loadResidents() async {
    state = state.copyWith(
      isLoadingResidents: true,
      errorMessage: () => null,
    );

    try {
      final residents = await _service.fetchLinkedResidents();
      if (residents.isEmpty) {
        state = state.copyWith(
          isLoadingResidents: false,
          residents: [],
          selectedResident: () => null,
          emails: [],
        );
        return;
      }

      // Keep previously selected if still in list, else pick the first
      LinkedResident selected = residents.first;
      if (state.selectedResident != null) {
        final found = residents.where((r) => r.userId == state.selectedResident!.userId);
        if (found.isNotEmpty) {
          selected = found.first;
        }
      }

      state = state.copyWith(
        isLoadingResidents: false,
        residents: residents,
        selectedResident: () => selected,
      );

      await loadEmailsForResident(selected.userId);
    } catch (e) {
      state = state.copyWith(
        isLoadingResidents: false,
        errorMessage: () => 'Failed to load linked residents: $e',
      );
    }
  }

  Future<void> selectResident(LinkedResident resident) async {
    state = state.copyWith(
      selectedResident: () => resident,
      emails: [],
      errorMessage: () => null,
    );
    await loadEmailsForResident(resident.userId);
  }

  Future<void> loadEmailsForResident(String residentId) async {
    state = state.copyWith(
      isLoadingEmails: true,
      errorMessage: () => null,
    );

    try {
      final emails = await _service.fetchEmails(residentId);
      state = state.copyWith(
        isLoadingEmails: false,
        emails: emails,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingEmails: false,
        errorMessage: () => 'Failed to load emails: $e',
      );
    }
  }

  Future<String?> addEmail({
    String? residentId,
    required String email,
    String? label,
  }) async {
    final targetResidentId = residentId ?? state.selectedResident?.userId;
    if (targetResidentId == null) {
      return 'No resident selected.';
    }

    state = state.copyWith(isSubmitting: true);
    final error = await _service.addEmail(
      residentId: targetResidentId,
      email: email,
      label: label,
    );

    state = state.copyWith(isSubmitting: false);

    if (error == null) {
      if (state.selectedResident?.userId == targetResidentId) {
        await loadEmailsForResident(targetResidentId);
      } else {
        final found = state.residents.where((r) => r.userId == targetResidentId);
        if (found.isNotEmpty) {
          await selectResident(found.first);
        }
      }
    }
    return error;
  }

  Future<String?> updateLabel({
    required String emailId,
    required String label,
  }) async {
    final residentId = state.selectedResident?.userId;
    state = state.copyWith(isSubmitting: true);

    final error = await _service.updateLabel(
      emailId: emailId,
      label: label,
    );

    state = state.copyWith(isSubmitting: false);

    if (error == null && residentId != null) {
      await loadEmailsForResident(residentId);
    }
    return error;
  }

  Future<String?> deleteEmail(String emailId) async {
    final residentId = state.selectedResident?.userId;
    state = state.copyWith(isSubmitting: true);

    final error = await _service.deleteEmail(emailId);

    state = state.copyWith(isSubmitting: false);

    if (error == null && residentId != null) {
      await loadEmailsForResident(residentId);
    }
    return error;
  }
}
