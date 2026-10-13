import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/providers/privacy_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

/// Savings goals with progress rings (adapted from the template's
/// circular progress style) plus full contribution history.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hideAmountsProvider);
    final goals = ref.watch(savingsProvider);

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Savings Goals'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.finance,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white)),
        onPressed: () => _showGoalForm(context, ref),
      ),
      body: goals.isEmpty
          ? const EmptyState(
              message: 'No savings goals yet.\nStart saving for something!',
              icon: Icons.savings_outlined,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16).copyWith(bottom: 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: goals.length,
              itemBuilder: (context, i) => FadeSlideIn.item(
                index: i,
                child: _GoalCard(goal: goals[i]),
              ),
            ),
    );
  }

  void _showGoalForm(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    DateTime? deadline;
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('New Savings Goal', style: LifeHubTheme.title),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal name (e.g. New Phone)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Target amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  deadline == null
                      ? 'Set target date (optional)'
                      : 'Target: ${Formatters.date(deadline!)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setSheetState(() => deadline = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final target = double.tryParse(
                            targetController.text.trim(),
                          );
                          if (nameController.text.trim().isEmpty ||
                              target == null ||
                              !target.isFinite ||
                              target <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter a goal name and valid target.',
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => saving = true);
                          try {
                            await ref
                                .read(savingsProvider.notifier)
                                .add(
                                  name: nameController.text.trim(),
                                  target: target,
                                  deadline: deadline,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (_) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save the savings goal.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setSheetState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      targetController.dispose();
    });
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final SavingsGoalModel goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hideAmountsProvider);
    final pct = goal.progress;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showGoalDetails(context, ref),
      child: Container(
        decoration: LifeHubTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LifeHubTheme.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () =>
                      ref.read(savingsProvider.notifier).remove(goal.id),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: LifeHubTheme.deactivatedText,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.fastOutSlowIn,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 7,
                          backgroundColor: LifeHubTheme.spacer,
                          valueColor: const AlwaysStoppedAnimation(
                            LifeHubTheme.finance,
                          ),
                        ),
                      ),
                      FittedBox(
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: LifeHubTheme.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              '${Formatters.money(goal.savedAmount)} / ${Formatters.money(goal.targetAmount)}',
              style: LifeHubTheme.caption,
              textAlign: TextAlign.center,
            ),
            if (goal.daysLeft != null) ...[
              const SizedBox(height: 2),
              Text(
                goal.daysLeft! >= 0
                    ? '${goal.daysLeft} days left'
                    : 'Past target date',
                style: LifeHubTheme.caption.copyWith(
                  fontSize: 10,
                  color: goal.daysLeft! >= 0
                      ? LifeHubTheme.lightText
                      : Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _addFunds(context, ref),
                child: const Text('Add Funds'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deposit/withdraw sheet with amount, date, and note.
  void _addFunds(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime date = DateTime.now();
    bool isWithdrawal = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add to "${goal.name}"', style: LifeHubTheme.title),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Deposit'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Withdraw'),
                    icon: Icon(Icons.north_east),
                  ),
                ],
                selected: {isWithdrawal},
                onSelectionChanged: (s) =>
                    setSheetState(() => isWithdrawal = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (e.g. Allowance, Bonus)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('Date: ${_fmtDateTime(date)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(date),
                  );
                  if (t == null) return;
                  setSheetState(
                    () => date = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountController.text.trim(),
                          );
                          if (amount == null ||
                              !amount.isFinite ||
                              amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid amount.'),
                              ),
                            );
                            return;
                          }
                          if (isWithdrawal && amount > goal.savedAmount) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cannot withdraw more than saved.',
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => saving = true);
                          try {
                            await ref
                                .read(savingsProvider.notifier)
                                .addFunds(
                                  goal,
                                  amount,
                                  date: date,
                                  note: noteController.text.trim(),
                                  isWithdrawal: isWithdrawal,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Could not save: $e')),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setSheetState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isWithdrawal ? 'Withdraw' : 'Deposit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Goal detail sheet: summary + contribution history.
  void _showGoalDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(goal.name, style: LifeHubTheme.headline),
            const SizedBox(height: 4),
            Text(
              'Saved ${Formatters.money(goal.savedAmount)} of ${Formatters.money(goal.targetAmount)}'
              '${goal.daysLeft != null ? ' • ${goal.daysLeft! >= 0 ? '${goal.daysLeft} days left' : 'past target'}' : ''}',
              style: LifeHubTheme.subtitle,
            ),
            Text(
              'Created ${Formatters.date(goal.createdAt)}',
              style: LifeHubTheme.caption,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                backgroundColor: LifeHubTheme.spacer,
                valueColor: const AlwaysStoppedAnimation(LifeHubTheme.finance),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'History (${goal.deposits.length})',
              style: LifeHubTheme.title,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: goal.deposits.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No contributions yet')),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: goal.deposits.length,
                        itemBuilder: (ctx, i) {
                          final d = goal.deposits[i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              d.isWithdrawal
                                  ? Icons.north_east
                                  : Icons.south_west,
                              color: d.isWithdrawal
                                  ? Colors.red
                                  : LifeHubTheme.finance,
                            ),
                            title: Text(
                              '${d.isWithdrawal ? '-' : '+'}${Formatters.money(d.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: d.isWithdrawal
                                    ? Colors.red
                                    : LifeHubTheme.finance,
                              ),
                            ),
                            subtitle: Text(
                              '${_fmtDateTime(d.date)}${d.note.isNotEmpty ? ' • ${d.note}' : ''}',
                              style: LifeHubTheme.caption,
                            ),
                            trailing: InkWell(
                              onTap: () async {
                                await ref
                                    .read(savingsProvider.notifier)
                                    .removeDeposit(goal, d.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: LifeHubTheme.deactivatedText,
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
    );
  }

  static String _fmtDateTime(DateTime d) =>
      '${Formatters.date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
