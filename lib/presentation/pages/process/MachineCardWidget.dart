import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class MachineCardWidget extends StatelessWidget {
  final Map<String, dynamic> machineInfo;
  final VoidCallback? onStartWork;
  final bool isAvailable;

  const MachineCardWidget({
    Key? key,
    required this.machineInfo,
    this.onStartWork,
    this.isAvailable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final machineCode = machineInfo['machineCode'] ?? 'Unknown';
    final machineType = machineInfo['machineType'] ?? 'Unknown';
    final unit = machineInfo['unit'] ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isAvailable ? AppColors.maincolor.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAvailable ? AppColors.maincolor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            _getMachineIcon(machineType),
            color: isAvailable ? AppColors.maincolor : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          machineCode,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isAvailable ? Colors.black87 : Colors.grey[600],
          ),
        ),
        subtitle: Text(
          '$machineType${unit.isNotEmpty ? ' ($unit)' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: isAvailable ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: isAvailable
            ? ElevatedButton(
                onPressed: onStartWork,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Start Work',
                  style: TextStyle(fontSize: 12),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Busy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
      ),
    );
  }

  IconData _getMachineIcon(String machineType) {
    switch (machineType.toLowerCase()) {
      case 'printing':
        return Icons.print;
      case 'corrugatic':
      case 'corrugation':
        return Icons.layers;
      case 'flute lam':
      case 'flute lamination':
        return Icons.layers_outlined;
      case 'auto pund':
      case 'punching':
        return Icons.cut;
      case 'auto flap':
      case 'flap pasting':
        return Icons.flip;
      case 'quality':
      case 'qc':
        return Icons.verified;
      case 'dispatch':
        return Icons.local_shipping;
      case 'paper store':
      case 'paperstore':
        return Icons.inventory;
      default:
        return Icons.settings;
    }
  }
}
