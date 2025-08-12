import 'package:flutter/material.dart';

class DemandStepWidget extends StatefulWidget {
  final String? selectedDemand;
  final ValueChanged<String?> onDemandChanged;

  const DemandStepWidget({
    Key? key,
    required this.selectedDemand,
    required this.onDemandChanged,
  }) : super(key: key);

  @override
  State<DemandStepWidget> createState() => _DemandStepWidgetState();
}

class _DemandStepWidgetState extends State<DemandStepWidget>
    with TickerProviderStateMixin {
  late final Map<String, AnimationController> _animations;

  final List<String> _demands = ['Urgent', 'Regular'];

  @override
  void initState() {
    super.initState();
    _animations = {
      for (var demand in _demands)
        demand: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )
    };

    if (widget.selectedDemand != null) {
      _animations[widget.selectedDemand!]?.forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _animations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSelected(String? demand) {
    for (var controller in _animations.values) {
      controller.reverse();
    }

    if (demand != null) {
      _animations[demand]?.forward();
    }

    widget.onDemandChanged(demand);
  }

  IconData _getIcon(String demand) {
    switch (demand.toLowerCase()) {
      case 'urgent':
        return Icons.priority_high;
      case 'regular':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  Color _getColor(String demand) {
    switch (demand.toLowerCase()) {
      case 'urgent':
        return Colors.redAccent;
      case 'regular':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selectedDemand != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColor(widget.selectedDemand!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getColor(widget.selectedDemand!).withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getIcon(widget.selectedDemand!),
                  color: _getColor(widget.selectedDemand!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.selectedDemand} demand selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getColor(widget.selectedDemand!),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: _demands.map((demand) {
            final isSelected = widget.selectedDemand == demand;
            final color = _getColor(demand);

            return AnimatedBuilder(
              animation: _animations[demand]!,
              builder: (context, child) {
                final scale = 1 + (_animations[demand]!.value * 0.03);

                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: () => _onSelected(demand),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(50),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.1) : Colors.white,
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? color.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIcon(demand),
                            color: color,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            demand,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? color : Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
