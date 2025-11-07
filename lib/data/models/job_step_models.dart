import 'package:flutter/material.dart';

// Enums for step status and type
enum StepStatus { pending, started, inProgress, paused, hold, major_hold }

enum StepType { paperStore, printing, corrugation, fluteLamination, punching, dieCutting, flapPasting, qc, dispatch }

// StepData model class
class StepData {
  final StepType type;
  final String title;
  final String description;
  StepStatus status;
  Map<String, dynamic> formData;
  String? internalStatus; // Internal status for hold/in_progress logic

  StepData({
    required this.type,
    required this.title,
    required this.description,
    this.status = StepStatus.pending,
    this.formData = const {},
    this.internalStatus,
  });
} 