import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class AllRecentActivitiesPage extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const AllRecentActivitiesPage({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Recent Activities'),
        backgroundColor: AppColors.maincolor,
      ),
      body: activities.isEmpty
          ? const Center(child: Text('No recent activities'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const Divider(),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                List<Widget> details = [];
                void addDetail(String label, String key) {
                  final v = activity[key];
                  if (v != null && v.toString().isNotEmpty) {
                    details.add(Text('$label: $v', style: const TextStyle(fontSize: 13)));
                  }
                }
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Job: ${activity['nrcJobNo'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Text(
                              activity['time'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (activity['status'] != null && activity['status'].toString().isNotEmpty)
                          Text('Status: ${activity['status']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        ...(() {
                          details.clear();
                          addDetail('Artwork Received Date', 'artworkReceivedDate');
                          addDetail('Artwork Approved Date', 'artworkApprovedDate');
                          addDetail('Shade Card Approval Date', 'shadeCardApprovalDate');
                          addDetail('Image URL', 'imageURL');
                          return details;
                        })(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
} 