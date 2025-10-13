# Corrugation "Sheets Count" Field Bug Fix ✅

## Problem Statement

**Issue:** When submitting corrugation work, the "Sheets Count" value entered by the user was being ignored, and the database was storing a default value of `1000` (or `0` in some cases) instead of the actual entered value.

**Example:**

```
User enters: 5000 in "Sheets Count" field
Expected in DB: 5000
Actual in DB: 1000 ❌
```

---

## Root Cause

### **Field Name Mismatch**

The corrugation step uses a field called **"Sheets Count"**, but the `_putCorrugationDetails` function was looking for a field called **"Qty Sheet"**.

### **Code Analysis:**

#### **1. Field Definition (StepDataManager.dart)**

```dart
case StepType.corrugation:
  return ['Sheets Count', 'Size', 'GSM1 (Top Face)', 'GSM2 (Bottom Face)', 'Flute Type', 'Remarks'];
  //      ^^^^^^^^^^^^^^ Field is named "Sheets Count"
```

#### **2. Generic Request Body Mapping (JobApiService.dart - Line 456)**

```dart
} else if (stepName.toLowerCase().contains('corrugation')) {
  requestBody['quantity'] = formData['Sheets Count'] ?? formData['quantity'];
  //                                   ^^^^^^^^^^^^^^ ✅ Correctly uses 'Sheets Count'
```

#### **3. Corrugation-Specific Function (JobApiService.dart - Line 570)**

```dart
final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  //                                 ^^^^^^^^^^^ ❌ WRONG! Looking for 'Qty Sheet'
```

### **The Bug:**

When the form data was submitted:

- `formData['Sheets Count']` = `"5000"` (user's input)
- `formData['Qty Sheet']` = `null` (doesn't exist)
- `int.tryParse(null ?? '0')` = `0`
- Database received: `0` or default value

---

## Solution

### **File: `lib/presentation/pages/process/JobApiService.dart`**

#### **Changes Made:**

1. **Line 559:** Updated debug print statement

   ```dart
   // Before:
   print('Qty Sheet: ${formData['Qty Sheet']}');

   // After:
   print('Sheets Count: ${formData['Sheets Count']}'); // ✅ Fixed
   ```

2. **Line 570:** Fixed quantity field mapping

   ```dart
   // Before:
   "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,

   // After:
   "quantity": int.tryParse(formData['Sheets Count'] ?? '0') ?? 0, // ✅ Fixed
   ```

3. **Lines 572-573:** Fixed GSM field names

   ```dart
   // Before:
   "gsm1": formData['GSM 1'] ?? '',
   "gsm2": formData['GSM 2'] ?? '',

   // After:
   "gsm1": formData['GSM1 (Top Face)'] ?? formData['GSM 1'] ?? '', // ✅ Fixed
   "gsm2": formData['GSM2 (Bottom Face)'] ?? formData['GSM 2'] ?? '', // ✅ Fixed
   ```

---

## Impact

### **Before Fix:**

```
User Input:
  - Sheets Count: 5000
  - GSM1 (Top Face): 120
  - GSM2 (Bottom Face): 180

Database Receives:
  - quantity: 0 ❌ (or 1000 default)
  - gsm1: null ❌
  - gsm2: null ❌
```

### **After Fix:**

```
User Input:
  - Sheets Count: 5000
  - GSM1 (Top Face): 120
  - GSM2 (Bottom Face): 180

Database Receives:
  - quantity: 5000 ✅
  - gsm1: "120" ✅
  - gsm2: "180" ✅
```

---

## Testing

### **Test Case 1: Basic Quantity Entry**

```
Input: Sheets Count = 5000
Expected: Database stores 5000
Result: ✅ PASS
```

### **Test Case 2: GSM Values**

```
Input:
  - GSM1 (Top Face) = 120
  - GSM2 (Bottom Face) = 180
Expected: Database stores gsm1=120, gsm2=180
Result: ✅ PASS
```

### **Test Case 3: Empty Quantity**

```
Input: Sheets Count = (empty)
Expected: Database stores 0
Result: ✅ PASS
```

### **Test Case 4: Integration with Cascading Quantity**

```
Paper Store Available: 11000
User enters Sheets Count: 10500
Expected:
  - Validation allows (10500 <= 11000)
  - Database stores 10500
  - Next step sees 10500 as max available
Result: ✅ PASS
```

---

## Related Issues Fixed

1. **Sheets Count validation:** Now that the correct field is being read, the cascading quantity validation works correctly for corrugation
2. **Placeholder display:** The "0 to [available]" placeholder now validates against the actual entered value
3. **Quantity tracking:** Multi-machine quantity summation now correctly includes corrugation quantities

---

## Additional Field Name Mappings

For reference, here are the correct field names for each step:

| Step                 | Quantity Field Name | Notes                                     |
| -------------------- | ------------------- | ----------------------------------------- |
| **Paper Store**      | `Required Qty`      | -                                         |
| **Printing**         | `Quantity OK`       | Also has `Wastage`                        |
| **Corrugation**      | `Sheets Count`      | ✅ **Fixed** - was using wrong field name |
| **Flute Lamination** | `OK Quantity`       | Also has `Wastage`                        |
| **Punching**         | `OK Quantity`       | Also has `Wastage`                        |
| **Flap Pasting**     | `Quantity`          | Also has `Wastage`                        |
| **Quality**          | `Pass Quantity`     | Also has `Reject Quantity`                |
| **Dispatch**         | `No of Boxes`       | -                                         |

---

## Debugging Tips

If similar field name mismatches occur in the future:

1. **Check StepDataManager.dart:** This defines the canonical field names
2. **Check formData in logs:** Print the full `formData` map to see what keys exist
3. **Compare field names:** Ensure the `putXDetails` function uses the same field names as `StepDataManager`
4. **Test with debug logs:** The fix includes improved debug logging to catch these issues

---

## Status

✅ **FIXED AND TESTED**

**Date:** October 13, 2025

**Files Modified:**

- `lib/presentation/pages/process/JobApiService.dart` (Lines 559, 570, 572-573)

**Impact:**

- Corrugation "Sheets Count" now saves correctly
- GSM values now save correctly
- Cascading quantity validation works properly for corrugation
- No regression in other steps

---

## Related Documentation

- `CASCADING_QUANTITY_VALIDATION_SYSTEM.md` - Cascading quantity system
- `MULTIPLE_MACHINES_QUANTITY_SUMMATION.md` - Multi-machine support
- `MULTIPLE_ROLES_JOBSTEP_IMPLEMENTATION.md` - Role-based access
