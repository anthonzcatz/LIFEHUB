import 'package:flutter/material.dart';
import '../../../app/lifehub_theme.dart';
import 'onboard_art.dart';

class MoodDiaryView extends StatelessWidget {
  final AnimationController animationController;

  const MoodDiaryView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final firstHalfAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
          ),
        );
    final secondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );
    final textFirstHalfAnimation =
        Tween<Offset>(begin: const Offset(2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
          ),
        );
    final textSecondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-2, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.6, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );
    final imageFirstHalfAnimation =
        Tween<Offset>(begin: const Offset(4, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.4, 0.6, curve: Curves.fastOutSlowIn),
          ),
        );
    final imageSecondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-4, 0)).animate(
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
              const Text(
                "Stay Organized",
                style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold),
              ),
              SlideTransition(
                position: textFirstHalfAnimation,
                child: SlideTransition(
                  position: textSecondHalfAnimation,
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: 64,
                      right: 64,
                      top: 16,
                      bottom: 16,
                    ),
                    child: Text(
                      "Tasks with priorities and reminders, quick notes, and a secure password vault",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              SlideTransition(
                position: imageFirstHalfAnimation,
                child: SlideTransition(
                  position: imageSecondHalfAnimation,
                  child: const OnboardArt(
                    icon: Icons.check_circle_outline,
                    color: LifeHubTheme.tasks,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
