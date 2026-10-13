import 'package:flutter/material.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/finance/screens/finance_screen.dart';
import '../features/habits/screens/habits_screen.dart';
import '../features/notes_tasks/screens/tasks_screen.dart';
import '../features/finance/screens/add_transaction_sheet.dart';
import '../features/habits/screens/habit_form_sheet.dart';
import '../features/notes_tasks/screens/note_editor_screen.dart';
import '../features/notes_tasks/screens/task_form_sheet.dart';
import 'lifehub_theme.dart';

/// Main shell: four-tab bottom navigation + center quick-add button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    FinanceScreen(),
    TasksScreen(),
    HabitsScreen(),
  ];

  void _quickAdd() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Quick Add', style: LifeHubTheme.title),
            ListTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: LifeHubTheme.finance,
              ),
              title: const Text('Expense'),
              onTap: () {
                Navigator.pop(ctx);
                showAddTransactionSheet(context, initialType: 'expense');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.savings_outlined,
                color: LifeHubTheme.finance,
              ),
              title: const Text('Income'),
              onTap: () {
                Navigator.pop(ctx);
                showAddTransactionSheet(context, initialType: 'income');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: LifeHubTheme.tasks,
              ),
              title: const Text('Task'),
              onTap: () {
                Navigator.pop(ctx);
                showTaskFormSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.note_alt_outlined,
                color: LifeHubTheme.notes,
              ),
              title: const Text('Note'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat, color: LifeHubTheme.habits),
              title: const Text('Habit'),
              onTap: () {
                Navigator.pop(ctx);
                showHabitFormSheet(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _tabs[_index];
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Finance'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.repeat),
                  selectedIcon: Icon(Icons.repeat),
                  label: Text('Habits'),
                ),
              ],
            ),
          Expanded(
            // Smooth template-style transition when switching tabs:
            // outgoing slides out + fades, incoming slides up + fades in.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.fastOutSlowIn,
              switchOutCurve: Curves.fastOutSlowIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_index), child: body),
            ),
          ),
        ],
      ),
      // Single floating + in the center of a flat bottom bar —
      // like the original template (only the button floats, not the bar).
      floatingActionButton: FloatingActionButton(
        onPressed: _quickAdd,
        backgroundColor: LifeHubTheme.nearlyDarkBlue,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: wide
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: wide
          ? null
          : BottomAppBar(
              color: LifeHubTheme.white,
              elevation: 12,
              // Curved cutout so the center + button floats into the bar.
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                      label: 'Home',
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                    _NavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      selectedIcon: Icons.account_balance_wallet,
                      label: 'Finance',
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    // Space for the floating + button
                    const SizedBox(width: 40),
                    _NavItem(
                      icon: Icons.check_circle_outline,
                      selectedIcon: Icons.check_circle,
                      label: 'Tasks',
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                    _NavItem(
                      icon: Icons.repeat,
                      selectedIcon: Icons.repeat,
                      label: 'Habits',
                      selected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? LifeHubTheme.nearlyDarkBlue.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected
                    ? LifeHubTheme.nearlyDarkBlue
                    : LifeHubTheme.deactivatedText,
                size: 23,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? LifeHubTheme.nearlyDarkBlue
                      : LifeHubTheme.deactivatedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
