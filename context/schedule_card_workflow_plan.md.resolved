# Refined Schedule Card Workflow — Implementation Plan

## Workflow Steps (Call-By / Walk-In Appointments)

```
[Scheduled] 
  → Patient Arrived (records arrival time)
  → Fill Patient Details / Resume Filling Patient Details
  → Start Consultation / Resume Consultation (creates consultation, caches partial form)
  → [consultation_form_saved = true]
  → Create Treatment Plan / Resume Treatment Plan  +  End Appointment
  → [Appointment Completed]
```

---

## 1. New DB Fields Needed (AppointmentModel + PocketBase)

| Field | Type | Purpose |
|---|---|---|
| `patient_arrival_time` | DateTime | Captured when "Patient Arrived" is clicked (already `check_in_time` — reuse) |
| `patient_details_saved` | Bool | True when PatientInfoScreen form fully submitted |
| `consultation_form_saved` | Bool | **Already exists** |
| `consultation_start_time` | DateTime | **Already exists** — set when START CONSULTATION opened |
| `consultation_end_time` | DateTime | NEW — set when consultation form is submitted |
| `treatment_plan_partial` | Bool | True when treatment plan form opened but not submitted |
| `linked_treatment_plan_id` | String | ID of the created treatment plan (prevents duplicates) |

> Note: `check_in_time` already captures patient arrival — rename display to "Arrival Time" in history.

---

## 2. Button State Decision Table

| Condition | Button Shown |
|---|---|
| `status == scheduled && !isFutureDate && type==callBy` | **Patient Arrived** |
| `status == inProgress && !patientDetailsSaved && !hasPatientLinked` | **Fill Patient Details** |
| `status == inProgress && !patientDetailsSaved && formPartiallyOpened` | **Resume Filling Patient Details** |
| `status == inProgress && patientDetailsSaved && consultationStartTime == null` | **Start Consultation** |
| `status == inProgress && patientDetailsSaved && consultationStartTime != null && !consultationFormSaved` | **Resume Consultation** |
| `consultationFormSaved && !linkedPlanId && !treatmentPlanPartial` | **Create Treatment Plan** + **End Appointment** |
| `consultationFormSaved && treatmentPlanPartial && !linkedPlanId` | **Resume Treatment Plan** + **End Appointment** |
| `consultationFormSaved && linkedPlanId` | *(appointment auto-ended)* |

---

## 3. Patient Details Form (PatientInfoScreen)

- **Current**: Form always shows "Fill Details" button  
- **Change**: Add `patient_details_partial` flag to `AppointmentModel`
  - When form is opened (but not submitted): set `patient_details_partial = true`
  - When form is submitted: set `patient_details_saved = true`, clear `partial`
  - Button label: `patient_details_partial && !patient_details_saved` → "Resume Filling Patient Details"

---

## 4. Consultation Form (ConsultationScreen)

### Time Recording:
- **Consultation Started Time** = `consultationStartTime` (already set on form **open**)
- **Consultation Ended Time** = new `consultation_end_time` field (set on form **submit**)

### Partial Fill / Cache:
- Use `shared_preferences` to cache partial form data keyed by `appointment_id`
- Cache key: `consultation_draft_{appointmentId}`
- On form open: load from cache if present
- On form close without submit: save to cache
- On form submit: clear cache, update `consultation_form_saved = true`, set `consultation_end_time`
- Button: `consultationStartTime != null && !consultationFormSaved` → **"Resume Consultation"**

---

## 5. Treatment Plan Form (CreateTreatmentPlanScreen)

### One Plan Per Consultation Enforcement:
- Before opening: check if `linked_treatment_plan_id` exists on appointment — block if yes
- Check in PocketBase: `treatment_plans` where `consultation = consultationId` — return first match

### Partial Fill / Cache:
- Cache key: `treatment_plan_draft_{appointmentId}`
- On form open: set `treatment_plan_partial = true` on appointment
- On form close without submit: save to cache
- On form submit: clear cache, set `linked_treatment_plan_id`, auto-end appointment

---

## 6. Files to Modify

### Model Changes:
- `appointment_model.dart` — add `patientDetailsSaved`, `patientDetailsPartial`, `consultationEndTime`, `treatmentPlanPartial`, `linkedTreatmentPlanId` fields

### Service Changes:
- `appointment_service.dart` — add methods:
  - `markPatientDetailsPartial(aptId)`
  - `markPatientDetailsSaved(aptId)`
  - `markConsultationEndTime(aptId)`
  - `markTreatmentPlanPartial(aptId)`
  - `markLinkedPlan(aptId, planId)`

### Screen Changes:
- `appointment_list_screen.dart` — rework button visibility logic in `_ScheduleCard.build()`
- `consultation_screen.dart`:
  - Add `shared_preferences` cache
  - Set `consultation_end_time` on submit
  - Load draft on open
  - Save draft on close
- `create_treatment_plan_screen.dart`:
  - Add cache support
  - Pass `appointmentId`
  - On open: mark `treatment_plan_partial`
  - One-plan guard

### PocketBase Migration Script:
- `scripts/add_appointment_workflow_fields.dart` — add all new Bool/DateTime/Text fields

---

## 7. Patient History Display

In `PatientProfileScreen` / timeline:
- Show `check_in_time` as **"Patient Arrived"** timestamp ✓ (already done)
- Show `consultation_start_time` as **"Consultation Started"** ✓ (already done)  
- Show NEW `consultation_end_time` as **"Consultation Ended"**
- Show `check_out_time` as **"Appointment Completed"**

---

## 8. Implementation Order

1. Add new fields to `AppointmentModel`
2. Add service methods in `appointment_service.dart`
3. Write migration script
4. Add `shared_preferences` to `pubspec.yaml`
5. Update `consultation_screen.dart` (cache + end time)
6. Update `create_treatment_plan_screen.dart` (cache + one-plan guard)
7. Update `appointment_list_screen.dart` (button logic)
8. Update `patient_info_screen.dart` (partial tracking)
9. Commit & push
