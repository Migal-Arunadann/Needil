import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/photo_quota_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Data model for a photo entry shown in the management screen.
class _PhotoEntry {
  final String recordId;
  final String collectionName; // 'consultations' or 'sessions'
  final String collectionId;
  final String fileName;
  final String patientId;
  final String? patientName;
  final DateTime? date;
  final String type; // 'Consultation' or 'Session'
  bool selected;

  _PhotoEntry({
    required this.recordId,
    required this.collectionName,
    required this.collectionId,
    required this.fileName,
    required this.patientId,
    this.patientName,
    this.date,
    required this.type,
    this.selected = false,
  });

  String getUrl(String baseUrl) =>
      '$baseUrl/api/files/$collectionId/$recordId/$fileName?thumb=100x100';

  String getFullUrl(String baseUrl) =>
      '$baseUrl/api/files/$collectionId/$recordId/$fileName';
}

class ManagePhotosScreen extends ConsumerStatefulWidget {
  const ManagePhotosScreen({super.key});

  @override
  ConsumerState<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends ConsumerState<ManagePhotosScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  int _photosUsed = 0;
  int _photoLimit = 2000;

  // Grouped by patient name → list of photo entries
  final Map<String, List<_PhotoEntry>> _groupedPhotos = {};
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final clinicId = ref.read(authProvider).clinicId;
      if (clinicId == null) return;

      // 1. Get quota info
      final quotaService = ref.read(photoQuotaServiceProvider);
      final (used, limit) = await quotaService.getQuota(clinicId);

      // 2. Get all doctors for this clinic
      final doctorsResult = await pb.collection(PBCollections.doctors).getFullList(
        filter: 'clinic = "$clinicId"',
      );
      final doctorIds = doctorsResult.map((d) => d.id).toList();
      if (doctorIds.isEmpty) {
        setState(() {
          _photosUsed = used;
          _photoLimit = limit;
          _isLoading = false;
        });
        return;
      }

      // 3. Build patient name cache
      final patientCache = <String, String>{};

      // 4. Fetch consultations with photos
      final allPhotos = <_PhotoEntry>[];

      for (final doctorId in doctorIds) {
        // Consultations
        try {
          final consultations = await pb.collection(PBCollections.consultations).getFullList(
            filter: 'doctor = "$doctorId" && photos != ""',
            expand: 'patient',
          );
          for (final c in consultations) {
            final photos = c.getListValue<String>('photos');
            final patientId = c.getStringValue('patient');
            String? patientName;
            try {
              final expand = c.data['expand'];
              if (expand != null && expand is Map && expand['patient'] != null) {
                patientName = (expand['patient'] as Map)['full_name'] as String?;
              }
            } catch (_) {}
            if (patientName != null) patientCache[patientId] = patientName;

            for (final photo in photos) {
              if (photo.isEmpty) continue;
              allPhotos.add(_PhotoEntry(
                recordId: c.id,
                collectionName: PBCollections.consultations,
                collectionId: c.collectionId,
                fileName: photo,
                patientId: patientId,
                patientName: patientName ?? patientCache[patientId],
                date: DateTime.tryParse(c.getStringValue('created')),
                type: 'Consultation',
              ));
            }
          }
        } catch (_) {}

        // Sessions
        try {
          final sessions = await pb.collection(PBCollections.sessions).getFullList(
            filter: 'doctor = "$doctorId" && photos != ""',
            expand: 'patient',
          );
          for (final s in sessions) {
            final photos = s.getListValue<String>('photos');
            final patientId = s.getStringValue('patient');
            String? patientName;
            try {
              final expand = s.data['expand'];
              if (expand != null && expand is Map && expand['patient'] != null) {
                patientName = (expand['patient'] as Map)['full_name'] as String?;
              }
            } catch (_) {}
            if (patientName != null) patientCache[patientId] = patientName;

            for (final photo in photos) {
              if (photo.isEmpty) continue;
              allPhotos.add(_PhotoEntry(
                recordId: s.id,
                collectionName: PBCollections.sessions,
                collectionId: s.collectionId,
                fileName: photo,
                patientId: patientId,
                patientName: patientName ?? patientCache[patientId],
                date: DateTime.tryParse(s.getStringValue('created')),
                type: 'Session #${s.getIntValue('session_number')}',
              ));
            }
          }
        } catch (_) {}
      }

