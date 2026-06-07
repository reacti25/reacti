import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A centered "couldn't load" state with a retry action.
///
/// Shown in place of a screen's content when its data stream emits an error,
/// so a failed load surfaces a message and a way to recover instead of a blank
/// screen. [onRetry] typically re-triggers the screen's load.
class LoadErrorRetry extends StatelessWidget {
  /// Creates the error/retry state.
  const LoadErrorRetry({
    super.key,
    required this.onRetry,
    this.message = 'Something went wrong.',
  });

  /// Short, user-facing description of the failure.
  final String message;

  /// Invoked when the user taps Retry — usually re-runs the failed load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 48.r),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
