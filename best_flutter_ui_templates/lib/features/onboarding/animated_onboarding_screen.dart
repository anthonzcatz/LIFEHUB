import 'package:flutter/material.dart';

import '../../app/lifehub_theme.dart';
import 'components/care_view.dart';
import 'components/center_next_button.dart';
import 'components/mood_diary_view.dart';
import 'components/relax_view.dart';
import 'components/splash_view.dart';
import 'components/top_back_skip_view.dart';
import 'components/welcome_view.dart';

/// Animated onboarding — adapted from the template's
/// introduction_animation, re-themed for LifeHub.
class AnimatedOnboardingScreen extends StatefulWidget {
  const AnimatedOnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<AnimatedOnboardingScreen> createState() =>
      _AnimatedOnboardingScreenState();
}

class _AnimatedOnboardingScreenState extends State<AnimatedOnboardingScreen>
    with TickerProviderStateMixin {
  AnimationController? _animationController;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _animationController?.animateTo(0.0);
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      body: ClipRect(
        child: Stack(
          children: [
            SplashView(animationController: _animationController!),
            RelaxView(animationController: _animationController!),
            CareView(animationController: _animationController!),
            MoodDiaryView(animationController: _animationController!),
            WelcomeView(animationController: _animationController!),
            TopBackSkipView(
              onBackClick: _onBackClick,
              onSkipClick: _onSkipClick,
              animationController: _animationController!,
            ),
            CenterNextButton(
              animationController: _animationController!,
              onNextClick: _onNextClick,
            ),
          ],
        ),
      ),
    );
  }

  void _onSkipClick() {
    _animationController?.animateTo(
      0.8,
      duration: const Duration(milliseconds: 1200),
    );
  }

  void _onBackClick() {
    final v = _animationController!.value;
    if (v <= 0.2) {
      _animationController?.animateTo(0.0);
    } else if (v <= 0.4) {
      _animationController?.animateTo(0.2);
    } else if (v <= 0.6) {
      _animationController?.animateTo(0.4);
    } else if (v <= 0.8) {
      _animationController?.animateTo(0.6);
    } else {
      _animationController?.animateTo(0.8);
    }
  }

  void _onNextClick() {
    final v = _animationController!.value;
    if (v <= 0.2) {
      _animationController?.animateTo(0.4);
    } else if (v <= 0.4) {
      _animationController?.animateTo(0.6);
    } else if (v <= 0.6) {
      _animationController?.animateTo(0.8);
    } else {
      widget.onDone();
    }
  }
}
