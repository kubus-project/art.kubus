import 'package:flutter/material.dart';

class AnalyticsOverviewCardData {
  const AnalyticsOverviewCardData({
    required this.metricId,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.changeLabel,
    this.isPositive,
  });

  final String metricId;
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final String? changeLabel;
  final bool? isPositive;
}

class AnalyticsInsightData {
  const AnalyticsInsightData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class AnalyticsComparisonData {
  const AnalyticsComparisonData({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.isPositive,
  });

  final String label;
  final String currentValue;
  final String previousValue;
  final bool? isPositive;
}
