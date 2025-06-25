// lib/presentation/pages/job/job_input_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/colors.dart';
import '../../../data/models/job_details.dart';
import '../../../data/models/purchase_order.dart';

class JobInputPage extends StatefulWidget {
  final PurchaseOrder order;

  JobInputPage({required this.order});

  @override
  _JobInputPageState createState() => _JobInputPageState();
}

class _JobInputPageState extends State<JobInputPage> {
  final _formKey = GlobalKey<FormState>();

  final _nrcJobNoController = TextEditingController();
  final _styleItemSKUController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _fluteTypeController = TextEditingController();
  final _jobStatusController = TextEditingController();
  final _latestRateController = TextEditingController();
  final _preRateController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _boxDimensionsController = TextEditingController();
  final _diePunchCodeController = TextEditingController();
  final _boardCategoryController = TextEditingController();
  final _noOfColorController = TextEditingController();
  final _processColorsController = TextEditingController();
  final _specialColor1Controller = TextEditingController();
  final _specialColor2Controller = TextEditingController();
  final _specialColor3Controller = TextEditingController();
  final _specialColor4Controller = TextEditingController();
  final _overPrintFinishingController = TextEditingController();
  final _topFaceGSMController = TextEditingController();
  final _flutingGSMController = TextEditingController();
  final _bottomLinerGSMController = TextEditingController();
  final _decalBoardXController = TextEditingController();
  final _lengthBoardYController = TextEditingController();
  final _boardSizeController = TextEditingController();
  final _noUpsController = TextEditingController();
  final _srNoController = TextEditingController();

  DateTime? _artworkReceivedDate;
  DateTime? _artworkApprovedDate;
  DateTime? _shadeCardApprovalDate;

  final Map<String, List<String>> dropdownOptions = {
    'Flute Type': ['Blank','2PLY','3PLY','4PLY','5PLY','6PLY','7PLY','8PLY'],

    'Job Status': ['Active','Inactive','Hold'],

    'Board Category': [  'Blank',
      'Art board',
      'Blue board',
      'Cartelumina',
      'Cyber board',
      'Cyber Xl',
      'CYBER XL GREY BACK ITC FOOD GRADE',
      'Grey back',
      'Kraft',
      'SBB',
      'SBS BOARD',
      'WHITE BACK',
      'White board',
      'Yellow board',],

    'No. of Color': [ 'Blank',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '44UNPRINTED',
      'CMYK',],

    'Process Colors': [  ' ',
      '-',
      'CMYK',
      'Coolgrey 10 C',
      'K',
      'MK',
      'P 287 C',
      'P 485 C',
      'P Process Blue C',
      'Process Blue C',
      'Spl K',],

    'Over Print Finishing': [
      ' ',
      '-',
      '350gsm W/B, Dripoff UV, Emoss, Window Pasting',
      '5mm Hole, Foil, Emboss, Gloss UV, Dripoff',
      '5mm Hole, Foil, Emboss, Matt Varnish, UV Dripoff',
      '5mm Hole, Gloss UV, Dripoff for Background',
      'AQ',
      'Aqua Varnish',
      'Aquas Varnish',
      'BOPP LAMINATION',
      'Dripoff UV',
      'Dripoff UV + Open Window',
      'Dripoff UV, Emboss, Open Window',
      'Dripoff UV, Emboss, Window',
      'Dripoff UV, Emboss, Window Pasting',
      'Dripoff UV, Open Window',
      'Dripoff, Spot UV, Emboss',
      'Gloss Aqua Varnish',
      'Gloss Lamination',
      'Gloss Lamination with Window',
      'GLOSS VARNISH',
      'GLOSSY LAMINATION',
      'Lamination + Window',
      'Lamination, Die,  side pasting, open window',
      'Matt Lamination',
      'Matt lamination with sceen printing',
      'Matt Varnish',
      'Matt Varnish + Emboss',
      'Matt Varnish / Matt Lamination',
      'Matt Varnish, Emboss',
      'PET Lamination 12 Mic Transparent Film, \'E\' flute, min 1.5 mm, 1.27 Take up factor,High Precisison Die cut and Punching and Starch based adhesive with minimum 20% solid content',
      'Silver Foiling',
      'SPOT UV',
      'SPOT UV, Drip off',
      'Spot UV, Open Window',
      'TOP - BOPP LAMINATION & DRIPOFF - -',
      'Top lamination',
      'Varnish',
      'WITH LAMINATION',
      'with window',
    ],

    'Top Face GSM': [
      ' ',
      '120',
      '150',
      '170',
      '180',
      '200',
      '230',
      '240',
      '240.00',
      '250',
      '270',
      '300',
      '320',
      '350',
      '400',
      'TOP-285 BOTTOM-300 INDOBAR-240',
      'TOP-285 BOTTOM-320 INDOBAR-240',
      'TOP-300 BOTTOM-350 INDOBAR-240',
    ],
    'No UPS': [
      ' ',
      '0.5',
      '1',
      '2',
      '3',
      '4',
      '6',
      '8',
      '9',
      '10',
      '12',
      '13',
      '15',
      '16',
      '20',
      '24',
      '25',
      '27',
      '30',
      '36',
      '42',
      '48',
      '49',
      '55',
      '60',
      '63',
      '80',
      '90',
      '96',
      'HALF',
      'Half & Half',
    ],
  };

