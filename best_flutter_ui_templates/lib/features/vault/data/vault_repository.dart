import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/security_service.dart';
import '../models/vault_entry.dart';

class VaultRepository {
  List<VaultEntry> getEntries() =>
      LocalDb.box(
        AppConstants.vaultBox,
      ).values.map((m) => VaultEntry.fromMap(m as Map)).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

  /// Saves an entry, encrypting [plainPassword] first.
  Future<VaultEntry> saveEntry({
    String? id,
    required String title,
    String username = '',
    String? plainPassword,
    String website = '',
    String notes = '',
  }) async {
    String encrypted;
    if (plainPassword != null) {
      encrypted = await SecurityService.encryptText(plainPassword);
    } else if (id != null) {
      final existing = LocalDb.box(AppConstants.vaultBox).get(id) as Map?;
      encrypted = (existing?['encryptedPassword'] as String?) ?? '';
    } else {
      encrypted = '';
    }
    final entry = VaultEntry(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      username: username,
      encryptedPassword: encrypted,
      website: website,
      notes: notes,
      updatedAt: DateTime.now(),
    );
    await LocalDb.box(AppConstants.vaultBox).put(entry.id, entry.toMap());
    return entry;
  }

  Future<String?> revealPassword(VaultEntry entry) =>
      SecurityService.decryptText(entry.encryptedPassword);

  Future<void> deleteEntry(String id) =>
      LocalDb.box(AppConstants.vaultBox).delete(id);
}
