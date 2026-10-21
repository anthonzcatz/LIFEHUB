import 'dart:io';

import 'package:flutter/material.dart';

import '../features/auth/services/auth_service.dart';
import '../features/finance/screens/finance_screen.dart';
import '../features/habits/screens/habits_screen.dart';
import '../features/notes_tasks/screens/tasks_screen.dart';
import '../features/profile/providers/profile_provider.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vault/screens/vault_screen.dart';
import '../features/vault/widgets/vault_gate.dart';
import 'lifehub_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/platform_actions.dart';

/// Animated sidebar drawer, adapted from the original template's
/// navigation drawer: the main screen slides + scales to the right
/// while the drawer slides in with staggered menu items.
class DrawerScreen extends ConsumerStatefulWidget {
  const DrawerScreen({super.key, required this.child});

  final Widget child;

  static DrawerScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<DrawerScreenState>();

  @override
  ConsumerState<DrawerScreen> createState() => DrawerScreenState();
}

class DrawerScreenState extends ConsumerState<DrawerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get isOpen => _controller.value > 0.5;

  void open() => _controller.forward();
  void close() => _controller.reverse();
  void toggle() => isOpen ? close() : open();

  void _go(Widget screen) {
    close();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final width = MediaQuery.of(context).size.width;
    // Responsive drawer width matching the original template: the drawer
    // occupies most of the screen while leaving the page visible behind it.
    final drawerWidth = (width * 0.78).clamp(280.0, 340.0);
    // On wide screens the scaled-down page should sit right beside the
    // drawer instead of sliding 72% of the (huge) screen width, which
    // left a big empty gap between drawer and page.
    final target = width >= 700 ? drawerWidth + 16 : width * 0.72;

    return Scaffold(
      backgroundColor: const Color(0xFF111A52),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = Curves.fastOutSlowIn.transform(_controller.value);
          return Stack(
            children: [
              // Drawer panel (slides in from the left).
              Transform.translate(
                offset: Offset(-drawerWidth * (1 - v), 0),
                child: SizedBox(
                  width: drawerWidth,
                  child: _DrawerPanel(
                    animValue: v,
                    profile: profile,
                    onHome: () => close(),
                    onGo: _go,
                    onClose: close,
                  ),
                ),
              ),
              // Main content slides + scales, like the original template.
              Transform.translate(
                offset: Offset(target * v, 0),
                child: Transform.scale(
                  scale: 1 - 0.15 * v,
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28 * v),
                    child: Stack(
                      children: [
                        widget.child,
                        // Tap target to close while open.
                        if (_controller.value > 0.3)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: close,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.25 * v),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Left-edge swipe to open.
              if (_controller.value < 0.05)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => _dragging = true,
                    onHorizontalDragUpdate: (d) {
                      if (!_dragging) return;
                      _controller.value =
                          (_controller.value + d.primaryDelta! / target).clamp(
                            0.0,
                            1.0,
                          );
                    },
                    onHorizontalDragEnd: (d) {
                      _dragging = false;
                      (d.primaryVelocity ?? 0) > 200 || isOpen
                          ? _controller.forward()
                          : _controller.reverse();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({
    required this.animValue,
    required this.profile,
    required this.onHome,
    required this.onGo,
    required this.onClose,
  });

  final double animValue;
  final ProfileState profile;
  final VoidCallback onHome;
  final void Function(Widget screen) onGo;
  final VoidCallback onClose;

  Widget _slide(Widget child, double start, double end) {
    final t = ((animValue - start) / (end - start)).clamp(0.0, 1.0);
    final curved = Curves.easeOut.transform(t);
    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(-40 * (1 - curved), 0),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isEmpty ? 'LifeHub User' : profile.name;
    final email = profile.email;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3445D5), Color(0xFF202FB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explicit back arrow, always visible in the drawer header.
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close menu',
                onPressed: onClose,
                icon: const Icon(
                  Icons.arrow_back,
                  color: LifeHubTheme.white,
                  size: 28,
                ),
              ),
            ),
            // Profile header — image scales and slides in like the original.
            _slide(
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onGo(const ProfileScreen()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: Offset(0, 24 * (1 - animValue)),
                        child: Transform.scale(
                          scale: 0.72 + (0.28 * animValue),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: LifeHubTheme.white.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: _avatarImage(profile.photoPath),
                            child: profile.photoPath == null
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: LifeHubTheme.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: LifeHubTheme.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            color: LifeHubTheme.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              0.0,
              0.4,
            ),
            const SizedBox(height: 12),
            Divider(
              color: LifeHubTheme.white.withValues(alpha: 0.15),
              height: 1,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _slide(
                    _item(Icons.home_outlined, 'Home', onHome, selected: true),
                    0.1,
                    0.45,
                  ),
                  _slide(
                    _item(
                      Icons.account_balance_wallet_outlined,
                      'Finance',
                      () => onGo(const FinanceScreen()),
                    ),
                    0.15,
                    0.5,
                  ),
                  _slide(
                    _item(
                      Icons.check_circle_outline,
                      'Tasks & Notes',
                      () => onGo(const TasksScreen()),
                    ),
                    0.2,
                    0.55,
                  ),
                  _slide(
                    _item(
                      Icons.repeat,
                      'Habits & Goals',
                      () => onGo(const HabitsScreen()),
                    ),
                    0.25,
                    0.6,
                  ),
                  _slide(
                    _item(
                      Icons.lock_outline,
                      'Vault',
                      () => onGo(const VaultGate(child: VaultScreen())),
                    ),
                    0.3,
                    0.65,
                  ),
                  _slide(
                    _item(
                      Icons.settings_outlined,
                      'Settings',
                      () => onGo(const SettingsScreen()),
                    ),
                    0.35,
                    0.7,
                  ),
                  _slide(
                    _item(Icons.share_outlined, 'Invite Friend', () {
                      onClose();
                      PlatformActions.shareText(
                        'Check out LifeHub — your all-in-one daily organizer!',
                      );
                    }),
                    0.4,
                    0.75,
                  ),
                ],
              ),
            ),
            Divider(
              color: LifeHubTheme.white.withValues(alpha: 0.15),
              height: 1,
            ),
            _slide(
              ListTile(
                leading: const Icon(
                  Icons.power_settings_new,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: LifeHubTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  await AuthService.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              0.5,
              0.85,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? LifeHubTheme.white.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          leading: Icon(icon, color: LifeHubTheme.white),
          title: Text(
            label,
            style: const TextStyle(
              color: LifeHubTheme.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  static ImageProvider? _avatarImage(String? path) {
    if (path == null) return null;
    if (path.startsWith('http')) return NetworkImage(path);
    final f = File(path);
    return f.existsSync() ? FileImage(f) : null;
  }
}
