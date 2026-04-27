import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'add_staff_receptionist_screen.dart';

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
      backgroundColor: error ? AppColors.error : AppColors.success,
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
      _snack('Failed. Check PocketBase update rule for receptionists.', error: true);
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

  // ────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manage Receptionist', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddStaffReceptionistScreen()),
              );
              if (added == true && mounted) _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _receptionists.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _receptionists.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (_, i) => _receptionistCard(_receptionists[i]),
                        ),
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Text('Failed to load', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Text(_error ?? '', style: AppTextStyles.caption, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]),
    ),
  );

  Widget _buildEmpty() => ListView(
    children: [
      const SizedBox(height: 80),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.support_agent_rounded, size: 36, color: AppColors.info),
          ),
          const SizedBox(height: 16),
          Text('No receptionists yet', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Text(
            'Receptionists can be added during\nclinic registration.',
            style: AppTextStyles.caption, textAlign: TextAlign.center,
          ),
        ]),
      ),
    ],
  );

  Widget _receptionistCard(Map<String, dynamic> rec) {
    final isActive = rec['is_active'] as bool? ?? true;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.support_agent_rounded, color: AppColors.info, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  rec['name'] as String? ?? 'Receptionist',
                  style: AppTextStyles.label.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: AppTextStyles.caption.copyWith(
                      color: isActive ? AppColors.success : AppColors.error,
                      fontSize: 9, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 1),
              Text('@${rec['username'] ?? ''}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ])),
            // Edit details button
            GestureDetector(
              onTap: () => _showEditDialog(rec),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
              ),
            ),
          ]),
        ),

        Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),

        // ── Info row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.badge_outlined, size: 13, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text('ID: ${rec['receptionist_id'] ?? '—'}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
            if ((rec['phone'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(width: 14),
              const Icon(Icons.phone_rounded, size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(rec['phone'], style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ]),
        ),

        Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),

        // ── Active toggle ──
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          secondary: Icon(
            Icons.toggle_on_rounded,
            size: 18,
            color: isActive ? AppColors.success : AppColors.textHint,
          ),
          title: Text('Account Active', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
          subtitle: Text(
            isActive ? 'Receptionist can log in' : 'Login is disabled',
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
          value: isActive,
          onChanged: (_) => _toggleActive(rec['id'], isActive),
          activeColor: AppColors.success,
          dense: true,
        ),

        Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),

        // ── Action buttons ──
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Reset Password
            Expanded(
              child: GestureDetector(
                onTap: () => _showResetPasswordDialog(rec),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.lock_reset_rounded, size: 15, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text('Reset Password', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
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
      if (mounted) setState(() { _loading = false; _error = 'Failed. Check PocketBase update rule.'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reset Password', style: AppTextStyles.h3),
        Text(widget.label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11)),
      ])),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11))),
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
        child: Text('Cancel', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Reset', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textHint, size: 18),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
        filled: true, fillColor: AppColors.background,
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
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 10),
      Text('Edit Receptionist', style: AppTextStyles.h3),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11))),
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
        child: Text('Cancel', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Save', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) =>
    TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
        filled: true, fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}
