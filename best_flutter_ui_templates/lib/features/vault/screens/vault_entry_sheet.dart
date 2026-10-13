import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../models/vault_entry.dart';
import '../providers/vault_providers.dart';
import '../widgets/password_generator.dart';

void showVaultEntrySheet(BuildContext context, {VaultEntry? entry}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => VaultEntrySheet(entry: entry),
  );
}

class VaultEntrySheet extends ConsumerStatefulWidget {
  const VaultEntrySheet({super.key, this.entry});

  final VaultEntry? entry;

  @override
  ConsumerState<VaultEntrySheet> createState() => _VaultEntrySheetState();
}

class _VaultEntrySheetState extends ConsumerState<VaultEntrySheet> {
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _website;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _username = TextEditingController(text: widget.entry?.username ?? '');
    _password = TextEditingController();
    _website = TextEditingController(text: widget.entry?.website ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    await ref
        .read(vaultProvider.notifier)
        .save(
          id: widget.entry?.id,
          title: _title.text.trim(),
          username: _username.text.trim(),
          plainPassword: _password.text.isEmpty ? null : _password.text,
          website: _website.text.trim(),
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
          Text(
            widget.entry == null ? 'New Entry' : 'Edit Entry',
            style: LifeHubTheme.title,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title (e.g. Facebook)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'Username / Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: widget.entry == null
                  ? 'Password'
                  : 'New password (leave blank to keep)',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  IconButton(
                    icon: const Icon(Icons.password),
                    tooltip: 'Generate',
                    onPressed: () => showPasswordGeneratorSheet(
                      context,
                      onUse: (p) => setState(() => _password.text = p),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _website,
            decoration: const InputDecoration(
              labelText: 'Website (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LifeHubTheme.vault,
              ),
              onPressed: _save,
              child: const Text('Save Entry'),
            ),
          ),
        ],
      ),
    );
  }
}
