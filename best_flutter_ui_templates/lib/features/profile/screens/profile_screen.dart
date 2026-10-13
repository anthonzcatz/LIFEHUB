import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/lifehub_theme.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _nameController = TextEditingController(text: p.name);
    _emailController = TextEditingController(text: p.email);
    _bioController = TextEditingController(text: p.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showPhotoOptions() {
    final hasPhoto = ref.read(profileProvider).photoPath != null;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Profile Photo', style: LifeHubTheme.title),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(profileProvider.notifier).removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        // Copy into app documents so the photo survives cache clears.
        final dir = await getApplicationDocumentsDirectory();
        final saved = await File(picked.path).copy(
          '${dir.path}/profile_photo${picked.name.contains('.') ? '.${picked.name.split('.').last}' : '.jpg'}',
        );
        ref.read(profileProvider.notifier).update(photoPath: saved.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get image: $e')));
      }
    }
  }

  void _save() {
    ref
        .read(profileProvider.notifier)
        .update(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          bio: _bioController.text.trim(),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final path = profile.photoPath;

    ImageProvider? image;
    if (path != null) {
      if (path.startsWith('http')) {
        image = NetworkImage(path);
      } else if (File(path).existsSync()) {
        image = FileImage(File(path));
      }
    }

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: LifeHubTheme.nearlyDarkBlue.withValues(
                      alpha: 0.15,
                    ),
                    backgroundImage: image,
                    child: image == null
                        ? const Icon(
                            Icons.person,
                            size: 56,
                            color: LifeHubTheme.nearlyDarkBlue,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: LifeHubTheme.nearlyDarkBlue,
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Tap photo to change', style: LifeHubTheme.caption),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Bio (optional)',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }
}
