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
          _detailRow('Address', p.address ?? 'Not provided'),
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
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/consultation',
                    arguments: {
                      'patientId': widget.patient.id,
                      'patientName': widget.patient.fullName,
                      'doctorId': widget.patient.doctorId,
                      'consultationId': c.id,
                      'isViewMode': true,
                    },
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
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
                                  DateFormat('MMM d, yyyy h:mm a').format(dt),
                                  style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOngoing 
                                        ? AppColors.warning.withValues(alpha: 0.1)
                                        : AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOngoing 
                                          ? AppColors.warning.withValues(alpha: 0.3)
                                          : AppColors.success.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    isOngoing ? 'Ongoing' : 'Completed',
                                    style: AppTextStyles.caption.copyWith(
                                      color: isOngoing ? AppColors.warning : AppColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              complaint.isNotEmpty ? complaint : 'General Consultation',
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
                ),
              ),
            );
          },
        );
      },
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
