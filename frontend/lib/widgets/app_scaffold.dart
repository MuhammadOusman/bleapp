import 'package:flutter/material.dart';
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final bool padded;

  const AppScaffold({super.key, required this.body, this.appBar, this.bottomBar, this.padded = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0E1118), Color(0xFF161B22)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF7F8FB), Color(0xFFE8ECF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: padded ? Padding(padding: const EdgeInsets.all(16), child: body) : body,
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
