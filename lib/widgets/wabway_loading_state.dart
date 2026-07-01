import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

class WabwayLoadingState extends StatefulWidget {
  const WabwayLoadingState({super.key, this.rows = 3});
  final int rows;

  @override
  State<WabwayLoadingState> createState() => _WabwayLoadingStateState();
}

class _WabwayLoadingStateState extends State<WabwayLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.45)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
      child: Column(
        children: List.generate(
          widget.rows,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < widget.rows - 1 ? kSpace3 : 0),
            child: _SkeletonRow(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: kCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusSm,
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.62,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: kColorSurfaceSunken,
                      borderRadius: kRadiusPill,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.36,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: kColorSurfaceSunken,
                      borderRadius: kRadiusPill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
