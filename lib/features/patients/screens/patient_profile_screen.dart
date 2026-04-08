import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../models/patient_model.dart';
import '../../consultations/models/consultation_model.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  final PatientModel patient;

  const PatientProfileScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Patient Profile', style: AppTextStyles.h4),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.h4,
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: const [
            Tab(text: 'Treatments'),
            Tab(text: 'History'),
            Tab(text: 'Patient Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTreatmentsTab(),
          _buildHistoryTab(),
          _buildBasicDetailsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 1. Intercept to check if there is an ongoing consultation
          final pb = ref.read(pocketbaseProvider);
          try {
            final ongoingRes = await pb.collection(PBCollections.consultations).getList(
              filter: 'patient = "${widget.patient.id}" && status = "ongoing"',
              perPage: 1,
            );

            if (ongoingRes.items.isNotEmpty) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Action Restricted', style: TextStyle(color: AppColors.error)),
                    content: const Text('There is already an ongoing consultation for this patient. Please complete it before creating a new one.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  )
                );
              }
              return; // Stop execution, do not create a new one!
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking consultations: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
            }
            return; // Block creation if check fails
          }

          // 2. If no ongoing consultation, proceed to create a new one
          final consultation = await Navigator.pushNamed(
            context,
            '/consultation',
            arguments: {
              'patientId': widget.patient.id,
              'patientName': widget.patient.fullName,
              'doctorId': widget.patient.doctorId,
            },
          ) as ConsultationModel?;

          if (consultation != null && mounted) {
            final shouldCreatePlan = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text('Consultation Saved', style: AppTextStyles.h3),
                content: Text(
                  'Would you like to auto-schedule a Treatment Plan with sessions based on this consultation?',
                  style: AppTextStyles.bodyMedium,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Create Plan'),
                  ),
                ],
              ),
            );

            if (shouldCreatePlan == true && mounted) {
              await Navigator.pushNamed(
                context,
                '/treatment-plan/create',
                arguments: {
                  'patientId': widget.patient.id,
                  'patientName': widget.patient.fullName,
                  'doctorId': widget.patient.doctorId,
                  'consultationId': consultation.id,
                },
              );
            }
            // Refresh history
            setState(() {});
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text('Consult', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBasicDetailsTab() {
    final p = widget.patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(p.fullName, style: AppTextStyles.h3),
          ),
          Center(
            child: Text(p.phone, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 32),
          _detailRow('Age', p.age?.toString() ?? 'Not provided'),
          _detailRow('Date of Birth', p.dateOfBirth ?? 'Not provided'),
          _detailRow('Gender', p.gender ?? 'Not provided'),
          _detailRow('City', p.city?.isNotEmpty == true ? p.city! : 'Not provided'),
          _detailRow('Area / Locality', p.area?.isNotEmpty == true ? p.area! : 'Not provided'),
          _detailRow('Occupation', p.occupation ?? 'Not provided'),
          _detailRow('Email', p.email ?? 'Not provided'),
          _detailRow('Emergency Contact', p.emergencyContact ?? 'Not provided'),
          _detailRow('Allergies/Conditions', p.allergiesConditions ?? 'None known'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final pb = ref.read(pocketbaseProvider);
    final patientId = widget.patient.id;

    return FutureBuilder(
      future: pb.collection(PBCollections.appointments).getList(
        filter: 'patient = "$patientId"',
        sort: '-date,-time',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}', style: AppTextStyles.bodyMedium));
        }

        final appointments = snapshot.data!.items;
        final events = <_HistoryEvent>[];

        for (var a in appointments) {
          final status = a.getStringValue('status');
          final checkInStr = a.getStringValue('check_in_time');
          final checkOutStr = a.getStringValue('check_out_time');
          
          // Drop un-arrived (scheduled-only) appointments
          if (status == 'scheduled' && checkInStr.isEmpty) continue;

          final dateStr = a.getStringValue('date');
          final timeStr = a.getStringValue('time');
          final typeVal = a.getStringValue('type');
          
          final dt = DateTime.tryParse('$dateStr $timeStr') ?? DateTime.tryParse(a.getStringValue('created'));
          
          String title = 'Scheduled Appointment';
          if (typeVal == 'walk_in') title = 'Walk-In Patient';
          if (typeVal == 'session') title = 'Treatment Session';

          // Format check-in/out explicitly based on Common Form (in) and Done Button (out)
          String? details1;
          String? details2;
          if (checkInStr.isNotEmpty) {
            details1 = 'Check-in (Form Filled): ${DateFormat("h:mm a").format(DateTime.parse(checkInStr).toLocal())}';
          }
          if (checkOutStr.isNotEmpty) {
            details2 = 'Check-out (Done): ${DateFormat("h:mm a").format(DateTime.parse(checkOutStr).toLocal())}';
          }
          
          events.add(_HistoryEvent(
            type: 'Appointment',
            date: dt ?? DateTime.now(),
            icon: typeVal == 'session' ? Icons.healing_rounded : Icons.event_available_rounded,
            color: AppColors.primary,
            title: title,
            subtitle: 'Time: $timeStr | Status: $status',
            details: details1,
            details2: details2,
          ));
        }

        events.sort((a, b) => b.date.compareTo(a.date));

        if (events.isEmpty) {
          return Center(
            child: Text('No history found.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line & icon
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: e.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(e.icon, size: 20, color: e.color),
                      ),
                      if (index != events.length - 1)
                        Container(width: 2, height: 40, color: AppColors.border),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(e.date), style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(e.title, style: AppTextStyles.h4),
                        const SizedBox(height: 4),
                        Text(e.subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        if (e.details != null) ...[
                          const SizedBox(height: 4),
                          Text(e.details!, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: AppColors.primary)),
                        ],
                        if (e.details2 != null) ...[
                          const SizedBox(height: 2),
                          Text(e.details2!, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: AppColors.primary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTreatmentsTab() {
    final pb = ref.read(pocketbaseProvider);
    final patientId = widget.patient.id;

    return FutureBuilder(
      future: pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId"',
        sort: '-id',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading treatments: ${snapshot.error}', style: AppTextStyles.bodyMedium));
        }

        final consultations = snapshot.data!.items;

        if (consultations.isEmpty) {
          return Center(
            child: Text('No consultations yet.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: consultations.length,
          itemBuilder: (context, index) {
            final c = consultations[index];
            final dt = DateTime.tryParse(c.getStringValue('created')) ?? DateTime.now();
            final complaint = c.getStringValue('chief_complaint');
            final statusStr = c.getStringValue('status');
            final isOngoing = statusStr != 'completed';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ConsultationCard(
                consultationId: c.id,
                date: dt,
                complaint: complaint,
                isOngoing: isOngoing,
                patientId: widget.patient.id,
                patientName: widget.patient.fullName,
                doctorId: widget.patient.doctorId,
                onReturn: () {
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// A self-contained consultation card that fetches session info
class _ConsultationCard extends ConsumerStatefulWidget {
  final String consultationId;
  final DateTime date;
  final String complaint;
  final bool isOngoing;
  final String patientId;
  final String patientName;
  final String doctorId;
  final VoidCallback onReturn;

  const _ConsultationCard({
    required this.consultationId,
    required this.date,
    required this.complaint,
    required this.isOngoing,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.onReturn,
  });

  @override
  ConsumerState<_ConsultationCard> createState() => _ConsultationCardState();
}

class _ConsultationCardState extends ConsumerState<_ConsultationCard> {
  int _totalSessions = 0;
  int _completedSessions = 0;
  bool _session1StartedToday = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final todayStr = _formatDate(DateTime.now());
      int total = 0;
      int completed = 0;
      bool s1Today = false;

      // Sessions link to treatment_plans, not directly to consultations.
      // Step 1: find treatment plans for this consultation
      final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "${widget.consultationId}"',
        perPage: 20,
      );

      // Step 2: for each plan, fetch its sessions
      for (final plan in plansRes.items) {
        final sessRes = await pb.collection(PBCollections.sessions).getList(
          filter: 'treatment_plan = "${plan.id}"',
          sort: 'session_number',
          perPage: 200,
        );
        for (final s in sessRes.items) {
          final status = s.getStringValue('status');
          if (status != 'cancelled') total++;
          if (status == 'completed') completed++;
          if (s.getIntValue('session_number') == 1 &&
              status == 'completed' &&
              s.getStringValue('scheduled_date') == todayStr) {
            s1Today = true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalSessions = total;
          _completedSessions = completed;
          _session1StartedToday = s1Today;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/consultation',
          arguments: {
            'patientId': widget.patientId,
            'patientName': widget.patientName,
            'doctorId': widget.doctorId,
            'consultationId': widget.consultationId,
            'isViewMode': true,
          },
        ).then((_) => widget.onReturn());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _session1StartedToday
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border,
            width: _session1StartedToday ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_information_rounded, color: Colors.blueAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy h:mm a').format(widget.date),
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.isOngoing 
                                  ? AppColors.warning.withValues(alpha: 0.1)
                                  : AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.isOngoing 
                                    ? AppColors.warning.withValues(alpha: 0.3)
                                    : AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              widget.isOngoing ? 'Ongoing' : 'Completed',
                              style: AppTextStyles.caption.copyWith(
                                color: widget.isOngoing ? AppColors.warning : AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.complaint.isNotEmpty ? widget.complaint : 'General Consultation',
                        style: AppTextStyles.h4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
            // Session summary
            if (_loaded && _totalSessions > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.healing_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '$_completedSessions / $_totalSessions sessions completed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Session #1 started today banner
            if (_session1StartedToday) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.1),
                      AppColors.success.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: AppColors.success, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session #1 Started Today',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.success,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'First treatment session has been initiated',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryEvent {
  final String type;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? details;
  final String? details2;

  _HistoryEvent({
    required this.type,
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.details,
    this.details2,
  });
}
