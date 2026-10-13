import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vault_repository.dart';
import '../models/vault_entry.dart';

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(),
);

class VaultNotifier extends Notifier<List<VaultEntry>> {
  @override
  List<VaultEntry> build() => ref.read(vaultRepositoryProvider).getEntries();

  Future<void> save({
    String? id,
    required String title,
    String username = '',
    String? plainPassword,
    String website = '',
    String notes = '',
  }) async {
    await ref
        .read(vaultRepositoryProvider)
        .saveEntry(
          id: id,
          title: title,
          username: username,
          plainPassword: plainPassword,
          website: website,
          notes: notes,
        );
    state = ref.read(vaultRepositoryProvider).getEntries();
  }

  Future<void> remove(String id) async {
    await ref.read(vaultRepositoryProvider).deleteEntry(id);
    state = ref.read(vaultRepositoryProvider).getEntries();
  }

  Future<String?> reveal(VaultEntry entry) =>
      ref.read(vaultRepositoryProvider).revealPassword(entry);
}

final vaultProvider = NotifierProvider<VaultNotifier, List<VaultEntry>>(
  VaultNotifier.new,
);
