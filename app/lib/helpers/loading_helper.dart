import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';

import 'navigation_service.dart';

extension Loader on Future {
  Future<dynamic> waitingForSucess() async {
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

  Future<dynamic> waitingForSucessWithoutIndicator() async {
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
