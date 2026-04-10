import 'package:flutter/material.dart';

import '../managers/alert_manager.dart';
import '../models/incoming_alert.dart';

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

class _AlertOverlayState extends State<AlertOverlay> {
  _OverlayStep _step = _OverlayStep.incoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF0070B1C), Color(0xF00C1124)],
        ),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            _OverlayStep.incoming => _incoming(),
            _OverlayStep.audioActions => _audioActions(),
            _OverlayStep.textAlert => _textAlert(),
            _OverlayStep.declineReasons => _declineReasons(),
            _OverlayStep.confirmation => _confirmation(),
          },
        ),
      ),
    );
  }

  Widget _incoming() {
    return _Layout(
      key: const ValueKey('incoming'),
      title: 'Emergency\nSystem',
      subtitle: 'Secure Emergency Response',
      topBadge: 'INCOMING ALERT',
      center: const CircleAvatar(
        radius: 44,
        backgroundColor: Color(0xFFE11D48),
        child: Text('ES', style: TextStyle(color: Colors.white, fontSize: 34)),
      ),
      panel: const _CriticalPanel(),
      bottom: Row(
        children: [
          Expanded(
            child: _CircleAction(
              icon: Icons.close,
              color: const Color(0xFFEF4444),
              label: 'NO',
              onTap: () => setState(() => _step = _OverlayStep.declineReasons),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _CircleAction(
              icon: Icons.check,
              color: const Color(0xFF22C55E),
              label: 'YES',
              onTap: () => setState(() {
                _step = widget.alert.type is TextAlert
                    ? _OverlayStep.textAlert
                    : _OverlayStep.audioActions;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioActions() {
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
        onAttend: () => setState(() => _step = _OverlayStep.confirmation),
        onDecline: () => setState(() => _step = _OverlayStep.declineReasons),
      ),
      bottom: _ActionButton(
        text: 'Confirm with Face ID',
        color: const Color(0xFF22C55E),
        onTap: () => setState(() => _step = _OverlayStep.confirmation),
      ),
    );
  }

  Widget _textAlert() {
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
        onAttend: () => setState(() => _step = _OverlayStep.confirmation),
        onDecline: () => setState(() => _step = _OverlayStep.declineReasons),
      ),
      bottom: _ActionButton(
        text: 'Respond with Face ID',
        color: const Color(0xFF1E5EFF),
        onTap: () => setState(() => _step = _OverlayStep.confirmation),
      ),
    );
  }

  Widget _declineReasons() {
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
        onTap: () => widget.alertManager.dismissActiveAlert(),
      ),
    );
  }

  Widget _confirmation() {
    return _Layout(
      key: const ValueKey('confirmation'),
      title: 'Response\nSubmitted',
      subtitle: 'Authenticated via Face ID',
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
            const _kv('Response', 'I can attend'),
            const _kv('Auth', 'Face ID ✓'),
            _kv('Time', TimeOfDay.now().format(context)),
          ],
        ),
      ),
      bottom: _ActionButton(
        text: 'View Alert History',
        color: const Color(0xFF1E5EFF),
        onTap: () {
          widget.alertManager.stopAudio();
          widget.alertManager.dismissActiveAlert();
        },
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(key, style: const TextStyle(color: Color(0xFF94A3B8)))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33EF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x66EF4444)),
              ),
              child: Text(topBadge!, style: const TextStyle(color: Color(0xFFFDA4AF), fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 40, height: 1.1)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8))),
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

class _CriticalPanel extends StatelessWidget {
  const _CriticalPanel();

  @override
  Widget build(BuildContext context) {
    return const _GlassTile(
      color: Color(0x66B91C1C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Priority Level', style: TextStyle(color: Color(0xFFFDA4AF))),
              ),
              Text('CRITICAL', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Immediate response required. Authentication will be required after you accept.',
            style: TextStyle(color: Color(0xFFFECACA), height: 1.4),
          ),
        ],
      ),
    );
  }
}

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
          CircleAvatar(radius: 15, backgroundColor: const Color(0x331E5EFF), child: Icon(icon, color: const Color(0xFF93C5FD), size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x334D5A84)),
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
        children: List.generate(
          16,
          (i) => Container(
            width: 4,
            height: i.isEven ? 18 + (i * 2) : 10 + (i * 3),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i % 3 == 0 ? const Color(0xFFEF4444) : const Color(0xFFF87171),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
