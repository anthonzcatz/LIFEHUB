import 'dart:io';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/backup_service.dart';
import 'core/services/local_db.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/restore_recovery_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/finance/data/finance_repository.dart';

void _registerBundledAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      <String>['Best Flutter UI Templates'],
      'MIT License\n'
      'Copyright © 2019 Mitesh Chodvadiya\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
      'of this software and associated documentation files (the "Software"), to deal\n'
      'in the Software without restriction, including without limitation the rights\n'
      'to use, copy, modify, merge, publish, distribute, sublicense, and/or modified\n'
      'copies of the Software, and to permit persons to whom the Software is\n'
      'furnished to do so, subject to the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included in all\n'
      'copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n'
      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n'
      'SOFTWARE.\n\n'
      'Finally, this software is helping the developer to solve their project issue and\n'
      'learning, it\'s free but doesn\'t mean to sell and earning, please respect the\n'
      'developer community.',
    );
    yield LicenseEntryWithLineBreaks(
      <String>['Roboto font'],
      'Roboto\n'
      'Copyright 2011 The Roboto Authors\n'
      'Licensed under the Apache License, Version 2.0.\n'
      'https://www.apache.org/licenses/LICENSE-2.0.txt',
    );
    yield LicenseEntryWithLineBreaks(
      <String>['Work Sans font'],
      'Work Sans\n'
      'Copyright 2019 The Work Sans Project Authors\n'
      'Licensed under the SIL Open Font License, Version 1.1.\n'
      'https://openfontlicense.org/open-font-license-official-text/',
    );
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerBundledAssetLicenses();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: !kIsWeb && Platform.isAndroid
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: _LifeHubBootstrap()));
}

class _LifeHubBootstrap extends StatefulWidget {
  const _LifeHubBootstrap();

  @override
  State<_LifeHubBootstrap> createState() => _LifeHubBootstrapState();
}

class _LifeHubBootstrapState extends State<_LifeHubBootstrap> {
  bool _databaseInitialized = false;
  bool _ready = false;
  bool _recoveryRequired = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_busy || _ready) return;
    setState(() {
      _busy = true;
      _error = null;
      _recoveryRequired = false;
    });
    try {
      if (!_databaseInitialized) {
        await LocalDb.init();
        _databaseInitialized = true;
      }
      await BackupService.recoverInterruptedRestore();
      await _finishStartup();
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryRequired = _databaseInitialized;
          _error = _databaseInitialized
              ? null
              : 'LifeHub could not open its local data. Keep the app installed and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishStartup() async {
    try {
      await FinanceRepository.ensureTransactionIndex();
    } catch (_) {}
    try {
      await BackupService.removeLegacyPlaintextBackup();
    } catch (_) {}
    try {
      await NotificationService.init();
    } catch (_) {}
    try {
      await AuthService.initFirebase();
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const LifeHubApp();
    return MaterialApp(
      title: 'LifeHub',
      debugShowCheckedModeBanner: false,
      home: _recoveryRequired
          ? RestoreRecoveryScreen(onRecovered: () => _finishStartup())
          : Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.dashboard_rounded,
                          size: 48,
                          color: Color(0xFF2633C5),
                        ),
                        const SizedBox(height: 16),
                        const Text('Preparing LifeHub'),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                        ] else ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _initialize,
                            child: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
