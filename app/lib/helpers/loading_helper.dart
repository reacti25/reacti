import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';

import 'navigation_service.dart';

/// Adds blocking-loading-dialog behaviour to any [Future].
///
/// Lets callers `await someFuture.waitingForSuccess()` to show a modal
/// progress spinner for the duration of an async operation without manually
/// pushing and popping a dialog at every call site.
extension Loader on Future {
  /// Awaits this future while showing a modal [CircularProgressIndicator].
  ///
  /// The dialog is non-dismissible and is always closed in a `finally` block
  /// so it is removed even if the awaited future throws. Returns whatever the
  /// underlying future resolves to.
  Future<dynamic> waitingForSuccess() async {
    showDialog(
      barrierDismissible: false,
      barrierColor: AppColors.c000000.withValues(alpha: 0.1),
      context: NavigationService.context,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    try {
      dynamic result = await this;
      return result;
    } finally {
      NavigationService.goBack;
    }
  }

  /// Awaits this future behind a non-dismissible modal barrier.
  ///
  /// Behaves like [waitingForSuccess] and currently still renders a spinner;
  /// kept as a separate entry point for call sites that semantically do not
  /// want a visible indicator. Returns the underlying future's result.
  Future<dynamic> waitingForSuccessWithoutIndicator() async {
    showDialog(
      barrierDismissible: false,
      barrierColor: AppColors.c000000.withValues(alpha: 0.1),
      context: NavigationService.context,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    try {
      dynamic result = await this;
      return result;
    } finally {
      NavigationService.goBack;
    }
  }
}
