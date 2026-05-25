import 'dart:io';

void main() {
  final file = File('lib/features/patients/screens/patient_profile_screen.dart');
  var content = file.readAsStringSync();

  // 1. Add _startSession method before _endSessionsForConsultation
  final startSessionMethod = '''
  Future<void> _startSession(SessionModel session) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final aptService = ref.read(appointmentServiceProvider);
      final treatmentService = ref.read(treatmentServiceProvider);
      
      // Look up the appointment for this session
      final apts = await pb.collection(PBCollections.appointments).getList(
        filter: 'type = "session" && patient = "\${patient.id}" && date = "\${session.scheduledDate}"',
      );
      
      if (apts.items.isNotEmpty) {
        final aptId = apts.items.first.id;
        await aptService.startSession(aptId);
      }
      
      await treatmentService.startSessionRecord(session.id);
      
      if (mounted) {
        await Navigator.pushNamed(context, '/sessions/record', arguments: {
          'session': session,
          'patientName': patient.fullName,
        });
        setState(() {
          _planLoaded = false;
          if (session.isMaintenance) {
            _maintenanceSessions = [];
          } else {
            _treatmentSessions = [];
          }
        });
        await _loadPlans();
        widget.onReturn();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting session: \$e')));
      }
    }
  }
''';
  content = content.replaceFirst(
    '  /// Force-end all remaining upcoming sessions for this consultation.',
    startSessionMethod + '\n  /// Force-end all remaining upcoming sessions for this consultation.'
  );

  // 2. Update _sessionStatusLabel
  content = content.replaceFirst(
    '  String _sessionStatusLabel(SessionStatus s) {',
    '''  String _sessionStatusLabel(SessionModel session, SessionStatus s) {
    if (s == SessionStatus.waiting) return 'Patient Waiting';
    if (s == SessionStatus.upcoming) {
      final dt = DateTime.tryParse(session.scheduledDate);
      if (dt != null) {
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          return 'Patient Waiting';
        }
      }
    }
    switch (s) {
      case SessionStatus.upcoming:    return 'Upcoming';
      case SessionStatus.waiting:     return 'Waiting';
      case SessionStatus.inProgress:  return 'Ongoing';
      case SessionStatus.completed:   return 'Done';
      case SessionStatus.missed:      return 'Missed';
      case SessionStatus.cancelled:   return 'Cancelled';
    }
  }
  
  // Dummy definition to replace original switch so we don't end up with duplicate
  String _dummy(SessionStatus s) {'''
  );

  // 3. Update _sessionTile usage of _sessionStatusLabel
  content = content.replaceAll(
    '_sessionStatusLabel(effectiveStatus)',
    '_sessionStatusLabel(session, effectiveStatus)'
  );

  // Find the start of _sessionTile
  final tileStartPattern = "final isViewable = effectiveStatus == SessionStatus.completed ||  effectiveStatus == SessionStatus.missed;";
  
  final additions = '''
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = date != null
        ? DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day)
        : null;
    final isToday = sessionDay != null && sessionDay.isAtSameMomentAs(today);

    final showStartBtn = isEditable && (effectiveStatus == SessionStatus.waiting || effectiveStatus == SessionStatus.inProgress || (effectiveStatus == SessionStatus.upcoming && isToday));
    final startLabel = effectiveStatus == SessionStatus.inProgress ? 'Resume Session' : 'Start Session';
''';

  content = content.replaceFirst(tileStartPattern, tileStartPattern + additions);

  // Replace child: Row with child: Column containing Row and Button
  final childRowPattern = '''
        child: Row(
          children: [
            // Session number badge''';

  final newChildContent = '''
        child: Column(
          children: [
            Row(
              children: [
                // Session number badge''';

  content = content.replaceFirst(childRowPattern, newChildContent);

  // Close the Row and add the Start Button
  final endRowPattern = '''
            // Long-press hint icon for upcoming sessions
            if (isEditable) ...[
              const SizedBox(width: 2),
              Icon(Icons.more_vert_rounded, color: context.colors.textHint.withValues(alpha: 0.5), size: 14),
            ],
          ],
        ),
      ),
    );''';

  final newEndRowPattern = '''
            // Long-press hint icon for upcoming sessions
            if (isEditable) ...[
              const SizedBox(width: 2),
              Icon(Icons.more_vert_rounded, color: context.colors.textHint.withValues(alpha: 0.5), size: 14),
            ],
          ],
        ),
        if (showStartBtn) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startSession(session),
              icon: Icon(effectiveStatus == SessionStatus.inProgress ? Icons.restart_alt_rounded : Icons.play_arrow_rounded, size: 18),
              label: Text(startLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    ),
  ),
);''';

  content = content.replaceFirst(endRowPattern, newEndRowPattern);

  file.writeAsStringSync(content);
}
