import '../../../data/models/Machine.dart';

class MachineData {
  static final List<Machine> machines = [
    // Printing Machines
    Machine(unit: 'NR1', machineCode: 'PR01', machineType: 'Printing', description: 'Heidelberg Printing Machine', type: 'Automatic', capacity: 27000, remarks: 'Up to 8 color with varnish'),
    Machine(unit: 'NR1', machineCode: 'PR02', machineType: 'Printing', description: 'Lithrone Printing Machine', type: 'Automatic', capacity: 9000, remarks: 'Up to 5 color with UV coating'),
    Machine(unit: 'NR1', machineCode: 'PR03', machineType: 'Printing', description: 'Mitsubishi Printing Machine', type: 'Automatic', capacity: 180000, remarks: 'Up to 6 color with varnish'),
    Machine(unit: 'MK', machineCode: 'PR01', machineType: 'Printing', description: 'Printing Machine 1', type: 'Automatic', capacity: 8000, remarks: '1 Color Printing'),
    Machine(unit: 'MK', machineCode: 'PR02', machineType: 'Printing', description: 'Printing Machine 2', type: 'Automatic', capacity: 8000, remarks: '2 Color Printing'),

    // Corrugation Machines
    Machine(unit: 'NR1', machineCode: 'CR01', machineType: 'Corrugation', description: 'Corrugation Machine 1', type: 'Automatic', capacity: 15000, remarks: 'Reel size up to 107"'),
    Machine(unit: 'NR1', machineCode: 'CR02', machineType: 'Corrugation', description: 'Corrugation Machine 2', type: 'Automatic', capacity: 15000, remarks: 'Reel size up to 117"'),
    Machine(unit: 'NR1', machineCode: 'CR03', machineType: 'Corrugation', description: 'Corrugation Machine 3', type: 'Automatic', capacity: 15000, remarks: 'Same as CR01 (107")'),
    Machine(unit: 'MK', machineCode: 'AP01', machineType: 'Corrugation', description: '5 Ply Auto Plant', type: 'Automatic', capacity: 10000, remarks: 'Main 5-ply corrugation line'),
    Machine(unit: 'MK', machineCode: 'CR01', machineType: 'Corrugation', description: 'Corrugation Machine', type: 'Automatic', capacity: 15000, remarks: 'A Flute and B Flute compatible'),
    Machine(unit: 'NR2', machineCode: 'CR01', machineType: 'Corrugation', description: 'Corrugation Machine', type: 'Automatic', capacity: 15000, remarks: 'Reel size up to 158"'),
    Machine(unit: 'DG', machineCode: 'CR01', machineType: 'Corrugation', description: 'Corrugation Machine', type: 'Automatic', capacity: 15000, remarks: ''),
    Machine(unit: 'DG', machineCode: 'CR02', machineType: 'Corrugation', description: 'Corrugation Machine', type: 'Automatic', capacity: 15000, remarks: ''),

    // Flute Lamination Machines
    Machine(unit: 'NR1', machineCode: 'FL01', machineType: 'Flute Lamination', description: 'Flute Laminator Machine 1', type: 'Automatic', capacity: 30000, remarks: 'Auto lamination'),
    Machine(unit: 'NR1', machineCode: 'FL02', machineType: 'Flute Lamination', description: 'Flute Laminator Machine 2', type: 'Automatic', capacity: 30000, remarks: ''),
    Machine(unit: 'NR2', machineCode: 'FL01', machineType: 'Flute Lamination', description: 'Flute Laminator Machine', type: 'Semi Auto', capacity: 22000, remarks: ''),
    Machine(unit: 'DG', machineCode: 'FL01', machineType: 'Flute Lamination', description: 'Flute Laminator Machine', type: 'Semi Auto', capacity: 22000, remarks: ''),

    // Punching Machines
    Machine(unit: 'NR1', machineCode: 'MP01', machineType: 'Punching', description: 'Manual Punching Machine 1', type: 'Manual', capacity: 7000, remarks: 'Die punching'),
    Machine(unit: 'NR1', machineCode: 'MP02', machineType: 'Punching', description: 'Manual Punching Machine 2', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'NR1', machineCode: 'MP03', machineType: 'Punching', description: 'Manual Punching Machine 3', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'NR1', machineCode: 'MP04', machineType: 'Punching', description: 'Manual Punching Machine 4', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'MK', machineCode: 'MP01', machineType: 'Punching', description: 'Punching Machine 1', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'MK', machineCode: 'MP02', machineType: 'Punching', description: 'Punching Machine 2', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'NR2', machineCode: 'MP01', machineType: 'Punching', description: 'Manual Punching Machine', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'DG', machineCode: 'MP01', machineType: 'Punching', description: 'Manual Punching Machine', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'DG', machineCode: 'MP02', machineType: 'Punching', description: 'Manual Punching Machine', type: 'Manual', capacity: 7000, remarks: ''),
    Machine(unit: 'NR1', machineCode: 'AP01', machineType: 'Punching', description: 'Auto Punching Machine 1', type: 'Automatic', capacity: 25000, remarks: 'High-speed die punching'),
    Machine(unit: 'NR1', machineCode: 'AP02', machineType: 'Punching', description: 'Auto Punching Machine 2', type: 'Automatic', capacity: 25000, remarks: ''),
    Machine(unit: 'NR2', machineCode: 'AP01', machineType: 'Punching', description: 'Auto Punching Machine', type: 'Automatic', capacity: 25000, remarks: ''),

    // Flap Pasting Machines
    Machine(unit: 'NR1', machineCode: 'MSP01', machineType: 'Flap Pasting', description: 'Side Flap Pasting Machine 1', type: 'Manual', capacity: 10000, remarks: 'Manual pasting'),
    Machine(unit: 'NR1', machineCode: 'MSP02', machineType: 'Flap Pasting', description: 'Side Flap Pasting Machine 2', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'MK', machineCode: 'MSP01', machineType: 'Flap Pasting', description: 'Side Flap Pasting Machine 1', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'MK', machineCode: 'MSP02', machineType: 'Flap Pasting', description: 'Side Flap Pasting Machine 2', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'NR', machineCode: 'MSP01', machineType: 'Flap Pasting', description: 'Manual Pasting Machine', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'NR', machineCode: 'MSP02', machineType: 'Flap Pasting', description: 'Manual Pasting Machine', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'NR1', machineCode: 'ASP01', machineType: 'Flap Pasting', description: 'Auto Side Flap Pasting Machine', type: 'Automatic', capacity: 30000, remarks: 'Auto side flap pasting'),
    Machine(unit: 'DG', machineCode: 'MSP01', machineType: 'Flap Pasting', description: 'Manual Pasting Machine', type: 'Manual', capacity: 10000, remarks: ''),
    Machine(unit: 'DG', machineCode: 'ASP02', machineType: 'Flap Pasting', description: 'Auto Side Flap Pasting Machine', type: 'Automatic', capacity: 30000, remarks: 'Auto side flap pasting'),
  ];

  static List<Machine> getFilteredMachines(String workStepType) {
    String machineType = '';
    switch (workStepType) {
      case 'printing':
        machineType = 'Printing';
        break;
      case 'corrugation':
        machineType = 'Corrugation';
        break;
      case 'fluteLamination':
        machineType = 'Flute Lamination';
        break;
      case 'punching':
        machineType = 'Punching';
        break;
      case 'flapPasting':
        machineType = 'Flap Pasting';
        break;
      default:
        return [];
    }

    return machines.where((machine) => machine.machineType == machineType).toList();
  }
}