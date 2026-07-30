/// Needil Scheduling Engine v2 — Database Migration Script
///
/// Run this script ONCE against your PocketBase instance to add the new
/// collections and fields required by the v2 scheduling engine.
///
/// Usage (with pocketbase_dart or via direct HTTP):
///   - This is a reference document for manual PocketBase Admin UI operations.
///   - Fields already existing in PocketBase will cause no harm if re-applied.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CHECKLIST
/// ─────────────────────────────────────────────────────────────────────────────
///
/// [ ] 1. Create collection: scheduling_audit_logs
/// [ ] 2. Create collection: scheduling_exceptions
/// [ ] 3. Add fields to: treatment_plans
/// [ ] 4. Add fields to: sessions
/// [ ] 5. Backfill existing data
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 1: New Collection — scheduling_audit_logs
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Collection: scheduling_audit_logs
/// Type: Base
///
/// Fields:
///   session           Relation → sessions         (optional, nullable)
///   treatment_plan    Relation → treatment_plans   (required)
///   action            Text                         (required)
///                     Examples: missed, auto_completed, rescheduled, paused,
///                               resumed, completed, closed, pinned, unpinned,
///                               moved_to_manual_review, auto_scheduled_from_dashboard
///   old_date          Text                         (optional)
///   old_time          Text                         (optional)
///   new_date          Text                         (optional)
///   new_time          Text                         (optional)
///   reason            Text                         (optional)
///   trigger           Text                         (required)
///                     Values: system_auto, doctor_manual, receptionist_manual, dashboard
///   performed_by      Text                         (required)
///                     User ID or "system"
///   schedule_version  Number                       (optional, default: 1)
///   metadata          JSON                         (optional)
///
/// Indexes:
///   treatment_plan (for plan history queries)
///   action         (for filtering by event type)
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 2: New Collection — scheduling_exceptions
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Collection: scheduling_exceptions
/// Type: Base
///
/// Fields:
///   doctor        Relation → doctors    (optional — if set: doctor-specific)
///   clinic        Relation → clinics    (optional — if set + no doctor: clinic-wide)
///   date          Text  YYYY-MM-DD      (required)
///   reason        Text                  (optional, human-readable)
///   type          Text                  (required)
///                 Values: leave, holiday, closure, training, maintenance
///   is_full_day   Bool                  (default: true)
///   start_time    Text  HH:mm           (optional, for partial-day blocks)
///   end_time      Text  HH:mm           (optional, for partial-day blocks)
///
/// Indexes:
///   date           (for date-range queries during slot finding)
///   doctor         (for per-doctor exception lookups)
///   clinic         (for clinic-wide exception lookups)
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 3: New Fields on treatment_plans
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Add these fields to the existing treatment_plans collection:
///
///   total_misses         Number   default: 0
///                        Lifetime total miss count (never resets)
///
///   completed_sessions   Number   default: 0
///                        Count of sessions with status = "completed"
///
///   schedule_version     Number   default: 1
///                        Incremented on every schedule rebuild
///
///   expiry_days          Number   default: 90
///                        Days of inactivity before auto-transition to manual_review
///
///   last_activity_at     DateTime (optional)
///                        Timestamp of last session completed/rescheduled
///
///   closure_reason       Text     (optional)
///                        Why the plan was closed early
///
///   closed_by            Text     (optional)
///                        User ID who closed the plan
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 4: New Fields on sessions
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Add these fields to the existing sessions collection:
///
///   is_pinned      Bool      default: false
///                  True when a doctor/receptionist manually rescheduled this
///                  session. Auto-cascades skip pinned sessions.
///
///   completed_at   DateTime  (optional)
///                  When the session was actually completed
///
///   missed_at      DateTime  (optional)
///                  When the session was marked missed
///
///   paused_at      DateTime  (optional)
///                  When the session was paused
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 5: Status Enum — treatment_plans
/// ─────────────────────────────────────────────────────────────────────────────
///
/// The status field on treatment_plans must now accept these values:
///   active          (existing)
///   paused          (existing)
///   completed       (existing)
///   manual_review   (NEW — replaces "stuck in dashboard" state)
///   closed          (NEW — early termination)
///
/// All existing "active" plans remain unchanged.
/// Existing PocketBase string field accepts any value — no enum restriction needed.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STEP 6: Data Backfill
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Run these operations via PocketBase Admin or a one-time script:
///
/// 6a. Set schedule_version = 1 on all existing treatment_plans where
///     schedule_version IS NULL or 0.
///
///     UPDATE treatment_plans SET schedule_version = 1
///     WHERE schedule_version IS NULL OR schedule_version = 0;
///
/// 6b. Set last_activity_at = updated on all existing treatment_plans
///     where last_activity_at IS NULL.
///
///     UPDATE treatment_plans SET last_activity_at = updated
///     WHERE last_activity_at IS NULL OR last_activity_at = '';
///
/// 6c. Set completed_sessions = (SELECT COUNT(*) FROM sessions
///     WHERE treatment_plan = id AND status = 'completed')
///     for all existing treatment_plans.
///
///     (No-op if completed_sessions defaults to 0 — counts will catch up
///      automatically as sessions complete going forward.)
///
/// 6d. Set total_misses = (SELECT COUNT(*) FROM sessions
///     WHERE treatment_plan = id AND status = 'missed')
///     for all existing treatment_plans.
///
///     (Optional — only needed for historical accuracy reports.)
///
/// ─────────────────────────────────────────────────────────────────────────────
/// BACKWARD COMPATIBILITY NOTES
/// ─────────────────────────────────────────────────────────────────────────────
///
/// • All new fields have safe defaults — existing data is unaffected.
/// • The new status values (manual_review, closed) are additive — existing
///   plans with status = "active" / "paused" / "completed" continue to work.
/// • The is_paused boolean is preserved on treatment_plans (still updated
///   by TreatmentScheduler) for any UI code that reads it directly.
/// • The consecutive_misses field is preserved and still used by existing
///   dashboard queries.
/// • All existing API call sites and screen code are unaffected — the
///   SessionLifecycleService facade preserves all existing method signatures.

void main() {
  // This script is a documentation artifact.
  // Apply the above changes via the PocketBase Admin UI or a migration runner.
  print('See comments above for manual migration steps.');
}
