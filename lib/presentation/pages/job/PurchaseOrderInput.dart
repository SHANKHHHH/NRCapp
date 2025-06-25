import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/colors.dart';
import '../../../data/models/purchase_order.dart';
import 'JobInputPage.dart';

class PurchaseOrderManagement extends StatefulWidget {
  @override
  _PurchaseOrderManagementState createState() => _PurchaseOrderManagementState();
}

class _PurchaseOrderManagementState extends State<PurchaseOrderManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<PurchaseOrder> _purchaseOrders = [];
  PurchaseOrder? _editingOrder;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'srNo': TextEditingController(),
    'poNumber': TextEditingController(),
    'poDate': TextEditingController(),
    'customer': TextEditingController(),
    'plant': TextEditingController(),
    'style': TextEditingController(),
    'dieCode': TextEditingController(),
    'boardSize': TextEditingController(),
    'fluteType': TextEditingController(),
    'noOfUps': TextEditingController(),
    'noOfSheets': TextEditingController(),
    'totalPOQuantity': TextEditingController(),
    'unit': TextEditingController(),
    'deliveryDate': TextEditingController(),
    'nrcDeliveryDate': TextEditingController(),
    'dispatchDate': TextEditingController(),
    'dispatchQuantity': TextEditingController(),
    'pendingQuantity': TextEditingController(),
    'pendingValidity': TextEditingController(),
    'jockeyMonth': TextEditingController(),
    'shadeCardApprovalDate': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase Order Management'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.add_box), text: 'Add Order'),
            Tab(icon: Icon(Icons.list), text: 'Orders (${_purchaseOrders.length})'),
            Tab(icon: Icon(Icons.work), text: 'Job Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormSection(),
          _buildOrdersListSection(),
          _buildJobDetailsSection(),
        ],
      ),
    );
  }

  // SECTION 1: FORM INPUT
  Widget _buildFormSection() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.maincolor.withOpacity(0.1), AppColors.maincolor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.maincolor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: AppColors.maincolor, size: 28),
                    SizedBox(width: 12),
                    Text(
                      _editingOrder != null ? 'Edit Purchase Order' : 'Create New Purchase Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.maincolor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _editingOrder != null
                      ? 'Update the purchase order details below'
                      : 'Fill in all the required information to create a purchase order',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Rejection notice (if editing a rejected order)
          if (_editingOrder?.status == ApprovalStatus.rejected)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Order Rejected',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reason: ${_editingOrder!.rejectionReason}',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                  ),
                  Text(
                    'Please update the details and resubmit.',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Form
          _buildForm(),

          SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitForm,
              icon: Icon(_editingOrder != null ? Icons.update : Icons.send),
              label: Text(
                _editingOrder != null ? 'Update Order' : 'Submit Order',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          if (_editingOrder != null) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: TextButton(
                onPressed: _cancelEdit,
                child: Text('Cancel Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Basic Information Section
          _buildSectionHeader('Basic Information', Icons.info_outline),
          _buildTextField('Sr #', 'srNo'),
          _buildTextField('PO Number', 'poNumber'),
          _buildTextField('PO Date', 'poDate'),
          _buildTextField('Customer', 'customer'),
          _buildTextField('Plant', 'plant'),

          SizedBox(height: 20),

          // Product Details Section
          _buildSectionHeader('Product Details', Icons.inventory),
          _buildTextField('Style', 'style'),
          _buildTextField('Die Code', 'dieCode'),
          _buildTextField('Board Size', 'boardSize'),
          _buildTextField('Flute Type', 'fluteType'),
          _buildTextField('No. of Ups', 'noOfUps'),
          _buildTextField('No. of Sheets', 'noOfSheets'),

          SizedBox(height: 20),

          // Quantity & Delivery Section
          _buildSectionHeader('Quantity & Delivery', Icons.local_shipping),
          _buildTextField('Total PO Quantity', 'totalPOQuantity'),
          _buildTextField('Unit', 'unit'),
          _buildTextField('Delivery Date', 'deliveryDate'),
          _buildTextField('NRC Delivery Date', 'nrcDeliveryDate'),
          _buildTextField('Dispatch Date', 'dispatchDate'),
          _buildTextField('Dispatch Quantity', 'dispatchQuantity'),
          _buildTextField('Pending Quantity', 'pendingQuantity'),
          _buildTextField('Pending Validity', 'pendingValidity'),

          SizedBox(height: 20),

          // Additional Information Section
          _buildSectionHeader('Additional Information', Icons.more_horiz),
          _buildTextField('Jockey Month', 'jockeyMonth'),
          _buildTextField('Shade Card Approval Date', 'shadeCardApprovalDate'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.maincolor, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controllers[key]!,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.maincolor, width: 2),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  // SECTION 2: ORDERS LIST
  Widget _buildOrdersListSection() {
    if (_purchaseOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Purchase Orders Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first purchase order using the form',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _purchaseOrders.length,
      itemBuilder: (context, index) {
        final order = _purchaseOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    Color statusColor = _getStatusColor(order.status);
    IconData statusIcon = _getStatusIcon(order.status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(order),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PO #${order.poNumber}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.maincolor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          order.customer,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Quick info
              Row(
                children: [
                  Expanded(
                    child: _buildQuickInfo('Quantity', order.totalPOQuantity),
                  ),
                  Expanded(
                    child: _buildQuickInfo('Delivery', order.deliveryDate),
                  ),
                  Expanded(
                    child: _buildQuickInfo('Plant', order.plant),
                  ),
                ],
              ),

              // Actions row
              if (order.status == ApprovalStatus.pending) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.orange.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Admin Actions Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveOrder(order),
                              icon: Icon(Icons.check, size: 18),
                              label: Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: Size(0, 36),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _rejectOrder(order),
                              icon: Icon(Icons.close, size: 18),
                              label: Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                minimumSize: Size(0, 36),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (order.status == ApprovalStatus.rejected) ...[
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _editOrder(order),
                    icon: Icon(Icons.edit),
                    label: Text('Edit & Resubmit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],

              if (order.status == ApprovalStatus.accepted && !order.hasJobDetails) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addJobDetails(order),
                    icon: Icon(Icons.work),
                    label: Text('Add Job Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _editOrder(order),
                    icon: Icon(Icons.edit),
                    label: Text('Edit Purchase Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value.isEmpty ? 'N/A' : value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // SECTION 3: JOB DETAILS
  Widget _buildJobDetailsSection() {
    final approvedOrders = _purchaseOrders
        .where((order) => order.status == ApprovalStatus.accepted)
        .toList();

    if (approvedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Approved Orders',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Approved purchase orders will appear here for job details entry',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: approvedOrders.length,
      itemBuilder: (context, index) {
        final order = approvedOrders[index];
        return GestureDetector(
          onTap: () => _showJobDetails(order),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PO #${order.poNumber}'),
                  Text('Job No: ${order.jobDetails?.nrcJobNo ?? 'N/A'}'),
                  // Add an Edit button
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _editJobDetails(order),
                    child: Text('Edit Job Details'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJobDetails(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Details for PO #${order.poNumber}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                // Display Purchase Order Details
                Text('Purchase Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('PO Number: ${order.poNumber}'),
                Text('Customer: ${order.customer}'),
                Text('Plant: ${order.plant}'),
                Text('Total PO Quantity: ${order.totalPOQuantity}'),
                Text('Delivery Date: ${order.deliveryDate}'),
                Text('NRC Delivery Date: ${order.nrcDeliveryDate}'),
                Text('Dispatch Date: ${order.dispatchDate}'),
                Text('Pending Quantity: ${order.pendingQuantity}'),
                Text('Pending Validity: ${order.pendingValidity}'),
                Text('Jockey Month: ${order.jockeyMonth}'),
                Text('Shade Card Approval Date: ${order.shadeCardApprovalDate}'),
                SizedBox(height: 20),
                // Display Job Details
                Text('Job Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('NRC Job No: ${order.jobDetails?.nrcJobNo ?? 'N/A'}'),
                Text('Style Item SKU: ${order.jobDetails?.styleItemSKU ?? 'N/A'}'),
                Text('Flute Type: ${order.jobDetails?.fluteType ?? 'N/A'}'),
                Text('Job Status: ${order.jobDetails?.jobStatus ?? 'N/A'}'),
                Text('Latest Rate: ${order.jobDetails?.latestRate ?? 'N/A'}'),
                Text('Pre Rate: ${order.jobDetails?.preRate ?? 'N/A'}'),
                Text('Length: ${order.jobDetails?.length ?? 'N/A'}'),
                Text('Width: ${order.jobDetails?.width ?? 'N/A'}'),
                Text('Height: ${order.jobDetails?.height ?? 'N/A'}'),
                Text('Box Dimensions: ${order.jobDetails?.boxDimensions ?? 'N/A'}'),
                Text('Die Punch Code: ${order.jobDetails?.diePunchCode ?? 'N/A'}'),
                Text('Board Category: ${order.jobDetails?.boardCategory ?? 'N/A'}'),
                Text('No. of Color: ${order.jobDetails?.noOfColor ?? 'N/A'}'),
                Text('Process Colors: ${order.jobDetails?.processColors ?? 'N/A'}'),
                Text('Special Color 1: ${order.jobDetails?.specialColor1 ?? 'N/A'}'),
                Text('Special Color 2: ${order.jobDetails?.specialColor2 ?? 'N/A'}'),
                Text('Special Color 3: ${order.jobDetails?.specialColor3 ?? 'N/A'}'),
                Text('Special Color 4: ${order.jobDetails?.specialColor4 ?? 'N/A'}'),
                Text('Over Print Finishing: ${order.jobDetails?.overPrintFinishing ?? 'N/A'}'),
                Text('Top Face GSM: ${order.jobDetails?.topFaceGSM ?? 'N/A'}'),
                Text('Fluting GSM: ${order.jobDetails?.flutingGSM ?? 'N/A'}'),
                Text('Bottom Liner GSM: ${order.jobDetails?.bottomLinerGSM ?? 'N/A'}'),
                Text('Decal Board X: ${order.jobDetails?.decalBoardX ?? 'N/A'}'),
                Text('Length Board Y: ${order.jobDetails?.lengthBoardY ?? 'N/A'}'),
                Text('Board Size: ${order.jobDetails?.boardSize ?? 'N/A'}'),
                Text('No UPS: ${order.jobDetails?.noUps ?? 'N/A'}'),
                Text('SR No: ${order.jobDetails?.srNo ?? 'N/A'}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (order.hasJobDetails) ...[
              TextButton(
                child: Text('Edit Purchase Order'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _editOrder(order);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  // HELPER METHODS
  Color _getStatusColor(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return Colors.orange;
      case ApprovalStatus.accepted:
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return Icons.hourglass_empty;
      case ApprovalStatus.accepted:
        return Icons.check_circle;
      case ApprovalStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getStatusText(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.accepted:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_editingOrder != null) {
        // Update existing order
        setState(() {
          _editingOrder!.srNo = _controllers['srNo']!.text;
          _editingOrder!.poNumber = _controllers['poNumber']!.text;
          _editingOrder!.poDate = _controllers['poDate']!.text;
          _editingOrder!.customer = _controllers['customer']!.text;
          _editingOrder!.plant = _controllers['plant']!.text;
          _editingOrder!.style = _controllers['style']!.text;
          _editingOrder!.dieCode = _controllers['dieCode']!.text;
          _editingOrder!.boardSize = _controllers['boardSize']!.text;
          _editingOrder!.fluteType = _controllers['fluteType']!.text;
          _editingOrder!.noOfUps = _controllers['noOfUps']!.text;
          _editingOrder!.noOfSheets = _controllers['noOfSheets']!.text;
          _editingOrder!.totalPOQuantity = _controllers['totalPOQuantity']!.text;
          _editingOrder!.unit = _controllers['unit']!.text;
          _editingOrder!.deliveryDate = _controllers['deliveryDate']!.text;
          _editingOrder!.nrcDeliveryDate = _controllers['nrcDeliveryDate']!.text;
          _editingOrder!.dispatchDate = _controllers['dispatchDate']!.text;
          _editingOrder!.dispatchQuantity = _controllers['dispatchQuantity']!.text;
          _editingOrder!.pendingQuantity = _controllers['pendingQuantity']!.text;
          _editingOrder!.pendingValidity = _controllers['pendingValidity']!.text;
          _editingOrder!.jockeyMonth = _controllers['jockeyMonth']!.text;
          _editingOrder!.shadeCardApprovalDate = _controllers['shadeCardApprovalDate']!.text;
          _editingOrder!.status = ApprovalStatus.pending;
          _editingOrder!.rejectionReason = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase Order updated and resubmitted!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new order
        final newOrder = PurchaseOrder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          srNo: _controllers['srNo']!.text,
          poNumber: _controllers['poNumber']!.text,
          poDate: _controllers['poDate']!.text,
          customer: _controllers['customer']!.text,
          plant: _controllers['plant']!.text,
          style: _controllers['style']!.text,
          dieCode: _controllers['dieCode']!.text,
          boardSize: _controllers['boardSize']!.text,
          fluteType: _controllers['fluteType']!.text,
          noOfUps: _controllers['noOfUps']!.text,
          noOfSheets: _controllers['noOfSheets']!.text,
          totalPOQuantity: _controllers['totalPOQuantity']!.text,
          unit: _controllers['unit']!.text,
          deliveryDate: _controllers['deliveryDate']!.text,
          nrcDeliveryDate: _controllers['nrcDeliveryDate']!.text,
          dispatchDate: _controllers['dispatchDate']!.text,
          dispatchQuantity: _controllers['dispatchQuantity']!.text,
          pendingQuantity: _controllers['pendingQuantity']!.text,
          pendingValidity: _controllers['pendingValidity']!.text,
          jockeyMonth: _controllers['jockeyMonth']!.text,
          shadeCardApprovalDate: _controllers['shadeCardApprovalDate']!.text,
        );

        setState(() {
          _purchaseOrders.add(newOrder);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase Order submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _clearForm();
      _tabController.animateTo(1); // Switch to orders tab
    }
  }

  void _clearForm() {
    _controllers.values.forEach((controller) => controller.clear());
    setState(() {
      _editingOrder = null;
    });
  }

  void _cancelEdit() {
    _clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit cancelled')),
    );
  }

  void _editOrder(PurchaseOrder order) {
    setState(() {
      _editingOrder = order;
      _controllers['srNo']!.text = order.srNo;
      _controllers['poNumber']!.text = order.poNumber;
      _controllers['poDate']!.text = order.poDate;
      _controllers['customer']!.text = order.customer;
      _controllers['plant']!.text = order.plant;
      _controllers['style']!.text = order.style;
      _controllers['dieCode']!.text = order.dieCode;
      _controllers['boardSize']!.text = order.boardSize;
      _controllers['fluteType']!.text = order.fluteType;
      _controllers['noOfUps']!.text = order.noOfUps;
      _controllers['noOfSheets']!.text = order.noOfSheets;
      _controllers['totalPOQuantity']!.text = order.totalPOQuantity;
      _controllers['unit']!.text = order.unit;
      _controllers['deliveryDate']!.text = order.deliveryDate;
      _controllers['nrcDeliveryDate']!.text = order.nrcDeliveryDate;
      _controllers['dispatchDate']!.text = order.dispatchDate;
      _controllers['dispatchQuantity']!.text = order.dispatchQuantity;
      _controllers['pendingQuantity']!.text = order.pendingQuantity;
      _controllers['pendingValidity']!.text = order.pendingValidity;
      _controllers['jockeyMonth']!.text = order.jockeyMonth;
      _controllers['shadeCardApprovalDate']!.text = order.shadeCardApprovalDate;
    });
    _tabController.animateTo(0); // Switch to form tab
  }

  void _approveOrder(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Approve Order'),
            ],
          ),
          content: Text('Are you sure you want to approve PO #${order.poNumber}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  order.status = ApprovalStatus.accepted;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Purchase Order approved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _rejectOrder(PurchaseOrder order) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Reject Order'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for rejecting PO #${order.poNumber}:'),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  order.status = ApprovalStatus.rejected;
                  order.rejectionReason = reasonController.text.isNotEmpty
                      ? reasonController.text
                      : 'No specific reason provided';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Purchase Order rejected'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDetails(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.maincolor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Order Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'PO #${order.poNumber}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(order.status).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(order.status), color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              _getStatusText(order.status),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildDetailSection('Basic Information', [
                          _buildDetailItem('Sr #', order.srNo),
                          _buildDetailItem('PO Number', order.poNumber),
                          _buildDetailItem('PO Date', order.poDate),
                          _buildDetailItem('Customer', order.customer),
                          _buildDetailItem('Plant', order.plant),
                        ]),

                        SizedBox(height: 20),

                        _buildDetailSection('Product Details', [
                          _buildDetailItem('Style', order.style),
                          _buildDetailItem('Die Code', order.dieCode),
                          _buildDetailItem('Board Size', order.boardSize),
                          _buildDetailItem('Flute Type', order.fluteType),
                          _buildDetailItem('No. of Ups', order.noOfUps),
                          _buildDetailItem('No. of Sheets', order.noOfSheets),
                        ]),

                        SizedBox(height: 20),

                        _buildDetailSection('Quantity & Delivery', [
                          _buildDetailItem('Total PO Quantity', order.totalPOQuantity),
                          _buildDetailItem('Unit', order.unit),
                          _buildDetailItem('Delivery Date', order.deliveryDate),
                          _buildDetailItem('NRC Delivery Date', order.nrcDeliveryDate),
                          _buildDetailItem('Dispatch Date', order.dispatchDate),
                          _buildDetailItem('Dispatch Quantity', order.dispatchQuantity),
                          _buildDetailItem('Pending Quantity', order.pendingQuantity),
                          _buildDetailItem('Pending Validity', order.pendingValidity),
                        ]),

                        SizedBox(height: 20),

                        _buildDetailSection('Additional Information', [
                          _buildDetailItem('Jockey Month', order.jockeyMonth),
                          _buildDetailItem('Shade Card Approval Date', order.shadeCardApprovalDate),
                        ]),

                        if (order.status == ApprovalStatus.rejected) ...[
                          SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.red.shade600),
                                    SizedBox(width: 8),
                                    Text(
                                      'Rejection Reason',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  order.rejectionReason,
                                  style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Close'),
                        ),
                      ),
                      if (order.status == ApprovalStatus.rejected) ...[
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _editOrder(order);
                            },
                            icon: Icon(Icons.edit),
                            label: Text('Edit Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (order.status == ApprovalStatus.accepted && !order.hasJobDetails) ...[
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addJobDetails(order),
                            icon: Icon(Icons.work),
                            label: Text('Add Job Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '(Not provided)' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.red.shade400 : Colors.black87,
                fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addJobDetails(PurchaseOrder order) {
    context.push('/job-input', extra: order);
  }

  void _editJobDetails(PurchaseOrder order) {
    context.push('/job-input', extra: order);
  }
}