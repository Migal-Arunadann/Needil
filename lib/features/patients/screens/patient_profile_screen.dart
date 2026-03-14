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
    _tabController = TabController(length: 2, vsync: this);
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
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'Basic Details'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicDetailsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
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
          _detailRow('Date of Birth', p.dateOfBirth ?? 'Not provided'),
          _detailRow('Address', p.address ?? 'Not provided'),
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
      future: Future.wait<dynamic>([
        pb.collection(PBCollections.appointments).getList(
          filter: 'patient = "$patientId"',
          sort: '-date,-time',
        ),
        pb.collection(PBCollections.consultations).getList(
          filter: 'patient = "$patientId"',
          sort: '-id',
        ),
        pb.collection(PBCollections.sessions).getList(
          filter: 'patient = "$patientId"',
          sort: '-scheduled_date',
        )
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}', style: AppTextStyles.bodyMedium));
        }

        final results = snapshot.data as List<dynamic>;
        final appointments = results[0].items;
        final consultations = results[1].items;
        final sessions = results[2].items;

        // Combine and sort events
        final events = <_HistoryEvent>[];

        for (var a in appointments) {
          final dateStr = a.getStringValue('date');
          final timeStr = a.getStringValue('time');
          final checkInStr = a.getStringValue('check_in_time');
          final checkOutStr = a.getStringValue('check_out_time');
          final dt = DateTime.tryParse('$dateStr $timeStr') ?? DateTime.tryParse(a.getStringValue('created'));
          
          events.add(_HistoryEvent(
            type: 'Appointment',
            date: dt ?? DateTime.now(),
            icon: Icons.event_available_rounded,
            color: AppColors.primary,
            title: '${a.getStringValue("type") == "walk_in" ? "Walk-In" : "Scheduled"} Appointment',
            subtitle: 'Time: $timeStr | Status: ${a.getStringValue("status")}',
            details: checkInStr.isNotEmpty ? 'Check-in: ${DateFormat("h:mm a").format(DateTime.parse(checkInStr).toLocal())}' : null,
            details2: checkOutStr.isNotEmpty ? 'Check-out: ${DateFormat("h:mm a").format(DateTime.parse(checkOutStr).toLocal())}' : null,
          ));
        }

        for (var c in consultations) {
          final dt = DateTime.tryParse(c.getStringValue('created'));
          events.add(_HistoryEvent(
            type: 'Consultation',
            date: dt ?? DateTime.now(),
            icon: Icons.medical_information_rounded,
            color: Colors.blueAccent,
            title: 'Consultation',
            subtitle: c.getStringValue('chief_complaint').isNotEmpty ? 'Complaint: ${c.getStringValue("chief_complaint")}' : 'No complaint recorded',
            details: c.getStringValue('notes').isNotEmpty ? 'Notes: ${c.getStringValue("notes")}' : null,
          ));
        }

        for (var s in sessions) {
          final dt = DateTime.tryParse(s.getStringValue('scheduled_date')) ?? DateTime.tryParse(s.getStringValue('created'));
          events.add(_HistoryEvent(
            type: 'Treatment Session',
            date: dt ?? DateTime.now(),
            icon: Icons.healing_rounded,
            color: AppColors.success,
            title: 'Treatment Session',
            subtitle: s.getStringValue('status'),
            details: s.getStringValue('notes').isNotEmpty ? 'Notes: ${s.getStringValue("notes")}' : null,
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
