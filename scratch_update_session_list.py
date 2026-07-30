import os

file_path = r'lib\features\treatments\screens\session_list_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Header (Summary)
header_old = """                        Text(
                          widget.plan.treatmentType,
                          style: context.textStyles.h2,
                        ),
                        Text(
                          widget.plan.patientName ?? 'Patient',
                          style: context.textStyles.caption,
                        ),"""
header_new = """                        Text(
                          widget.plan.treatmentType,
                          style: context.textStyles.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.plan.totalSessions} Sessions • Every ${widget.plan.intervalDays} Day${widget.plan.intervalDays > 1 ? "s" : ""} • ₹${widget.plan.sessionFee.toInt()}/session',
                          style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.plan.patientName ?? 'Patient',
                          style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                        ),"""
content = content.replace(header_old, header_new)


# 2. Update Progress Bar & Pause/Review Context Row
progressBar_old = """            final progressBar = Padding(
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: context.textStyles.label.copyWith(fontSize: 13),
                        ),
                        Row(
                          children: [
                            Text(
                              '$completedCount / ${widget.plan.totalSessions} sessions',
                              style: context.textStyles.label.copyWith(
                                color: context.colors.primary,
                                fontSize: 13,
                              ),
                            ),
                            // Schedule version badge
                            if (widget.plan.scheduleVersion > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${widget.plan.scheduleVersion}',
                                  style: context.textStyles.caption.copyWith(
                                    color: context.colors.info,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: widget.plan.totalSessions > 0
                            ? completedCount / widget.plan.totalSessions
                            : 0,
                        backgroundColor: context.colors.primary.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Every ${widget.plan.intervalDays} days',
                          style: context.textStyles.caption,
                        ),
                        Row(
                          children: [
                            if (widget.plan.consecutiveMisses > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 12, color: context.colors.warning),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.plan.consecutiveMisses} miss${widget.plan.consecutiveMisses > 1 ? "es" : ""}',
                                      style: context.textStyles.caption.copyWith(
                                        color: context.colors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              '₹${widget.plan.sessionFee.toInt()} / session',
                              style: context.textStyles.caption.copyWith(
                                color: context.colors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Plan status badge row
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildPlanStatusBadge(widget.plan.status),
                    ),
                    // Last active info
                    if (widget.plan.lastActivityAt != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Last active: ${DateFormat('MMM d, yyyy').format(widget.plan.lastActivityAt!.toLocal())}',
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );"""

progressBar_new = """            final isPausedOrReview = widget.plan.status == TreatmentPlanStatus.paused || widget.plan.status == TreatmentPlanStatus.manualReview;
            
            final statusContextRow = isPausedOrReview ? Container(
              margin: EdgeInsets.only(top: 16, left: isDesktop ? 0 : 24, right: isDesktop ? 0 : 24),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.plan.status == TreatmentPlanStatus.paused 
                    ? context.colors.warning.withValues(alpha: 0.1)
                    : context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.plan.status == TreatmentPlanStatus.paused 
                    ? context.colors.warning.withValues(alpha: 0.3)
                    : context.colors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.plan.status == TreatmentPlanStatus.paused ? Icons.pause_circle_outline : Icons.warning_amber_rounded,
                    size: 18,
                    color: widget.plan.status == TreatmentPlanStatus.paused ? context.colors.warning : context.colors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.plan.status == TreatmentPlanStatus.paused
                          ? 'Paused${widget.plan.pausedAt != null ? " on " + DateFormat('dd MMM yyyy').format(DateTime.parse(widget.plan.pausedAt!).toLocal()) : ""}${widget.plan.closureReason?.isNotEmpty == true ? " • Reason: " + widget.plan.closureReason! : ""}'
                          : 'Manual Review${widget.plan.closureReason?.isNotEmpty == true ? " • " + widget.plan.closureReason! : ""}',
                      style: context.textStyles.caption.copyWith(
                        color: widget.plan.status == TreatmentPlanStatus.paused ? context.colors.warning : context.colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ) : const SizedBox.shrink();

            final progressBar = Padding(
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedCount of ${widget.plan.totalSessions} Sessions Completed',
                        style: context.textStyles.label.copyWith(fontSize: 13),
                      ),
                      if (widget.plan.scheduleVersion > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${widget.plan.scheduleVersion}',
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.info,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: widget.plan.totalSessions > 0
                          ? completedCount / widget.plan.totalSessions
                          : 0,
                      backgroundColor: context.colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );"""
