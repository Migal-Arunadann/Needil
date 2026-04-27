# Clinic Appointment Workflow & Validation Plan

This plan details the changes needed to enforce strict date/time rules and cleanly separate active Consultation from Treatment sessions as requested.

## Proposed Changes

### 1. `lib/features/appointments/screens/appointment_list_screen.dart`
- **Consultation/Treatment Mixup fix**: Update the local state filtering. We will determine `activeConsultationPatientIds` (patients who currently have an active consultation open) and explicitly **hide** their treatment sessions from the "Treatment Sessions" tab until the consultation is completed or canceled.
- **End Consultation button**: Rename the *“Appointment Ended”* button on the Consultation card to **“End Consultation”**. Clicking this will trigger the existing flow to end the active consultation, which satisfies the condition to un-hide the session in the Treatement list.
- **Patient Arrived Validation**: Inside `_markArrived`, query PocketBase for the doctor's `WorkingSchedule`. Then compare `DateTime.now()` against the boundaries of the doctor's schedule using the existing `SchedulingService`. Block the “Patient Arrived” action if it lies outside working hours and show an appropriate error Snackbar.

### 2. `lib/features/appointments/screens/create_appointment_screen.dart`
- **Force Walk-in Validation**: To restrict Walk-ins strictly to correct clinic hours, intercept the submission logic when `_forceWalkIn == true`. Check `DateTime.now()` against the selected doctor’s precise `WorkingSchedule`. If it falls outside operating hours or breaks, block creation and show an error Snackbar.

### 3. `lib/features/scheduling/screens/available_slots_screen.dart`
- **Calendar Logic updates**: When navigating to the slot picker for a Walk-In (where `allowFutureDates == false`), update the calendar rendering to explicitly grey-out and disable taps on future dates, strongly indicating that Walk-in mode is explicitly for current-day slots only.

## Open Questions

- If a patient walks in 1 minute before closing time, should the system still allow capturing the "Walk in"? *(Currently, the exact time format match `isWithinWorkingHours` allows up to the last minute).*

## Verification Plan

- **Automated/Code Checks**: All dart files will be analyzed to make sure there are no new syntactical or typed errors.
- **Manual Verification**: We will launch the application and check:
  1. Creating a new walk in with `Force Walk-in` will be blocked if we simulate outside working hours.
  2. Submitting "Patient Arrived" on an existing appointment will be simulated to ensure it properly checks limits.
  3. Generating a Treatment Plan inside an active consultation will verify the "session" is properly hidden until "End Consultation" is clicked on the parent Appointment card.
