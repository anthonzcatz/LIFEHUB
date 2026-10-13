import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/providers/privacy_providers.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/finance_providers.dart';

/// Budget planner — set a monthly limit per expense category and
/// see live usage based on this month's transactions.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hideAmountsProvider);
    final budgets = ref.watch(budgetsProvider);
    ref.watch(transactionsProvider);
    final now = DateTime.now();
    final spentByCategory = ref
        .read(financeRepositoryProvider)
        .spentByCategoryForMonth(now.year, now.month);

    double spent(String category) => spentByCategory[category] ?? 0;

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Budget Planner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.nearlyDarkBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Budget', style: TextStyle(color: Colors.white)),
        onPressed: () => _showBudgetForm(context, ref),
      ),
      body: budgets.isEmpty
          ? const EmptyState(
              message: 'No budgets yet.\nSet a monthly limit per category.',
              icon: Icons.account_balance_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ).copyWith(bottom: 90),
              itemCount: budgets.length,
              itemBuilder: (context, i) {
                final b = budgets[i];
                final used = spent(b.category);
                final pct = (used / b.monthlyLimit).clamp(0.0, 1.0);
                final over = used > b.monthlyLimit;
                return Card(
                  color: LifeHubTheme.white,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.category,
                                style: LifeHubTheme.title,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref
                                  .read(budgetsProvider.notifier)
                                  .remove(b.id),
                            ),
                          ],
                        ),
                        Text(
                          '${Formatters.money(used)} of ${Formatters.money(b.monthlyLimit)}',
                          style: LifeHubTheme.caption,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: LifeHubTheme.spacer,
                            valueColor: AlwaysStoppedAnimation(
                              over ? Colors.red : LifeHubTheme.finance,
                            ),
                          ),
                        ),
                        if (over)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Over budget!',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showBudgetForm(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String category = CategoryService.expenseCategories().first;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('New Budget', style: LifeHubTheme.title),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: CategoryService.expenseCategories()
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monthly limit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    final limit = double.tryParse(controller.text.trim());
                    if (limit == null || !limit.isFinite || limit <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid budget limit.'),
                        ),
                      );
                      return;
                    }
                    if (ref
                        .read(budgetsProvider)
                        .any(
                          (budget) =>
                              budget.category.toLowerCase() ==
                              category.toLowerCase(),
                        )) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A budget already exists for this category.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(budgetsProvider.notifier)
                          .save(category: category, limit: limit);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save the budget.'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}
