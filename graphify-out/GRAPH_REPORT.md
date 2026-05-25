# Graph Report - C:\App Development\PMS  (2026-05-22)

## Corpus Check
- 166 files · ~2,194,349 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1442 nodes · 1917 edges · 52 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 62 edges
2. `package:pms_app/core/theme/app_theme.dart` - 52 edges
3. `package:flutter_riverpod/flutter_riverpod.dart` - 50 edges
4. `package:pocketbase/pocketbase.dart` - 37 edges
5. `../../../core/constants/app_text_styles.dart` - 36 edges
6. `dart:io` - 35 edges
7. `../../../core/constants/app_colors.dart` - 32 edges
8. `dart:convert` - 31 edges
9. `../../../core/providers/pocketbase_provider.dart` - 29 edges
10. `../../auth/providers/auth_provider.dart` - 25 edges

## Surprising Connections (you probably didn't know these)
- `RegisterPlugins()` --calls--> `OnCreate()`  [INFERRED]
  C:\App Development\PMS\windows\flutter\generated_plugin_registrant.cc → C:\App Development\PMS\windows\runner\flutter_window.cpp
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  C:\App Development\PMS\windows\runner\flutter_window.cpp → C:\App Development\PMS\windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  C:\App Development\PMS\windows\runner\main.cpp → C:\App Development\PMS\windows\runner\utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  C:\App Development\PMS\windows\runner\main.cpp → C:\App Development\PMS\windows\runner\win32_window.cpp
- `dispose` --calls--> `my_application_dispose()`  [INFERRED]
  C:\App Development\PMS\lib\features\treatments\screens\record_session_screen.dart → C:\App Development\PMS\linux\runner\my_application.cc

## Communities

### Community 0 - "Community 0"
Cohesion: 0.02
Nodes (93): AuditService, AppointmentModel, _parseStatus, _parseType, statusToString, typeToString, ClinicModel, DoctorModel (+85 more)

