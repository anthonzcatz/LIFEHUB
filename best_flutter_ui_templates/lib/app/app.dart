import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/services/local_db.dart';
import '../core/services/security_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/pin_screen.dart';
import '../features/onboarding/animated_onboarding_screen.dart';
import 'drawer_screen.dart';
import 'home_shell.dart';
import 'lifehub_theme.dart';

enum _Gate { onboarding, login, pinSetup, pinUnlock, home }

class LifeHubApp extends StatefulWidget {
  const LifeHubApp({super.key});

  @override
  State<LifeHubApp> createState() => _LifeHubAppState();
}

class _LifeHubAppState extends State<LifeHubApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _obscureForPrivacy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.authRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    AuthService.authRevision.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscure =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (_obscureForPrivacy != obscure && mounted) {
      setState(() => _obscureForPrivacy = obscure);
    }
    if (state == AppLifecycleState.paused && AuthService.requiresPinOnLaunch) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      AuthService.lockSession();
    }
  }

  _Gate _gate() {
    final settings = LocalDb.settings;
    final onboardingDone =
        settings.get(AppConstants.keyOnboardingDone, defaultValue: false) ==
        true;
    if (!onboardingDone) return _Gate.onboarding;

    final mode =
        settings.get(AppConstants.keyAuthMode, defaultValue: 'none')
            as String? ??
        'none';
    switch (mode) {
      case 'pin':
        if (!SecurityService.hasPin) return _Gate.pinSetup;
        if (!AuthService.sessionAuthenticated) return _Gate.pinUnlock;
        return _Gate.home;
      case 'firebase':
        return AuthService.firebaseUser == null ? _Gate.login : _Gate.home;
      default:
        return _Gate.login;
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeHub',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          if (_obscureForPrivacy)
            const ColoredBox(
              color: LifeHubTheme.background,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: LifeHubTheme.nearlyDarkBlue,
                ),
              ),
            ),
        ],
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: LifeHubTheme.nearlyDarkBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: LifeHubTheme.background,
        textTheme: LifeHubTheme.textTheme,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LifeHubTheme.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: LifeHubTheme.nearlyDarkBlue,
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: Builder(
        builder: (context) {
          switch (_gate()) {
            case _Gate.onboarding:
              return AnimatedOnboardingScreen(
                onDone: () {
                  LocalDb.settings.put(AppConstants.keyOnboardingDone, true);
                  _refresh();
                },
              );
            case _Gate.login:
              return LoginScreen(
                onSignedIn: _refresh,
                onBiometricSignedIn: _refresh,
              );
            case _Gate.pinSetup:
              return PinScreen(
                key: const ValueKey('pin_setup'),
                mode: PinMode.setup,
                onSuccess: AuthService.markSessionAuthenticated,
              );
            case _Gate.pinUnlock:
              return PinScreen(
                key: const ValueKey('pin_unlock'),
                mode: PinMode.unlock,
                onSuccess: AuthService.markSessionAuthenticated,
              );
            case _Gate.home:
              return const DrawerScreen(child: HomeShell());
          }
        },
      ),
    );
  }
}
