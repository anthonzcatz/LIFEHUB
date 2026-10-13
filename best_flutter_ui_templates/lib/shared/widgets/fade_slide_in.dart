import 'package:flutter/material.dart';

/// Template-style staggered entrance: fades in and slides up
/// after [delay]. Self-contained — no shared controller needed.
/// Matches the fitness template's fastOutSlowIn feel.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = 30.0,
  });

  /// Convenience: delay scaled by list [index], capped so deep
  /// items don't wait too long.
  factory FadeSlideIn.item({
    Key? key,
    required int index,
    required Widget child,
  }) => FadeSlideIn(
    key: key,
    delay: Duration(milliseconds: 60 * index.clamp(0, 12)),
    child: child,
  );

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _slide = Tween<Offset>(begin: Offset(0, widget.offset), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
        );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
    );
  }
}
