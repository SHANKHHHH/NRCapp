import 'package:flutter/material.dart';

// Enums for step status and type
enum StepStatus { pending, started, inProgress, paused, completed }

enum StepType { jobAssigned, paperStore, printing, corrugation, fluteLamination, punching, flapPasting, qc, dispatch }

// StepData model class
class StepData {
  final StepType type;
  final String title;
  final String description;
  StepStatus status;
  Map<String, dynamic> formData;

  StepData({
    required this.type,
    required this.title,
    required this.description,
    this.status = StepStatus.pending,
    this.formData = const {},
  });
} 