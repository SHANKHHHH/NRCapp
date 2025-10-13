# Machine Access UI Indicator Enhancement ✅

## Overview

Added **visual indicators** in the machine selection dialog to show users **which machines they have access to** and **which they don't**, preventing confusion and providing immediate feedback when clicking on restricted machines.

---

## Problem Statement

**Before:**

- ❌ All machines looked the same in the selection dialog
- ❌ Users had to click on a machine to find out they don't have access
- ❌ Backend returned error after clicking
- ❌ No visual distinction between accessible and restricted machines

**Example:**

```
User sees machine list:
  - Printer-1 (looks normal)
  - Printer-2 (looks normal)
  - Printer-3 (looks normal)

User clicks Printer-2:
  → Backend returns 403 Access Denied
  → Error shown after the fact
```

---

## Solution

### **File: `lib/presentation/pages/job/JobStep.dart`**

#### **Changes Made (Lines 2374-2540):**

Added visual indicators to show machine access status **before** user clicks.

---

### **1. Check User Access (Line 2375)**

```dart
// Check if user has access to this machine
final hasAccess = _userMachineIds.contains(machineId);
```

**How it works:**

- `_userMachineIds` is loaded from `/api/users-machines` during initialization
- Contains list of machine IDs the current user has access to
- Example: `["machine-id-1", "machine-id-3", "machine-id-5"]`

---

### **2. Override Visual Styling for No Access (Lines 2381-2395)**

```dart
// If no access, override colors to show restricted
final statusColor = !hasAccess ? Colors.red :              // ← RED for no access
                   machineStatus == 'in_progress' ? Colors.blue :
                   machineStatus == 'hold' ? Colors.orange :
                   machineStatus == 'stop' ? Colors.grey :
                   Colors.green;

final statusText = !hasAccess ? 'No Access' :              // ← "No Access" label
                  machineStatus == 'in_progress' ? 'Working' :
                  machineStatus == 'hold' ? 'On Hold' :
                  machineStatus == 'stop' ? 'Stopped' :
                  'Available';

final statusIcon = !hasAccess ? Icons.lock :               // ← Lock icon
                  machineStatus == 'in_progress' ? Icons.play_circle_filled :
                  machineStatus == 'hold' ? Icons.pause_circle_filled :
                  machineStatus == 'stop' ? Icons.stop_circle :
                  Icons.check_circle;
```

---

### **3. Add Access Denied Alert on Click (Lines 2402-2428)**

```dart
onTap: !hasAccess ? () {
  // Show access denied message immediately
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.lock, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You don\'t have access to $machineCode. Please contact your administrator.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
    ),
  );
} : () {
  // Normal click behavior for accessible machines
  Navigator.pop(context);
  _showWorkFormWithMachine(step, machineId!);
},
```

---

### **4. Grey Out Restricted Machines (Line 2433)**

```dart
decoration: BoxDecoration(
  color: !hasAccess ? Colors.grey[100] : Colors.white, // ← Grey background for no access
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: statusColor.withOpacity(0.3),
    width: 2,
  ),
  // ...
),
```

---

## User Experience

### **Before Enhancement:**

```
Machine Selection Dialog:

  Printer-1     [Available] ✅
  Printer-2     [Available] ✅  ← Looks accessible but isn't!
  Printer-3     [Available] ✅

User clicks Printer-2:
  → Tries to start work
  → Backend returns 403
  → Error shown: "Access Denied"
```

### **After Enhancement:**

```
Machine Selection Dialog:

  Printer-1     [Available] ✅  ← Green, looks clickable
  Printer-2     [No Access] 🔒  ← RED, lock icon, greyed out!
  Printer-3     [Available] ✅  ← Green, looks clickable

User clicks Printer-2:
  → Immediate SnackBar: "You don't have access to Printer-2"
  → No backend call
  → Clear visual feedback
```

---

## Visual Indicators

### **Accessible Machine:**

- ✅ **Background:** White
- ✅ **Status Color:** Green (available) / Blue (working) / Orange (hold)
- ✅ **Status Icon:** Check circle / Play / Pause
- ✅ **Status Text:** "Available" / "Working" / "On Hold"
- ✅ **Border:** Status color with opacity
- ✅ **Clickable:** Opens work form

### **Restricted Machine (No Access):**

