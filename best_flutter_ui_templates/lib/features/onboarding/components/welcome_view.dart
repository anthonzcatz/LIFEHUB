import 'package:flutter/material.dart';
import '../../../app/lifehub_theme.dart';
import 'onboard_art.dart';

class WelcomeView extends StatelessWidget {
  final AnimationController animationController;

  const WelcomeView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final firstHalfAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );
    final secondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.8, 1.0, curve: Curves.fastOutSlowIn),
          ),
        );
    final welcomeFirstHalfAnimation =
        Tween<Offset>(begin: const Offset(2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );
    final welcomeImageAnimation =
        Tween<Offset>(begin: const Offset(4, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );

    return SlideTransition(
      position: firstHalfAnimation,
      child: SlideTransition(
        position: secondHalfAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideTransition(
                position: welcomeImageAnimation,
                child: const OnboardArt(
                  icon: Icons.lock_outline,
                  color: LifeHubTheme.vault,
                  size: 260,
                ),
              ),
              SlideTransition(
                position: welcomeFirstHalfAnimation,
                child: const Text(
                  "Private & Secure",
                  style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 64,
                  right: 64,
                  top: 16,
                  bottom: 16,
                ),
                child: Text(
                  "Your data stays on your device — protected with PIN and fingerprint",
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
