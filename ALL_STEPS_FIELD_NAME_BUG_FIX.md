# All Steps Field Name Mismatch Bug Fix ✅

## Problem Statement

**Issue:** Multiple steps were using incorrect field names when saving data to the database, causing user-entered values to be ignored and replaced with default values (typically `0` or `1000`).

**Affected Steps:**

- ❌ **Printing:** Using `Qty Sheet` instead of `Quantity OK`
- ❌ **Corrugation:** Using `Qty Sheet` instead of `Sheets Count`
- ❌ **Flute Lamination:** Using `Qty Sheet` instead of `OK Quantity`
- ❌ **Punching:** Using `Qty Sheet` instead of `OK Quantity`
- ❌ **Quality Control:** Using `Qty Sheet` instead of `Pass Quantity`
- ❌ **Dispatch:** Using `Qty Sheet` instead of `No of Boxes`
- ✅ **Flap Pasting:** Correctly using `Quantity` (no fix needed)

---

## Root Cause

Each step has its own unique field names defined in `StepDataManager.dart`, but the `putXDetails` functions were all using a generic `Qty Sheet` field name that doesn't exist in most forms.

### **Field Names by Step (from StepDataManager.dart):**

| Step                 | Correct Quantity Field | Was Using (Wrong) | Status     |
| -------------------- | ---------------------- | ----------------- | ---------- |
| **Printing**         | `Quantity OK`          | `Qty Sheet` ❌    | ✅ FIXED   |
| **Corrugation**      | `Sheets Count`         | `Qty Sheet` ❌    | ✅ FIXED   |
| **Flute Lamination** | `OK Quantity`          | `Qty Sheet` ❌    | ✅ FIXED   |
| **Punching**         | `OK Quantity`          | `Qty Sheet` ❌    | ✅ FIXED   |
| **Flap Pasting**     | `Quantity`             | `Quantity` ✅     | ✅ CORRECT |
| **Quality Control**  | `Pass Quantity`        | `Qty Sheet` ❌    | ✅ FIXED   |
| **Dispatch**         | `No of Boxes`          | `Qty Sheet` ❌    | ✅ FIXED   |

---

## Solution

### **File: `lib/presentation/pages/process/JobApiService.dart`**

All `_putXDetails` functions were updated to use the correct field names.

---

### **1. Printing (Lines 526, 533, 538-540)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
  "machine": formData['Machine'] ?? '',
};
```

#### **After:**

```dart
print('Quantity OK: ${formData['Quantity OK']}'); // ✅ Fixed

final body = {
  "quantity": int.tryParse(formData['Quantity OK'] ?? '0') ?? 0, // ✅ Fixed
  "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
  "machine": formData['Machine'] ?? '',
  "noOfColours": int.tryParse(formData['Colors Used'] ?? '0') ?? 0, // ✅ Added
  "inksUsed": formData['Inks Used'] ?? '', // ✅ Added
  "coatingType": formData['Coating Type'] ?? '', // ✅ Added
};
```

---

### **2. Corrugation (Lines 559, 570, 572-573)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  "gsm1": formData['GSM 1'] ?? '',
  "gsm2": formData['GSM 2'] ?? '',
};
```

#### **After:**

```dart
print('Sheets Count: ${formData['Sheets Count']}'); // ✅ Fixed

final body = {
  "quantity": int.tryParse(formData['Sheets Count'] ?? '0') ?? 0, // ✅ Fixed
  "gsm1": formData['GSM1 (Top Face)'] ?? formData['GSM 1'] ?? '', // ✅ Fixed
  "gsm2": formData['GSM2 (Bottom Face)'] ?? formData['GSM 2'] ?? '', // ✅ Fixed
};
```

---

### **3. Flute Lamination (Lines 604, 615)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
};
```

#### **After:**

```dart
print('OK Quantity: ${formData['OK Quantity']}'); // ✅ Fixed

final body = {
  "quantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0, // ✅ Fixed
};
```

---

### **4. Punching (Lines 637, 647-648)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  "die": formData['Die Used'] ?? '',
};
```

#### **After:**

```dart
print('OK Quantity: ${formData['OK Quantity']}'); // ✅ Fixed

final body = {
  "quantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0, // ✅ Fixed
  "die": formData['Die Used (diePunchCode)'] ?? formData['Die Used'] ?? '', // ✅ Fixed
};
```

---

### **5. Quality Control (Lines 668, 677-678)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "passQuantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
};
```

#### **After:**

```dart
print('Pass Quantity: ${formData['Pass Quantity']}'); // ✅ Fixed

final body = {
  "passQuantity": int.tryParse(formData['Pass Quantity'] ?? '0') ?? 0, // ✅ Fixed
  "quantity": int.tryParse(formData['Pass Quantity'] ?? '0') ?? 0, // ✅ Fixed
};
```

---

### **6. Dispatch (Lines 728, 737-738)**

#### **Before:**

```dart
print('Qty Sheet: ${formData['Qty Sheet']}');

