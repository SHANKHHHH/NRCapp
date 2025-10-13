# Step Completion Quantity Validation System 🚧

## Problem Statement

**Current Behavior (❌ WRONG):**

```
Paper Store: 10,000 available

Printing - Machine 1:
  - Processes: 3,000 (2,800 OK + 200 wastage)
  - Status: Completed ✅

❌ ENTIRE STEP shows as "Completed"
❌ Remaining 7,000 units ignored
❌ Cannot process remaining quantity on other machines
```

**Expected Behavior (✅ CORRECT):**

```
Paper Store: 10,000 available

Printing - Machine 1:
  - Processes: 3,000 (2,800 OK + 200 wastage)
  - Machine status: Completed ✅

✅ STEP shows as "In Progress" (3,000/10,000 processed)
✅ Remaining 7,000 units available
✅ Can select Machine 2 to process remaining quantity

Printing - Machine 2:
  - Processes: 7,000 (6,700 OK + 300 wastage)
  - Machine status: Completed ✅

✅ STEP shows as "Completed" (10,000/10,000 processed)
✅ All available quantity has been processed
```

---

## Solution Design

### **Key Principle:**

> A step should only be marked as "Completed" when:
>
> 1. **All available quantity** from the previous step has been processed, OR
> 2. **No more machines** are available to process the remaining quantity

### **Implementation Strategy:**

1. **After machine work completion:**

   - Sum all processed quantities (OK + wastage) across all machines for this step
   - Compare total processed vs. available quantity from previous step
   - If `totalProcessed < availableQuantity`:
     - Mark step as **"In Progress"** (not "Completed")
     - Allow other machines to process remaining quantity
   - If `totalProcessed >= availableQuantity`:
     - Mark step as **"Completed"**
     - Move to next step

2. **Display processed quantity:**
   - Show progress: "Printing: 3,000/10,000 processed"
   - Show remaining: "7,000 units remaining"
   - Visual progress bar

---

## Implementation Plan

### **File 1: `lib/presentation/pages/process/JobApiService.dart`**

#### **New Function:**

```dart
/// Check if step should be marked as completed based on quantity processed
Future<bool> shouldStepBeCompleted(String jobNumber, StepType stepType) async {
  try {
    // 1. Get available quantity from previous step
    final availableQty = await getPreviousStepAvailableQuantity(jobNumber, stepType);
    if (availableQty == null || availableQty == 0) {
      print('⚠️ No available quantity found for ${stepType.name}, allowing completion');
      return true; // If no quantity tracking, allow normal completion
    }

    // 2. Get all machine records for this step
    final stepDetails = await getStepDetailsWithEditability(jobNumber, stepType);
    if (stepDetails.isEmpty) {
      print('⚠️ No step details found for ${stepType.name}');
      return false;
    }

    // 3. Sum all processed quantities (OK + wastage) across all machines
    int totalProcessed = 0;
    for (var detail in stepDetails) {
      final data = detail.data;

      // Get OK quantity
      final okQty = int.tryParse((data['quantityOK'] ??
                                  data['quantity'] ??
                                  data['Qty Sheet'] ??
                                  data['OK Qty'] ??
                                  0).toString()) ?? 0;

      // Get wastage
      final wastageQty = int.tryParse((data['wastage'] ??
                                       data['Wastage'] ??
                                       0).toString()) ?? 0;

      totalProcessed += (okQty + wastageQty);
    }

    print('🔍 Step Completion Check for ${stepType.name}:');
    print('   Available: $availableQty');
    print('   Processed: $totalProcessed');
    print('   Remaining: ${availableQty - totalProcessed}');

    // 4. Step is completed only if all quantity is processed
    final isCompleted = totalProcessed >= availableQty;
    print(isCompleted
        ? '✅ Step ${stepType.name} should be COMPLETED (all quantity processed)'
        : '⚠️  Step ${stepType.name} should remain IN PROGRESS ($totalProcessed/$availableQty)');

    return isCompleted;

  } catch (e) {
    print('❌ Error checking step completion for ${stepType.name}: $e');
    return true; // On error, allow normal completion
  }
}

/// Get total processed quantity for a step (OK + wastage)
Future<Map<String, int>> getStepQuantityProgress(String jobNumber, StepType stepType) async {
  try {
    final availableQty = await getPreviousStepAvailableQuantity(jobNumber, stepType);
    final stepDetails = await getStepDetailsWithEditability(jobNumber, stepType);

    int totalProcessed = 0;
    int totalOK = 0;
    int totalWastage = 0;

    for (var detail in stepDetails) {
      final data = detail.data;

      final okQty = int.tryParse((data['quantityOK'] ?? data['quantity'] ?? 0).toString()) ?? 0;
      final wastageQty = int.tryParse((data['wastage'] ?? 0).toString()) ?? 0;

      totalOK += okQty;
      totalWastage += wastageQty;
      totalProcessed += (okQty + wastageQty);
    }

    return {
      'available': availableQty ?? 0,
      'processed': totalProcessed,
      'ok': totalOK,
      'wastage': totalWastage,
      'remaining': (availableQty ?? 0) - totalProcessed,
    };
  } catch (e) {
    print('Error getting step quantity progress: $e');
    return {
      'available': 0,
      'processed': 0,
      'ok': 0,
      'wastage': 0,
      'remaining': 0,
    };
  }
}
```

