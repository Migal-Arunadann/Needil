# Session Flow & UX Fixes — Implementation Plan

## 1. New Session Flow (Arrived → Waiting → Start → End)
- **Model**: Add `waiting` to `AppointmentStatus` enum
- **Service**: `markSessionArrived` → status `waiting`; new `startSession` → status `in_progress`
- **UI**: Session card shows: Waiting → Start Session btn; In Progress → End Session btn; Remove View Session btn

## 2. Treatment Plan Creation Fix
- When "first session today" is on, create session at CURRENT time with `in_progress` status
- Only creates under Treatment Sessions, NOT also under Consultations
- Show snackbar: "Created treatment plan. Today's session created at <<time>>"

## 3. Patient Info Screen
- Remove Allergies/Conditions field
- BP field: number-only input

## 4. Consultation Screen
- Remove Treatment Plan Session area completely

## 5. Analytics
- Auto-refresh after treatment/session completion

## 6. Misc
- Past time slots shouldn't appear
- Duplicate phone capture prevention
