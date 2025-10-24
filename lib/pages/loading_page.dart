import 'package:flutter/material.dart';
import '../widgets/loading_screen.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen(
      message: 'Loading...',
      duration: Duration(seconds: 2),
    );
  }
}
