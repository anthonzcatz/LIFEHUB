/// Abstraction for cloud sync. The app is local-first; a cloud
/// implementation can be plugged in later (premium feature).
abstract class SyncService {
  bool get isAvailable;
  Future<void> syncAll();
  Future<void> pushCollection(String name, Map<String, dynamic> data);
}

/// Default no-op implementation used until a cloud provider is configured.
class LocalSyncService implements SyncService {
  @override
  bool get isAvailable => false;

  @override
  Future<void> syncAll() async {}

  @override
  Future<void> pushCollection(String name, Map<String, dynamic> data) async {}
}
