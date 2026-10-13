import 'package:flutter/material.dart';
import '../../../app/lifehub_theme.dart';
import 'onboard_art.dart';

class SplashView extends StatefulWidget {
  final AnimationController animationController;

  const SplashView({super.key, required this.animationController});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  Widget build(BuildContext context) {
    final introductionAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0.0, -1.0),
        ).animate(
          CurvedAnimation(
            parent: widget.animationController,
            curve: const Interval(0.0, 0.2, curve: Curves.fastOutSlowIn),
          ),
        );
    return SlideTransition(
      position: introductionAnimation,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 64),
            const OnboardArt(
              icon: Icons.dashboard_rounded,
              color: LifeHubTheme.nearlyDarkBlue,
              size: 300,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Text(
                "LifeHub",
                style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 64, right: 64),
              child: Text(
                "Your all-in-one personal organizer — money, tasks, habits, and secure notes in one place",
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: InkWell(
                onTap: () {
                  widget.animationController.animateTo(0.2);
                },
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.only(
                    left: 56.0,
                    right: 56.0,
                    top: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(38.0),
                    color: LifeHubTheme.nearlyDarkBlue,
                  ),
                  child: const Text(
                    "Let's begin",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
