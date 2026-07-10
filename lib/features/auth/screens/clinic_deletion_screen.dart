import 'dart:io' show Directory, File, FileSystemEntity, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/clinic_deletion_service.dart';
import 'package:pms_app/core/services/data_export_service.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pms_app/core/theme/app_theme.dart';

/// Full-page lockout shown when a clinic is in `status = pending_deletion`.
/// No sidebar, no navigation — only deletion info + limited actions.
class ClinicDeletionScreen extends ConsumerStatefulWidget {
  const ClinicDeletionScreen({super.key});

  @override
  ConsumerState<ClinicDeletionScreen> createState() =>
      _ClinicDeletionScreenState();
}

class _ClinicDeletionScreenState extends ConsumerState<ClinicDeletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _isExporting = false;
  String? _exportStatus;
  String? _exportPath;
  bool _isRequesting = false;
  String? _reactivationStatus;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  static const _bg = Color(0xFF0D0D1A);
  static const _cardColor = Color(0xFF1A1A30);
  static const _border = Color(0xFF2A2A45);
  static const _textPrimary = Color(0xFFE2E8F0);
  static const _textSecondary = Color(0xFF94A3B8);
  static const _textHint = Color(0xFF64748B);
  static const _accent = Color(0xFF6366F1); // indigo
  static const _success = Color(0xFF10B981);
  static const _error = Color(0xFFEF4444);
  static const _warning = Color(0xFFF59E0B);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    AppToast.show(msg, type: ToastType.error);
  }

  Future<Directory?> _getSaveDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openExportFolder() async {
    if (_exportPath == null) return;
    try {
      final uri = Uri.directory(_exportPath!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(Uri.parse('file://$_exportPath'));
      }
    } catch (e) {
      _snack('Could not open folder automatically: $e', error: true);
    }
  }

  Future<void> _copyExportPath() async {
    if (_exportPath == null) return;
    await Clipboard.setData(ClipboardData(text: _exportPath!));
    _snack('Folder path copied to clipboard');
  }

  Future<void> _shareExportedFiles() async {
    if (_exportPath == null) return;
    try {
      final dir = Directory(_exportPath!);
      if (!await dir.exists()) {
        _snack('Export directory does not exist.', error: true);
        return;
      }
      final List<FileSystemEntity> entities = await dir.list().toList();
      final List<XFile> xFiles = [];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.csv')) {
          xFiles.add(XFile(entity.path));
        }
      }
      if (xFiles.isEmpty) {
        _snack('No CSV files found to share.', error: true);
        return;
      }
      final params = ShareParams(
        text: 'Needil Clinic Data Export',
        files: xFiles,
      );
      await SharePlus.instance.share(params);
    } catch (e) {
      _snack('Failed to share files: $e', error: true);
    }
  }

  Future<void> _downloadData() async {
    final auth = ref.read(authProvider);
    final clinicId = auth.clinicId;
    final clinicName = auth.clinic?.name ?? 'clinic';
    if (clinicId == null) return;

    setState(() {
      _isExporting = true;
      _exportStatus = 'Fetching data…';
      _exportPath = null;
    });

    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = DataExportService(pb);
      setState(() => _exportStatus = 'Generating CSV files…');
      final csvFiles = await svc.exportAllData(clinicId, clinicName);

      if (kIsWeb) {
        for (final entry in csvFiles.entries) {
          setState(() => _exportStatus = 'Downloading ${entry.key}…');
          downloadCsvWeb(entry.value, entry.key);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        setState(() => _exportStatus = '✓ ${csvFiles.length} files downloaded!');
      } else {
        setState(() => _exportStatus = 'Saving files locally…');
        final baseDir = await _getSaveDirectory();
        if (baseDir == null) {
          throw 'Could not access local storage directories.';
        }

        final sanitizedName = clinicName
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .trim()
            .replaceAll(' ', '_');
        final dateStr = DateTime.now().toIso8601String().substring(0, 10);
        final exportDir = Directory('${baseDir.path}/Needil_Export_${sanitizedName}_$dateStr');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }

        for (final entry in csvFiles.entries) {
          final file = File('${exportDir.path}/${entry.key}');
          await file.writeAsString(entry.value);
        }

        setState(() {
          _exportPath = exportDir.path;
          _exportStatus = '✓ ${csvFiles.length} CSV files exported successfully to:\n${exportDir.path}';
        });
      }
    } catch (e) {
      setState(() {
        _exportStatus = '✗ Export failed: $e';
        _exportPath = null;
      });
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _requestReactivation() async {
    final auth = ref.read(authProvider);
    final clinicId = auth.clinicId;
    final clinicName = auth.clinic?.name ?? '';
    if (clinicId == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ReactivationDialog(reasonCtrl: reasonCtrl),
    );
    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _snack('Please provide a reason for reactivation.', error: true);
      return;
    }

    setState(() {
      _isRequesting = true;
      _reactivationStatus = null;
    });

    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = ClinicDeletionService(pb);
      final error = await svc.requestReactivation(
        clinicId: clinicId,
        clinicName: clinicName,
        requestedBy: clinicId,
        reason: reason,
      );

      if (error == null) {
        setState(() => _reactivationStatus =
            '✓ Reactivation request submitted! A superadmin will review it shortly.');
      } else {
        setState(() => _reactivationStatus = '✗ $error');
      }
    } catch (e) {
      setState(() => _reactivationStatus = '✗ $e');
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final purgeAt = auth.purgeAt;
    final clinicName = auth.clinic?.name ?? 'Your Clinic';

    final daysRemaining = purgeAt != null
        ? purgeAt.difference(DateTime.now()).inDays.clamp(0, 9999)
        : 30;
    final deletionDateStr = purgeAt != null
        ? DateFormat('dd MMM yyyy').format(purgeAt.toLocal())
        : 'Pending';

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header icon ───────────────────────────────────────
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _error.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded,
                            color: _error, size: 36),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────────
                    const Center(
                      child: Text(
                        'Clinic Scheduled For Deletion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        clinicName,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Deletion info card ─────────────────────────────────
                    _card(
                      child: Row(children: [
                        Expanded(
                          child: _infoBlock(
                            icon: Icons.calendar_today_rounded,
                            label: 'Deletion Date',
                            value: deletionDateStr,
                            valueColor: _error,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 52,
                          color: _border,
                        ),
                        Expanded(
                          child: _infoBlock(
                            icon: Icons.hourglass_bottom_rounded,
                            label: 'Days Remaining',
                            value: '$daysRemaining',
                            valueColor: daysRemaining <= 7 ? _error : _warning,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Description ───────────────────────────────────────
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your clinic has requested deletion.',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // What you CAN do
                          const Text(
                            'Until the deletion date:',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          ..._allowed.map((t) => _permRow(t, allowed: true)),
                          const SizedBox(height: 16),

                          // Divider
                          Container(height: 1, color: _border),
                          const SizedBox(height: 16),

                          // What you CANNOT do
                          ..._blocked.map((t) => _permRow(t, allowed: false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Export status ─────────────────────────────────────
                    if (_exportStatus != null) ...[
                      _statusBanner(
                        _exportStatus!,
                        success: _exportStatus!.startsWith('✓'),
                        error: _exportStatus!.startsWith('✗'),
                      ),
                      if (_exportPath != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_isDesktop)
                              Expanded(
                                child: _outlineButton(
                                  icon: Icons.folder_open_rounded,
                                  label: 'Open Folder',
                                  onTap: _openExportFolder,
                                ),
                              )
                            else if (_isMobile)
                              Expanded(
                                child: _outlineButton(
                                  icon: Icons.share_rounded,
                                  label: 'Share Files',
                                  onTap: _shareExportedFiles,
                                ),
                              ),
                            if (_isDesktop || _isMobile) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _outlineButton(
                                  icon: Icons.copy_all_rounded,
                                  label: 'Copy Path',
                                  onTap: _copyExportPath,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    // ── Download Data button ───────────────────────────────
                    _primaryButton(
                      icon: _isExporting
                          ? null
                          : Icons.download_rounded,
                      label: _isExporting
                          ? _exportStatus ?? 'Exporting…'
                          : 'Download Clinic Data',
                      onTap: _isExporting ? null : _downloadData,
                      loading: _isExporting,
                    ),
                    const SizedBox(height: 12),

                    // ── Reactivation status ───────────────────────────────
                    if (_reactivationStatus != null) ...[
                      _statusBanner(
                        _reactivationStatus!,
                        success: _reactivationStatus!.startsWith('✓'),
                        error: _reactivationStatus!.startsWith('✗'),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Request Reactivation button ────────────────────────
                    _outlineButton(
                      icon: Icons.restore_rounded,
                      label: 'Request Reactivation',
                      onTap: (_isRequesting || _reactivationStatus?.startsWith('✓') == true)
                          ? null
                          : _requestReactivation,
                      loading: _isRequesting,
                      color: _success,
                    ),
                    const SizedBox(height: 12),

                    // ── Sign Out button ────────────────────────────────────
                    _outlineButton(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      onTap: _signOut,
                      color: _textHint,
                    ),

                    const SizedBox(height: 32),

                    // ── Footer ─────────────────────────────────────────────
                    const Center(
                      child: Text(
                        'Need help? Contact support@needil.com',
                        style: TextStyle(color: _textHint, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── permission list items ─────────────────────────────────────────────────

  static const _allowed = [
    'Download clinic data',
    'Request reactivation',
    'Contact support',
  ];

  static const _blocked = [
    'Create appointments',
    'Edit patients',
    'Record consultations',
    'Create sessions',
  ];

  Widget _permRow(String label, {required bool allowed}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: allowed
                ? _success.withValues(alpha: 0.12)
                : _error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            allowed ? Icons.check_rounded : Icons.close_rounded,
            size: 13,
            color: allowed ? _success : _error,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: allowed ? _textPrimary : _textHint,
            fontSize: 13,
            fontWeight: allowed ? FontWeight.w500 : FontWeight.w400,
            decoration: allowed ? null : TextDecoration.lineThrough,
            decorationColor: _textHint,
          ),
        ),
      ]),
    );
  }

  // ── ui helpers ─────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _infoBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(children: [
      Icon(icon, color: valueColor, size: 20),
      const SizedBox(height: 6),
      Text(label,
          style: const TextStyle(
              color: _textHint, fontSize: 11, letterSpacing: 0.4)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }

  Widget _statusBanner(String msg,
      {bool success = false, bool error = false}) {
    final color = error ? _error : success ? _success : _accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        msg,
        style: TextStyle(color: color, fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _primaryButton({
    IconData? icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _accent.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.colors.textPrimary),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (!loading) const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
    Color color = _accent,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ── Reactivation dialog ────────────────────────────────────────────────────────

class _ReactivationDialog extends StatelessWidget {
  final TextEditingController reasonCtrl;

  const _ReactivationDialog({required this.reasonCtrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restore_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Request Reactivation',
                    style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Explain why you want to cancel the deletion. A superadmin will review your request.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reason for reactivation…',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF6366F1), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF2A2A45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Submit Request',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
