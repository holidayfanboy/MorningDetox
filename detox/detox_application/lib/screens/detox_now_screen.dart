import 'package:flutter/material.dart';

/// Placeholder for starting an immediate, alarm-less detox session, reached
/// from the alarm list's overflow menu. Empty for now -- content to follow.
class DetoxNowScreen extends StatelessWidget {
  const DetoxNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detox Now')),
      body: const SafeArea(child: SizedBox.shrink()),
    );
  }
}
