/**
 * PocketBase Server-Side Tamper-Proof Audit Logging Hook
 */

console.log('>>> [AUDIT_HOOK] Audit hook loaded successfully at startup <<<');

const AUDITED_COLLECTIONS = [
  'patients',
  'appointments',
  'consultations',
  'treatment_plans',
  'sessions',
  'consent_records',
  'doctors',
  'receptionists',
  'clinics',
  'scheduling_exceptions',
  'clinic_reactivation_requests',
];

function writeAuditLog(e, actionType) {
  try {
    const auditLogsCollection = $app.findCollectionByNameOrId('audit_logs');
    if (!auditLogsCollection) {
      console.log('>>> [AUDIT_HOOK] audit_logs collection not found');
      return;
    }

    let authRecord = null;
    let clientIp = '';

    if (e.httpContext) {
      authRecord = e.httpContext.get('authRecord');
      clientIp = e.httpContext.realIP() || e.httpContext.remoteIP() || '';
    }

    const userId = authRecord ? authRecord.id : 'system';
    const userRole = authRecord ? (authRecord.collection ? authRecord.collection().name : 'system') : 'system';
    const collName = e.collection ? (e.collection.name || e.collection.id || '').toUpperCase() : 'UNKNOWN';

    const logRecord = new Record(auditLogsCollection);
    logRecord.set('user_id', userId);
    logRecord.set('user_role', userRole);
    logRecord.set('action', `${actionType}_${collName}`);
    logRecord.set('target_id', e.record ? e.record.id : '');
    logRecord.set('details', '');
    logRecord.set('timestamp', new Date().toISOString());
    logRecord.set('ip_address', clientIp);

    $app.save(logRecord);
    console.log(`>>> [AUDIT_HOOK] Logged ${actionType}_${collName} by ${userId} (${userRole})`);
  } catch (err) {
    console.error('>>> [AUDIT_HOOK_ERROR]', err);
  }
}

// ─── Interceptors ───────────────────────────────────────────────────────────
onRecordAfterCreateSuccess((e) => {
  writeAuditLog(e, 'CREATE');
}, ...AUDITED_COLLECTIONS);

onRecordAfterUpdateSuccess((e) => {
  writeAuditLog(e, 'UPDATE');
}, ...AUDITED_COLLECTIONS);

onRecordAfterDeleteSuccess((e) => {
  writeAuditLog(e, 'DELETE');
}, ...AUDITED_COLLECTIONS);
