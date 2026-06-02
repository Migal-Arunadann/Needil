# Needil - Advanced Clinic Management System

Needil is a modern, cross-platform Flutter application designed specifically for Clinics, Hospitals, and doctors who practice session-type medicine (e.g., Physiotherapy, Ayurveda, Acupuncture, Chiropractic). 

Built with an elegant UI and a powerful backend powered by **PocketBase**, Needil seamlessly integrates role-based workflows for Clinics, Doctors, and Receptionists to provide end-to-end patient care management.

---

## 🌟 Key Features

### 🏢 Tri-Role Access Control (RBAC)
- **Clinic Accounts**: Clinic owners can register a clinical facility, define the maximum physical bed capacity (for smart scheduling), and manage an entire roster of doctors and receptionists.
- **Doctor Accounts**: Doctors have full control over their own schedules, the treatments they offer, and patient consultations. They can work independently or under a Clinic.
- **Receptionist Accounts**: Receptionists handle the daily operational pipeline. They manage doctor assignments, book walk-ins and call-bys, and execute billings to ensure a smooth front-desk experience.

### 📅 Smart Appointment Booking
- **Role-Aware Scheduling**: Book appointments precisely mapped to a specific doctor's working schedule.
- **Smart Patient Lookup**: Embeds patient registration natively into the walk-in and call-by booking flow. Just entering a phone number instantly pulls up registered patients or intelligently builds a new profile without duplicate data entry.

### 🩺 Comprehensive Medical Consultations
- Replaces paper records entirely. Doctors can log intensive, structured medical conversations.
- **History Tracking**: Captures Chief Complaints, Medical History, Surgeries, Current Medications, Allergies, and Chronic Diseases.
- **Workflow State Management**: A robust consultation engine handles state transitions gracefully. It strictly enforces workflows, transitioning appointments seamlessly from "Scheduled" → "Start Consultation" → "Create Plan" → "Auto-End".

### 🤖 Intelligent Session Auto-Scheduling
- Unlike standard calendars, Needil features a "Smart Scheduling Engine". 
- Doctors prescribe a Treatment Plan (e.g., 10 Sessions, Interval of 3 Days).
- **Bed-Count Logic**: The algorithm calculates the sequence of dates and automatically searches for available overlapping time slots. If a slot has reached the clinic's maximum physical `bed_count` capacity, the engine gracefully shifts the session to the next closest available time.

### 📸 Medical Session Management
- Interactive visual timelines for upcoming sessions, complete with progress tracking.
- **Record Vitals**: Doctors can measure and record BP and Pulse variables at the start of every session.
- **Image Uploads**: Natively uses device cameras or galleries to attach progression photos (e.g., wound healing, posture alignment) directly to the patient's session record.

### 👤 Unified Patient Timeline
- A scrollable, consolidated timeline UI that merges every Appointment, Consultation, and Treatment Session into a single chronological view for effortless patient history review.

---

## 🛠️ Technology Stack

- **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Backend / Database**: [PocketBase](https://pocketbase.io/) (Self-Hosted SQLite Database & Auth Provider)
- **Design System**: Bespoke UI utilizing elegant gradient heroes, glass-morphism panels, and carefully curated Typography/Colors.

---

## 🚀 Setup & Installation

### 1. Prerequisites
- Flutter SDK (`>=3.0.0`)
- A running instance of PocketBase (v0.23+)

### 2. Configure Environment
Point the Flutter application to your PocketBase server instance.
update constants inside `lib/core/providers/pocketbase_provider.dart` and `scripts/`.

### 3. Database Schema Initialization
Use the built-in dart scripts to automatically schema-sync your fresh PocketBase server:
```bash
# Initialize base collections, relations, and strict API rules
dart run scripts/setup_pocketbase.dart <admin_email> <admin_password>
dart run scripts/add_fields.dart <admin_email> <admin_password>
dart run scripts/add_status_field.dart <admin_email> <admin_password>
dart run scripts/add_consultation_form_saved.dart <admin_email> <admin_password>
# Setup basic test records
dart run scripts/setup_demo_data.dart <admin_email> <admin_password>
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
- **Clinic Cross-Sharing**: Clinically linked Doctors can utilize the `share_past_patients` and `share_future_patients` flags to granularly control patient data crossover with the parent Clinic.
