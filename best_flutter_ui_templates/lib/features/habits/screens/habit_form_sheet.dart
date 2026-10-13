import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/habits_providers.dart';

void showHabitFormSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const HabitFormSheet(),
  );
}

const _habitColors = [
  0xFF7B61FF,
  0xFF00B686,
  0xFFFA7D34,
  0xFF00B6F0,
  0xFFE91E63,
  0xFFF0A500,
];

IconData habitIcon(String name) {
  switch (name) {
    case 'exercise':
      return Icons.fitness_center;
    case 'reading':
      return Icons.menu_book;
    case 'studying':
      return Icons.school;
    case 'water':
      return Icons.water_drop;
    case 'sleep':
      return Icons.bedtime;
    case 'meditation':
      return Icons.self_improvement;
    default:
      return Icons.star_outline;
  }
}

class HabitFormSheet extends ConsumerStatefulWidget {
  const HabitFormSheet({super.key});

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _icon = 'exercise';
  int _color = _habitColors.first;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    await ref
        .read(habitsProvider.notifier)
        .add(
          name: _nameController.text.trim(),
          icon: _icon,
          colorValue: _color,
          description: _descController.text.trim(),
        );
    if (mounted) Navigator.pop(context);
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
          const Text('New Habit', style: LifeHubTheme.title),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Habit name (e.g. Read 20 mins)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Icon', style: LifeHubTheme.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppConstants.habitIcons
                .map(
                  (ic) => ChoiceChip(
                    avatar: Icon(habitIcon(ic), size: 18),
                    label: Text(ic),
                    selected: _icon == ic,
                    onSelected: (_) => setState(() => _icon = ic),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text('Color', style: LifeHubTheme.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _habitColors
                .map(
                  (c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LifeHubTheme.habits,
              ),
              onPressed: _save,
              child: const Text('Create Habit'),
            ),
          ),
        ],
      ),
    );
  }
}
