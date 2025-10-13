# Complete Work Button - Current Logic for Multiple Machines 📋

## Overview

This document explains **how the "Complete Work" button currently works** when multiple machines are processing the same step, and **what needs to be changed** to properly handle quantity-based step completion.

---

## Current Flow

### **1. User Completes Work on Machine**

**Location:** `lib/presentation/pages/job/work_action_form.dart` (Lines 1056-1119)

```dart
void _handleComplete() async {
  if (_formKey.currentState!.validate()) {
    if (_status != 'stop') {
      return; // Must click "Stop Work" before "Complete"
    }

    setState(() => _isLoading = true);

    // Collect form data
    final formData = <String, String>{};
    for (var entry in _controllers.entries) {
      formData[entry.key] = entry.value.text;
    }

    // Call API to complete work on THIS machine
    final result = await widget.apiService!.completeWorkOnMachine(
      widget.nrcJobNo!,
      widget.stepNo!,
      widget.machineId!,
      formData: formData,
    );

    // Call onComplete callback (goes to JobStep._handleWorkFormComplete)
    widget.onComplete(formData);

    // Close dialog
    Navigator.of(context).pop(true);
  }
}
```

---

### **2. API Call: `completeWorkOnMachine`**

**Location:** `lib/presentation/pages/process/JobApiService.dart` (Lines 975-985)

```dart
Future<Map<String, dynamic>?> completeWorkOnMachine(
  String nrcJobNo,
  int stepNo,
  String machineId,
  {Map<String, dynamic>? formData}
) async {
  try {
    final result = await _jobApi.completeWorkOnMachine(
      nrcJobNo,
      stepNo,
      machineId,
      formData: formData
    );

    // Clear cache to ensure fresh data
    _clearCacheForJob(nrcJobNo);

    return result;
  } catch (e) {
    print('Error completing work on machine $machineId: $e');
    return null;
  }
}
```

**This function:**

- ✅ Saves the machine's work data (quantity, wastage, etc.) to the database
- ✅ Marks THIS machine's work as "completed"
- ❌ **Does NOT check** if all available quantity has been processed
- ❌ **Does NOT check** if other machines are still working
- ❌ **Does NOT determine** if the step should be marked as "Completed"

---

### **3. JobStep Handles Completion**

**Location:** `lib/presentation/pages/job/JobStep.dart` (Lines 3988-4078)

```dart
Future<void> _handleWorkFormComplete(StepData step, Map<String, String> formData) async {
  try {
    showDialog(...); // Show loading

    final stepNo = StepDataManager.getStepNumber(step.type);

    // Save step details
    await _apiService.putStepDetails(step.type, widget.jobNumber!, formData, stepNo);

    // Update planning status to "stop"
    await _apiService.updateJobPlanningStepComplete(
      widget.jobNumber!,
      stepNo,
      "stop",
      additionalFields: formData
    );

    final stepIndex = steps.indexOf(step);

    setState(() {
      step.formData = formData;
      step.status = StepStatus.completed; // ❌ ALWAYS sets to "completed"

      // Clear started step index
      if (_startedStepIndex == stepIndex) {
        _startedStepIndex = null;
        _startedStepType = null;
        _freezeAtStarted = false;
      }
    });

    // Move to next step
    await _optimizedStepProgressionCheck(step, stepIndex);

    // Refresh UI
    _refreshAllStepData();

  } catch (e) {
    // Error handling
  }
}
```

**The Problem:**

```dart
setState(() {
  step.status = StepStatus.completed; // ❌ ALWAYS sets to "completed"
});
```

This line **ALWAYS** marks the entire step as "Completed", regardless of:

- ❌ How much quantity was processed
- ❌ How much quantity remains
- ❌ Whether other machines are still available
- ❌ Whether all available quantity has been processed

---

## Current Behavior (What Happens Now)

### **Scenario: Printing with Multiple Machines**

```
Paper Store: 10,000 available

Step 1: User selects Printer-1
  - Processes: 3,000 (2,800 OK + 200 wastage)
  - Clicks "Stop Work" → Status changes to 'stop'
  - Clicks "Complete Work" → Form submitted

Result:
  ✅ Printer-1 work saved to database (quantity = 2,800)
  ❌ ENTIRE STEP marked as "Completed"
  ❌ Remaining 7,000 units ignored
  ❌ Cannot select Printer-2 anymore
  ❌ Moves to next step (Flute Lamination)
  ❌ Flute Lamination only sees 2,800 available (should see 2,800)
```

---

## What SHOULD Happen (Desired Behavior)

