# Machine Work APIs - Complete List 📋

## Overview

This document lists all APIs that are called during the machine work lifecycle: **Start**, **Stop**, and **Complete** work.

---

## 1. START WORK APIs

### **1.1. Start Work on Specific Machine**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/{machineId}/start
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1558-1583)

**Request Body:**

```json
{
  "formData": {
    // Optional: Any initial form data
  }
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "machine_work_id",
    "jobStepId": 1212,
    "machineId": "cmfig03qc00051ewlgn943u1a",
    "status": "start",
    "startedAt": "2025-10-13 12:40:53.29",
    "userId": "NRC017"
  }
}
```

**What it does:**

- ✅ Creates a new record in `job_step_machine` table
- ✅ Sets status = "start"
- ✅ Records `startedAt` timestamp
- ✅ Associates machine with job step
- ✅ Links to logged-in user

---

### **1.2. Start Urgent Job Work (Auto-assigns Machine)**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/urgent/start
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1586-1611)

**Request Body:**

```json
{
  "formData": {
    // Optional: Any initial form data
  }
}
```

**What it does:**

- ✅ Automatically assigns user's machine
- ✅ Creates record in `job_step_machine` table
- ✅ Sets status = "start"
- ✅ Used for urgent jobs

---

## 2. STOP WORK APIs

### **2.1. Stop Work on Specific Machine**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/{machineId}/stop
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1699-1724)

**Request Body:**

```json
{
  "formData": {
    "Status": "stop",
    "Quantity OK": "6000",
    "Wastage": "500",
    "Colors Used": "4",
    "Inks Used": "5",
    "Coating Type": "qwerty",
    "Separate Sheets": "25",
    "Extra Sheets": "20",
    "Remarks": "ok",
    "Start Time": "2025-10-13 12:40:53.290Z",
    "End Time": "2025-10-13 18:11:25.063"
  }
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "cmgp4fhwj0057107cjzv1mvo3",
    "jobStepId": 1212,
    "machineId": "cmfig03qc00051ewlgn943u1a",
    "status": "stop",
    "startedAt": "2025-10-13 12:40:53.29",
    "completedAt": null,
    "userId": "NRC017",
    "formData": "{\"Quantity OK\": \"6000\", \"Wastage\": \"500\", ...}",
    "createdAt": "2025-10-13 12:40:23.395",
    "updatedAt": "2025-10-13 12:41:26.534"
  }
}
```

**What it does:**

- ✅ Updates `job_step_machine` record
- ✅ Sets status = "stop"
- ✅ **Saves ALL form data** to `formData` JSON field
- ✅ Does NOT mark as complete yet
- ✅ Machine is "stopped" but can still be resumed or completed

---

## 3. COMPLETE WORK APIs

### **3.1. Complete Work on Specific Machine**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/{machineId}/complete
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1614-1639)

**Request Body:**

```json
{
  "formData": {
    "Status": "stop",
    "Quantity OK": "6000",
    "Wastage": "500",
    "Colors Used": "4",
    "Inks Used": "5",
    "Coating Type": "qwerty",
    "Separate Sheets": "25",
    "Extra Sheets": "20",
    "Remarks": "ok",
    "Start Time": "2025-10-13 12:40:53.290Z",
    "End Time": "2025-10-13 18:11:25.063"
  }
}
```

**Response (Current):**

```json
{
  "success": true,
  "data": {
    "id": "cmgp4fhwj0057107cjzv1mvo3",
    "jobStepId": 1212,
    "machineId": "cmfig03qc00051ewlgn943u1a",
    "status": "complete",
    "startedAt": "2025-10-13 12:40:53.29",
    "completedAt": "2025-10-13 12:41:25.061",
    "userId": "NRC017",
    "formData": "{\"Quantity OK\": \"6000\", \"Wastage\": \"500\", ...}"
  }
}
```

**What it currently does:**

- ✅ Updates `job_step_machine` record
- ✅ Sets status = "complete"
- ✅ Sets `completedAt` timestamp
- ✅ Keeps formData in `job_step_machine` table
- ❌ **Does NOT check if all quantity is processed**
- ❌ **Does NOT copy to step details table** (printing, corrugation, etc.)
- ❌ **Does NOT determine if entire step should be complete**

