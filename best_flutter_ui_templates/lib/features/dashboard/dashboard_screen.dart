import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/drawer_screen.dart';
import '../../app/lifehub_theme.dart';
import '../../core/providers/privacy_providers.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_title.dart';
import '../finance/models/finance_models.dart';
import '../finance/providers/finance_providers.dart';
import '../finance/screens/finance_screen.dart';
import '../finance/screens/report_screen.dart';
import '../habits/providers/habits_providers.dart';
import '../habits/screens/habit_form_sheet.dart';
import '../habits/screens/habits_screen.dart';
import '../notes_tasks/providers/notes_tasks_providers.dart';
import '../notes_tasks/screens/note_editor_screen.dart';
import '../notes_tasks/screens/notes_screen.dart';
import '../notes_tasks/screens/tasks_screen.dart';
import '../profile/providers/profile_provider.dart';
import '../profile/screens/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../vault/screens/vault_screen.dart';
import '../vault/widgets/vault_gate.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scrollController = ScrollController();
  double _topBarOpacity = 0;

  @override
  void initState() {
    super.initState();
    // Original template behavior: the white curved app bar fades in
    // only after the user scrolls down.
    _scrollController.addListener(() {
      final o = (_scrollController.offset / 24).clamp(0.0, 1.0);
      if (o != _topBarOpacity) setState(() => _topBarOpacity = o);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.watch(hideAmountsProvider);
    final profile = ref.watch(profileProvider);
    final totals = ref.watch(monthlyTotalsProvider);
    final tasks = ref.watch(todaysTasksProvider);
    final habits = ref.watch(habitsProvider);
    final notes = ref.watch(notesProvider);
    ref.watch(transactionsProvider);
    final budgets = ref.watch(budgetsProvider);
    final financeRepository = ref.read(financeRepositoryProvider);
    final recentExpenses = financeRepository.recentTransactions(
      type: TransactionType.expense,
      limit: 5,
    );
    final totalBudget = budgets.fold(0.0, (s, b) => s + b.monthlyLimit);
    final now = DateTime.now();
    final spentByCategory = financeRepository.spentByCategoryForMonth(
      now.year,
      now.month,
    );
    final name = profile.name.isEmpty ? 'there' : profile.name.split(' ').first;

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable content first — the header is painted on top.
            ListView(
              controller: _scrollController,
              // Extra top space so the floating header never covers content,
              // and extra bottom space for the floating + button.
              padding: const EdgeInsets.only(top: 96, bottom: 160),
              children: [
                // Budget status card — circular ring style like the
                // original template's diet card (Eaten/Burned + ring).
                FadeSlideIn.item(
                  index: 1,
                  child: _DashboardSection(
                    title: 'Budget Status',
                    actionText: 'Report',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportScreen()),
                    ),
                    child: _BudgetRingCard(
                      income: totals.income,
                      expense: totals.expense,
                      totalBudget: totalBudget,
                      budgets: budgets,
                      spentByCategory: spentByCategory,
                    ),
                  ),
                ),

                // Today's tasks
                FadeSlideIn.item(
                  index: 2,
                  child: _DashboardSection(
                    title: "Today's Tasks",
                    actionText: 'All tasks',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksScreen()),
                    ),
                    child: tasks.isEmpty
                        ? const EmptyState(
                            message: 'No tasks due today. Enjoy your day!',
                          )
                        : Material(
                            color: Colors.transparent,
                            child: Column(
                              children: tasks
                                  .take(4)
                                  .map(
                                    (t) => CheckboxListTile(
                                      dense: true,
                                      title: Text(t.title),
                                      subtitle: t.priority != 'Medium'
                                          ? Text('Priority: ${t.priority}')
                                          : null,
                                      value: t.isDone,
                                      onChanged: (_) => ref
                                          .read(tasksProvider.notifier)
                                          .toggle(t),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ),

                // Today's habits
                FadeSlideIn.item(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        title: "Today's Habits",
                        actionText: 'All habits',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HabitsScreen(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: habits.isEmpty
                            ? Container(
                                decoration: LifeHubTheme.cardDecoration,
                                child: const EmptyState(
                                  message:
                                      'No habits yet. Add your first habit!',
                                ),
                              )
                            : SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: habits.length,
                                  itemBuilder: (context, i) {
                                    final h = habits[i];
                                    final done = h.isDoneToday;
                                    return GestureDetector(
                                      onTap: () => ref
                                          .read(habitsProvider.notifier)
                                          .toggleToday(h),
                                      child: Container(
                                        width: 100,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: done
                                              ? Color(h.colorValue)
                                              : LifeHubTheme.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: LifeHubTheme
                                              .cardDecoration
                                              .boxShadow,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              done
                                                  ? Icons.check_circle
                                                  : habitIcon(h.icon),
                                              color: done
                                                  ? Colors.white
                                                  : Color(h.colorValue),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              h.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: done
                                                    ? Colors.white
                                                    : LifeHubTheme.darkText,
                                              ),
                                            ),
                                            Text(
                                              '🔥 ${h.streak}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: done
                                                    ? Colors.white70
                                                    : LifeHubTheme.lightText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Recent expenses
                FadeSlideIn.item(
                  index: 4,
                  child: _DashboardSection(
                    title: 'Recent Expenses',
                    actionText: 'Finance',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FinanceScreen()),
                    ),
                    child: recentExpenses.isEmpty
                        ? const EmptyState(message: 'No expenses logged yet.')
                        : Column(
                            children: recentExpenses
                                .map(
                                  (t) => ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.arrow_upward,
                                      color: LifeHubTheme.tasks,
                                    ),
                                    title: Text(t.category),
                                    subtitle: Text(Formatters.date(t.date)),
                                    trailing: Text(
                                      '-${Formatters.money(t.amount)}',
                                      style: const TextStyle(
                                        color: LifeHubTheme.tasks,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),

                // Quick notes
                FadeSlideIn.item(
                  index: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        title: 'Quick Notes',
                        actionText: 'All notes',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotesScreen(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          height: 110,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NoteEditorScreen(),
                                  ),
                                ),
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: LifeHubTheme.nearlyDarkBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: LifeHubTheme.nearlyDarkBlue
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: LifeHubTheme.nearlyDarkBlue,
                                  ),
                                ),
                              ),
                              ...notes
                                  .take(6)
                                  .map(
                                    (n) => GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              NoteEditorScreen(note: n),
                                        ),
                                      ),
                                      child: Container(
                                        width: 160,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        decoration: LifeHubTheme.cardDecoration,
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.title.isEmpty
                                                  ? 'Note'
                                                  : n.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: LifeHubTheme.subtitle
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Expanded(
                                              child: Text(
                                                n.content,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: LifeHubTheme.caption,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Fixed overlay app bar: transparent at rest; only its
            // background, left curve, border, and shadow animate on scroll.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: LifeHubTheme.white.withValues(alpha: _topBarOpacity),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28 * _topBarOpacity),
                  ),
                  border: _topBarOpacity > 0.5
                      ? Border(
                          bottom: BorderSide(
                            color: LifeHubTheme.grey.withValues(alpha: 0.18),
                          ),
                        )
                      : null,
                  boxShadow: _topBarOpacity <= 0.1
                      ? const []
                      : [
                          BoxShadow(
                            color: LifeHubTheme.grey.withValues(
                              alpha: 0.32 * _topBarOpacity,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menu',
                      onPressed: () => DrawerScreen.of(context)?.toggle(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, $name', style: LifeHubTheme.headline),
                          Text(
                            Formatters.date(DateTime.now()),
                            style: LifeHubTheme.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.lock_outline),
                      tooltip: 'Vault',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VaultGate(child: VaultScreen()),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: LifeHubTheme.nearlyDarkBlue.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: _avatarImage(profile.photoPath),
                        child: profile.photoPath == null
                            ? Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: LifeHubTheme.nearlyDarkBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

/// Card wrapper that pairs a [SectionTitle] with a white content card —
/// the signature look of the original template.
class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title, actionText: actionText, onAction: onAction),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            decoration: LifeHubTheme.cardDecoration,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Budget card styled after the original template's "Mediterranean diet"
/// card: stat columns on the left, big progress ring on the right, and
/// per-category mini progress bars below (like Carbs/Protein/Fat).
class _BudgetRingCard extends StatelessWidget {
  const _BudgetRingCard({
    required this.income,
    required this.expense,
    required this.totalBudget,
    required this.budgets,
    required this.spentByCategory,
  });

  final double income;
  final double expense;
  final double totalBudget;
  final List<BudgetModel> budgets;
  final Map<String, double> spentByCategory;

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final hasBudget = totalBudget > 0;
    final used = hasBudget ? (expense / totalBudget).clamp(0.0, 1.0) : 0.0;
    final remaining = (totalBudget - expense);
    final over = remaining < 0;
    final ringColor = over
        ? Colors.red
        : (used > 0.8 ? LifeHubTheme.tasks : LifeHubTheme.nearlyDarkBlue);

    final cats =
        budgets
            .map((b) => (budget: b, spent: spentByCategory[b.category] ?? 0.0))
            .toList()
          ..sort((a, b) => b.spent.compareTo(a.spent));
    final topCats = cats.take(3).toList();
    final barColors = [
      LifeHubTheme.nearlyBlue,
      const Color(0xFFF56A98),
      const Color(0xFFF1B440),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      label: 'Income',
                      amount: income,
                      color: LifeHubTheme.finance,
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(height: 14),
                    _StatRow(
                      label: 'Expenses',
                      amount: expense,
                      color: LifeHubTheme.tasks,
                      icon: Icons.arrow_upward,
                    ),
                    const SizedBox(height: 14),
                    _StatRow(
                      label: 'Balance',
                      amount: balance,
                      color: LifeHubTheme.nearlyBlue,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 118,
                      height: 118,
                      // Animate the ring from 0 like the original template.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: hasBudget ? used : 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.fastOutSlowIn,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          backgroundColor: LifeHubTheme.spacer,
                          valueColor: AlwaysStoppedAnimation(ringColor),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: FittedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasBudget
                                  ? Formatters.money(remaining.abs())
                                  : Formatters.money(balance.abs()),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ringColor,
                              ),
                            ),
                            Text(
                              hasBudget
                                  ? (over ? 'over budget' : 'budget left')
                                  : 'balance',
                              style: LifeHubTheme.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (topCats.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: LifeHubTheme.spacer),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < topCats.length; i++) ...[
                  Expanded(
                    child: _CategoryBar(
                      name: topCats[i].budget.category,
                      spent: topCats[i].spent,
                      limit: topCats[i].budget.monthlyLimit,
                      color: barColors[i % barColors.length],
                    ),
                  ),
                  if (i < topCats.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Left-bordered stat row like the template's "Eaten/Burned" entries.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: LifeHubTheme.caption),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.money(amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: LifeHubTheme.darkText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small labeled progress bar, like the template's Carbs/Protein/Fat row.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.spent,
    required this.limit,
    required this.color,
  });

  final String name;
  final double spent;
  final double limit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final used = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final left = limit - spent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: LifeHubTheme.subtitle.copyWith(fontSize: 13)),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Animated fill like the template's macro bars.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: used),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.fastOutSlowIn,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: LifeHubTheme.spacer,
                valueColor: AlwaysStoppedAnimation(
                  left < 0 ? Colors.red : color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          left >= 0
              ? '${Formatters.money(left)} left'
              : '${Formatters.money(left.abs())} over',
          style: LifeHubTheme.caption.copyWith(
            fontSize: 10,
            color: left < 0 ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
