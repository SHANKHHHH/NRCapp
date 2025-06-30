import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/Job.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/purchase_order.dart';

class PurchaseOrderInput extends StatefulWidget {
  final Job job;

  final PurchaseOrder? existingPo;

  const PurchaseOrderInput({
    Key? key,
    required this.job,   this.existingPo,
  }) : super(key: key);

  @override
  State<PurchaseOrderInput> createState() => _PurchaseOrderInputState();
}

class _PurchaseOrderInputState extends State<PurchaseOrderInput> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  late TextEditingController _purchaseOrderDateController;
  late TextEditingController _deliverDateController;
  late TextEditingController _totalPoController;
  late TextEditingController _dispatchPoController;
  late TextEditingController _dispatchDateController;

  // Calculated field
  int _pendingQuantity = 0;

  @override
  void initState() {
    super.initState();

    if (widget.existingPo != null) {
      _purchaseOrderDateController.text = widget.existingPo!.purchaseOrderDate;
      _deliverDateController.text = widget.existingPo!.deliverDate;
      _totalPoController.text = widget.existingPo!.totalPo.toString();
      _dispatchPoController.text = widget.existingPo!.dispatchPo.toString();
      _dispatchDateController.text = widget.existingPo!.dispatchDate;
    }

    _purchaseOrderDateController = TextEditingController();
    _deliverDateController = TextEditingController();
    _totalPoController = TextEditingController();
    _dispatchPoController = TextEditingController();
    _dispatchDateController = TextEditingController();

    // Add listeners to calculate pending quantity
    _totalPoController.addListener(_calculatePendingQuantity);
    _dispatchPoController.addListener(_calculatePendingQuantity);
  }

  @override
  void dispose() {
    _purchaseOrderDateController.dispose();
    _deliverDateController.dispose();
    _totalPoController.dispose();
    _dispatchPoController.dispose();
    _dispatchDateController.dispose();
    super.dispose();
  }

  void _calculatePendingQuantity() {
    final totalPo = int.tryParse(_totalPoController.text) ?? 0;
    final dispatchPo = int.tryParse(_dispatchPoController.text) ?? 0;
    setState(() {
      _pendingQuantity = totalPo - dispatchPo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase Order'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Details Card
            _buildJobDetailsCard(),
            const SizedBox(height: 20),

            // Purchase Order Form
            _buildPurchaseOrderForm(),

            const SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Job Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Job Information (all fields)
            _buildJobDetailRow(Icons.confirmation_number, 'Job Number', widget.job.jobNumber),
            _buildJobDetailRow(Icons.person, 'Customer', widget.job.customer),
            _buildJobDetailRow(Icons.factory, 'Plant', widget.job.plant),
            _buildJobDetailRow(Icons.calendar_today, 'Job Date', widget.job.jobDate),
            _buildJobDetailRow(Icons.delivery_dining, 'Delivery Date', widget.job.deliveryDate),
            _buildJobDetailRow(Icons.style, 'Style', widget.job.style ?? ''),
            _buildJobDetailRow(Icons.code, 'Die Code', widget.job.dieCode ?? ''),
            _buildJobDetailRow(Icons.aspect_ratio, 'Board Size', widget.job.boardSize ?? ''),
            _buildJobDetailRow(Icons.layers, 'Flute Type', widget.job.fluteType ?? ''),
            _buildJobDetailRow(Icons.format_list_numbered, 'No. of Ups', widget.job.noOfUps ?? ''),
            _buildJobDetailRow(Icons.format_list_numbered, 'No. of Sheets', widget.job.noOfSheets ?? ''),
            _buildJobDetailRow(Icons.straighten, 'Unit', widget.job.unit ?? ''),
            _buildJobDetailRow(Icons.calendar_month, 'Job Month', widget.job.jobMonth ?? ''),
            _buildJobDetailRow(Icons.person_outline, 'Created By', widget.job.createdBy ?? ''),
            _buildJobDetailRow(Icons.date_range, 'Created Date', widget.job.createdDate ?? ''),
            // Add more fields as needed

            const SizedBox(height: 12),

            // Artwork Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artwork Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.job.artworkReceivedDate != null)
                    _buildArtworkStatusRow('Artwork Received', widget.job.artworkReceivedDate!),
                  if (widget.job.artworkApprovalDate != null)
                    _buildArtworkStatusRow('Artwork Approved', widget.job.artworkApprovalDate!),
                  if (widget.job.shadeCardDate != null)
                    _buildArtworkStatusRow('Shade Card Approved', widget.job.shadeCardDate!),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Job Quantities
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuantityInfo('Total Qty', widget.job.totalQuantity.toString()),
                  _buildQuantityInfo('Dispatched', widget.job.dispatchQuantity.toString()),
                  _buildQuantityInfo('Pending', widget.job.pendingQuantity.toString()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkStatusRow(String label, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseOrderForm() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_business, color: Colors.orange[700], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Purchase Order Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Purchase Order Date
              _buildDateFormField(
                controller: _purchaseOrderDateController,
                label: 'Purchase Order Date',
                icon: Icons.calendar_today,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select purchase order date';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Deliver Date
              _buildDateFormField(
                controller: _deliverDateController,
                label: 'Deliver Date',
                icon: Icons.local_shipping,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select deliver date';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Total PO
              _buildNumberFormField(
                controller: _totalPoController,
                label: 'Total PO',
                icon: Icons.inventory,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total PO quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Pending Quantity (Read-only)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Text(
                      'Pending Quantity: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      _pendingQuantity.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dispatch Date
              _buildDateFormField(
                controller: _dispatchDateController,
                label: 'Dispatch Date',
                icon: Icons.schedule,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select dispatch date';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDate(controller),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      readOnly: true,
      validator: validator,
      onTap: () => _selectDate(controller),
    );
  }

  Widget _buildNumberFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _savePurchaseOrder,
            icon: const Icon(Icons.save),
            label: const Text('Save Purchase Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => GoRouter.of(context).pop(),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
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

  void _savePurchaseOrder() {
    if (_formKey.currentState!.validate()) {
      final purchaseOrder = PurchaseOrder(
        purchaseOrderDate: _purchaseOrderDateController.text,
        deliverDate: _deliverDateController.text,
        totalPo: int.parse(_totalPoController.text),
        dispatchPo: int.parse(_dispatchPoController.text),
        dispatchDate: _dispatchDateController.text,
      );

      // Navigate to Job Details Page
      context.push(
        '/job-details/${widget.job.jobNumber}',
        extra: {
          'job': widget.job,
          'po': purchaseOrder,
        },
      );
    }
  }

}