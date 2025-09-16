import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class PendingJobsWorkPage extends StatelessWidget {
  final String nrcJobNo;
  final List<Map<String, dynamic>> pendingFields;
  const PendingJobsWorkPage({super.key, required this.nrcJobNo, required this.pendingFields});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Works for $nrcJobNo'),
        backgroundColor: AppColors.maincolor,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const Divider(),
        itemCount: pendingFields.length,
        itemBuilder: (context, index) {
          final field = pendingFields[index];
          return ListTile(
            title: Text(field['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(field['value']),
          );
        },
      ),
    );
  }
} 