import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CachedBreak {
  final TimeOfDay? from;
  final TimeOfDay? to;
  const CachedBreak({this.from, this.to});
}

class CachedDayOverride {
  final TimeOfDay? workFrom;
  final TimeOfDay? workTo;
  final List<CachedBreak> breaks;
  const CachedDayOverride({this.workFrom, this.workTo, this.breaks = const []});
}

class CachedWorkingDoctor {
  final String name;
  final String username;
  final String password;
  final DateTime? dob;
  final String? photoPath;
  final Map<String, bool> selectedDays;
  final TimeOfDay? workFrom;
  final TimeOfDay? workTo;
  final List<CachedBreak> globalBreaks;
  final Map<String, CachedDayOverride?> dayOverrides;
  final Map<String, bool> selectedTreatments;
  final Map<String, String> treatmentDurations;
  final Map<String, String> treatmentFees;

  const CachedWorkingDoctor({
    this.name = '',
    this.username = '',
    this.password = '',
    this.dob,
    this.photoPath,
    this.selectedDays = const {},
    this.workFrom,
    this.workTo,
    this.globalBreaks = const [],
    this.dayOverrides = const {},
    this.selectedTreatments = const {},
    this.treatmentDurations = const {},
    this.treatmentFees = const {},
  });
}

class RegistrationCacheState {
  // Step 3 – Primary Doctor
  final String doctorName;
  final DateTime? doctorDob;
  final String? doctorPhotoPath;
  final Map<String, bool> selectedDays;
  final TimeOfDay? workFrom;
  final TimeOfDay? workTo;
  final List<CachedBreak> globalBreaks;
  final Map<String, CachedDayOverride?> dayOverrides;
  final Map<String, bool> selectedTreatments;
  final Map<String, String> treatmentDurations;
  final Map<String, String> treatmentFees;

  // Step 4 – Working Doctors
  final List<CachedWorkingDoctor> workingDoctors;

  // Step 5 – Receptionist
  final bool enableReceptionist;
  final String recName;
  final String recUsername;
  final String recPassword;

  const RegistrationCacheState({
    this.doctorName = '',
    this.doctorDob,
    this.doctorPhotoPath,
    this.selectedDays = const {},
    this.workFrom,
    this.workTo,
    this.globalBreaks = const [],
    this.dayOverrides = const {},
    this.selectedTreatments = const {},
    this.treatmentDurations = const {},
    this.treatmentFees = const {},
    this.workingDoctors = const [],
    this.enableReceptionist = false,
    this.recName = '',
    this.recUsername = '',
    this.recPassword = '',
  });

  bool get hasPrimaryDoctor => doctorName.isNotEmpty || selectedDays.values.any((v) => v);
  bool get hasWorkingDoctors => workingDoctors.isNotEmpty;
}

class RegistrationCacheNotifier extends StateNotifier<RegistrationCacheState> {
  RegistrationCacheNotifier() : super(const RegistrationCacheState());

  void savePrimaryDoctor({
    required String name,
    DateTime? dob,
    String? photoPath,
    required Map<String, bool> selectedDays,
    TimeOfDay? workFrom,
    TimeOfDay? workTo,
    required List<CachedBreak> globalBreaks,
    required Map<String, CachedDayOverride?> dayOverrides,
    required Map<String, bool> selectedTreatments,
    required Map<String, String> treatmentDurations,
    required Map<String, String> treatmentFees,
  }) {
    state = RegistrationCacheState(
      doctorName: name,
      doctorDob: dob,
      doctorPhotoPath: photoPath,
      selectedDays: Map.from(selectedDays),
      workFrom: workFrom,
      workTo: workTo,
      globalBreaks: List.from(globalBreaks),
      dayOverrides: Map.from(dayOverrides),
      selectedTreatments: Map.from(selectedTreatments),
      treatmentDurations: Map.from(treatmentDurations),
      treatmentFees: Map.from(treatmentFees),
      workingDoctors: state.workingDoctors,
      enableReceptionist: state.enableReceptionist,
      recName: state.recName,
      recUsername: state.recUsername,
      recPassword: state.recPassword,
    );
  }

  void saveWorkingDoctors(List<CachedWorkingDoctor> doctors) {
    state = RegistrationCacheState(
      doctorName: state.doctorName,
      doctorDob: state.doctorDob,
      doctorPhotoPath: state.doctorPhotoPath,
      selectedDays: state.selectedDays,
      workFrom: state.workFrom,
      workTo: state.workTo,
      globalBreaks: state.globalBreaks,
      dayOverrides: state.dayOverrides,
      selectedTreatments: state.selectedTreatments,
      treatmentDurations: state.treatmentDurations,
      treatmentFees: state.treatmentFees,
      workingDoctors: List.from(doctors),
      enableReceptionist: state.enableReceptionist,
      recName: state.recName,
      recUsername: state.recUsername,
      recPassword: state.recPassword,
    );
  }

  void saveReceptionist({
    required bool enabled,
    required String name,
    required String username,
    required String password,
  }) {
    state = RegistrationCacheState(
      doctorName: state.doctorName,
      doctorDob: state.doctorDob,
      doctorPhotoPath: state.doctorPhotoPath,
      selectedDays: state.selectedDays,
      workFrom: state.workFrom,
      workTo: state.workTo,
      globalBreaks: state.globalBreaks,
      dayOverrides: state.dayOverrides,
      selectedTreatments: state.selectedTreatments,
      treatmentDurations: state.treatmentDurations,
      treatmentFees: state.treatmentFees,
      workingDoctors: state.workingDoctors,
      enableReceptionist: enabled,
      recName: name,
      recUsername: username,
      recPassword: password,
    );
  }

  void clear() => state = const RegistrationCacheState();
}

final registrationCacheProvider =
    StateNotifierProvider<RegistrationCacheNotifier, RegistrationCacheState>(
  (ref) => RegistrationCacheNotifier(),
);
