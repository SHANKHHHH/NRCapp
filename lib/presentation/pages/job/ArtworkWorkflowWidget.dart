import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import 'package:go_router/go_router.dart';

class ArtworkWorkflowWidget extends StatefulWidget {
  final Job job;
  final Function(Job) onJobUpdate;
  final bool isActive;

  const ArtworkWorkflowWidget({
    Key? key,
    required this.job,
    required this.onJobUpdate,
    required this.isActive,
  }) : super(key: key);

  @override
  State<ArtworkWorkflowWidget> createState() => _ArtworkWorkflowWidgetState();
}

class _ArtworkWorkflowWidgetState extends State<ArtworkWorkflowWidget> {
  late TextEditingController _artworkReceivedController;
  late TextEditingController _artworkApprovalController;
  late TextEditingController _shadeCardController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _artworkReceivedController = TextEditingController(
      text: widget.job.artworkReceivedDate ?? '',
    );
    _artworkApprovalController = TextEditingController(
      text: widget.job.artworkApprovalDate ?? '',
    );
    _shadeCardController = TextEditingController(
      text: widget.job.shadeCardDate ?? '',
    );
  }

  @override
  void dispose() {
    _artworkReceivedController.dispose();
    _artworkApprovalController.dispose();
    _shadeCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Artwork Workflow',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              if (!_isEditing && widget.isActive)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Edit Dates', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Artwork Received Date
          _buildDateField(
            label: 'Artwork Received Date',
            controller: _artworkReceivedController,
            icon: Icons.download,
            isCompleted: _artworkReceivedController.text.isNotEmpty,
            isEnabled: _isEditing,
          ),

          const SizedBox(height: 12),

          // Artwork Approval Date
          _buildDateField(
            label: 'Artwork Approval Date',
            controller: _artworkApprovalController,
            icon: Icons.check_circle,
            isCompleted: _artworkApprovalController.text.isNotEmpty,
            isEnabled: _isEditing && _artworkReceivedController.text.isNotEmpty,
          ),

          const SizedBox(height: 12),

          // Shade Card Approval Date
          _buildDateField(
            label: 'Shade Card Approval Date',
            controller: _shadeCardController,
            icon: Icons.color_lens,
            isCompleted: _shadeCardController.text.isNotEmpty,
            isEnabled: _isEditing && _artworkApprovalController.text.isNotEmpty,
          ),

          const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isCompleted,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[300]!,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isCompleted ? Colors.green[700] : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isEnabled ? Colors.black87 : Colors.grey[500],
          ),
        ),
        subtitle: GestureDetector(
          onTap: isEnabled ? () => _selectDate(controller) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Select Date' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty ? Colors.grey[500] : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isEnabled ? Colors.blue[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        trailing: isCompleted ? null : null,
      ),
    );
  }

  Widget _buildActionButtons() {
    final allDatesFilled =
        _artworkReceivedController.text.isNotEmpty &&
            _artworkApprovalController.text.isNotEmpty &&
            _shadeCardController.text.isNotEmpty;
    final hasPoAdded = widget.job.hasPoAdded;

    if (_isEditing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final updatedJob = widget.job.copyWith(
              artworkReceivedDate: _artworkReceivedController.text.isEmpty ? null : _artworkReceivedController.text,
              artworkApprovalDate: _artworkApprovalController.text.isEmpty ? null : _artworkApprovalController.text,
              shadeCardDate: _shadeCardController.text.isEmpty ? null : _shadeCardController.text,
            );
            widget.onJobUpdate(updatedJob);
            setState(() {
              _isEditing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Changes saved for job ${widget.job.jobNumber}'),
                backgroundColor: Colors.blue[600],
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (allDatesFilled && !hasPoAdded) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // Navigate to PurchaseOrderInput page
            GoRouter.of(context).push('/add-po', extra: widget.job);
          },
          icon: const Icon(Icons.add_business),
          label: const Text('Add PO'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (allDatesFilled && hasPoAdded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(
              'Artwork workflow completed & PO added',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    if (!_isEditing) return; // Only allow date picking in edit mode
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = _formatDate(pickedDate);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}