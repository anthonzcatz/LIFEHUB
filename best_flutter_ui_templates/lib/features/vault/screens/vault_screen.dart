import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/vault_entry.dart';
import '../providers/vault_providers.dart';
import '../widgets/password_generator.dart';
import 'vault_entry_sheet.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vaultProvider);
    final filtered = entries
        .where(
          (e) =>
              e.title.toLowerCase().contains(_search.toLowerCase()) ||
              e.username.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Password Vault'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.password),
            tooltip: 'Password generator',
            onPressed: () => showPasswordGeneratorSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.vault,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
        onPressed: () => showVaultEntrySheet(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search passwords...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: LifeHubTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    message: entries.isEmpty
                        ? 'Vault is empty.\nStore your passwords securely here.'
                        : 'No matching entries.',
                    icon: Icons.lock_outline,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => FadeSlideIn.item(
                      index: i,
                      child: _EntryTile(entry: filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerStatefulWidget {
  const _EntryTile({required this.entry});

  final VaultEntry entry;

  @override
  ConsumerState<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends ConsumerState<_EntryTile> {
  String? _revealed;

  Future<void> _toggleReveal() async {
    if (_revealed != null) {
      setState(() => _revealed = null);
      return;
    }
    final plain = await ref.read(vaultProvider.notifier).reveal(widget.entry);
    if (!mounted) return;
    if (plain == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot decrypt — this entry was backed up on another device.',
          ),
        ),
      );
      return;
    }
    setState(() => _revealed = plain);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Card(
      color: LifeHubTheme.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: LifeHubTheme.vault.withValues(alpha: 0.12),
          child: Text(
            e.title.isEmpty ? '?' : e.title[0].toUpperCase(),
            style: const TextStyle(color: LifeHubTheme.vault),
          ),
        ),
        title: Text(e.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.username.isNotEmpty) Text(e.username),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _revealed ?? '••••••••',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                InkWell(
                  onTap: _toggleReveal,
                  child: Icon(
                    _revealed == null
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: LifeHubTheme.lightText,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final plain =
                        _revealed ??
                        await ref.read(vaultProvider.notifier).reveal(e);
                    if (plain == null) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot decrypt — entry from another device.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: plain));
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Password copied')),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.copy,
                    size: 18,
                    color: LifeHubTheme.lightText,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              showVaultEntrySheet(context, entry: e);
            } else if (v == 'delete') {
              ref.read(vaultProvider.notifier).remove(e.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