- 🔒 **Background:** Grey (`Colors.grey[100]`)
- 🔒 **Status Color:** RED (`Colors.red`)
- 🔒 **Status Icon:** Lock (`Icons.lock`)
- 🔒 **Status Text:** "No Access"
- 🔒 **Border:** Red with opacity
- 🔒 **Clickable:** Shows access denied SnackBar (doesn't try to start work)

---

## Machine Status Priority

The system shows the most important status for each machine:

| Priority    | Condition          | Status        | Color     | Icon     |
| ----------- | ------------------ | ------------- | --------- | -------- |
| 1 (Highest) | User has no access | **No Access** | 🔴 Red    | 🔒 Lock  |
| 2           | Machine working    | **Working**   | 🔵 Blue   | ▶️ Play  |
| 3           | Machine on hold    | **On Hold**   | 🟠 Orange | ⏸️ Pause |
| 4           | Machine stopped    | **Stopped**   | ⬜ Grey   | ⏹️ Stop  |
| 5 (Lowest)  | Machine available  | **Available** | 🟢 Green  | ✅ Check |

**Access check overrides all other statuses!**

---

## Technical Details

### **Access Check Logic:**

```dart
// During initialization (Line 116)
await _loadUserMachineAccess();

// Loads user's assigned machines
_userMachineIds = ["machine-id-1", "machine-id-3", "machine-id-5"];

// During machine card rendering (Line 2375)
final hasAccess = _userMachineIds.contains(machineId);

if (!hasAccess) {
  // Override ALL visual elements to show "No Access"
  statusColor = Colors.red;
  statusText = 'No Access';
  statusIcon = Icons.lock;
  backgroundColor = Colors.grey[100];
  onTap = showAccessDeniedSnackBar;
}
```

---

## Benefits

### **1. Immediate Visual Feedback**

- ✅ Users can see which machines they can use **before** clicking
- ✅ No need to click and get error
- ✅ Clear RED color and LOCK icon indicate restriction

### **2. Better UX**

- ✅ Prevents frustration from clicking inaccessible machines
- ✅ Clear, friendly error message when restricted machine is clicked
- ✅ No backend API calls for restricted machines

### **3. Consistency**

- ✅ Same visual language across all steps
- ✅ Consistent with existing status indicators (Working, On Hold, etc.)
- ✅ Follows material design patterns

### **4. Performance**

- ✅ No unnecessary API calls for restricted machines
- ✅ Access check happens client-side (fast)
- ✅ Only makes API calls for accessible machines

---

## Example Scenarios

### **Scenario 1: Full Access**

```
User assigned to: Printer-1, Printer-2

Machine List:
  Printer-1  [Available] ✅ Green
  Printer-2  [Working]   🔵 Blue
  Printer-3  [No Access] 🔴 Red, Locked
```

### **Scenario 2: Limited Access**

```
User assigned to: Printer-3 only

Machine List:
  Printer-1  [No Access] 🔴 Red, Locked
  Printer-2  [No Access] 🔴 Red, Locked
  Printer-3  [Available] ✅ Green
```

### **Scenario 3: No Access (Admin/Supervisor View)**

```
Admin viewing machines (no direct machine assignments):

Machine List:
  Printer-1  [No Access] 🔴 Red, Locked
  Printer-2  [No Access] 🔴 Red, Locked
  Printer-3  [No Access] 🔴 Red, Locked

Note: Admin can see all machines but cannot work on them directly
```

---

## Error Messages

### **Access Denied SnackBar:**

```
┌─────────────────────────────────────────────┐
│ 🔒  You don't have access to Printer-2.     │
│     Please contact your administrator.      │
└─────────────────────────────────────────────┘
Color: Red (#D32F2F)
Duration: 4 seconds
Type: Floating SnackBar
```

---

## Testing Checklist

- [x] **User with access:** Machine shows green/blue status ✅
- [x] **User without access:** Machine shows red "No Access" with lock icon 🔒
- [x] **Click accessible machine:** Opens work form ✅
- [x] **Click restricted machine:** Shows access denied SnackBar 🔴
- [x] **Multiple users:** Each sees correct access status ✅
- [x] **Machine status updates:** Real-time status shown correctly ✅
- [x] **Mixed access:** Some accessible, some restricted ✅

---

## Future Enhancements

1. **Access Request:** Allow users to request access directly from the UI
2. **Tooltip:** Hover to see why access is denied
3. **Filter Toggle:** Show/hide restricted machines
4. **Access Badge:** "Assigned to you" badge for user's machines
5. **Quick Actions:** "Contact Admin" button on restricted machines

---

## Status

✅ **IMPLEMENTED**

**Date:** October 13, 2025

**Files Modified:**

- `lib/presentation/pages/job/JobStep.dart` (Lines 2374-2540)

**Changes:**

- Added `hasAccess` check using `_userMachineIds.contains(machineId)`
- Modified `statusColor`, `statusText`, `statusIcon` to show "No Access" state
- Changed background color for restricted machines (grey)
- Modified `onTap` to show access denied SnackBar instead of opening form
- No backend changes needed (access control already exists)

**Impact:**

- ✅ Clear visual indication of machine access
- ✅ Prevents unnecessary API calls to restricted machines
- ✅ Better user experience with immediate feedback
- ✅ Consistent with existing UI patterns

---

## Related Documentation

- `MACHINE_WORK_APIS_LIST.md` - Machine API documentation
- `PAPER_STORE_RED_ALERT_FIX.md` - Paper Store error fix
- `ALL_STEPS_FIELD_NAME_BUG_FIX.md` - Field name fixes