  @override
  void initState() {
    super.initState();
    // Populate fields with existing purchase order details if available
    if (widget.order != null) {
      _nrcJobNoController.text = widget.order.jobDetails?.nrcJobNo ?? '';
      _styleItemSKUController.text = widget.order.jobDetails?.styleItemSKU ?? '';
      _customerNameController.text = widget.order.jobDetails?.customerName ?? '';
      _fluteTypeController.text = widget.order.jobDetails?.fluteType ?? '';
      _jobStatusController.text = widget.order.jobDetails?.jobStatus ?? '';
      _latestRateController.text = widget.order.jobDetails?.latestRate ?? '';
      _preRateController.text = widget.order.jobDetails?.preRate ?? '';
      _lengthController.text = widget.order.jobDetails?.length ?? '';
      _widthController.text = widget.order.jobDetails?.width ?? '';
      _heightController.text = widget.order.jobDetails?.height ?? '';
      _boxDimensionsController.text = widget.order.jobDetails?.boxDimensions ?? '';
      _diePunchCodeController.text = widget.order.jobDetails?.diePunchCode ?? '';
      _boardCategoryController.text = widget.order.jobDetails?.boardCategory ?? '';
      _noOfColorController.text = widget.order.jobDetails?.noOfColor ?? '';
      _processColorsController.text = widget.order.jobDetails?.processColors ?? '';
      _specialColor1Controller.text = widget.order.jobDetails?.specialColor1 ?? '';
      _specialColor2Controller.text = widget.order.jobDetails?.specialColor2 ?? '';
      _specialColor3Controller.text = widget.order.jobDetails?.specialColor3 ?? '';
      _specialColor4Controller.text = widget.order.jobDetails?.specialColor4 ?? '';
      _overPrintFinishingController.text = widget.order.jobDetails?.overPrintFinishing ?? '';
      _topFaceGSMController.text = widget.order.jobDetails?.topFaceGSM ?? '';
      _flutingGSMController.text = widget.order.jobDetails?.flutingGSM ?? '';
      _bottomLinerGSMController.text = widget.order.jobDetails?.bottomLinerGSM ?? '';
      _decalBoardXController.text = widget.order.jobDetails?.decalBoardX ?? '';
      _lengthBoardYController.text = widget.order.jobDetails?.lengthBoardY ?? '';
      _boardSizeController.text = widget.order.jobDetails?.boardSize ?? '';
      _noUpsController.text = widget.order.jobDetails?.noUps ?? '';
      _srNoController.text = widget.order.jobDetails?.srNo ?? '';
    }
  }

