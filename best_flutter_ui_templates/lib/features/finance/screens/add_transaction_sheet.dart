import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/services/category_service.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

/// Bottom sheet form for adding an expense or income.
void showAddTransactionSheet(
  BuildContext context, {
  String initialType = 'expense',
  TransactionModel? transaction,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        AddTransactionSheet(initialType: initialType, transaction: transaction),
  );
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialType = 'expense',
    this.transaction,
  });

  final String initialType;
  final TransactionModel? transaction;

  bool get isEditing => transaction != null;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type =
        transaction?.type ??
        (widget.initialType == 'income'
            ? TransactionType.income
            : TransactionType.expense);
    _amountController = TextEditingController(
      text: transaction?.amount.toString() ?? '',
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _date = transaction?.date ?? DateTime.now();
    _category = transaction?.category ?? _categories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final categories = _type == TransactionType.expense
        ? CategoryService.expenseCategories()
        : CategoryService.incomeCategories();
    final existing = widget.transaction?.category;
    if (existing != null && !categories.contains(existing)) {
      categories.add(existing);
    }
    return categories;
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New ${_type == TransactionType.expense ? 'Expense' : 'Income'} Category',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Pets, Gym, Side hustle',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await CategoryService.add(
      name,
      isExpense: _type == TransactionType.expense,
    );
    setState(() => _category = name);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final transaction = widget.transaction;
      final notifier = ref.read(transactionsProvider.notifier);
      if (transaction == null) {
        await notifier.add(
          type: _type,
          amount: amount,
          category: _category,
          note: _noteController.text.trim(),
          date: _date,
        );
      } else {
        await notifier.update(
          TransactionModel(
            id: transaction.id,
            type: _type,
            amount: amount,
            category: _category,
            note: _noteController.text.trim(),
            date: _date,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the transaction.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? 'Edit Transaction' : 'New Transaction',
            style: LifeHubTheme.title,
          ),
          const SizedBox(height: 16),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _category = _categories.first;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.payments_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Category', style: LifeHubTheme.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  avatar: Icon(
                    CategoryService.iconFor(c),
                    size: 16,
                    color: _category == c
                        ? Colors.white
                        : LifeHubTheme.nearlyDarkBlue,
                  ),
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                onPressed: _addCategory,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('Date: ${_date.month}/${_date.day}/${_date.year}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _type == TransactionType.expense
                    ? LifeHubTheme.tasks
                    : LifeHubTheme.finance,
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing
                          ? 'Save Transaction'
                          : 'Add ${_type == TransactionType.expense ? 'Expense' : 'Income'}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