content = content.replace(progressBar_old, progressBar_new)


# 3. Update list view to use isLast and remove separator if using line connectors
listView_old = """                : ListView.separated(
                    shrinkWrap: isDesktop,
                    physics: isDesktop ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: state.sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _sessionCard(state.sessions[index]);
                    },
                  );"""
listView_new = """                : ListView.builder(
                    shrinkWrap: isDesktop,
                    physics: isDesktop ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: state.sessions.length,
                    itemBuilder: (context, index) {
                      return _sessionCard(state.sessions[index], isLast: index == state.sessions.length - 1);
                    },
                  );"""
content = content.replace(listView_old, listView_new)

# Inject statusContextRow in Desktop and Mobile layouts
desktop_layout_old = """                          header,
                          const SizedBox(height: 24),
                          progressBar,"""
desktop_layout_new = """                          header,
                          if (isPausedOrReview) statusContextRow,
                          const SizedBox(height: 24),
                          progressBar,"""
content = content.replace(desktop_layout_old, desktop_layout_new)

mobile_layout_old = """                  header,
                  const SizedBox(height: 16),
                  progressBar,"""
mobile_layout_new = """                  header,
                  if (isPausedOrReview) statusContextRow,
                  const SizedBox(height: 16),
                  progressBar,"""
content = content.replace(mobile_layout_old, mobile_layout_new)

# 4. Rewrite _sessionCard signature and implementation
sessionCard_old = """  Widget _sessionCard(SessionModel session) {"""
sessionCard_new = """  Widget _sessionCard(SessionModel session, {bool isLast = false}) {"""
content = content.replace(sessionCard_old, sessionCard_new)

sessionCardBody_old = """    return GestureDetector(
      onTap: () {
        if (!isActive) return;
        if (scheduledDt != null) {
          final schedDay = DateTime(scheduledDt.year, scheduledDt.month, scheduledDt.day);
          final today = DateTime(now.year, now.month, now.day);
          if (schedDay != today) {
            if (isFuture) {
              // V-5 fix: Block recording future sessions
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Session Not Due Yet'),
                  content: Text(
                    'This session is scheduled for ${DateFormat('EEE, MMM d').format(scheduledDt)}. '
                    'You cannot record it before its scheduled date.\\n\\nYou can reschedule it if needed.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rescheduleSessionFromList(session);
                      },
                      child: Text('Reschedule', style: TextStyle(color: context.colors.primary)),
                    ),
                  ],
                ),
              );
            } else {
              // Past date mismatch — allow with confirmation
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Date Mismatch'),
                  content: const Text(
                    'This session is not scheduled for today. Are you sure you want to record it now?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        navigateToRecord(session);
                      },
                      child: Text(
                        'Proceed',
                        style: TextStyle(color: context.colors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }
          } else {
            navigateToRecord(session);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canRecord
                ? context.colors.primary.withValues(alpha: 0.4)
                : context.colors.border,
          ),
          boxShadow: canRecord
              ? [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Session number circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#${session.sessionNumber}',
                  style: context.textStyles.label.copyWith(
                    color: statusColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session ${session.sessionNumber}',
                    style: context.textStyles.label.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.treatmentModality.isNotEmpty
                        ? session.treatmentModality
                        : widget.plan.treatmentType,
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(dateLabel, style: context.textStyles.caption),
                      // Missed session: show original date if rescheduled
                      if (session.isRescheduled && session.originalDate != null &&
                          session.originalDate!.isNotEmpty &&
                          session.originalDate != session.scheduledDate) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(was ${DateFormat('MMM d').format(DateTime.parse(session.originalDate!))})',
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (session.rescheduleCount > 0)
                    Text(
                      'Rescheduled ${session.rescheduleCount}×',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.warning,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            // Badges
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(session.status),
                    style: context.textStyles.caption.copyWith(
                      color: statusColor,
                      fontSize: 11,
                    ),
                  ),
                ),
                // Action Menu
                if (session.status != SessionStatus.completed)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary, size: 20),
                    onSelected: (val) {
                      if (val == 'reschedule') {
                        _rescheduleSessionFromList(session);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'reschedule',
                        child: Row(
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 18, color: context.colors.primary),
                            const SizedBox(width: 8),
                            Text('Reschedule', style: TextStyle(color: context.colors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );"""

