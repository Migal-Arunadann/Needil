import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/settings/screens/add_staff_receptionist_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/services/audit_service.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


class ManageReceptionistScreen extends ConsumerStatefulWidget {
  const ManageReceptionistScreen({super.key});

  @override
  ConsumerState<ManageReceptionistScreen> createState() => _ManageReceptionistScreenState();
}

class _ManageReceptionistScreenState extends ConsumerState<ManageReceptionistScreen> {
  List<Map<String, dynamic>> _receptionists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final result = await pb.collection(PBCollections.receptionists).getList(
        filter: 'clinic = "${auth.clinicId}"',
        sort: 'name',
      );
      if (!mounted) return;
      setState(() {
        _receptionists = result.items.map((r) => {
          'id': r.id,
          'name': r.getStringValue('name'),
          'username': r.getStringValue('username'),
          'phone': r.getStringValue('phone'),
          'is_active': r.getBoolValue('is_active'),
          'receptionist_id': r.getStringValue('receptionist_id'),
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? context.colors.error : context.colors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      await pb.collection(PBCollections.receptionists).update(id, body: {'is_active': !current});
      await _load();
      _snack(!current ? 'Account activated.' : 'Account deactivated.');
    } catch (e) {
      _snack('Failed: ${e.toString()}', error: true);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> rec) async {
    final pb = ref.read(pocketbaseProvider); // read before async
    final nameCtrl = TextEditingController(text: rec['name'] as String? ?? '');
    final usernameCtrl = TextEditingController(text: rec['username'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: rec['phone'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditReceptionistDialog(
        nameCtrl: nameCtrl,
        usernameCtrl: usernameCtrl,
        phoneCtrl: phoneCtrl,
        onSubmit: (name, username, phone) async {
          final safe = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final body = <String, dynamic>{
            'name': name,
            'username': username,
            'email': '$safe@pms.local',
          };
          if (phone.isNotEmpty) body['phone'] = phone;
          await pb.collection(PBCollections.receptionists).update(rec['id'], body: body);
        },
      ),
    );

    nameCtrl.dispose();
    usernameCtrl.dispose();
    phoneCtrl.dispose();

    if (saved == true && mounted) {
      _snack('Receptionist details updated.');
      _load();
    }
  }

  Future<void> _showResetPasswordDialog(Map<String, dynamic> rec) async {
    final pb = ref.read(pocketbaseProvider); // read before async
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetPasswordDialog(
        label: rec['name'] as String? ?? 'Receptionist',
        newPassCtrl: newPassCtrl,
        confirmCtrl: confirmCtrl,
        onSubmit: (newPass, confirm) async {
          await pb.collection(PBCollections.receptionists).update(
            rec['id'], body: {'password': newPass, 'passwordConfirm': confirm},
          );
        },
      ),
    );

    newPassCtrl.dispose();
    confirmCtrl.dispose();

    if (result == true && mounted) _snack('Password reset successfully.');
  }

  Future<void> _showActivityLog(Map<String, dynamic> rec) async {
    final auditService = ref.read(auditServiceProvider);
    final logs = await auditService.getReceptionistLogs(rec['id'] as String);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityLogSheet(
        receptionistName: rec['name'] as String? ?? 'Receptionist',
        logs: logs,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Manage Receptionist', style: context.textStyles.h3),
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: context.colors.primary),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => AddStaffReceptionistScreen()),
              );
              if (added == true && mounted) _load();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.colors.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;

                    final mainBody = RefreshIndicator(
                      onRefresh: _load,
                      color: context.colors.primary,
                      child: _receptionists.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              shrinkWrap: isDesktop,
                              physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
                              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(20),
                              itemCount: _receptionists.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (_, i) => _receptionistCard(_receptionists[i]),
                            ),
                    );

                    if (isDesktop) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: mainBody,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return mainBody;
                    }
                  },
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
        const SizedBox(height: 12),
        Text('Failed to load', style: context.textStyles.label),
        const SizedBox(height: 8),
        Text(_error ?? '', style: context.textStyles.caption, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: Text('Retry')),
      ]),
    ),
  );

  Widget _buildEmpty() => ListView(
    children: [
      SizedBox(height: 80),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: context.colors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.support_agent_rounded, size: 36, color: context.colors.info),
          ),
          const SizedBox(height: 16),
          Text('No receptionists yet', style: context.textStyles.label),
          const SizedBox(height: 6),
          Text(
            'Receptionists can be added during\nclinic registration.',
            style: context.textStyles.caption, textAlign: TextAlign.center,
          ),
        ]),
      ),
    ],
  );

  Widget _receptionistCard(Map<String, dynamic> rec) {
    final isActive = rec['is_active'] as bool? ?? true;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? context.colors.border : context.colors.error.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: context.colors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.support_agent_rounded, color: context.colors.info, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  rec['name'] as String? ?? 'Receptionist',
                  style: context.textStyles.label.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isActive ? context.colors.success : context.colors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: context.textStyles.caption.copyWith(
                      color: isActive ? context.colors.success : context.colors.error,
                      fontSize: 9, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 1),
              Text('@${rec['username'] ?? ''}', style: context.textStyles.caption.copyWith(fontSize: 11)),
            ])),
            // Edit details button
            GestureDetector(
              onTap: () => _showEditDialog(rec),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_rounded, size: 16, color: context.colors.primary),
              ),
            ),
          ]),
        ),

        Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),

        // ── Info row ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.badge_outlined, size: 13, color: context.colors.textHint),
            SizedBox(width: 4),
            Text('ID: ${rec['receptionist_id'] ?? '—'}', style: context.textStyles.caption.copyWith(fontSize: 11)),
            if ((rec['phone'] as String?)?.isNotEmpty == true) ...[
              SizedBox(width: 14),
              Icon(Icons.phone_rounded, size: 13, color: context.colors.textHint),
              const SizedBox(width: 4),
              Text(rec['phone'], style: context.textStyles.caption.copyWith(fontSize: 11)),
            ],
          ]),
        ),

        Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),

        // ── Active toggle ──
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          secondary: Icon(
            Icons.toggle_on_rounded,
            size: 18,
            color: isActive ? context.colors.success : context.colors.textHint,
          ),
          title: Text('Account Active', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
          subtitle: Text(
            isActive ? 'Receptionist can log in' : 'Login is disabled',
            style: context.textStyles.caption.copyWith(fontSize: 10),
          ),
          value: isActive,
          onChanged: (_) {
            HapticFeedback.lightImpact();
            _toggleActive(rec['id'], isActive);
          },
          activeColor: context.colors.success,
          dense: true,
        ),

        Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),

        // ── Action buttons ──
        Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            // Reset Password
            Expanded(
              child: GestureDetector(
                onTap: () => _showResetPasswordDialog(rec),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_reset_rounded, size: 15, color: context.colors.warning),
                    const SizedBox(width: 6),
                    Text('Reset Password', style: context.textStyles.caption.copyWith(color: context.colors.warning, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Activity Log
            Expanded(
              child: GestureDetector(
                onTap: () => _showActivityLog(rec),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.history_rounded, size: 15, color: context.colors.info),
                    const SizedBox(width: 6),
                    Text('Activity Log', style: context.textStyles.caption.copyWith(color: context.colors.info, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Reset Password Dialog
// ════════════════════════════════════════════════════════════════════════════

class _ResetPasswordDialog extends StatefulWidget {
  final String label;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmCtrl;
  final Future<void> Function(String newPass, String confirm) onSubmit;

  const _ResetPasswordDialog({
    required this.label,
    required this.newPassCtrl,
    required this.confirmCtrl,
    required this.onSubmit,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final newPass = widget.newPassCtrl.text.trim();
    final confirm = widget.confirmCtrl.text.trim();
    if (newPass.length < 8) { setState(() => _error = 'Password must be at least 8 characters.'); return; }
    if (newPass != confirm) { setState(() => _error = 'Passwords do not match.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onSubmit(newPass, confirm);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed: ${e.toString()}'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.lock_reset_rounded, color: context.colors.warning, size: 18),
      ),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reset Password', style: context.textStyles.h3),
        Text(widget.label, style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 11)),
      ])),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 14, color: context.colors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: context.textStyles.caption.copyWith(color: context.colors.error, fontSize: 11))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _field('New Password', widget.newPassCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 12),
        _field('Confirm Password', widget.confirmCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context, false),
        child: Text('Cancel', style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.warning,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Reset', style: context.textStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: context.textStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.colors.textHint, size: 18),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.primary)),
        filled: true, fillColor: context.colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}

// ════════════════════════════════════════════════════════════════════════════
// Edit Receptionist Details Dialog
// ════════════════════════════════════════════════════════════════════════════

class _EditReceptionistDialog extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController phoneCtrl;
  final Future<void> Function(String name, String username, String phone) onSubmit;

  const _EditReceptionistDialog({
    required this.nameCtrl,
    required this.usernameCtrl,
    required this.phoneCtrl,
    required this.onSubmit,
  });

  @override
  State<_EditReceptionistDialog> createState() => _EditReceptionistDialogState();
}

class _EditReceptionistDialogState extends State<_EditReceptionistDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final name = widget.nameCtrl.text.trim();
    final username = widget.usernameCtrl.text.trim();
    final phone = widget.phoneCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required.'); return; }
    if (username.isEmpty) { setState(() => _error = 'Username is required.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onSubmit(name, username, phone);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to update. Username may already be taken.'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.edit_rounded, color: context.colors.primary, size: 18),
      ),
      SizedBox(width: 10),
      Text('Edit Receptionist', style: context.textStyles.h3),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 14, color: context.colors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: context.textStyles.caption.copyWith(color: context.colors.error, fontSize: 11))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _field('Full Name', widget.nameCtrl, Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _field('Username', widget.usernameCtrl, Icons.alternate_email_rounded),
        const SizedBox(height: 12),
        _field('Phone (optional)', widget.phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context, false),
        child: Text('Cancel', style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Save', style: context.textStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) =>
    TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: context.textStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint),
        prefixIcon: Icon(icon, color: context.colors.textHint, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.primary)),
        filled: true, fillColor: context.colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}

// ════════════════════════════════════════════════════════════════════════════
// Activity Log Bottom Sheet
// ════════════════════════════════════════════════════════════════════════════

class _ActivityLogSheet extends StatelessWidget {
  final String receptionistName;
  final List<Map<String, dynamic>> logs;

  const _ActivityLogSheet({required this.receptionistName, required this.logs});

  IconData _iconForAction(String action) {
    switch (action) {
      case 'createAppointment': return Icons.calendar_today_rounded;
      case 'markArrived': return Icons.how_to_reg_rounded;
      case 'cancelAppointment': return Icons.cancel_rounded;
      case 'rescheduleAppointment': return Icons.event_repeat_rounded;
      case 'createPatient': return Icons.person_add_rounded;
      case 'updatePatient': return Icons.edit_rounded;
      case 'viewPatient': return Icons.visibility_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _colorForAction(BuildContext context, String action) {
    switch (action) {
      case 'createAppointment': return context.colors.primary;
      case 'markArrived': return context.colors.success;
      case 'cancelAppointment': return context.colors.error;
      case 'rescheduleAppointment': return context.colors.warning;
      case 'createPatient': return context.colors.accent;
      case 'updatePatient': return context.colors.info;
      default: return context.colors.textSecondary;
    }
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'createAppointment': return 'Created Appointment';
      case 'markArrived': return 'Marked Arrived';
      case 'cancelAppointment': return 'Cancelled Appointment';
      case 'rescheduleAppointment': return 'Rescheduled';
      case 'createPatient': return 'Created Patient';
      case 'updatePatient': return 'Updated Patient';
      case 'viewPatient': return 'Viewed Patient';
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: 44, height: 4,
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: context.colors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded, color: context.colors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activity Log', style: context.textStyles.h3),
                Text(receptionistName, style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.colors.border),

          // Log entries
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_rounded, size: 40, color: context.colors.textHint),
                const SizedBox(height: 10),
                Text('No activity recorded yet', style: context.textStyles.caption),
              ]),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shrinkWrap: true,
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final log = logs[i];
                  final action = log['action'] as String? ?? '';
                  final details = log['details'] as String? ?? '';
                  final timestamp = log['timestamp'] as String? ?? log['created'] as String? ?? '';
                  DateTime? dt;
                  try { dt = DateTime.parse(timestamp).toLocal(); } catch (_) {}
                  final timeStr = dt != null ? DateFormat('dd MMM, h:mm a').format(dt) : '';
                  final color = _colorForAction(context, action);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForAction(action), color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_labelForAction(action), style: context.textStyles.label.copyWith(fontSize: 13)),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(details, style: context.textStyles.caption.copyWith(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ])),
                      const SizedBox(width: 8),
                      Text(timeStr, style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.textHint)),
                    ]),
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }
}
