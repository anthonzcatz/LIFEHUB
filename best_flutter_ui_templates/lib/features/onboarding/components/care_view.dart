import 'package:flutter/material.dart';
import '../../../app/lifehub_theme.dart';
import 'onboard_art.dart';

class CareView extends StatelessWidget {
  final AnimationController animationController;

  const CareView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final firstHalfAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final secondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
          ),
        );
    final titleFirstHalfAnimation =
        Tween<Offset>(begin: const Offset(2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final titleSecondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-2, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
          ),
        );
    final imageFirstHalfAnimation =
        Tween<Offset>(begin: const Offset(4, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final imageSecondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-4, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
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
                position: imageFirstHalfAnimation,
                child: SlideTransition(
                  position: imageSecondHalfAnimation,
                  child: const OnboardArt(
                    icon: Icons.repeat,
                    color: LifeHubTheme.habits,
                  ),
                ),
              ),
              SlideTransition(
                position: titleFirstHalfAnimation,
                child: SlideTransition(
                  position: titleSecondHalfAnimation,
                  child: const Text(
                    "Build Habits",
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 64,
                  right: 64,
                  bottom: 16,
                  top: 0,
                ),
                child: Text(
                  "Create custom daily habits, keep your streaks alive, and see progress on the calendar",
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
