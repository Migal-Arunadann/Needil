# Graph Report - C:\App Development\PMS  (2026-04-26)

## Corpus Check
- 146 files · ~2,061,877 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1305 nodes · 1697 edges · 49 communities detected
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

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 54 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 49 edges
3. `../../../core/constants/app_text_styles.dart` - 38 edges
4. `../../../core/constants/app_colors.dart` - 35 edges
5. `package:pocketbase/pocketbase.dart` - 34 edges
6. `dart:convert` - 28 edges
7. `../../../core/providers/pocketbase_provider.dart` - 28 edges
8. `dart:io` - 26 edges
9. `../../auth/providers/auth_provider.dart` - 24 edges
10. `../../../core/widgets/app_button.dart` - 20 edges

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
Nodes (111): build, ClinicStep0OtpScreen, _ClinicStep0OtpScreenState, dispose, Scaffold, SizedBox, build, _buildStepIndicator (+103 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (87): ../../appointments/models/appointment_model.dart, ../../auth/providers/auth_provider.dart, PocketBase, AnalyticsData, AnalyticsNotifier, AppointmentListNotifier, AppointmentListState, AppointmentService (+79 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (81): app_colors.dart, app.dart, app_text_field.dart, AppColors, AppTextStyles, AppButton, build, _buildChild (+73 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (57): AuthResult, AuthService, _clearStorage, _fakeEmail, _generateUniqueId, OtpResult, _parseError, _saveSession (+49 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (36): AuditService, AppointmentModel, _parseStatus, _parseType, statusToString, typeToString, DoctorModel, TreatmentConfig (+28 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (50): build, CircularProgressIndicator, ClinicStep1Screen, _getHomeForAuth, initState, MainLayout, MaterialApp, PmsApp (+42 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (48): build, _ClinicListCard, dispose, GestureDetector, Icon, _infoChip, Row, Scaffold (+40 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (40): copyWith, SessionModel, SessionsNotifier, SessionsState, TreatmentPlansNotifier, TreatmentPlansState, TreatmentService, _addPhotoBtn (+32 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (47): DateFormat, formatStringTime, formatTimeOfDay, TimeUtils, build, _buildLoadingCard, ClinicDashboardScreen, Container (+39 more)

### Community 9 - "Community 9"
Cohesion: 0.04
Nodes (47): _actionTile, AnimatedContainer, build, _buildBasicDetailsTab, _buildConsultationDetails, _buildHistoryTab, _buildSessionsSection, _buildTreatmentsTab (+39 more)

### Community 10 - "Community 10"
Cohesion: 0.04
Nodes (46): _AgeGroupBars, _AnalyticsAppBar, AnalyticsScreen, BarChartGroupData, BoxDecoration, build, _cardDeco, Center (+38 more)

### Community 11 - "Community 11"
Cohesion: 0.04
Nodes (44): ../../analytics/providers/analytics_provider.dart, _ActionButton, AppointmentListScreen, _AppointmentListScreenState, build, Center, Container, didUpdateWidget (+36 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (36): ../../appointments/providers/appointment_provider.dart, build, _buildLateMinutesPicker, _buildToggleTile, Container, initState, NotificationsScreen, _NotificationsScreenState (+28 more)

### Community 13 - "Community 13"
Cohesion: 0.05
Nodes (37): _addDoctor, build, _buildDayChips, _buildDoctorBreaksCard, _buildDoctorCard, _buildDoctorHoursCard, _buildStepIndicator, _buildTreatmentTile (+29 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (36): BreakTime, build, _buildBreakRow, _buildDayOverrideCard, _buildGlobalBreaksCard, _buildGlobalHoursCard, _buildScheduleSection, _buildStepIndicator (+28 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (33): ../../auth/models/doctor_model.dart, AvailableSlotsNotifier, AvailableSlotsState, copyWith, SchedulingService, AvailableSlotsScreen, _AvailableSlotsScreenState, build (+25 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (34): about_screen.dart, build, _buildClinicDetailsCard, _buildDoctorClinicInfo, _buildDoctorDetailsCard, _buildProfileCompletion, _buildProfileHero, _buildReceptionistDetailsCard (+26 more)

### Community 17 - "Community 17"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 18 - "Community 18"
Cohesion: 0.07
Nodes (29): _actionCard, build, Container, _DangerTab, _darkDialog, _darkTextField, Dialog, dispose (+21 more)

### Community 19 - "Community 19"
Cohesion: 0.07
Nodes (28): _addPhotoBtn, build, _buildDropdown, _buildFormContent, _buildRadioGroup, _buildSectionHeader, _clearDraft, Column (+20 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (27): AnimatedContainer, build, _buildAvailabilityTab, _buildBasicInfoTab, _buildTreatmentsTab, Column, Container, _dayScheduleCard (+19 more)

### Community 21 - "Community 21"
Cohesion: 0.07
Nodes (26): ../../analytics/screens/analytics_screen.dart, ../../appointments/screens/appointment_list_screen.dart, AnalyticsScreen, AppointmentListScreen, build, _buildNavItem, Center, clearHighlight (+18 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (25): add_staff_doctor_screen.dart, _avatar, _badge, build, _buildError, Container, _emptyState, _field (+17 more)

### Community 23 - "Community 23"
Cohesion: 0.08
Nodes (24): ../../auth/screens/clinic_registration/clinic_step3_screen.dart, AddStaffDoctorScreen, _AddStaffDoctorScreenState, build, _buildDoctorBreaksCard, _buildDoctorHoursCard, _buildTreatmentTile, Container (+16 more)

### Community 24 - "Community 24"
Cohesion: 0.09
Nodes (21): _AnimatedCard, _AnimatedCardState, build, Center, dispose, Divider, _emptyView, _errorView (+13 more)

### Community 25 - "Community 25"
Cohesion: 0.1
Nodes (19): add_staff_receptionist_screen.dart, build, _buildEmpty, _buildError, Container, _EditReceptionistDialog, _EditReceptionistDialogState, _field (+11 more)

### Community 26 - "Community 26"
Cohesion: 0.1
Nodes (19): build, _buildCredentialsForm, _buildOtpGrid, _buildPrimaryButton, _buildResendRow, Column, _darkField, dispose (+11 more)

### Community 27 - "Community 27"
Cohesion: 0.2
Nodes (9): CachedBreak, CachedDayOverride, CachedWorkingDoctor, clear, RegistrationCacheNotifier, RegistrationCacheState, savePrimaryDoctor, saveReceptionist (+1 more)

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
Cohesion: 0.67
Nodes (2): main, package:flutter_test/flutter_test.dart

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (1): PBCollections

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (1): Validators

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (0): 

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

## Knowledge Gaps
- **1034 isolated node(s):** `main`, `main`, `runQuery`, `main`, `main` (+1029 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 35`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (2 nodes): `pb_collections.dart`, `PBCollections`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `validators.dart`, `Validators`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `my_application.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 2` to `Community 0`, `Community 1`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 26`, `Community 27`?**
  _High betweenness centrality (0.247) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 1` to `Community 0`, `Community 2`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 26`, `Community 27`?**
  _High betweenness centrality (0.182) - this node is a cross-community bridge._
- **Why does `package:pocketbase/pocketbase.dart` connect `Community 4` to `Community 1`, `Community 3`, `Community 5`, `Community 6`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.119) - this node is a cross-community bridge._
- **What connects `main`, `main`, `runQuery` to the rest of the system?**
  _1034 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._