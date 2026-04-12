import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/alert_manager.dart';
import '../managers/signalr_manager.dart';
import '../models/incoming_alert.dart';
import '../services/audio_service.dart';
import '../services/local_notification_service.dart';
import 'alert_overlay.dart';
import 'widgets/novitas_logo.dart';

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final signalR = context.read<SignalRManager>();
      final alertManager = context.read<AlertManager>();
      signalR.configure(alertManager: alertManager);
      signalR.connect();

      // When user taps the notification banner (app was backgrounded):
      // → switch to Home tab and start the audio (overlay is already shown
      //   because activeAlert is set by the SignalR handler).
      LocalNotificationService.notificationTapCount.addListener(() {
        if (!mounted) return;
        setState(() => _selectedIndex = 0);
        // Start audio now that the app is foregrounded
        if (alertManager.activeAlert != null) {
          AudioService.instance.playLoop();
        }
      });
    });
  }

  @override
  void dispose() {
    LocalNotificationService.notificationTapCount
        .removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertManager>(
      builder: (context, alertManager, _) {
        return PopScope(
          canPop: alertManager.activeAlert == null,
          child: Scaffold(
            extendBody: true,
            backgroundColor: const Color(0xFF060A19),
            body: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: const [
                    _HomeDashboardScreen(),
                    _AlertHistoryScreen(),
                    _PlaceholderScreen(title: 'Profile'),
                    _PlaceholderScreen(title: 'Settings'),
                  ],
                ),
                // Full-screen incoming call overlay
                if (alertManager.activeAlert != null)
                  Positioned.fill(
                    child: AlertOverlay(
                      alert: alertManager.activeAlert!,
                      alertManager: alertManager,
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: alertManager.activeAlert != null
                ? null // hide nav while call screen is showing
                : _BottomNav(
                    selectedIndex: _selectedIndex,
                    onChanged: (i) => setState(() => _selectedIndex = i),
                  ),
            floatingActionButton: alertManager.activeAlert != null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () {
                      final demo = IncomingAlert(
                        type: TextAlert(
                          'All personnel required at Station 3 immediately. Confirm your response.',
                        ),
                      );
                      alertManager.handle(demo);
                    },
                    backgroundColor: const Color(0xFF1E5EFF),
                    icon: const Icon(Icons.notification_add_outlined),
                    label: const Text('Demo Alert'),
                  ),
          ),
        );
      },
    );
  }
}

// ── Screens ──────────────────────────────────────────────────────────────────

class _HomeDashboardScreen extends StatelessWidget {
  const _HomeDashboardScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0x22161616),
                  child: NovitasLogo(size: 24),
                ),
                title: Text('Good morning,\nAhmad Nour',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                subtitle: Text('Novitas Alerts',
                    style: TextStyle(color: Color(0xFF98A3C7))),
                trailing: Icon(Icons.notifications_none, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 14),
            const _GlassCard(
              borderColor: Color(0xFF1F8F4B),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('SYSTEM STATUS',
                    style: TextStyle(color: Color(0xFF74D08E), fontSize: 12)),
                subtitle: Text('Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                trailing: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFF1BA04F),
                  child: Icon(Icons.circle, color: Colors.white, size: 10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: _CountCard(label: 'Total', value: '4', color: Color(0xFFEF4444))),
                SizedBox(width: 10),
                Expanded(child: _CountCard(label: 'Attended', value: '2', color: Color(0xFF22C55E))),
                SizedBox(width: 10),
                Expanded(child: _CountCard(label: 'Pending', value: '1', color: Color(0xFF1E5EFF))),
              ],
            ),
            const SizedBox(height: 18),
            const Text('RECENT', style: TextStyle(color: Color(0xFF8995BA))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  _RecentTile(status: 'Done', statusColor: Color(0xFF22C55E), title: 'Emergency System'),
                  _RecentTile(status: 'Sent', statusColor: Color(0xFFF59E0B), title: 'Emergency System'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertHistoryScreen extends StatelessWidget {
  const _AlertHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('Alert History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: _CountCard(label: 'Total', value: '4', color: Color(0xFFEF4444))),
                SizedBox(width: 10),
                Expanded(child: _CountCard(label: 'Attended', value: '2', color: Color(0xFF22C55E))),
                SizedBox(width: 10),
                Expanded(child: _CountCard(label: 'Pending', value: '1', color: Color(0xFF1E5EFF))),
              ],
            ),
            const SizedBox(height: 18),
            const Text('RECENT ALERTS', style: TextStyle(color: Color(0xFF8995BA))),
            const SizedBox(height: 10),
            Expanded(
              child: Consumer<AlertManager>(
                builder: (_, manager, __) {
                  if (manager.alerts.isEmpty) {
                    return const Center(
                      child: Text('No alerts yet',
                          style: TextStyle(color: Color(0xFF98A3C7))),
                    );
                  }
                  return ListView.builder(
                    itemCount: manager.alerts.length,
                    itemBuilder: (_, i) {
                      final alert = manager.alerts[i];
                      return _RecentTile(
                        status: i == 0 ? 'Done' : 'Sent',
                        statusColor: i == 0
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                        title: alert.displayTitle,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title,
          style: const TextStyle(color: Colors.white70, fontSize: 28)),
    );
  }
}

// ── Shared UI components ──────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.list_alt_rounded, 'Alerts'),
      (Icons.person_outline, 'Profile'),
      (Icons.settings_outlined, 'Settings'),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC101527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x334D5A84)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == selectedIndex;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1,
                      color: selected
                          ? const Color(0xFFFD5A5A)
                          : const Color(0xFF8A93B5)),
                  const SizedBox(height: 2),
                  Text(items[i].$2,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFFD5A5A)
                            : const Color(0xFF8A93B5),
                        fontSize: 11,
                      )),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard(
      {required this.child,
      this.borderColor = const Color(0x334D5A84)});
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xAA141A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Color(0xFFB6C0E0))),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile(
      {required this.status,
      required this.statusColor,
      required this.title});
  final String status;
  final Color statusColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA141A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334D5A84)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
              radius: 4, backgroundColor: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}