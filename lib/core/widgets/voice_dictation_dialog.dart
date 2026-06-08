import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/services/ollama_service.dart';

/// A voice dictation overlay dialog with optional AI cleanup via Ollama.
///
/// Opens a bottom-sheet-style dialog with a live animated microphone,
/// real-time transcript display, an optional ✨ Summarize action,
/// and Insert / Cancel actions.
///
/// Usage:
/// ```dart
/// await VoiceDictationDialog.show(
///   context: context,
///   controller: _notesCtrl,
/// );
/// ```
class VoiceDictationDialog extends StatefulWidget {
  final TextEditingController controller;
  final String fieldLabel;

  const VoiceDictationDialog({
    super.key,
    required this.controller,
    this.fieldLabel = 'field',
  });

  /// Convenience method — shows the dialog as a bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required TextEditingController controller,
    String fieldLabel = 'field',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceDictationDialog(
        controller: controller,
        fieldLabel: fieldLabel,
      ),
    );
  }

  @override
  State<VoiceDictationDialog> createState() => _VoiceDictationDialogState();
}

class _VoiceDictationDialogState extends State<VoiceDictationDialog>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInitializing = true;
  bool _isAvailable = false;
  bool _isListening = false;
  bool _hasError = false;
  String _errorMsg = '';

  /// The text transcribed so far in this session.
  String _transcribed = '';

  /// AI summarization state
  bool _isSummarizing = false;
  String? _summarizeError;
  bool _wasSummarized = false; // shows the "✓ summarized" badge

  /// Animation controllers for the sound-wave micro-animation.
  late final List<AnimationController> _barCtrl;
  late final List<Animation<double>> _barAnim;
  static const int _barCount = 5;

  @override
  void initState() {
    super.initState();
    _barCtrl = List.generate(
      _barCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
        lowerBound: 0.15,
        upperBound: 1.0,
      )..repeat(reverse: true),
    );
    _barAnim = _barCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();

    // Pause bars initially (not listening yet)
    for (final c in _barCtrl) {
      c.stop();
      c.value = 0.15;
    }

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _hasError = true;
              _errorMsg = e.errorMsg;
            });
            _pauseBars();
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            _pauseBars();
          }
        },
      );
      if (mounted) {
        setState(() {
          _isAvailable = available;
          _isInitializing = false;
        });
        if (available) _startListening();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
          _isInitializing = false;
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_isAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _hasError = false;
      _errorMsg = '';
      _wasSummarized = false;
    });
    _animateBars();

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _transcribed = result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(minutes: 3),
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    _pauseBars();
  }

  void _animateBars() {
    for (int i = 0; i < _barCtrl.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted && _isListening) _barCtrl[i].repeat(reverse: true);
      });
    }
  }

  void _pauseBars() {
    for (final c in _barCtrl) {
      c.animateTo(0.15, duration: const Duration(milliseconds: 300));
    }
  }

  /// Calls Ollama to clean up the raw transcribed text.
  Future<void> _summarize() async {
    final raw = _transcribed.trim();
    if (raw.isEmpty) return;

    // Stop listening first so the text is stable
    if (_isListening) await _stopListening();

    setState(() {
      _isSummarizing = true;
      _summarizeError = null;
    });

    try {
      final cleaned = await OllamaService.instance.summarizeVoiceText(raw);
      if (mounted) {
        setState(() {
          _transcribed = cleaned;
          _isSummarizing = false;
          _wasSummarized = true;
        });
      }
    } on OllamaException catch (e) {
      if (mounted) {
        setState(() {
          _isSummarizing = false;
          _summarizeError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSummarizing = false;
          _summarizeError = 'Unexpected error: $e';
        });
      }
    }
  }

  void _insert() {
    final text = _transcribed.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final ctrl = widget.controller;
    final existing = ctrl.text;
    if (existing.isEmpty) {
      ctrl.text = text;
    } else {
      final separator = existing.endsWith(' ') || existing.endsWith('\n') ? '' : ' ';
      ctrl.text = '$existing$separator$text';
    }
    // Move cursor to end
    ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: ctrl.text.length),
    );
    Navigator.pop(context);
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMsg = '';
      _transcribed = '';
      _wasSummarized = false;
      _summarizeError = null;
    });
    _startListening();
  }

  @override
  void dispose() {
    _speech.stop();
    for (final c in _barCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // ── Title row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Voice Dictation', style: context.textStyles.h3),
                if (_wasSummarized) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 11, color: Color(0xFF7C3AED)),
                        SizedBox(width: 4),
                        Text(
                          'AI cleaned',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Speak to fill the ${widget.fieldLabel}',
              style: context.textStyles.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // ── Mic + Sound Wave ──
            _buildMicWidget(),
            const SizedBox(height: 28),

            // ── Transcript ──
            _buildTranscriptArea(),

            // ── Summarize error ──
            if (_summarizeError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 14, color: context.colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI error: $_summarizeError',
                        style: context.textStyles.caption.copyWith(color: context.colors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Summarize button (only when there's text & not summarizing) ──
            if (_transcribed.trim().isNotEmpty && !_isSummarizing) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _summarize,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(_wasSummarized ? 'Re-summarize with AI' : '✨  Summarize with AI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Summarizing loader ──
            if (_isSummarizing) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI is cleaning your notes…',
                      style: context.textStyles.caption.copyWith(
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Action Buttons ──
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMicWidget() {
    if (_isInitializing) {
      return Column(children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            color: context.colors.primary,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Initializing microphone…',
          style: context.textStyles.caption.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ]);
    }

    if (_hasError || !_isAvailable) {
      return Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.colors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_off_rounded, color: context.colors.error, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          !_isAvailable
              ? 'Microphone not available.\nPlease grant microphone permission.'
              : 'Error: $_errorMsg',
          textAlign: TextAlign.center,
          style: context.textStyles.caption.copyWith(color: context.colors.error),
        ),
      ]);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left bars
        ..._buildBars(reverse: true),
        const SizedBox(width: 16),

        // Mic button
        GestureDetector(
          onTap: _isSummarizing ? null : (_isListening ? _stopListening : _startListening),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isListening
                  ? LinearGradient(
                      colors: [
                        context.colors.primary,
                        context.colors.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _isSummarizing
                  ? context.colors.border.withValues(alpha: 0.5)
                  : _isListening
                      ? null
                      : context.colors.primary.withValues(alpha: 0.1),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
              border: _isListening
                  ? null
                  : Border.all(
                      color: _isSummarizing
                          ? context.colors.border
                          : context.colors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: _isSummarizing
                  ? context.colors.textHint
                  : _isListening
                      ? Colors.white
                      : context.colors.primary,
              size: 30,
            ),
          ),
        ),

        const SizedBox(width: 16),
        // Right bars
        ..._buildBars(reverse: false),
      ],
    );
  }

  List<Widget> _buildBars({required bool reverse}) {
    final indices = reverse
        ? List.generate(_barCount, (i) => _barCount - 1 - i)
        : List.generate(_barCount, (i) => i);

    return indices.map((i) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedBuilder(
          animation: _barAnim[i],
          builder: (context, child) {
            final scale = _isListening ? _barAnim[i].value : 0.15;
            final height = 28.0 * scale;
            return Container(
              width: 4,
              height: math.max(height, 4),
              decoration: BoxDecoration(
                color: _isListening
                    ? Color.lerp(
                        context.colors.primary.withValues(alpha: 0.4),
                        context.colors.accent,
                        _barAnim[i].value,
                      )
                    : context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildTranscriptArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _wasSummarized
            ? const Color(0xFF7C3AED).withValues(alpha: 0.04)
            : context.colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _wasSummarized
              ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
              : _isListening
                  ? context.colors.primary.withValues(alpha: 0.4)
                  : context.colors.border,
          width: (_wasSummarized || _isListening) ? 1.5 : 1,
        ),
      ),
      child: _transcribed.isEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.record_voice_over_outlined,
                  size: 18,
                  color: context.colors.textHint,
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening ? 'Listening…' : 'Tap the mic to start',
                  style: context.textStyles.bodyMedium.copyWith(
                    color: context.colors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Text(
                _transcribed,
                style: context.textStyles.bodyMedium.copyWith(
                  color: context.colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
    );
  }

  Widget _buildActions() {
    if (_hasError || !_isAvailable) {
      return Column(children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        ),
      ]);
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSummarizing ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.colors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: (_transcribed.trim().isEmpty || _isSummarizing) ? null : _insert,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Insert Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
