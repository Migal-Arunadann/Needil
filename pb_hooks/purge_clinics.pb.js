/// PocketBase JS Hook — Clinic Purge Cron Job
/// Runs daily at 02:00 UTC. Finds all clinics with status='pending_deletion'
/// and purge_at in the past, then cascades deletion through all collections.
///
/// Deploy: Place this file in the pb_hooks/ directory of your PocketBase instance.
/// PocketBase 0.23+ required for cronAdd() support.

/// Register daily cron job at 02:00 UTC
cronAdd("purge-pending-clinics", "0 2 * * *", function () {
  const now = new Date().toISOString();

  console.log("[purge-clinics] Starting daily purge check at " + now);

  let clinics;
  try {
    clinics = $app.dao().findRecordsByFilter(
      "clinics",
      `status = 'pending_deletion' && purge_at != '' && purge_at <= '` + now + `'`,
      "",   // sort
      200,  // max
      0     // offset
    );
  } catch (e) {
    console.log("[purge-clinics] Error fetching clinics: " + e);
    return;
  }

  if (!clinics || clinics.length === 0) {
    console.log("[purge-clinics] No clinics to purge.");
    return;
  }

  console.log("[purge-clinics] Found " + clinics.length + " clinic(s) to purge.");

  for (const clinic of clinics) {
    const clinicId = clinic.id;
    console.log("[purge-clinics] Purging clinic: " + clinicId);

    try {
      // 1. Delete sessions
      deleteByFilter("sessions", `clinic_id = '` + clinicId + `'`);
      // 2. Delete treatment_plans
      deleteByFilter("treatment_plans", `clinic_id = '` + clinicId + `'`);
      // 3. Delete consultations
      deleteByFilter("consultations", `clinic_id = '` + clinicId + `'`);
      // 4. Delete appointments
      deleteByFilter("appointments", `clinic_id = '` + clinicId + `'`);
      // 5. Delete consent_records
      deleteByFilter("consent_records", `clinic_id = '` + clinicId + `'`);
      // 6. Delete patients
      deleteByFilter("patients", `clinic_id = '` + clinicId + `'`);
      // 7. Delete audit_logs
      deleteByFilter("audit_logs", `target_id = '` + clinicId + `'`);
      // 8. Delete reactivation requests
      deleteByFilter("clinic_reactivation_requests", `clinic_id = '` + clinicId + `'`);
      // 9. Delete doctors
      deleteByFilter("doctors", `clinic_id = '` + clinicId + `'`);
      // 10. Delete receptionists
      deleteByFilter("receptionists", `clinic_id = '` + clinicId + `'`);
      // 11. Delete the clinic record itself
      $app.dao().deleteRecord(clinic);

      // Log tombstone
      const tombstone = new Record($app.dao().findCollectionByNameOrId("audit_logs"));
      tombstone.set("user_id", "system");
      tombstone.set("user_role", "system");
      tombstone.set("action", "clinicPurged");
      tombstone.set("target_id", clinicId);
      tombstone.set("details", "Clinic permanently purged by scheduled cron after 30-day retention period.");
      tombstone.set("timestamp", now);
      $app.dao().saveRecord(tombstone);

      console.log("[purge-clinics] ✓ Purged clinic: " + clinicId);
    } catch (e) {
      console.log("[purge-clinics] ✗ Error purging clinic " + clinicId + ": " + e);
    }
  }

  console.log("[purge-clinics] Purge run complete.");
});

/// Helper: delete all records matching a filter in a collection (paginated).
function deleteByFilter(collection, filter) {
  let page = 1;
  const perPage = 200;
  while (true) {
    let records;
    try {
      records = $app.dao().findRecordsByFilter(
        collection, filter, "", perPage, (page - 1) * perPage
      );
    } catch (_) {
      break;
    }
    if (!records || records.length === 0) break;
    for (const r of records) {
      try { $app.dao().deleteRecord(r); } catch (_) {}
    }
    if (records.length < perPage) break;
    page++;
  }
}
