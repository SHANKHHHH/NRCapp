import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/Job.dart';
import 'package:go_router/go_router.dart';
import '../../../data/datasources/job_api.dart';
import '../../../core/services/dio_service.dart';

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

  // Track loading state for each field
  bool _isLoadingArtworkReceived = false;
  bool _isLoadingArtworkApproval = false;
  bool _isLoadingShadeCard = false;

  late JobApi _jobApi;

  String? _artworkImageUrl;
  bool _isUploadingImage = false;

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
      text: widget.job.shadeCardApprovalDate ?? '',
    );
    _jobApi = JobApi(DioService.instance);
    _artworkImageUrl = widget.job.imageURL;

    // If all fields are empty, allow editing immediately
    if ((widget.job.artworkReceivedDate == null || widget.job.artworkReceivedDate!.isEmpty) &&
        (widget.job.artworkApprovalDate == null || widget.job.artworkApprovalDate!.isEmpty) &&
        (widget.job.shadeCardApprovalDate == null || widget.job.shadeCardApprovalDate!.isEmpty)) {
      _isEditing = true;
    }
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
              // Only show edit button if not editing and at least one field is filled
              if (!_isEditing && widget.isActive && (
                (widget.job.artworkReceivedDate?.isNotEmpty ?? false) ||
                (widget.job.artworkApprovalDate?.isNotEmpty ?? false) ||
                (widget.job.shadeCardApprovalDate?.isNotEmpty ?? false)
              ))
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

          // Upload Artwork Button and Image Preview (below all date fields)
          Padding(
            padding: const EdgeInsets.only(left: 0, right: 0, bottom: 8, top: 12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  icon: _isUploadingImage
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.upload),
                  label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Artwork'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_artworkImageUrl != null && _artworkImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _artworkImageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
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
    // Determine which field is loading
    bool isLoading = false;
    if (label == 'Artwork Received Date') isLoading = _isLoadingArtworkReceived;
    if (label == 'Artwork Approval Date') isLoading = _isLoadingArtworkApproval;
    if (label == 'Shade Card Approval Date') isLoading = _isLoadingShadeCard;
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
          onTap: isEnabled && !isLoading ? () => _selectAndUpdateDate(controller, label) : null,
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
                  child: isLoading
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Updating...'),
                          ],
                        )
                      : Text(
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


    if (_isEditing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final updatedJob = widget.job.copyWith(
              artworkReceivedDate: _artworkReceivedController.text.isEmpty ? null : _artworkReceivedController.text,
              artworkApprovalDate: _artworkApprovalController.text.isEmpty ? null : _artworkApprovalController.text,
              shadeCardApprovalDate: _shadeCardController.text.isEmpty ? null : _shadeCardController.text,
            );
            widget.onJobUpdate(updatedJob);
            setState(() {
              _isEditing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Changes saved for job ${widget.job.nrcJobNo}'),
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

    return const SizedBox.shrink();
  }

  Future<void> _selectAndUpdateDate(TextEditingController controller, String label) async {
    if (!_isEditing) return;
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
      String formattedDate = _formatDate(pickedDate);
      setState(() {
        controller.text = formattedDate;
        if (label == 'Artwork Received Date') _isLoadingArtworkReceived = true;
        if (label == 'Artwork Approval Date') _isLoadingArtworkApproval = true;
        if (label == 'Shade Card Approval Date') _isLoadingShadeCard = true;
      });
      try {
        Map<String, dynamic> updateField = {};
        if (label == 'Artwork Received Date') updateField['artworkReceivedDate'] = formattedDate;
        if (label == 'Artwork Approval Date') updateField['artworkApprovedDate'] = formattedDate;
        if (label == 'Shade Card Approval Date') updateField['shadeCardApprovalDate'] = formattedDate;
        await _jobApi.updateJobField(widget.job.nrcJobNo, updateField);

        final updatedJob = widget.job.copyWith(
          artworkReceivedDate: label == 'Artwork Received Date' ? formattedDate : widget.job.artworkReceivedDate,
          artworkApprovalDate: label == 'Artwork Approval Date' ? formattedDate : widget.job.artworkApprovalDate,
          shadeCardApprovalDate: label == 'Shade Card Approval Date' ? formattedDate : widget.job.shadeCardApprovalDate,
        );
        widget.onJobUpdate(updatedJob);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label updated!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $label'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        setState(() {
          if (label == 'Artwork Received Date') _isLoadingArtworkReceived = false;
          if (label == 'Artwork Approval Date') _isLoadingArtworkApproval = false;
          if (label == 'Shade Card Approval Date') _isLoadingShadeCard = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hour:$minute:${second}z';
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _isUploadingImage = true;
      });
      try {
        // Simulate upload and get a mock URL
        final imageUrl = await _mockUploadImage(pickedFile.path);
        setState(() {
          _artworkImageUrl = imageUrl;
        });
        await _jobApi.updateJobField(widget.job.nrcJobNo, {'imageURL': imageUrl});
        widget.onJobUpdate(widget.job.copyWith(imageURL: imageUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Artwork image uploaded!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<String> _mockUploadImage(String path) async {
    // Simulate a network upload delay
    await Future.delayed(Duration(seconds: 2));
    // Return a mock image URL (in real app, upload to server and get URL)
    return 'https://via.placeholder.com/150?text=Artwork';
  }
}