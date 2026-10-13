class VaultEntry {
  VaultEntry({
    required this.id,
    required this.title,
    this.username = '',
    this.encryptedPassword = '',
    this.website = '',
    this.notes = '',
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String username;

  /// AES-encrypted 'iv:ciphertext' — never store plain text.
  final String encryptedPassword;
  final String website;
  final String notes;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'username': username,
    'encryptedPassword': encryptedPassword,
    'website': website,
    'notes': notes,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory VaultEntry.fromMap(Map map) => VaultEntry(
    id: map['id'] as String,
    title: map['title'] as String,
    username: (map['username'] as String?) ?? '',
    encryptedPassword: (map['encryptedPassword'] as String?) ?? '',
    website: (map['website'] as String?) ?? '',
    notes: (map['notes'] as String?) ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}