sessionCardBody_new = """    // Connector line color mapping
    Color connectorColor;
    if (session.status == SessionStatus.completed) {
      connectorColor = context.colors.success;
    } else if (session.status == SessionStatus.missed) {
      connectorColor = context.colors.error;
    } else if (session.status == SessionStatus.paused || session.status == SessionStatus.waiting) {
      connectorColor = context.colors.warning;
    } else {
      connectorColor = context.colors.border;
    }

    String timeStr = '';
    if (scheduledDt != null) {
      timeStr = DateFormat('h:mm a').format(scheduledDt);
    }
    
    // Formatting Date • Time • Doctor
    List<String> metaParts = [];
    if (dateLabel.isNotEmpty) metaParts.add(dateLabel);
    if (timeStr.isNotEmpty) metaParts.add(timeStr);
    
    final fullMetaString = metaParts.join(' • ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Session number circle
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${session.sessionNumber}',
                      style: context.textStyles.label.copyWith(
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: connectorColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                if (isLast) const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Session Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  if (!isActive) return;
                  if (scheduledDt != null) {
                    final schedDay = DateTime(scheduledDt.year, scheduledDt.month, scheduledDt.day);
                    final today = DateTime(now.year, now.month, now.day);
                    if (schedDay != today) {
                      if (isFuture) {
                        // V-5 fix: Block recording future sessions
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Session Not Due Yet'),
                            content: Text(
                              'This session is scheduled for ${DateFormat('EEE, MMM d').format(scheduledDt)}. '
                              'You cannot record it before its scheduled date.\\n\\nYou can reschedule it if needed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _rescheduleSessionFromList(session);
                                },
                                child: Text('Reschedule', style: TextStyle(color: context.colors.primary)),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Past date mismatch — allow with confirmation
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Date Mismatch'),
                            content: const Text(
                              'This session is not scheduled for today. Are you sure you want to record it now?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  navigateToRecord(session);
                                },
                                child: Text(
                                  'Proceed',
                                  style: TextStyle(color: context.colors.primary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      navigateToRecord(session);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: canRecord
                          ? context.colors.primary.withValues(alpha: 0.4)
                          : context.colors.border,
                    ),
                    boxShadow: canRecord
                        ? [
                            BoxShadow(
                              color: context.colors.primary.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.treatmentModality.isNotEmpty
                                      ? session.treatmentModality
                                      : widget.plan.treatmentType,
                                  style: context.textStyles.label.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fullMetaString,
                                  style: context.textStyles.caption.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                // Missed session: show original date if rescheduled
                                if (session.isRescheduled && session.originalDate != null &&
                                    session.originalDate!.isNotEmpty &&
                                    session.originalDate != session.scheduledDate) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '(was ${DateFormat('MMM d').format(DateTime.parse(session.originalDate!))})',
                                    style: context.textStyles.caption.copyWith(
                                      color: context.colors.textHint,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Status pill & Action Menu
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusLabel(session.status),
                                  style: context.textStyles.caption.copyWith(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (session.status != SessionStatus.completed)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: context.colors.textSecondary, size: 20),
                                  onSelected: (val) {
                                    if (val == 'reschedule') {
                                      _rescheduleSessionFromList(session);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'reschedule',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_calendar_rounded, size: 18, color: context.colors.primary),
                                          const SizedBox(width: 8),
                                          Text('Reschedule', style: TextStyle(color: context.colors.primary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Metadata chips (Pinned, Rescheduled, Manual Review)
                      if (session.isPinned || session.isRescheduled || session.status == SessionStatus.waiting) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (session.isPinned)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: context.colors.info.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.push_pin_rounded, size: 10, color: context.colors.info),
                                    const SizedBox(width: 4),
                                    Text('Pinned', style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.info)),
                                  ],
                                ),
                              ),
                            if (session.isRescheduled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: context.colors.warning.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_calendar_rounded, size: 10, color: context.colors.warning),
                                    const SizedBox(width: 4),
                                    Text('Rescheduled${session.rescheduleCount > 1 ? " ${session.rescheduleCount}×" : ""}', style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.warning)),
                                  ],
                                ),
                              ),
                            if (session.status == SessionStatus.waiting)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: context.colors.warning.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 10, color: context.colors.warning),
                                    const SizedBox(width: 4),
                                    Text('Manual Review', style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.warning)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );"""
content = content.replace(sessionCardBody_old, sessionCardBody_new)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated session_list_screen.dart successfully!")