### **Scenario: Printing with Multiple Machines (Correct)**

```
Paper Store: 10,000 available

Step 1: User selects Printer-1
  - Processes: 3,000 (2,800 OK + 200 wastage)
  - Clicks "Stop Work"
  - Clicks "Complete Work"

Result:
  ✅ Printer-1 work saved (quantity = 2,800, wastage = 200)
  ✅ Total processed: 3,000 / 10,000
  ✅ Remaining: 7,000
  ✅ Step status: "In Progress" (not "Completed")
  ✅ Can still select Printer-2

Step 2: User selects Printer-2
  - Processes: 7,000 (6,700 OK + 300 wastage)
  - Clicks "Stop Work"
  - Clicks "Complete Work"

Result:
  ✅ Printer-2 work saved (quantity = 6,700, wastage = 300)
  ✅ Total processed: 10,000 / 10,000 (3,000 + 7,000)
  ✅ Remaining: 0
  ✅ Step status: "Completed" (all quantity processed)
  ✅ Moves to next step
  ✅ Flute Lamination sees 9,500 available (2,800 + 6,700)
```

---

## Required Changes

### **Change 1: Modify `_handleWorkFormComplete()` in JobStep.dart**

**Current Code (Line 4027):**

```dart
setState(() {
  step.formData = formData;
  step.status = StepStatus.completed; // ❌ ALWAYS completed
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

    // Clear started step index
    if (_startedStepIndex == stepIndex) {
      _startedStepIndex = null;
      _startedStepType = null;
      _freezeAtStarted = false;
    }
  } else {
    step.status = StepStatus.inProgress;
    print('⚠️ Step ${step.title} remains IN PROGRESS (more quantity to process)');

    // Keep step active for more work
    if (!currentActiveSteps.contains(stepIndex)) {
      currentActiveSteps.add(stepIndex);
    }
  }
});
```

---

### **Change 2: Add `shouldStepBeCompleted()` function**

**New Function in `JobApiService.dart`:**

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
        : '⚠️ Step ${stepType.name} should remain IN PROGRESS ($totalProcessed/$availableQty)');

    return isCompleted;

  } catch (e) {
    print('❌ Error checking step completion for ${stepType.name}: $e');
    return true; // On error, allow normal completion
  }
}
```

---

## Decision Logic

### **When to Mark Step as "Completed"**

```dart
if (totalProcessedQuantity >= availableQuantity) {
  // ALL quantity has been processed
  step.status = StepStatus.completed;
  moveToNextStep();
} else {
  // MORE quantity remains to be processed
  step.status = StepStatus.inProgress;
  allowMoreMachineSelection();
}
```

### **Examples:**

| Available | Processed | Remaining | Step Status    | Reason                                          |
| --------- | --------- | --------- | -------------- | ----------------------------------------------- |
| 10,000    | 10,000    | 0         | ✅ Completed   | All quantity processed                          |
| 10,000    | 9,800     | 200       | 🟠 In Progress | 200 units remaining                             |
| 10,000    | 3,000     | 7,000     | 🟠 In Progress | 7,000 units remaining                           |
| 10,000    | 10,200    | -200      | ✅ Completed   | Over-processed (validation should prevent this) |
| null      | 5,000     | -         | ✅ Completed   | No quantity tracking (Paper Store, etc.)        |

---

## Benefits of This Change

### **1. Accurate Step Status**

- ✅ Steps remain "In Progress" until all quantity is processed
- ✅ No premature step completion
- ✅ Prevents skipping remaining work

### **2. Multi-Machine Support**

- ✅ Multiple machines can work on the same step
- ✅ Each machine's work is tracked independently
- ✅ Step completes only when all machines finish processing all quantity

### **3. Quantity Integrity**

- ✅ All available quantity gets processed
- ✅ No quantity loss
- ✅ Accurate cascading to next step

### **4. Better UX**

- ✅ Users can clearly see progress (3,000/10,000 processed)
- ✅ Can select additional machines while "In Progress"
- ✅ Clear indication when step is truly complete

---

## Implementation Status

🚧 **STATUS: DESIGN COMPLETE - AWAITING USER APPROVAL**

**Waiting for user confirmation to:**

1. Implement `shouldStepBeCompleted()` function
2. Modify `_handleWorkFormComplete()` logic
3. Test with multiple machines
4. Update UI to show quantity progress

---

**Date:** October 13, 2025

**Impact:** Enables proper multi-machine quantity tracking, prevents premature step completion, maintains data integrity across the workflow.
