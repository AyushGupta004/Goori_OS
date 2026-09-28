import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/command_service.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/settings_service.dart';
import '../../connection/screens/discovery_screen.dart';
import '../services/speech_recognition_service.dart';

/// Screen managing full voice command flow:
/// - Idle state ("○ MIC / Tap to command")
/// - Listening state ("● LISTENING..." with subtle pulse/fade animation)
/// - Live partial transcript streaming
/// - "COMMAND" review card with [SEND] / [CANCEL] (or auto-send via Settings toggle)
/// - Correlated command dispatch and "✓ Command completed" / "✕ Command failed" result badges
class VoiceScreen extends StatefulWidget {
  final SpeechRecognitionService? speechService;

  const VoiceScreen({
    super.key,
    this.speechService,
  });

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  late SpeechRecognitionService _speechService;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _liveTranscript = '';
  String? _stagedCommand;
  bool _isDispatching = false;
  CommandResult? _lastResult;
  bool _hasAttemptedPermission = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _speechService = widget.speechService ?? NativeSpeechRecognitionService();

    // Subtle, calm pulse animation for LISTENING state
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.speechService == null) {
      try {
        _speechService = context.read<SpeechRecognitionService>();
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(VoiceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speechService != null &&
        widget.speechService != _speechService) {
      _speechService = widget.speechService!;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _onMicTap() async {
    if (_isDispatching) return;

    if (_speechService.isListening) {
      await _speechService.stopListening();
      if (!mounted) return;
      final settings = context.read<SettingsService>();
      final autoSend = !settings.confirmBeforeSend;
      final trimmed = _liveTranscript.trim();
      if (trimmed.isNotEmpty) {
        if (autoSend) {
          _dispatchCommand(trimmed);
        } else {
          setState(() {
            _stagedCommand = trimmed;
          });
        }
      }
      return;
    }

    _lastResult = null;

    // Check permission on first tap
    if (!_hasAttemptedPermission) {
      _hasAttemptedPermission = true;
      final granted = await _speechService.requestPermission();
      if (!granted) {
        setState(() {
          _permissionDenied = true;
        });
        return;
      }
    } else if (_permissionDenied) {
      final granted = await _speechService.requestPermission();
      if (!granted) return;
      setState(() {
        _permissionDenied = false;
      });
    }

    setState(() {
      _liveTranscript = '';
      _stagedCommand = null;
    });

    if (!mounted) return;
    final settings = context.read<SettingsService>();
    final autoSend = !settings.confirmBeforeSend;

    await _speechService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _liveTranscript = words;
        });

        if (isFinal) {
          final trimmed = words.trim();
          if (trimmed.isNotEmpty) {
            if (autoSend) {
              _dispatchCommand(trimmed);
            } else {
              setState(() {
                _stagedCommand = trimmed;
              });
            }
          }
        }
      },
      onError: (errMsg) {
        debugPrint('[VoiceScreen] Speech error: $errMsg');
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  Future<void> _dispatchCommand(String payload) async {
    final cleanPayload = payload.trim();
    if (cleanPayload.isEmpty) return;

    setState(() {
      _isDispatching = true;
      _stagedCommand = null;
      _lastResult = null;
    });

    final commandService = context.read<CommandService>();

    // Unique generated request_id conforming to spec: cmd-{timestamp}-{n}
    final requestId = commandService.generateRequestId();

    final request = CommandRequest(
      commandId: requestId,
      type: 'voice_transcript',
      payload: cleanPayload,
      timestamp: DateTime.now(),
    );

    try {
      final result = await commandService.sendCommandRequest(request);

      if (!mounted) return;

      if (!result.success && result.errorDetails != null) {
        debugPrint(
            '[VoiceScreen] Technical error detail for request $requestId: ${result.errorDetails}');
      }

      setState(() {
        _isDispatching = false;
        _lastResult = result;
      });
    } catch (e) {
      debugPrint('[VoiceScreen] Unhandled dispatch exception for $requestId: $e');
      if (!mounted) return;
      setState(() {
        _isDispatching = false;
        _lastResult = CommandResult(
          commandId: requestId,
          success: false,
          status: 'failed',
          message: AppErrorMapper.map(e, fallback: AppErrors.commandFailed),
          timestamp: DateTime.now(),
          errorDetails: e.toString(),
        );
      });
    }
  }

  void _onCancelReview() {
    setState(() {
      _stagedCommand = null;
      _liveTranscript = '';
      _speechService.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final connectionService = context.watch<ConnectionService>();
    final isAuthenticated = connectionService.isAuthenticated;
    final isListening = _speechService.isListening;

    if (isListening) {
      if (!_fadeController.isAnimating) {
        _fadeController.repeat(reverse: true);
      }
    } else {
      if (_fadeController.isAnimating) {
        _fadeController.stop();
      }
    }

    return Scaffold(
      key: const ValueKey('voice_screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'VOICE TRANSMIT',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('voice_history_btn'),
            icon: const Icon(Icons.history_rounded, size: 20),
            tooltip: 'Command History',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.commands),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: palette.border,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Disconnected inline strip if not authenticated
              if (!isAuthenticated) ...[
                _buildNotConnectedStrip(palette),
              ],

              // 1. Mic idle / listening indicator block
              _buildStateHeader(isListening, palette),

              const SizedBox(height: 32),

              // 2. Centered minimal geometric microphone button
              Center(
                child: _buildMicButton(isListening, isAuthenticated, palette),
              ),

              const SizedBox(height: 24),

              // 3. Permission rationale banner (if denied)
              if (_permissionDenied) ...[
                _buildPermissionRationaleCard(palette),
                const SizedBox(height: 20),
              ],

              // 4. Live transcript display (when listening or just spoken)
              if (isListening || (_liveTranscript.isNotEmpty && _stagedCommand == null && _lastResult == null)) ...[
                _buildLiveTranscriptBox(palette),
                const SizedBox(height: 20),
              ],

              // 5. "COMMAND" review card with [SEND] / [CANCEL]
              if (_stagedCommand != null && !_isDispatching) ...[
                _buildReviewCard(_stagedCommand!, isAuthenticated, palette),
                const SizedBox(height: 20),
              ],

              // 6. Transmitting indicator
              if (_isDispatching) ...[
                _buildDispatchingCard(palette),
                const SizedBox(height: 20),
              ],

              // 7. Correlated Command Result (✓ Command completed / ✕ Command failed)
              if (_lastResult != null && !_isDispatching) ...[
                _buildResultCard(_lastResult!, palette),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Subtle inline strip showing disconnection status with CONNECT action.
  Widget _buildNotConnectedStrip(AppPalette palette) {
    return Container(
      key: const ValueKey('voice_not_connected_strip'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: palette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not connected to PC',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            key: const ValueKey('voice_connect_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiscoveryScreen(),
                ),
              );
            },
            child: Text(
              'CONNECT',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header indicator: idle shows "○ MIC / Tap to command", recording shows "● LISTENING..."
  Widget _buildStateHeader(bool isListening, AppPalette palette) {
    if (isListening) {
      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '● LISTENING...',
                  key: const ValueKey('voice_listening_indicator'),
                  style: AppTypography.monoConsole.copyWith(
                    color: palette.accentGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.textMuted, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '○ MIC / Tap to command',
          key: const ValueKey('voice_idle_indicator'),
          style: AppTypography.monoConsole.copyWith(
            color: palette.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Geometric, minimal microphone control button
  Widget _buildMicButton(
      bool isListening, bool isAuthenticated, AppPalette palette) {
    final canTap = isAuthenticated && !_isDispatching;
    return InkWell(
      key: const ValueKey('voice_mic_btn'),
      onTap: canTap ? _onMicTap : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: isListening
              ? palette.accentGreen.withValues(alpha: 0.08)
              : palette.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isListening
                ? palette.accentGreen
                : (isAuthenticated ? palette.textPrimary : palette.border),
            width: isListening ? 2.0 : 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
            size: 46,
            color: isListening
                ? palette.accentGreen
                : (isAuthenticated ? palette.textPrimary : palette.textMuted.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }

  /// Friendly rationale card when microphone permission is denied
  Widget _buildPermissionRationaleCard(AppPalette palette) {
    return Container(
      key: const ValueKey('mic_permission_rationale_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_off_outlined,
                color: palette.errorRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'MICROPHONE PERMISSION NEEDED',
                style: AppTypography.sectionHeading.copyWith(
                  color: palette.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Microphone access is needed to capture voice commands for your Windows PC.',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 12,
              height: 1.4,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const ValueKey('grant_permission_btn'),
            onPressed: () async {
              final granted = await _speechService.requestPermission();
              setState(() {
                _permissionDenied = !granted;
              });
            },
            child: const Text('GRANT PERMISSION'),
          ),
        ],
      ),
    );
  }

  /// Real-time partial transcript box
  Widget _buildLiveTranscriptBox(AppPalette palette) {
    return Container(
      key: const ValueKey('live_transcript_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSCRIPT',
            style: AppTypography.mutedMetadata.copyWith(
              color: palette.textMuted,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _liveTranscript.isNotEmpty
                ? _liveTranscript
                : 'Listening for speech...',
            key: const ValueKey('live_transcript_text'),
            style: AppTypography.monoConsole.copyWith(
              color: _liveTranscript.isNotEmpty
                  ? palette.textPrimary
                  : palette.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Review card displaying recognized text with [SEND] and [CANCEL] actions
  Widget _buildReviewCard(
      String commandText, bool isAuthenticated, AppPalette palette) {
    final canSend = isAuthenticated && !_isDispatching;
    return Container(
      key: const ValueKey('command_review_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.textPrimary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND',
            style: AppTypography.mutedMetadata.copyWith(
              color: palette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.secondary,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: palette.border, width: 1),
            ),
            child: Text(
              commandText,
              key: const ValueKey('staged_command_text'),
              style: AppTypography.monoConsole.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cancel_command_btn'),
                  onPressed: _onCancelReview,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textMuted,
                    side: BorderSide(color: palette.border, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'CANCEL',
                    style: AppTypography.sectionHeading.copyWith(
                      fontSize: 12,
                      color: palette.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('send_command_btn'),
                  onPressed: canSend ? () => _dispatchCommand(commandText) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.textPrimary,
                    foregroundColor: palette.background,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'SEND',
                    style: AppTypography.sectionHeading.copyWith(
                      fontSize: 12,
                      color: palette.background,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dispatch in-flight status indicator
  Widget _buildDispatchingCard(AppPalette palette) {
    return Container(
      key: const ValueKey('dispatching_command_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'TRANSMITTING TO WINDOWS...',
            style: AppTypography.monoConsole.copyWith(
              color: palette.textPrimary,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Execution result badge: "✓ Command completed" / "✕ Command failed"
  Widget _buildResultCard(CommandResult result, AppPalette palette) {
    final isSuccess = result.success;

    return Container(
      key: const ValueKey('command_result_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSuccess ? palette.accentGreen : palette.errorRed,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isSuccess ? '✓' : '✕',
                style: TextStyle(
                  color: isSuccess ? palette.accentGreen : palette.errorRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isSuccess ? '✓ Command completed' : '✕ Command failed',
                key: ValueKey(isSuccess
                    ? 'command_completed_text'
                    : 'command_failed_text'),
                style: AppTypography.sectionHeading.copyWith(
                  color: isSuccess ? palette.accentGreen : palette.errorRed,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSuccess
                ? 'Automation executed successfully on Windows.'
                : 'Windows host reported an execution failure.',
            style: AppTypography.mutedMetadata.copyWith(
              color: palette.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
