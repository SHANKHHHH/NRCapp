class PurchaseOrder {
  final DateTime poDate;
  final DateTime deliveryDate;
  final DateTime dispatchDate;
  final DateTime nrcDeliveryDate;
  final int totalPOQuantity;
  final String unit;
  final int pendingValidity;
  final int noOfSheets;

  PurchaseOrder({
    required this.poDate,
    required this.deliveryDate,
    required this.dispatchDate,
    required this.nrcDeliveryDate,
    required this.totalPOQuantity,
    required this.unit,
    required this.pendingValidity,
    required this.noOfSheets,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poDate: DateTime.parse(json['poDate']),
      deliveryDate: DateTime.parse(json['deliveryDate']),
      dispatchDate: DateTime.parse(json['dispatchDate']),
      nrcDeliveryDate: DateTime.parse(json['nrcDeliveryDate']),
      totalPOQuantity: json['totalPOQuantity'],
      unit: json['unit'],
      pendingValidity: json['pendingValidity'],
      noOfSheets: json['noOfSheets'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poDate': poDate.toIso8601String(),
      'deliveryDate': deliveryDate.toIso8601String(),
      'dispatchDate': dispatchDate.toIso8601String(),
      'nrcDeliveryDate': nrcDeliveryDate.toIso8601String(),
      'totalPOQuantity': totalPOQuantity,
      'unit': unit,
      'pendingValidity': pendingValidity,
      'noOfSheets': noOfSheets,
    };
  }
}
