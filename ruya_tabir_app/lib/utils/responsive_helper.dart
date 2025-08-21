import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static double getCardWidth(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(context)) {
      return screenWidth * 0.5; // Desktop için %50 genişlik
    } else if (isTablet(context)) {
      return screenWidth * 0.7; // Tablet için %70 genişlik
    } else {
      return screenWidth * 0.9; // Mobil için %90 genişlik
    }
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }

  static double getTextScaleFactor(BuildContext context) {
    if (isDesktop(context)) {
      return 1.2;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.0;
    }
  }
} 