      // Resolve any remaining patient names
      for (final entry in allPhotos) {
        if (entry.patientName == null && patientCache.containsKey(entry.patientId)) {
          allPhotos[allPhotos.indexOf(entry)] = _PhotoEntry(
            recordId: entry.recordId,
            collectionName: entry.collectionName,
            collectionId: entry.collectionId,
            fileName: entry.fileName,
            patientId: entry.patientId,
            patientName: patientCache[entry.patientId],
            date: entry.date,
            type: entry.type,
          );
        }
      }

      // Group by patient name
      final grouped = <String, List<_PhotoEntry>>{};
      for (final entry in allPhotos) {
        final name = entry.patientName ?? 'Unknown Patient';
        grouped.putIfAbsent(name, () => []).add(entry);
      }
      // Sort each group by date (newest first)
      for (final list in grouped.values) {
        list.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
      }

      setState(() {
        _photosUsed = used;
        _photoLimit = limit;
        _groupedPhotos
          ..clear()
          ..addAll(grouped);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading photos: $e'), backgroundColor: context.colors.error),
        );
      }
    }
  }

  int get _selectedCount {
    int count = 0;
    for (final list in _groupedPhotos.values) {
      count += list.where((e) => e.selected).length;
    }
    return count;
  }

  Future<void> _deleteSelected() async {
    final selected = <_PhotoEntry>[];
    for (final list in _groupedPhotos.values) {
      selected.addAll(list.where((e) => e.selected));
    }
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: ctx.colors.error, size: 24),
            const SizedBox(width: 10),
            const Text('Delete Photos'),
          ],
        ),
        content: Text(
          'Delete ${selected.length} photo${selected.length != 1 ? 's' : ''}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: ctx.colors.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: TextStyle(color: ctx.colors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final pb = ref.read(pocketbaseProvider);
      int deletedCount = 0;

      // Group selected by (collectionName, recordId) to batch updates
      final byRecord = <String, List<_PhotoEntry>>{};
      for (final entry in selected) {
        final key = '${entry.collectionName}::${entry.recordId}';
        byRecord.putIfAbsent(key, () => []).add(entry);
      }

      for (final entry in byRecord.entries) {
        final parts = entry.key.split('::');
        final collectionName = parts[0];
        final recordId = parts[1];
        final filesToDelete = entry.value.map((e) => e.fileName).toSet();

        try {
          // Fetch current record to get all photos
          final record = await pb.collection(collectionName).getOne(recordId);
          final currentPhotos = record.getListValue<String>('photos');
          final keepPhotos = currentPhotos.where((p) => !filesToDelete.contains(p)).toList();

          // Update with only the kept photos — PocketBase will remove the rest
          await pb.collection(collectionName).update(
            recordId,
            body: {'photos': keepPhotos},
          );
          deletedCount += filesToDelete.length;
        } catch (e) {
          debugPrint('Failed to delete photos from $collectionName/$recordId: $e');
        }
      }

      // Decrement quota
      if (deletedCount > 0) {
        final clinicId = ref.read(authProvider).clinicId;
        if (clinicId != null) {
          await ref.read(photoQuotaServiceProvider).decrementUsage(clinicId, deletedCount);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount photo${deletedCount != 1 ? 's' : ''} deleted'),
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Reload everything
      await _loadPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _photoLimit > 0 ? (_photosUsed / _photoLimit).clamp(0.0, 1.0) : 0.0;
    final progressColor = progress > 0.9
        ? context.colors.error
        : progress > 0.75
            ? context.colors.warning
            : context.colors.success;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Manage Photos', style: context.textStyles.h3),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                final mainBody = Column(
                  children: [
                    // ── Quota Header ──
                    Container(
                      margin: isDesktop ? const EdgeInsets.only(bottom: 20) : const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Photo Storage', style: context.textStyles.label),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Base Plan',
                                    style: context.textStyles.caption.copyWith(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: progressColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_photosUsed / $_photoLimit',
                                  style: context.textStyles.label.copyWith(
                                    color: progressColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: context.colors.border,
                              valueColor: AlwaysStoppedAnimation(progressColor),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_photoLimit - _photosUsed).clamp(0, _photoLimit)} remaining',
                                style: context.textStyles.caption,
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}% used',
                                style: context.textStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Photo List ──
                    Expanded(
                      child: _groupedPhotos.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 64,
                                      color: context.colors.textHint.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  Text('No photos found', style: context.textStyles.bodyMedium.copyWith(
                                    color: context.colors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('Clinical photos will appear here',
                                      style: context.textStyles.caption),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: isDesktop ? const EdgeInsets.only(bottom: 100) : const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _groupedPhotos.length,
                              itemBuilder: (ctx, index) {
                                final patientName = _groupedPhotos.keys.elementAt(index);
                                final photos = _groupedPhotos[patientName]!;
                                final isExpanded = _expandedGroups.contains(patientName);
                                final selectedInGroup = photos.where((e) => e.selected).length;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: context.colors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      // Patient header
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedGroups.remove(patientName);
                                            } else {
                                              _expandedGroups.add(patientName);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: context.colors.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(Icons.person_rounded,
                                                    color: context.colors.primary, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(patientName, style: context.textStyles.label),
                                                    Text(
                                                      '${photos.length} photo${photos.length != 1 ? 's' : ''}'
                                                      '${selectedInGroup > 0 ? ' · $selectedInGroup selected' : ''}',
                                                      style: context.textStyles.caption.copyWith(
                                                        color: selectedInGroup > 0
                                                            ? context.colors.error
                                                            : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isExpanded)
                                                TextButton(
                                                  onPressed: () {
                                                    final allSelected = photos.every((e) => e.selected);
                                                    setState(() {
                                                      for (final p in photos) {
                                                        p.selected = !allSelected;
                                                      }
                                                    });
                                                  },
                                                  child: Text(
                                                    photos.every((e) => e.selected) ? 'Deselect' : 'Select All',
                                                    style: TextStyle(fontSize: 12, color: context.colors.primary),
                                                  ),
                                                ),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                color: context.colors.textHint,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Expanded photo grid
                                      if (isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                          child: Column(
                                            children: [
                                              Divider(height: 1, color: context.colors.divider),
                                              const SizedBox(height: 10),
                                              _buildPhotoGrid(photos),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );

                if (isDesktop) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 800,
                        maxHeight: constraints.maxHeight - 80,
                      ),
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
                  );
                } else {
                  return mainBody;
                }
              },
            ),

      // ── Floating Delete Bar ──
      bottomSheet: _selectedCount > 0
          ? LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final deleteBar = Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$_selectedCount photo${_selectedCount != 1 ? 's' : ''} selected',
                            style: context.textStyles.label.copyWith(color: context.colors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final list in _groupedPhotos.values) {
                                for (final p in list) {
                                  p.selected = false;
                                }
                              }
                            });
                          },
                          child: Text('Clear', style: TextStyle(color: context.colors.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _deleteSelected,
                          icon: _isDeleting
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.delete_rounded, size: 18),
                          label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isDesktop) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: deleteBar,
                    ),
                  );
                } else {
                  return deleteBar;
                }
              },
            )
          : null,
    );
  }

  Widget _buildPhotoGrid(List<_PhotoEntry> photos) {
    final baseUrl = ref.read(pocketbaseProvider).baseUrl;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (ctx, index) {
        final photo = photos[index];
        final dateStr = photo.date != null
            ? DateFormat('dd MMM yy').format(photo.date!)
            : '—';

        return GestureDetector(
          onTap: () {
            setState(() => photo.selected = !photo.selected);
          },
          onLongPress: () {
            // Show full-size photo
            _showFullPhoto(photo, baseUrl);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: photo.selected
                    ? context.colors.error
                    : context.colors.border,
                width: photo.selected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(photo.selected ? 7 : 9),
                  child: Image.network(ImageHelper.getSecureUrl(photo.getUrl(baseUrl)), ref.read(pocketbaseProvider).authStore.token),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.colors.divider,
                      child: Icon(Icons.broken_image_rounded,
                          color: context.colors.textHint, size: 24),
                    ),
                  ),
                ),

                // Bottom label
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photo.type,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Selection checkmark
                if (photo.selected)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: context.colors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullPhoto(_PhotoEntry photo, String baseUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(ImageHelper.getSecureUrl(photo.getFullUrl(baseUrl)), ref.read(pocketbaseProvider).authStore.token),
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 300,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
