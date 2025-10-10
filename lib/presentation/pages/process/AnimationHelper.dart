import 'package:flutter/material.dart';

/// World-class animations for the NRC Manufacturing App
class AnimationHelper {
  // Smooth page transitions
  static Route createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var opacityAnimation = animation.drive(tween);

        return FadeTransition(
          opacity: opacityAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Slide from bottom transition
  static Route createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Scale transition with fade
  static Route createScaleRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutBack;

        var scaleTween = Tween(begin: 0.8, end: 1.0).chain(CurveTween(curve: curve));
        var fadeTween = Tween(begin: 0.0, end: 1.0);

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Success celebration animation
  static Widget successAnimation({
    required Widget child,
    required bool show,
    VoidCallback? onComplete,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: show ? 0.0 : 1.0, end: show ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      onEnd: onComplete,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Shimmer loading effect
  static Widget shimmerLoading({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - value * 2, 0),
              end: Alignment(1.0 + value * 2, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }

  // Pulse animation for attention
  static Widget pulseAnimation({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
      onEnd: () {},
    );
  }

  // Smooth card expansion
  static Widget expandableCard({
    required Widget child,
    required bool expanded,
    Duration? duration,
  }) {
    return AnimatedContainer(
      duration: duration ?? const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedSize(
        duration: duration ?? const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }

  // Loading dots animation
  static Widget loadingDots({Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 100)),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -5 * value),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (color ?? Colors.blue).withOpacity(value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // Ripple effect
  static Widget rippleEffect({
    required Widget child,
    required VoidCallback onTap,
    Color? rippleColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (rippleColor ?? Colors.blue).withOpacity(0.2),
        highlightColor: (rippleColor ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  // Smooth refresh indicator
  static Widget refreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
    Color? color,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? Colors.blue,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 40.0,
      child: child,
    );
  }

  // Skeleton loading for cards
  static Widget skeletonCard({
    required double height,
    EdgeInsets? padding,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shimmerLoading(width: 150, height: 20, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 12),
          shimmerLoading(width: double.infinity, height: height - 50, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 12),
          Row(
            children: [
              shimmerLoading(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 12),
              shimmerLoading(width: 100, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ],
      ),
    );
  }

  // Success checkmark animation
  static Widget successCheckmark({required bool show, double size = 60}) {
    return AnimatedScale(
      scale: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          Icons.check,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }

  // Error shake animation
  static Widget shakeAnimation({
    required Widget child,
    required bool shake,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: shake ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        final offset = 10 * (value - 0.5).abs() * 2;
        return Transform.translate(
          offset: Offset(offset * (value > 0.5 ? -1 : 1), 0),
          child: child,
        );
      },
      child: child,
    );
  }

  // Smooth fade in
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Duration? delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

