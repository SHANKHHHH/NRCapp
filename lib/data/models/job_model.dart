class JobModel {
  final int id;
  final String styleItemSKU;
  final String customerName;

  JobModel({required this.id, required this.styleItemSKU, required this.customerName});

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'],
      styleItemSKU: json['styleItemSKU'],
      customerName: json['customerName'],
    );
  }
}
