import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/Job.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/purchase_order.dart';
import '../stepsselections/AssignWorkSteps.dart';
import '../../../constants/colors.dart';


class PurchaseOrderInput extends StatefulWidget {
  final Job job;

  final PurchaseOrder? existingPo;

  const PurchaseOrderInput({
    Key? key,
    required this.job,
    this.existingPo,
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
  late TextEditingController _dispatchDateController;

  // Calculated field
  int _pendingQuantity = 0;

  @override
  void initState() {
    super.initState();
    // Initialize controllers first
    _purchaseOrderDateController = TextEditingController();
    _deliverDateController = TextEditingController();
    _totalPoController = TextEditingController();
    _dispatchDateController = TextEditingController();

    // Then set their values if editing
    if (widget.existingPo != null) {
      _purchaseOrderDateController.text = widget.existingPo!.purchaseOrderDate;
      _deliverDateController.text = widget.existingPo!.deliverDate;
      _totalPoController.text = widget.existingPo!.totalPo.toString();
      _dispatchDateController.text = widget.existingPo!.dispatchDate;
    }
  }

  @override
  void dispose() {
    _purchaseOrderDateController.dispose();
    _deliverDateController.dispose();
    _totalPoController.dispose();
    _dispatchDateController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase Order'),
        backgroundColor: AppColors.maincolor,
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
    final job = widget.job;
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
            // Show all job fields
            _buildJobDetailRow(Icons.confirmation_number, 'Job Number', job.nrcJobNo),
            _buildJobDetailRow(Icons.person, 'Customer', job.customerName),
            _buildJobDetailRow(Icons.category, 'Style/SKU', job.styleItemSKU),
            _buildJobDetailRow(Icons.settings, 'Flute Type', job.fluteType),
            _buildJobDetailRow(Icons.aspect_ratio, 'Board Size', job.boardSize ?? ''),
            _buildJobDetailRow(Icons.format_list_numbered, 'No. of Ups', job.noUps ?? ''),
            _buildJobDetailRow(Icons.attach_money, 'Latest Rate', job.latestRate?.toString() ?? ''),
            _buildJobDetailRow(Icons.money_off, 'Previous Rate', job.preRate?.toString() ?? ''),
            _buildJobDetailRow(Icons.straighten, 'Dimensions', (job.length != null && job.width != null && job.height != null) ? '${job.length} x ${job.width} x ${job.height}' : ''),
            _buildJobDetailRow(Icons.check, 'Artwork Received Date', job.artworkReceivedDate ?? ''),
            _buildJobDetailRow(Icons.check, 'Artwork Approval Date', job.artworkApprovalDate ?? ''),
            _buildJobDetailRow(Icons.check, 'Shade Card Approval Date', job.shadeCardApprovalDate ?? ''),
            _buildJobDetailRow(Icons.calendar_today, 'Created At', job.createdAt ?? ''),
            _buildJobDetailRow(Icons.update, 'Updated At', job.updatedAt ?? ''),
            if (job.purchaseOrder != null)
              _buildJobDetailRow(Icons.assignment, 'Purchase Order', 'Available'),
            if (job.hasPoAdded)
              _buildJobDetailRow(Icons.assignment_turned_in, 'PO Status', 'Added'),
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
        dispatchDate: _dispatchDateController.text,
      );

      final updatedJob = widget.job.copyWith(purchaseOrder: purchaseOrder);

      // Pop and return the updated job
      context.pop(updatedJob);
    }
  }

}