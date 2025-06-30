class PurchaseOrder {
  final String purchaseOrderDate;
  final String deliverDate;
  final int totalPo;
  final int dispatchPo;
  final String dispatchDate;

  PurchaseOrder({
    required this.purchaseOrderDate,
    required this.deliverDate,
    required this.totalPo,
    required this.dispatchPo,
    required this.dispatchDate,
  });

  int get pending => totalPo - dispatchPo;
}