### Community 1 - "Community 1"
Cohesion: 0.02
Nodes (102): build, ClinicStep0OtpScreen, _ClinicStep0OtpScreenState, dispose, Scaffold, SizedBox, build, _buildStepIndicator (+94 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (78): AuthResult, AuthService, _clearStorage, _fakeEmail, _generateUniqueId, OtpResult, _parseError, _saveSession (+70 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (74): ../../analytics/screens/analytics_screen.dart, ../../appointments/models/appointment_model.dart, ../../appointments/screens/appointment_list_screen.dart, ../../auth/providers/auth_provider.dart, PocketBase, AnalyticsData, AnalyticsNotifier, AppointmentListNotifier (+66 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (77): ../../analytics/providers/analytics_provider.dart, ../../auth/models/doctor_model.dart, _ActionButton, AppointmentListScreen, _AppointmentListScreenState, build, buildTimelineInfo, Center (+69 more)

### Community 5 - "Community 5"
Cohesion: 0.03
Nodes (72): app_text_field.dart, AppButton, build, _buildChild, Row, SizedBox, Text, AppTextField (+64 more)

### Community 6 - "Community 6"
Cohesion: 0.03
Nodes (59): copyWith, SessionModel, SessionsNotifier, SessionsState, TreatmentPlansNotifier, TreatmentPlansState, TreatmentService, _addPhotoBtn (+51 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (51): build, ClinicStep1Screen, _getHomeForAuth, initState, MainLayout, MaterialApp, PmsApp, _PmsAppState (+43 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (49): ../../app.dart, _checkIdle, dispose, _ensurePolling, IdleReminderService, recordInteraction, _showIdleReminder, SizedBox (+41 more)

### Community 9 - "Community 9"
Cohesion: 0.04
Nodes (50): ../../auth/screens/clinic_registration/clinic_step3_screen.dart, AddStaffDoctorScreen, _AddStaffDoctorScreenState, build, _buildDoctorBreaksCard, _buildDoctorHoursCard, _buildTreatmentTile, Container (+42 more)

### Community 10 - "Community 10"
Cohesion: 0.04
Nodes (47): DateFormat, formatStringTime, formatTimeOfDay, TimeUtils, build, _buildLoadingCard, ClinicDashboardScreen, Container (+39 more)

### Community 11 - "Community 11"
Cohesion: 0.04
Nodes (47): ThemeNotifier, _addPhotoBtn, build, _buildAllergyCheckbox, _buildDropdown, _buildFormContent, _buildMultiSelectGrid, _buildRadioGroup (+39 more)

### Community 12 - "Community 12"
Cohesion: 0.04
Nodes (46): _AgeGroupBars, _AnalyticsAppBar, AnalyticsScreen, BarChartGroupData, BoxDecoration, build, _cardDeco, Center (+38 more)

### Community 13 - "Community 13"
Cohesion: 0.04
Nodes (46): _actionTile, AnimatedContainer, build, _buildBasicDetailsTab, _buildConsultationDetails, _buildHistoryTab, _buildSessionsSection, _buildTreatmentsTab (+38 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (38): app_colors.dart, app_colors_extension.dart, app_text_styles_extension.dart, AppColors, AppTextStyles, AppColorsExtension, AppTextStylesExtension, AppTextStylesExtension (+30 more)

### Community 15 - "Community 15"
Cohesion: 0.05
Nodes (36): _addDoctor, build, _buildDayChips, _buildDoctorBreaksCard, _buildDoctorCard, _buildDoctorHoursCard, _buildStepIndicator, _buildTreatmentTile (+28 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (35): BreakTime, build, _buildBreakRow, _buildDayOverrideCard, _buildGlobalBreaksCard, _buildGlobalHoursCard, _buildScheduleSection, _buildStepIndicator (+27 more)

### Community 17 - "Community 17"
Cohesion: 0.06
Nodes (35): about_screen.dart, build, _buildClinicDetailsCard, _buildDoctorClinicInfo, _buildDoctorDetailsCard, _buildProfileCompletion, _buildProfileHero, _buildReceptionistDetailsCard (+27 more)

### Community 18 - "Community 18"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 19 - "Community 19"
Cohesion: 0.07
Nodes (28): ../../appointments/providers/appointment_provider.dart, _advanceByInterval, build, _clearDraft, Container, CreateTreatmentPlanScreen, _CreateTreatmentPlanScreenState, DateTime (+20 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (27): AvailableSlotsScreen, _AvailableSlotsScreenState, build, Center, _ConfirmPanel, _confirmSlot, Container, _DayOffState (+19 more)

### Community 21 - "Community 21"
Cohesion: 0.08
Nodes (24): build, _clinicTile, Color, Container, _emptyCard, _errorCard, Row, Scaffold (+16 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (24): add_staff_doctor_screen.dart, _avatar, _badge, build, _buildError, Container, _emptyState, _field (+16 more)

### Community 23 - "Community 23"
Cohesion: 0.1
Nodes (20): _AnimatedCard, _AnimatedCardState, build, Center, dispose, _emptyView, _errorView, FadeTransition (+12 more)

### Community 24 - "Community 24"
Cohesion: 0.1
Nodes (19): build, _buildCredentialsForm, _buildOtpGrid, _buildPrimaryButton, _buildResendRow, Column, _darkField, dispose (+11 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (18): add_staff_receptionist_screen.dart, build, _buildEmpty, _buildError, Container, _EditReceptionistDialog, _EditReceptionistDialogState, _field (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.13
Nodes (6): dispose, fl_register_plugins(), main(), my_application_activate(), my_application_dispose(), my_application_new()

### Community 27 - "Community 27"
Cohesion: 0.15
Nodes (12): build, _buildStepIndicator, ClinicStep2Screen, _ClinicStep2ScreenState, _counterButton, Expanded, GestureDetector, _next (+4 more)

### Community 28 - "Community 28"
Cohesion: 0.22
Nodes (3): AppDelegate, FlutterAppDelegate, FlutterImplicitEngineDelegate

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 30 - "Community 30"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 31 - "Community 31"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 32 - "Community 32"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (2): FlutterSceneDelegate, SceneDelegate

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (1): main

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (1): main

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (1): PBCollections

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (1): Validators

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (0): 

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (0): 

### Community 42 - "Community 42"
Cohesion: 1.0
Nodes (0): 

### Community 43 - "Community 43"
Cohesion: 1.0
Nodes (0): 

### Community 44 - "Community 44"
Cohesion: 1.0
Nodes (0): 

### Community 45 - "Community 45"
Cohesion: 1.0
Nodes (0): 

### Community 46 - "Community 46"
Cohesion: 1.0
Nodes (0): 

### Community 47 - "Community 47"
Cohesion: 1.0
Nodes (0): 

### Community 48 - "Community 48"
Cohesion: 1.0
Nodes (0): 

### Community 49 - "Community 49"
Cohesion: 1.0
Nodes (0): 

### Community 50 - "Community 50"
Cohesion: 1.0
Nodes (0): 

### Community 51 - "Community 51"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **1140 isolated node(s):** `main`, `main`, `main`, `_loadPlans`, `_dummy` (+1135 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 34`** (2 nodes): `scratchpad_fix_const.py`, `fix_line()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (2 nodes): `scratchpad_fix_const_manual.dart`, `main`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (2 nodes): `scratchpad_fix_switch.dart`, `main`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `pb_collections.dart`, `PBCollections`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (2 nodes): `validators.dart`, `Validators`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `patient_profile_screen_old.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (1 nodes): `my_application.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 14` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 27`?**
  _High betweenness centrality (0.243) - this node is a cross-community bridge._
- **Why does `package:pms_app/core/theme/app_theme.dart` connect `Community 5` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 27`?**
  _High betweenness centrality (0.177) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 3` to `Community 0`, `Community 1`, `Community 4`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`?**
  _High betweenness centrality (0.138) - this node is a cross-community bridge._
- **What connects `main`, `main`, `main` to the rest of the system?**
  _1140 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._