import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

enum SnackType { info, success, error }

void showAppSnackBar(BuildContext context, String message, {SnackType type = SnackType.info}) {
  final snack = switch (type) {
    SnackType.success => CustomSnackBar.success(message: message, messagePadding: const EdgeInsets.all(12)),
    SnackType.error => CustomSnackBar.error(message: message, messagePadding: const EdgeInsets.all(12)),
    _ => CustomSnackBar.info(message: message, messagePadding: const EdgeInsets.all(12)),
  };
  showTopSnackBar(
    Overlay.of(context),
    snack,
    animationDuration: const Duration(milliseconds: 400),
    reverseAnimationDuration: const Duration(milliseconds: 300),
    displayDuration: const Duration(seconds: 2),
  );
}
