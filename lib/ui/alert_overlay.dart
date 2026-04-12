import 'dart:async';

import 'package:flutter/material.dart';

import '../managers/alert_manager.dart';
import '../models/incoming_alert.dart';
import '../services/audio_service.dart';
import '../services/device_auth_service.dart';
import 'widgets/novitas_logo.dart';

enum _OverlayStep { incoming, audioActions, textAlert, declineReasons, confirmation }

class AlertOverlay extends StatefulWidget {
  final IncomingAlert alert;
  final AlertManager alertManager;

  const AlertOverlay({
    required this.alert,
    required this.alertManager,
    super.key,
  });

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  _OverlayStep _step = _OverlayStep.incoming;

  // ── Pulsing ring animation ─────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── 15-second auto-dismiss ─────────────────────────────────────────────────
  static const int _totalSeconds = 15;
  int _secondsLeft = _totalSeconds;
  Timer? _dismissTimer;
  Timer? _tickTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Pulse animation: 1.8 s per cycle, repeats indefinitely
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    // Start looping ringtone (bypasses silent switch via AudioService)
    AudioService.instance.playLoop();

    // Auto-dismiss countdown
    _startCountdown();
  }

  void _startCountdown() {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) _autoDismiss();
    });
    _dismissTimer = Timer(
      Duration(seconds: _totalSeconds),
      _autoDismiss,
    );
  }

  void _cancelCountdown() {
    _dismissTimer?.cancel();
    _tickTimer?.cancel();
    _dismissTimer = null;
    _tickTimer = null;
  }

  void _autoDismiss() {
    _cancelCountdown();
    if (!mounted) return;
    widget.alertManager.stopAndDismiss();
  }

  @override
  void dispose() {
    _cancelCountdown();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  /// Used for YES/NO on the incoming screen.
  /// Phone already unlocked → no Face ID re-prompt here.
  void _goTo(_OverlayStep next) {
    _cancelCountdown();
    AudioService.instance.stop();
    if (!mounted) return;
    setState(() => _step = next);
  }

  /// Used for actions AFTER the incoming screen (confirmation, submit).
  /// Asks Face ID because user is submitting a deliberate response.
  Future<void> _moveWithAuth(_OverlayStep next) async {
    final authenticated = await DeviceAuthService.authenticateIfAvailable();
    if (!mounted || !authenticated) return;
    setState(() => _step = next);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [Color(0xFF0D2F20), Color(0xFF03130B), Color(0xFF010B06)],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_step) {
              _OverlayStep.incoming     => _incomingScreen(),
              _OverlayStep.audioActions => _audioActionsScreen(),
              _OverlayStep.textAlert    => _textAlertScreen(),
              _OverlayStep.declineReasons => _declineReasonsScreen(),
              _OverlayStep.confirmation => _confirmationScreen(),
            },
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // INCOMING CALL SCREEN  (pixel-perfect match to the design)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _incomingScreen() {
    return Padding(
      key: const ValueKey('incoming'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        children: [
          // ── INCOMING ALERT badge ───────────────────────────────────────────
          _IncomingBadge(secondsLeft: _secondsLeft),

          const SizedBox(height: 36),

          // ── Pulsing rings + ES avatar ──────────────────────────────────────
          _PulsingAvatar(animation: _pulseAnim),

          const SizedBox(height: 32),

          // ── Title ─────────────────────────────────────────────────────────
          const Text(
            'Emergency\nSystem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          // ── Subtitle ──────────────────────────────────────────────────────
          const Text(
            'Secure Emergency Response',
            style: TextStyle(color: Color(0xFF849090), fontSize: 17),
          ),

          const Spacer(),

          // ── Critical panel ────────────────────────────────────────────────
          const _CriticalPanel(),

          const SizedBox(height: 40),

          // ── NO / YES buttons ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallButton(
                icon: Icons.close,
                color: const Color(0xFFEF4444),
                label: 'NO',
                onTap: () => _goTo(_OverlayStep.declineReasons),
              ),
              _CallButton(
                icon: Icons.check,
                color: const Color(0xFF22C55E),
                label: 'YES',
                onTap: () => _goTo(
                  widget.alert.type is TextAlert
                      ? _OverlayStep.textAlert
                      : _OverlayStep.audioActions,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // AUDIO ACTIONS SCREEN
  // ════════════════════════════════════════════════════════════════════════════
  Widget _audioActionsScreen() {
    return _Layout(
      key: const ValueKey('audio'),
      title: 'Emergency System',
      subtitle: 'Alert #${widget.alert.id} · Audio',
      topBadge: 'PLAYING',
      center: Column(
        children: [
          const _WavePlaceholder(),
          const SizedBox(height: 8),
          Slider(
            value: 0.32,
            onChanged: (_) {},
            activeColor: const Color(0xFFEF4444),
            inactiveColor: const Color(0xFF334155),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              CircleAvatar(backgroundColor: Color(0xFF1A223C), child: Icon(Icons.replay_10, color: Colors.white)),
              CircleAvatar(radius: 30, backgroundColor: Color(0xFFEF4444), child: Icon(Icons.play_arrow, color: Colors.white, size: 34)),
              CircleAvatar(backgroundColor: Color(0xFF1A223C), child: Icon(Icons.forward_10, color: Colors.white)),
            ],
          ),
        ],
      ),
      panel: _ResponsePanel(
        onAttend: () => _moveWithAuth(_OverlayStep.confirmation),
        onDecline: () => _moveWithAuth(_OverlayStep.declineReasons),
      ),
      bottom: _ActionButton(
        text: 'Confirm with Face ID',
        color: const Color(0xFF22C55E),
        onTap: () => _moveWithAuth(_OverlayStep.confirmation),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TEXT ALERT SCREEN
  // ════════════════════════════════════════════════════════════════════════════
  Widget _textAlertScreen() {
    final message = widget.alert.type is TextAlert
        ? (widget.alert.type as TextAlert).message
        : 'Priority Alert';
    return _Layout(
      key: const ValueKey('text'),
      title: 'Text Alert',
      subtitle: 'EMERGENCY SYSTEM • CRITICAL',
      center: _GlassTile(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, height: 1.5),
          textAlign: TextAlign.left,
        ),
      ),
      panel: _ResponsePanel(
        onAttend: () => _moveWithAuth(_OverlayStep.confirmation),
        onDecline: () => _moveWithAuth(_OverlayStep.declineReasons),
      ),
      bottom: _ActionButton(
        text: 'Respond with Face ID',
        color: const Color(0xFF1E5EFF),
        onTap: () => _moveWithAuth(_OverlayStep.confirmation),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DECLINE REASONS SCREEN
  // ════════════════════════════════════════════════════════════════════════════
  Widget _declineReasonsScreen() {
    return _Layout(
      key: const ValueKey('decline'),
      title: 'Decline Reason',
      subtitle: 'WHY ARE YOU DECLINING?',
      center: Column(
        children: const [
          _ReasonTile(label: 'Busy', icon: Icons.do_not_disturb_on_outlined),
          SizedBox(height: 10),
          _ReasonTile(label: 'Not available', icon: Icons.person_off_outlined),
          SizedBox(height: 10),
          _ReasonTile(label: 'Wrong notification', icon: Icons.report_problem_outlined),
        ],
      ),
      panel: const _GlassTile(
        color: Color(0x66B91C1C),
        child: Text(
          'Authentication required\nFace ID or passcode needed to securely submit your response.',
          style: TextStyle(color: Color(0xFFFCA5A5), height: 1.5),
        ),
      ),
      bottom: _ActionButton(
        text: 'Submit with Face ID',
        color: const Color(0xFFEF4444),
        onTap: () async {
          final authenticated = await DeviceAuthService.authenticateIfAvailable();
          if (!authenticated || !mounted) return;
          widget.alertManager.stopAndDismiss();
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CONFIRMATION SCREEN
  // ════════════════════════════════════════════════════════════════════════════
  Widget _confirmationScreen() {
    return _Layout(
      key: const ValueKey('confirmation'),
      title: 'Response\nSubmitted',
      subtitle: 'Authenticated via Face ID or passcode',
      center: const CircleAvatar(
        radius: 44,
        backgroundColor: Color(0xFF22C55E),
        child: Icon(Icons.check, color: Colors.white, size: 40),
      ),
      panel: _GlassTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Alert ID', '#${widget.alert.id}'),
            _kv('Type', widget.alert.displayTitle),
            _kv('Response', 'I can attend'),
            _kv('Auth', 'Validated ✓'),
            _kv('Time', TimeOfDay.now().format(context)),
          ],
        ),
      ),
      bottom: _ActionButton(
        text: 'View Alert History',
        color: const Color(0xFF1E5EFF),
        onTap: () => widget.alertManager.stopAndDismiss(),
      ),
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(key, style: const TextStyle(color: Color(0xFF94A3B8)))),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// INCOMING ALERT BADGE  (• INCOMING ALERT  |  15s countdown)
// ══════════════════════════════════════════════════════════════════════════════
class _IncomingBadge extends StatelessWidget {
  const _IncomingBadge({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x441F0A0A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x99C53E2C), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'INCOMING ALERT',
            style: TextStyle(
              color: Color(0xFFFF6A67),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x33FF3B30),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${secondsLeft}s',
              style: const TextStyle(
                color: Color(0xFFFF6A67),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PULSING AVATAR  — animated concentric rings + ES avatar
// ══════════════════════════════════════════════════════════════════════════════
class _PulsingAvatar extends StatelessWidget {
  const _PulsingAvatar({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Three rings staggered by 1/3 of the cycle
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(offset: 0.0,   baseSize: 200, maxExtra: 0),
              _ring(offset: 0.33,  baseSize: 170, maxExtra: 0),
              _ring(offset: 0.66,  baseSize: 140, maxExtra: 0),
              // ES avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'ES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring({required double offset, required double baseSize, required int maxExtra}) {
    final t = (animation.value + offset) % 1.0;
    final scale = 0.85 + t * 0.25;
    final opacity = (1.0 - t) * 0.45;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF22C55E).withOpacity(opacity),
            width: 2,
          ),
          // Subtle filled glow
          color: const Color(0xFF22C55E).withOpacity(opacity * 0.08),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CRITICAL PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _CriticalPanel extends StatelessWidget {
  const _CriticalPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x8848180E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66C53E2C), width: 1.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Priority Level',
                    style: TextStyle(color: Color(0xFFFDA4AF))),
              ),
              Text('CRITICAL',
                  style: TextStyle(
                      color: Color(0xFFFF3B30), fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Immediate response required.\nAuthentication will be required after you accept.',
            style: TextStyle(color: Color(0xFFFECACA), height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CALL BUTTON  (large circle with icon + label below)
// ══════════════════════════════════════════════════════════════════════════════
class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED LAYOUT WRAPPER  (used for all steps except incoming)
// ══════════════════════════════════════════════════════════════════════════════
class _Layout extends StatelessWidget {
  const _Layout({
    super.key,
    required this.title,
    required this.subtitle,
    this.topBadge,
    required this.center,
    required this.panel,
    required this.bottom,
  });

  final String title;
  final String subtitle;
  final String? topBadge;
  final Widget center;
  final Widget panel;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          if (topBadge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x551F120E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x88C53E2C), width: 1.5),
              ),
              child: Text('• $topBadge',
                  style: const TextStyle(
                    color: Color(0xFFFF6A67),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 18,
                  )),
            ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 46,
                  height: 1.0)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF849090), fontSize: 17)),
          const SizedBox(height: 20),
          center,
          const SizedBox(height: 16),
          panel,
          const Spacer(),
          bottom,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _ResponsePanel extends StatelessWidget {
  const _ResponsePanel({required this.onAttend, required this.onDecline});
  final VoidCallback onAttend;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _GlassTile(
      child: Column(
        children: [
          _ChoiceTile(label: 'I can attend', color: const Color(0xFF22C55E), onTap: onAttend),
          const SizedBox(height: 10),
          _ChoiceTile(label: 'I cannot attend', color: const Color(0xFFEF4444), onTap: onDecline),
          const SizedBox(height: 10),
          _ChoiceTile(label: 'Need assistance', color: const Color(0xFF1E5EFF), onTap: onDecline),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xAA141A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334D5A84)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0x331E5EFF),
            child: Icon(icon, color: const Color(0xFF93C5FD), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({required this.child, this.color = const Color(0xAA141A2E)});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x663F5A44)),
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.text, required this.color, required this.onTap});
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }
}

class _WavePlaceholder extends StatelessWidget {
  const _WavePlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(16, (i) => Container(
          width: 4,
          height: i.isEven ? 18 + (i * 2) : 10 + (i * 3),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i % 3 == 0 ? const Color(0xFFEF4444) : const Color(0xFFF87171),
            borderRadius: BorderRadius.circular(4),
          ),
        )),
      ),
    );
  }
}