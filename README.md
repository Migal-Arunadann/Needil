# Pulse - Advanced Practice Management System (PMS)

Pulse is a modern, cross-platform Flutter application designed specifically for Clinics, Hospitals, and Independent Doctors who practice session-type medicine (e.g., Physiotherapy, Acupuncture, Reflexology, Chiropractic). 

It is built with a dual-role architectural design (Clinic Admins & Independent Doctors), offering an elegant UI and a powerful backend powered by **PocketBase**.

---

## 🌟 Key Features

### 🏢 Dual Role-Based Access Control (RBAC)
- **Clinic Accounts**: Clinic owners can register a clinical facility, define the maximum physical bed capacity (for smart scheduling), and manage an entire roster of doctors.
- **Doctor Accounts**: Doctors can register independently or link their accounts directly to a Clinic. Doctors have full control over their own schedules, the treatments they offer, and the fees they charge.

### 📅 Smart Appointment Booking
- **Role-Aware Scheduling**: Patients can book appointments based on the exact time-slots a specific doctor is available on a given day.
- **Direct Walk-Ins**: Embeds patient registration natively into the walk-in booking flow, eliminating redundant data entry for receptionists.

### 🩺 Comprehensive Medical Consultations
- Replaces paper records entirely. Doctors can log intensive, structured medical conversations.
- **History Tracking**: Captures Chief Complaints, Medical History, Surgeries, Current Medications, Allergies, and Chronic Diseases.
- **Lifestyle Metrics**: Tracks Diet, Sleep Quality, Addictions, Stress Levels, and Exercise.
- **Physical Therapy Consent**: Includes integrated digital consent tracking for specialized physical treatments.

### 🤖 Intelligent Session Auto-Scheduling
- Unlike standard calendars, this PMS features a "Smart Scheduling Engine". 
- Doctors prescribe a Treatment Plan (e.g., 10 Sessions, Interval of 3 Days).
- **Bed-Count Logic**: The algorithm calculates the sequence of dates and automatically searches for available overlapping time slots. If a 10:00 AM slot has reached the clinic's maximum physical `bed_count` capacity, the engine gracefully shifts the session to the next closest available time (e.g., 10:30 AM), ensuring the clinic is never over-booked.

### 📸 Medical Session Management
- Interactive visual timelines for upcoming sessions, complete with progress tracking.
- **Record Vitals**: Doctors can measure and record BP and Pulse variables at the start of every session.
- **Image Compression & Upload**: Natively uses device cameras or galleries to upload compressed progression photos (e.g., posture alignment, wound healing) directly to the patient's secure medical record.

### 👤 Unified Patient Timeline
- A gorgeous, scrollable timeline UI that merges every Appointment, Consultation, and Treatment Session into a single chronological view for effortless patient history review.

---

## 🛠️ Technology Stack

- **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Backend / Database**: [PocketBase](https://pocketbase.io/) (Self-Hosted SQLite Database & Auth Provider)
- **Networking**: HTTP, fully integrated token-based authentication.
- **Design System**: Fully bespoke UI utilizing elegant gradient heroes, glass-morphism panels, and carefully curated Typography/Colors (`AppColors`, `AppTextStyles`).

---

## 🚀 Setup & Installation

### 1. Prerequisites
- Flutter SDK (`>=3.0.0`)
- A running instance of PocketBase (v0.23+)

### 2. Configure Environment
Point the Flutter application to your PocketBase server instance.
update constants inside `lib/core/constants/api_constants.dart` (or `add_fields.dart` / `setup_pocketbase.dart` helper scripts).

### 3. Database Schema Initialization
Use the built-in dart scripts to automatically schema-sync your fresh PocketBase server:
```bash
# Create all collections and strict API rules
dart run scripts/setup_pocketbase.dart <admin_email> <admin_password>
```

### 4. Run the App
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔐 Security & Privacy
- **Strict Data Isolation**: PocketBase API Rules are rigorously designed to ensure that Doctors only see patients they actively treat. 
- **Clinic Cross-Sharing**: If a Doctor works under a Clinic, they can utilize the `share_past_patients` and `share_future_patients` flags to granularly control patient data crossover with the parent Clinic.
- **KSUID Sorting**: Utilizes KSUID chronological sorting over raw timestamps to reliably handle time-based pagination.

---

*Architected and Designed by the Gemini Antigravity Agent.*
