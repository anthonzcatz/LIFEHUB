import 'package:flutter/material.dart';
import '../../../app/lifehub_theme.dart';
import 'onboard_art.dart';

class RelaxView extends StatelessWidget {
  final AnimationController animationController;

  const RelaxView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final firstHalfAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.0, 0.2, curve: Curves.fastOutSlowIn),
          ),
        );
    final secondHalfAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final textAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-2, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final imageAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-4, 0)).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
          ),
        );
    final relaxAnimation =
        Tween<Offset>(begin: const Offset(0, -2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.0, 0.2, curve: Curves.fastOutSlowIn),
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
                position: relaxAnimation,
                child: const Text(
                  "Track Your Money",
                  style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold),
                ),
              ),
              SlideTransition(
                position: textAnimation,
                child: const Padding(
                  padding: EdgeInsets.only(
                    left: 64,
                    right: 64,
                    top: 16,
                    bottom: 16,
                  ),
                  child: Text(
                    "Log expenses and income, set monthly budgets, and watch your savings goals grow",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SlideTransition(
                position: imageAnimation,
                child: const OnboardArt(
                  icon: Icons.account_balance_wallet_outlined,
                  color: LifeHubTheme.finance,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
