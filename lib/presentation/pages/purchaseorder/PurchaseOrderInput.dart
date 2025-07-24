import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/Job.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/purchase_order.dart';
import '../stepsselections/AssignWorkSteps.dart';
import '../../../constants/colors.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';


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
  late TextEditingController _nrcDeliveryDateController;
  late TextEditingController _unitController;
  late TextEditingController _noOfSheetsController;

  // Calculated field
  int _pendingQuantity = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers first
    _purchaseOrderDateController = TextEditingController();
    _deliverDateController = TextEditingController();
    _totalPoController = TextEditingController();
    _dispatchDateController = TextEditingController();
    _nrcDeliveryDateController = TextEditingController();
    _unitController = TextEditingController(text: 'PCS');
    _noOfSheetsController = TextEditingController();

    // Then set their values if editing
    if (widget.existingPo != null) {
      _purchaseOrderDateController.text = widget.existingPo!.poDate.toIso8601String();
      _deliverDateController.text = widget.existingPo!.deliveryDate.toIso8601String();
      _totalPoController.text = widget.existingPo!.totalPOQuantity.toString();
      _dispatchDateController.text = widget.existingPo!.dispatchDate.toIso8601String();
      _nrcDeliveryDateController.text = widget.existingPo!.nrcDeliveryDate.toIso8601String();
      _unitController.text = widget.existingPo!.unit;
      _noOfSheetsController.text = widget.existingPo!.noOfSheets.toString();
    }
  }

  @override
  void dispose() {
    _purchaseOrderDateController.dispose();
    _deliverDateController.dispose();
    _totalPoController.dispose();
    _dispatchDateController.dispose();
    _nrcDeliveryDateController.dispose();
    _unitController.dispose();
    _noOfSheetsController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildJobDetailsCard() {
    final job = widget.job;
    int pendingValidity = 0;
    Color validityColor = Colors.grey;
    if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty) {
      final shadeCardDate = DateTime.tryParse(job.shadeCardApprovalDate!);
      if (shadeCardDate != null) {
        pendingValidity = DateTime.now().difference(shadeCardDate).inDays;
        if (pendingValidity <= 70) {
          validityColor = Colors.green;
        } else if (pendingValidity <= 140) {
          validityColor = Colors.yellow[700]!;
        } else {
          validityColor = Colors.red;
        }
      }
    }
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
            // Pending Validity Indicator
            if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: validityColor, size: 16),
                    const SizedBox(width: 8),
                    Text('$pendingValidity days since Shade Card Approval', style: TextStyle(color: validityColor, fontWeight: FontWeight.bold)),
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
              // PO Date (read-only)
              _buildJobDetailRow(Icons.calendar_today, 'PO Date', DateTime.now().toIso8601String()),
              const SizedBox(height: 16),
              // Delivery Date
              _buildDateFormField(
                controller: _deliverDateController,
                label: 'Delivery Date',
                icon: Icons.local_shipping,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select delivery date';
                  }
                  return null;
                },
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
              const SizedBox(height: 16),
              // NRC Delivery Date
              _buildDateFormField(
                controller: _nrcDeliveryDateController,
                label: 'NRC Delivery Date',
                icon: Icons.calendar_today,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select NRC delivery date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Total PO Quantity
              _buildNumberFormField(
                controller: _totalPoController,
                label: 'Total PO Quantity',
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
              // Unit
              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter unit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // No of Sheets
              _buildNumberFormField(
                controller: _noOfSheetsController,
                label: 'No. of Sheets',
                icon: Icons.format_list_numbered,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of sheets';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Pending Validity (read-only)
              Builder(
                builder: (context) {
                  int pendingValidity = 0;
                  Color validityColor = Colors.grey;
                  final job = widget.job;
                  if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty) {
                    final shadeCardDate = DateTime.tryParse(job.shadeCardApprovalDate!);
                    if (shadeCardDate != null) {
                      pendingValidity = DateTime.now().difference(shadeCardDate).inDays;
                      if (pendingValidity <= 70) {
                        validityColor = Colors.green;
                      } else if (pendingValidity <= 140) {
                        validityColor = Colors.yellow[700]!;
                      } else {
                        validityColor = Colors.red;
                      }
                    }
                  }
                  return Row(
                    children: [
                      Icon(Icons.circle, color: validityColor, size: 16),
                      const SizedBox(width: 8),
                      Text('$pendingValidity days since Shade Card Approval', style: TextStyle(color: validityColor, fontWeight: FontWeight.bold)),
                    ],
                  );
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
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hour:$minute:${second}z';
  }

  void _savePurchaseOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final poDate = DateTime.now();
      final shadeCardDate = widget.job.shadeCardApprovalDate != null && widget.job.shadeCardApprovalDate!.isNotEmpty
          ? DateTime.tryParse(widget.job.shadeCardApprovalDate!)
          : null;
      final pendingValidity = shadeCardDate != null
          ? DateTime.now().difference(shadeCardDate).inDays
          : 0;
      final purchaseOrderData = {
        'jobNrcJobNo': widget.job.nrcJobNo,
        'customer': widget.job.customerName,
        'poDate': _formatDate(poDate),
        'deliveryDate': _formatDate(DateTime.parse(_deliverDateController.text)),
        'dispatchDate': _formatDate(DateTime.parse(_dispatchDateController.text)),
        'nrcDeliveryDate': _formatDate(DateTime.parse(_nrcDeliveryDateController.text)),
        'totalPOQuantity': int.parse(_totalPoController.text),
        'unit': _unitController.text,
        'pendingValidity': pendingValidity,
        'noOfSheets': int.parse(_noOfSheetsController.text),
        'updatedAt': _formatDate(DateTime.now()),
      };
      try {
        final jobApi = JobApi(Dio());
        final response = await jobApi.createPurchaseOrder(purchaseOrderData);
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue, size: 32),
                    SizedBox(width: 8),
                    Text('PO Created', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text('Purchase Order has been created successfully!'),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            context.pop(true);
          }
        } else {
          throw Exception('Failed to create purchase order');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error:  ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}