---

### **File 2: `lib/presentation/pages/job/JobStep.dart`**

#### **Modify: `_handleWorkFormComplete()`**

**Current Code (line 4027):**

```dart
setState(() {
  step.formData = formData;
  step.status = StepStatus.completed; // ❌ Always sets to completed
  // ...
});
```

**New Code:**

```dart
// Check if step should actually be completed based on quantity processed
final shouldComplete = await _apiService.shouldStepBeCompleted(
  widget.jobNumber!,
  step.type
);

setState(() {
  step.formData = formData;

  if (shouldComplete) {
    step.status = StepStatus.completed;
    print('✅ Step ${step.title} marked as COMPLETED (all quantity processed)');

    // Clear started step index when step is completed
    if (_startedStepIndex == stepIndex) {
      _startedStepIndex = null;
      _startedStepType = null;
      _freezeAtStarted = false;
    }
  } else {
    step.status = StepStatus.inProgress;
    print('⚠️  Step ${step.title} remains IN PROGRESS (more quantity to process)');

    // Keep step active for more work
    if (!currentActiveSteps.contains(stepIndex)) {
      currentActiveSteps.add(stepIndex);
    }
  }
});
```

---

### **File 3: `lib/presentation/pages/job/JobStep.dart`**

#### **New: Display Quantity Progress**

**Add progress indicator in step UI:**

```dart
// In _buildTimelineStep()
Widget _buildQuantityProgress(StepData step) {
  return FutureBuilder<Map<String, int>>(
    future: _apiService.getStepQuantityProgress(widget.jobNumber!, step.type),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return SizedBox.shrink();

      final progress = snapshot.data!;
      final available = progress['available']!;
      final processed = progress['processed']!;
      final remaining = progress['remaining']!;

      if (available == 0) return SizedBox.shrink();

      final percentage = (processed / available * 100).toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$processed / $available processed ($remaining remaining)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: processed / available,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining == 0 ? Colors.green : Colors.orange
            ),
          ),
          SizedBox(height: 2),
          Text(
            '$percentage%',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      );
    },
  );
}
```

---

## User Experience

### **Before Implementation:**

```
❌ Printing:
   - Machine 1 completes 3,000 units
   - Step shows as "Completed" ✅
   - Remaining 7,000 units stuck
   - Cannot select other machines
   - Flute Lamination only sees 2,800 OK qty
```

### **After Implementation:**

```
✅ Printing:
   - Machine 1 completes 3,000 units (2,800 OK + 200 wastage)
   - Step shows as "In Progress" 🟠
   - Progress: "3,000 / 10,000 processed (7,000 remaining)"
   - Can select Machine 2 for remaining work

   - Machine 2 completes 7,000 units (6,700 OK + 300 wastage)
   - Step shows as "Completed" ✅
   - Progress: "10,000 / 10,000 processed (0 remaining)"
   - Flute Lamination sees 9,500 OK qty (2,800 + 6,700)
```

---

## Edge Cases

### **Case 1: Partial Quantity Processing**

```
Available: 10,000
Machine 1: 8,000 processed
Remaining: 2,000

Decision: Keep as "In Progress" (user might want to process remaining 2,000)
```

### **Case 2: Over-Processing (Should be prevented by validation)**

```
Available: 10,000
Machine 1: 6,000 processed
Machine 2: 5,000 processed
Total: 11,000 ❌

Decision: Validation should prevent Machine 2 from processing > 4,000
```

### **Case 3: Exact Match**

```
Available: 10,000
Machine 1: 6,000 processed
Machine 2: 4,000 processed
Total: 10,000 ✅

Decision: Mark as "Completed"
```

### **Case 4: No Available Quantity (Paper Store, etc.)**

```
Available: null or 0
Machine 1: Completes work

Decision: Mark as "Completed" (no quantity tracking for this step)
```

---

## Testing Checklist

- [ ] Single machine processes partial quantity → Step stays "In Progress"
- [ ] Single machine processes all quantity → Step becomes "Completed"
- [ ] Multiple machines process partial quantities → Step stays "In Progress"
- [ ] Multiple machines process all quantity → Step becomes "Completed"
- [ ] Quantity progress displayed correctly
- [ ] Remaining quantity calculated correctly
- [ ] Can select additional machines while "In Progress"
- [ ] Cannot over-allocate quantity (validation prevents it)
- [ ] Steps without quantity tracking (Paper Store) work normally
- [ ] Parallel steps (Printing/Corrugation) work independently

---

## Implementation Status

🚧 **STATUS: DESIGN COMPLETE - AWAITING IMPLEMENTATION**

**Next Steps:**

1. Implement `shouldStepBeCompleted()` in `JobApiService.dart`
2. Implement `getStepQuantityProgress()` in `JobApiService.dart`
3. Modify `_handleWorkFormComplete()` in `JobStep.dart`
4. Add quantity progress UI in `JobStep.dart`
5. Test all scenarios
6. Document final implementation

---

**Date:** October 13, 2025

**Impact:** Enables true multi-machine processing with quantity tracking, prevents premature step completion, improves workflow accuracy.