final body = {
  "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
  "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '100') ?? 100,
};
```

#### **After:**

```dart
print('No of Boxes: ${formData['No of Boxes']}'); // ✅ Fixed

final body = {
  "quantity": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0, // ✅ Fixed
  "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0, // ✅ Fixed
};
```

---

### **7. Flap Pasting (Line 708) - No Changes Needed**

```dart
final body = {
  "quantity": int.tryParse(formData['Quantity'] ?? '0') ?? 0, // ✅ Already correct
};
```

---

## Impact

### **Before Fix:**

```
User enters:
  - Printing: Quantity OK = 5000
  - Corrugation: Sheets Count = 4500
  - Flute Lamination: OK Quantity = 4000
  - Punching: OK Quantity = 3900
  - QC: Pass Quantity = 3800
  - Dispatch: No of Boxes = 100

Database receives:
  - All fields: 0 or 1000 ❌
  - User data lost
  - Cascading quantity fails
```

### **After Fix:**

```
User enters:
  - Printing: Quantity OK = 5000
  - Corrugation: Sheets Count = 4500
  - Flute Lamination: OK Quantity = 4000
  - Punching: OK Quantity = 3900
  - QC: Pass Quantity = 3800
  - Dispatch: No of Boxes = 100

Database receives:
  - Printing: quantity = 5000 ✅
  - Corrugation: quantity = 4500 ✅
  - Flute Lamination: quantity = 4000 ✅
  - Punching: quantity = 3900 ✅
  - QC: passQuantity = 3800 ✅
  - Dispatch: quantity = 100 ✅
  - Cascading quantity works correctly ✅
```

---

## Additional Fixes

### **Printing:**

- ✅ Added `noOfColours` (Colors Used)
- ✅ Added `inksUsed` (Inks Used)
- ✅ Added `coatingType` (Coating Type)

### **Corrugation:**

- ✅ Fixed GSM field names to include "(Top Face)" and "(Bottom Face)"

### **Punching:**

- ✅ Fixed Die field to include "(diePunchCode)" suffix

---

## Testing Checklist

- [x] **Printing:** Quantity OK saves correctly
- [x] **Printing:** Colors Used, Inks Used, Coating Type save correctly
- [x] **Corrugation:** Sheets Count saves correctly
- [x] **Corrugation:** GSM1 (Top Face) and GSM2 (Bottom Face) save correctly
- [x] **Flute Lamination:** OK Quantity saves correctly
- [x] **Punching:** OK Quantity saves correctly
- [x] **Punching:** Die Used (diePunchCode) saves correctly
- [x] **Quality Control:** Pass Quantity saves correctly
- [x] **Dispatch:** No of Boxes saves correctly
- [x] **Flap Pasting:** Quantity saves correctly (no changes needed)
- [x] **Cascading Quantity:** Works correctly across all steps
- [x] **Multi-machine:** Quantities sum correctly across all steps

---

## Debugging Guide

### **How to Verify Field Names:**

1. **Check StepDataManager.dart** (lines 216-236):

   - This is the source of truth for all field names
   - Each step has a `getFieldNamesForStep()` case

2. **Check formData logs:**

   - All `_putXDetails` functions now print the correct field name
   - Example: `print('Quantity OK: ${formData['Quantity OK']}');`

3. **Verify field mapping:**
   - Form field name → Database field name
   - Example: `"quantity": formData['Quantity OK']`

### **Future Prevention:**

To prevent similar bugs in the future:

1. Always check `StepDataManager.dart` for canonical field names
2. Print full `formData` map in debug logs
3. Test data submission for each step individually
4. Verify database values match user input

---

## Status

✅ **ALL STEPS FIXED AND TESTED**

**Date:** October 13, 2025

**Files Modified:**

- `lib/presentation/pages/process/JobApiService.dart`

**Lines Changed:**

- **Printing:** Lines 526, 533, 538-540
- **Corrugation:** Lines 559, 570, 572-573
- **Flute Lamination:** Lines 598, 604, 615
- **Punching:** Lines 631, 637, 647-648
- **Quality Control:** Lines 662, 668, 677-678
- **Dispatch:** Lines 728, 737-738

**Impact:**

- ✅ All quantity fields now save correctly
- ✅ Additional fields (Colors, Inks, GSM, Die) now save correctly
- ✅ Cascading quantity validation works across all steps
- ✅ Multi-machine quantity summation works correctly
- ✅ No data loss or default values
- ✅ Better debug logging for troubleshooting

---

## Related Documentation

- `CASCADING_QUANTITY_VALIDATION_SYSTEM.md` - Cascading quantity system
- `MULTIPLE_MACHINES_QUANTITY_SUMMATION.md` - Multi-machine support
- `CORRUGATION_SHEETS_COUNT_BUG_FIX.md` - Original corrugation fix (now superseded by this document)
