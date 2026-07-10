import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Branded spinner for use as a full-screen early-return (own Scaffold).
// Use when the screen returns early before building — e.g. `if (_loading) return const WabwayLoadingScaffold();`
class WabwayLoadingScaffold extends StatelessWidget {
  const WabwayLoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kColorCream,
      body: Center(child: WabwayLoadingIndicator()),
    );
  }
}

// Inline spinner for use inside an existing Scaffold body — e.g. `body: _loading ? const WabwayLoadingIndicator() : ...`
class WabwayLoadingIndicator extends StatelessWidget {
  const WabwayLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(kColorPrimary),
        ),
      ),
    );
  }
}
