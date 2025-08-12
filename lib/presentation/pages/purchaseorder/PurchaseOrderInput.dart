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
  late TextEditingController _poNumberController;
  late TextEditingController _deliverDateController;
  late TextEditingController _totalPoController;
  late TextEditingController _dispatchDateController;
  late TextEditingController _locationController;
  late TextEditingController _noOfSheetsController;

  // Calculated field
  int _pendingQuantity = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers first
    _purchaseOrderDateController = TextEditingController();
    _poNumberController = TextEditingController();
    _deliverDateController = TextEditingController();
    _totalPoController = TextEditingController();
    _dispatchDateController = TextEditingController();
    _locationController = TextEditingController();
    _noOfSheetsController = TextEditingController();

    // Then set their values if editing
    if (widget.existingPo != null) {
      _purchaseOrderDateController.text = widget.existingPo!.poDate.toIso8601String();
      _poNumberController.text = widget.existingPo!.poNumber ?? '';
      _deliverDateController.text = widget.existingPo!.deliveryDate.toIso8601String();
      _totalPoController.text = widget.existingPo!.totalPOQuantity.toString();
      _dispatchDateController.text = widget.existingPo!.dispatchDate.toIso8601String();
      _locationController.text = widget.existingPo!.unit;
      _noOfSheetsController.text = widget.existingPo!.noOfSheets.toString();
    }

    _totalPoController.addListener(_calculateNumberOfSheets);
    _calculateNumberOfSheets();
  }

  @override
  void dispose() {
    _purchaseOrderDateController.dispose();
    _poNumberController.dispose();
    _deliverDateController.dispose();
    _totalPoController.dispose();
    _dispatchDateController.dispose();
    _locationController.dispose();
    _noOfSheetsController.dispose();
    super.dispose();
  }

  // Extract first integer found in a string, or null
  int? _digitsToInt(String? source) {
    if (source == null) return null;
    final match = RegExp(r'\d+').firstMatch(source);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  int? _getNoUpsInt() {
    return _digitsToInt(widget.job.noUps);
  }

  int? _computeSheets(int? totalPoQty) {
    final noUps = _getNoUpsInt();
    if (totalPoQty == null || noUps == null || noUps <= 0) return null;
    return (totalPoQty / noUps).ceil();
  }

  // Calculate number of sheets based on Total PO Quantity / Number of Ups
  void _calculateNumberOfSheets() {
    final totalPoQty = int.tryParse(_totalPoController.text.trim());
    final calculatedSheets = _computeSheets(totalPoQty);
    if (calculatedSheets != null) {
      setState(() {
        _noOfSheetsController.text = calculatedSheets.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text(
              'Purchase Order',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: AppColors.maincolor,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => GoRouter.of(context).pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.maincolor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job Details Card
                _buildJobDetailsCard(),
                const SizedBox(height: 24),

                // Purchase Order Form
                _buildPurchaseOrderForm(),

                const SizedBox(height: 32),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Creating Purchase Order...',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
          validityColor = Colors.orange;
        } else {
          validityColor = Colors.red;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Job Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildJobDetailRow(Icons.tag, 'Job Number', job.nrcJobNo),
                _buildJobDetailRow(Icons.person_outline, 'Customer', job.customerName),
                _buildJobDetailRow(Icons.style, 'Style/SKU', job.styleItemSKU),
                _buildJobDetailRow(Icons.category_outlined, 'Flute Type', job.fluteType),
                _buildJobDetailRow(Icons.aspect_ratio, 'Board Size', job.boardSize ?? ''),
                _buildJobDetailRow(Icons.format_list_numbered_outlined, 'No. of Ups', job.noUps ?? ''),
                _buildJobDetailRow(Icons.attach_money, 'Latest Rate', job.latestRate?.toString() ?? ''),
                _buildJobDetailRow(Icons.money_off_outlined, 'Previous Rate', job.preRate?.toString() ?? ''),
                _buildJobDetailRow(Icons.straighten, 'Dimensions', (job.length != null && job.width != null && job.height != null) ? '${job.length} x ${job.width} x ${job.height}' : ''),
                _buildJobDetailRow(Icons.check_circle_outline, 'Artwork Received', _formatDateForDisplay(job.artworkReceivedDate ?? '')),
                _buildJobDetailRow(Icons.check_circle_outline, 'Artwork Approved', _formatDateForDisplay(job.artworkApprovalDate ?? '')),
                _buildJobDetailRow(Icons.palette_outlined, 'Shade Card Approved', _formatDateForDisplay(job.shadeCardApprovalDate ?? '')),
                _buildJobDetailRow(Icons.schedule, 'Created At', _formatDateForDisplay(job.createdAt ?? '')),
                _buildJobDetailRow(Icons.update, 'Updated At', _formatDateForDisplay(job.updatedAt ?? '')),
                if (job.purchaseOrder != null)
                  _buildJobDetailRow(Icons.assignment_outlined, 'Purchase Order', 'Available'),
                if (job.hasPoAdded)
                  _buildJobDetailRow(Icons.assignment_turned_in_outlined, 'PO Status', 'Added'),

                // Validity Status
                if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: validityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: validityColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: validityColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$pendingValidity days since Shade Card Approval',
                            style: TextStyle(
                              color: validityColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[50]!, Colors.orange[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_business,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Purchase Order Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Form Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PO Date (read-only)
                  _buildInfoRow(Icons.calendar_today_outlined, 'PO Date', _formatDateForDisplay(DateTime.now().toIso8601String())),
                  const SizedBox(height: 20),

                  // PO Number
                  _buildTextFormField(
                    controller: _poNumberController,
                    label: 'PO Number',
                    icon: Icons.numbers_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter PO number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Form Fields Grid
                  _buildDateFormField(
                    controller: _deliverDateController,
                    label: 'Delivery Date',
                    icon: Icons.local_shipping_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select delivery date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildDateFormField(
                    controller: _dispatchDateController,
                    label: 'Dispatch Date',
                    icon: Icons.schedule_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select dispatch date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildNumberFormField(
                          controller: _totalPoController,
                          label: 'Total PO Quantity',
                          icon: Icons.inventory_outlined,
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextFormField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.location_on_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter location';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildReadOnlyNumberField(
                    controller: _noOfSheetsController,
                    label: 'Number of Sheets (Calculated)',
                    icon: Icons.format_list_numbered_outlined,
                    hintText: 'Auto-calculated from Total PO Quantity / Number of Ups',
                  ),
                  const SizedBox(height: 20),

                  // Validity Status
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
                            validityColor = Colors.orange;
                          } else {
                            validityColor = Colors.red;
                          }
                        }
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: validityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: validityColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, color: validityColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$pendingValidity days since Shade Card Approval',
                                style: TextStyle(
                                  color: validityColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
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

  Widget _buildDateFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectDate(controller),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.text.isEmpty ? 'Select Date' : _formatDateForDisplay(controller.text),
                        style: TextStyle(
                          color: controller.text.isEmpty ? Colors.grey[500] : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today, color: Colors.grey[400], size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (validator != null && controller.text.isNotEmpty)
          Builder(
            builder: (context) {
              final validationResult = validator(controller.text);
              if (validationResult != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    validationResult,
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildNumberFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildReadOnlyNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: false,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[600]!, Colors.green[500]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _savePurchaseOrder,
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Purchase Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => GoRouter.of(context).pop(),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_outlined, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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

  String _formatDateForDisplay(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate; // Return original if parsing fails
    }
  }

  void _savePurchaseOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      // Ensure Number of Sheets is calculated and valid before submitting
      final totalPoQty = int.tryParse(_totalPoController.text.trim());
      final calculatedSheets = _computeSheets(totalPoQty);
      if (totalPoQty == null || calculatedSheets == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enter valid Total PO Quantity and ensure Job has a valid Number of Ups'),
            backgroundColor: Colors.red[600],
          ),
        );
        return;
      }
      _noOfSheetsController.text = calculatedSheets.toString();
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
        'poNumber': _poNumberController.text,
        'deliveryDate': _formatDate(DateTime.parse(_deliverDateController.text)),
        'dispatchDate': _formatDate(DateTime.parse(_dispatchDateController.text)),
        'unit': _locationController.text,
        'totalPOQuantity': totalPoQty,
        'pendingValidity': pendingValidity,
        'noOfSheets': calculatedSheets,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: EdgeInsets.zero,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.green[100]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Success!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Purchase Order has been created successfully!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}