---

## 4. ADDITIONAL MACHINE APIs

### **4.1. Hold Work on Machine**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/{machineId}/hold
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1642-1667)

**Request Body:**

```json
{
  "formData": {...},
  "holdReason": "Machine breakdown"
}
```

**What it does:**

- ✅ Sets status = "hold"
- ✅ Saves hold reason
- ✅ Can be resumed later

---

### **4.2. Resume Work on Machine**

**API Endpoint:**

```
POST /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/{machineId}/resume
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1671-1696)

**Request Body:**

```json
{
  "formData": {...}
}
```

**What it does:**

- ✅ Changes status from "hold" back to "start"
- ✅ Clears hold reason
- ✅ Work can continue

---

### **4.3. Get Available Machines for Step**

**API Endpoint:**

```
GET /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1520-1555)

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "machine_id_1",
      "name": "Printer-1",
      "isAvailable": true,
      "status": "idle"
    },
    {
      "id": "machine_id_2",
      "name": "Printer-2",
      "isAvailable": true,
      "status": "working"
    }
  ]
}
```

**What it does:**

- ✅ Returns list of machines available for this step
- ✅ Shows which machines are idle/working
- ✅ User can select from available machines

---

### **4.4. Get Machine Work Status**

**API Endpoint:**

```
GET /job-step-machines/{nrcJobNo}/steps/{stepNo}/machines/status
```

**File:** `lib/data/datasources/job_api.dart` (Lines 1727-1749)

**Response:**

```json
{
  "success": true,
  "data": {
    "totalMachines": 3,
    "workingMachines": 1,
    "completedMachines": 2,
    "machineDetails": [...]
  }
}
```

**What it does:**

- ✅ Shows overall status of all machines for this step
- ✅ Counts how many machines are working/completed
- ✅ Useful for determining if step is complete

---

## Flow Summary

### **Complete Lifecycle:**

```
1. START WORK
   API: POST /job-step-machines/.../start
   → Creates record in job_step_machine
   → status = "start"

2. STOP WORK
   API: POST /job-step-machines/.../stop
   → Updates job_step_machine
   → status = "stop"
   → Saves formData (Quantity OK, Wastage, etc.)

3. COMPLETE WORK (Current - WRONG)
   API: POST /job-step-machines/.../complete
   → Updates job_step_machine
   → status = "complete"
   → ❌ ENTIRE STEP marked complete (regardless of quantity)

3. COMPLETE WORK (Desired - CORRECT)
   API: POST /job-step-machines/.../complete
   → Updates job_step_machine
   → status = "complete"

   THEN (in frontend):
   → Check: totalProcessed >= availableQuantity?

   IF YES:
     → Copy formData to step details table (printing/corrugation/etc)
     → Mark ENTIRE STEP as complete
     → Move to next step

   IF NO:
     → Keep step as "In Progress"
     → User can select another machine
```

---

## Key Differences

### **job_step_machine Table** (Machine-level)

- Tracks EACH machine's work
- Stores formData as JSON
- Multiple records per step (one per machine)
- Status: start → stop → complete

### **Step Details Tables** (Step-level)

- Examples: `printing`, `corrugation`, `flute_lamination`
- Stores FINAL aggregated data
- ONE record per step (or multiple if batched)
- Only filled when step is COMPLETE

---

## What Needs to Change

### **Frontend Logic (After `/complete` API):**

Currently:

```dart
// ❌ Always marks entire step as complete
await completeWorkOnMachine(...);
step.status = StepStatus.completed;
```

Should be:

```dart
// ✅ Check quantity before marking complete
await completeWorkOnMachine(...); // Marks THIS machine as complete

// Calculate total processed
final totalProcessed = sumAllMachines(OK + Wastage);
final available = getPreviousStepQuantity();

if (totalProcessed >= available) {
  // Copy data from job_step_machine to step details table
  await copyToStepDetailsTable();

  // Mark entire step as complete
  step.status = StepStatus.completed;
} else {
  // Keep step in progress
  step.status = StepStatus.inProgress;
}
```

---

**Date:** October 13, 2025

**Status:** APIs are working correctly. Frontend logic needs to be updated to handle quantity-based step completion.
