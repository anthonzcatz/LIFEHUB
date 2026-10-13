import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';

class ProfileState {
  const ProfileState({
    this.name = '',
    this.email = '',
    this.bio = '',
    this.photoPath,
  });

  final String name;
  final String email;
  final String bio;

  /// Local file path or network URL.
  final String? photoPath;
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final s = LocalDb.settings;
    return ProfileState(
      name: s.get(AppConstants.keyUserName, defaultValue: '') as String,
      email: s.get(AppConstants.keyUserEmail, defaultValue: '') as String,
      bio: s.get(AppConstants.keyUserBio, defaultValue: '') as String,
      photoPath: s.get(AppConstants.keyUserPhoto) as String?,
    );
  }

  void update({String? name, String? email, String? bio, String? photoPath}) {
    final s = LocalDb.settings;
    if (name != null) s.put(AppConstants.keyUserName, name);
    if (email != null) s.put(AppConstants.keyUserEmail, email);
    if (bio != null) s.put(AppConstants.keyUserBio, bio);
    if (photoPath != null) s.put(AppConstants.keyUserPhoto, photoPath);
    state = ProfileState(
      name: name ?? state.name,
      email: email ?? state.email,
      bio: bio ?? state.bio,
      photoPath: photoPath ?? state.photoPath,
    );
  }

  void removePhoto() {
    LocalDb.settings.delete(AppConstants.keyUserPhoto);
    state = ProfileState(name: state.name, email: state.email, bio: state.bio);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
