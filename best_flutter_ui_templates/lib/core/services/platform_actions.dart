import 'package:flutter/services.dart';

/// Android platform actions implemented in MainActivity via the
/// `lifehub/security` channel — replaces the share_plus, file_picker
/// and image_picker plugins.
class PlatformActions {
  PlatformActions._();

  static const _channel = MethodChannel('lifehub/security');

  static Future<void> shareText(String text) =>
      _channel.invokeMethod('shareText', {'text': text});

  static Future<void> shareFile(String path, {String? subject}) =>
      _channel.invokeMethod('shareFile', {'path': path, 'subject': subject});

  /// Lets the user pick any file; returns a copy path in the cache dir,
  /// or null when cancelled.
  static Future<String?> pickFile() =>
      _channel.invokeMethod<String>('pickFile');

  /// Gallery image pick; returns a copy path in the cache dir.
  static Future<String?> pickImage() =>
      _channel.invokeMethod<String>('pickImage');

  /// Camera capture; returns the captured photo path in the cache dir.
  static Future<String?> capturePhoto() =>
      _channel.invokeMethod<String>('capturePhoto');
}