  @override
  void dispose() {
    _nrcJobNoController.dispose();
    _styleItemSKUController.dispose();
    _customerNameController.dispose();
    _fluteTypeController.dispose();
    _jobStatusController.dispose();
    _latestRateController.dispose();
    _preRateController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _boxDimensionsController.dispose();
    _diePunchCodeController.dispose();
    _boardCategoryController.dispose();
    _noOfColorController.dispose();
    _processColorsController.dispose();
    _specialColor1Controller.dispose();
    _specialColor2Controller.dispose();
    _specialColor3Controller.dispose();
    _specialColor4Controller.dispose();
    _overPrintFinishingController.dispose();
    _topFaceGSMController.dispose();
    _flutingGSMController.dispose();
    _bottomLinerGSMController.dispose();
    _decalBoardXController.dispose();
    _lengthBoardYController.dispose();
    _boardSizeController.dispose();
    _noUpsController.dispose();
    _srNoController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Create JobDetails instance
      JobDetails jobDetails = JobDetails(
        nrcJobNo: _nrcJobNoController.text,
        styleItemSKU: _styleItemSKUController.text,
        customerName: _customerNameController.text,
        fluteType: _fluteTypeController.text,
        jobStatus: _jobStatusController.text,
        latestRate: _latestRateController.text,
        preRate: _preRateController.text,
        length: _lengthController.text,
        width: _widthController.text,
        height: _heightController.text,
        boxDimensions: _boxDimensionsController.text,
        diePunchCode: _diePunchCodeController.text,
        boardCategory: _boardCategoryController.text,
        noOfColor: _noOfColorController.text,
        processColors: _processColorsController.text,
        specialColor1: _specialColor1Controller.text,
        specialColor2: _specialColor2Controller.text,
        specialColor3: _specialColor3Controller.text,
        specialColor4: _specialColor4Controller.text,
        overPrintFinishing: _overPrintFinishingController.text,
        topFaceGSM: _topFaceGSMController.text,
        flutingGSM: _flutingGSMController.text,
        bottomLinerGSM: _bottomLinerGSMController.text,
        decalBoardX: _decalBoardXController.text,
        lengthBoardY: _lengthBoardYController.text,
        boardSize: _boardSizeController.text,
        noUps: _noUpsController.text,
        srNo: _srNoController.text,
      );

      // Assign job details to the PurchaseOrder
      widget.order.jobDetails = jobDetails;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job data submitted successfully!'),
          backgroundColor: AppColors.green,
        ),
      );

      // Optionally, navigate back or update the UI
      Navigator.pop(context);
    }
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.grey[600]),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.maincolor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false, Function(String)? onChanged}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: _getInputDecoration(label),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String label, TextEditingController controller) {
    final options = dropdownOptions[label] ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: _getInputDecoration(label),
        isExpanded: true, // Prevents overflow
        dropdownColor: AppColors.white, // Dropdown menu background color
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        icon: Icon(
          Icons.arrow_drop_down,
          color: AppColors.maincolor,
        ),
        items: options.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Container(
              width: double.infinity,
              child: Text(
                val,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
        onChanged: (val) => setState(() => controller.text = val!),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
        menuMaxHeight: 300, // Limit dropdown height
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, void Function(DateTime?) onPick) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => onPick(picked));
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Select a date',
                      style: TextStyle(
                        color: date != null ? Colors.black87 : AppColors.grey[500],
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today, color: AppColors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.grey[800],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Desktop/Tablet: Show in row
          return Row(
            children: children.map((child) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: children.last == child ? 0 : 12),
                  child: child,
                ),
              );
            }).toList(),
          );
        } else {
          // Mobile: Show in column
          return Column(
            children: children,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update calculated fields safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final length = _lengthController.text;
      final width = _widthController.text;
      final height = _heightController.text;
      final newBoxDimensions = '$length x $width x $height';

      if (_boxDimensionsController.text != newBoxDimensions) {
        _boxDimensionsController.text = newBoxDimensions;
      }

      final decalX = _decalBoardXController.text;
      final lengthY = _lengthBoardYController.text;
      final newBoardSize = '$decalX x $lengthY';

      if (_boardSizeController.text != newBoardSize) {
        _boardSizeController.text = newBoardSize;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPinkWhite,
      appBar: AppBar(
        title: Text(
          'Job Input',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Section
                _buildSectionHeader('Basic Information'),
                _buildTextField('NRC Job No', _nrcJobNoController),
                _buildTextField('Style Item SKU', _styleItemSKUController),
                _buildTextField('Customer Name', _customerNameController),
                _buildDropdown('Flute Type', _fluteTypeController),
                _buildDropdown('Job Status', _jobStatusController),

                // Pricing Section
                _buildSectionHeader('Pricing Information'),
                _buildResponsiveRow([
                  _buildTextField('Latest Rate', _latestRateController),
                  _buildTextField('Pre Rate', _preRateController),
                ]),

                // Dimensions Section
                _buildSectionHeader('Dimensions'),
                _buildResponsiveRow([
                  _buildTextField('Length', _lengthController, onChanged: (_) => setState(() {})),
                  _buildTextField('Width', _widthController, onChanged: (_) => setState(() {})),
                  _buildTextField('Height', _heightController, onChanged: (_) => setState(() {})),
                ]),
                _buildTextField('Box Dimensions', _boxDimensionsController, readOnly: true),
                _buildTextField('Die Punch Code', _diePunchCodeController),

                // Materials & Colors Section
                _buildSectionHeader('Materials & Colors'),
                _buildDropdown('Board Category', _boardCategoryController),
                _buildDropdown('No. of Color', _noOfColorController),
                _buildDropdown('Process Colors', _processColorsController),

                _buildResponsiveRow([
                  _buildTextField('Special Color 1', _specialColor1Controller),
                  _buildTextField('Special Color 2', _specialColor2Controller),
                ]),
                _buildResponsiveRow([
                  _buildTextField('Special Color 3', _specialColor3Controller),
                  _buildTextField('Special Color 4', _specialColor4Controller),
                ]),

                // Finishing & Specifications Section
                _buildSectionHeader('Finishing & Specifications'),
                _buildDropdown('Over Print Finishing', _overPrintFinishingController),
                _buildDropdown('Top Face GSM', _topFaceGSMController),
                _buildResponsiveRow([
                  _buildTextField('Fluting GSM', _flutingGSMController),
                  _buildTextField('Bottom Liner GSM', _bottomLinerGSMController),
                ]),

                // Board Details Section
                _buildSectionHeader('Board Details'),
                _buildResponsiveRow([
                  _buildTextField('Decal Board X', _decalBoardXController, onChanged: (_) => setState(() {})),
                  _buildTextField('Length Board Y', _lengthBoardYController, onChanged: (_) => setState(() {})),
                ]),
                _buildTextField('Board Size', _boardSizeController, readOnly: true),
                _buildDropdown('No UPS', _noUpsController),

                // Dates Section
                _buildSectionHeader('Important Dates'),
                _buildDateField('Artwork Received Date', _artworkReceivedDate, (val) => _artworkReceivedDate = val),
                _buildDateField('Artwork Approved Date', _artworkApprovedDate, (val) => _artworkApprovedDate = val),
                _buildDateField('Shade Card Approval Date', _shadeCardApprovalDate, (val) => _shadeCardApprovalDate = val),

                // Additional Information
                _buildSectionHeader('Additional Information'),
                _buildTextField('Sr#', _srNoController),

                SizedBox(height: 32),

                // Submit Button
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maincolor,
                      foregroundColor: AppColors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Submit Job Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}