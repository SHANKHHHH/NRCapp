# Multiple Roles Implementation - JobStep & Notifications

This document describes the implementation of multiple roles support in the JobStep timeline and notification system.

## Overview

The JobStep timeline and notification system now support users having multiple roles simultaneously. This allows users to see and interact with steps based on all their assigned roles, not just a single role.

## Key Changes

### 1. JobStep Timeline Updates

The `JobTimelinePage` now handles multiple roles:

- **Multiple Roles Loading**: Loads all user roles from UserRoleManager
- **Step Filtering**: Shows steps based on all user roles, not just one
- **Primary Role**: Uses first role as primary for backward compatibility
- **Error Messages**: Shows all user roles in error messages

#### Updated Methods:
- `_loadUserRoleAndInitializeSteps()` - Now loads multiple roles
- `_initializeSteps()` - Passes multiple roles to StepDataManager
- Error handling - Shows all roles when no steps are available

### 2. StepDataManager Updates

The `StepDataManager` has been enhanced to support multiple roles:

#### New Methods:
- `getStepsForRoles(List<String> userRoles)` - Get steps for multiple roles
- `isStepAllowedForRoles(StepType stepType, List<String> userRoles)` - Check if step is allowed for multiple roles

#### Updated Methods:
- `initializeSteps()` - Now accepts both single role and multiple roles parameters
- Step filtering logic - Prioritizes multiple roles over single role

### 3. Notification System Updates

The notification system now supports multiple roles:

#### New Functions:
- `shouldNotifyUserForStepWithRoles(List<String> currentUserRoles, String stepName)` - Check notification for multiple roles
- `shouldShowNotificationForRoles(Map<String, dynamic> notification, List<String> currentUserRoles)` - Filter notifications for multiple roles

#### Updated Classes:
- `NotificationsScreen` - Now stores and uses multiple roles
- `fetchNotificationCountForBadge()` - Uses multiple roles for badge counting

## Usage Examples

### JobStep Timeline
```dart
// In JobTimelinePage
final userRoleManager = UserRoleManager();
await userRoleManager.loadUserRole();
_userRoles = userRoleManager.userRoles;
_primaryRole = userRoleManager.userRole ?? '';

// Initialize steps with multiple roles
steps = StepDataManager.initializeSteps(
  widget.assignedSteps, 
  userRole: _primaryRole, 
  userRoles: _userRoles
);
```

### Step Filtering
```dart
// Check if step is allowed for multiple roles
bool isAllowed = StepDataManager.isStepAllowedForRoles(stepType, userRoles);

// Get all allowed steps for multiple roles
List<StepType> allowedSteps = StepDataManager.getStepsForRoles(userRoles);
```

### Notifications
```dart
// Check if user should be notified for a step
bool shouldNotify = shouldNotifyUserForStepWithRoles(userRoles, stepName);

// Filter notifications for multiple roles
bool shouldShow = shouldShowNotificationForRoles(notification, userRoles);
```

## Role-Based Step Access

### Single Role User
- Sees steps only for their assigned role
- Gets notifications only for their role's steps
- Works exactly as before (backward compatible)

### Multiple Role User
- Sees steps for ALL their assigned roles
- Gets notifications for ALL their roles' steps
- Can interact with steps from any of their roles

### Admin User
- Sees all steps regardless of other roles
- Gets all notifications
- Has full access to all functionality

## Step Types by Role

The system supports these role-step mappings:

- **planner**: Paper Store
- **printer**: Printing
- **production_head**: Corrugation, Flute Lamination, Punching, Flap Pasting
- **qc_manager**: Quality Control
- **dispatch_executive**: Dispatch
- **admin**: All steps

## Notification Types

### Next Step Notifications
- Triggered when a step becomes available
- Filtered based on user's roles
- Shows for steps the user can work on

### Completion Notifications
- Triggered when a step is completed
- Filtered based on user's roles
- Shows for steps the user has access to

## Backend Integration

The system automatically handles multiple roles from the backend:

- **JSON Array**: `["planner", "admin", "printer"]`
- **Comma-separated**: `"planner,admin,printer"`
- **Single Role**: `"planner"` (backward compatible)

## Migration

Existing users with single roles will continue to work without changes. The system automatically:

- Migrates single role data to multiple roles format
- Maintains backward compatibility
- Preserves existing functionality

## Testing

To test the multiple roles functionality:

1. **Login with multiple roles**: Use a user account with multiple roles
2. **Check step visibility**: Verify all role-appropriate steps are shown
3. **Test notifications**: Verify notifications appear for all relevant steps
4. **Test interactions**: Verify user can interact with steps from all their roles

## Error Handling

- **No steps available**: Shows message with all user roles
- **Role loading failure**: Falls back to single role behavior
- **Invalid roles**: Handles gracefully with appropriate error messages

## Performance Considerations

- **Caching**: Step data is cached to avoid repeated API calls
- **Batch loading**: Multiple steps are loaded in parallel
- **Optimized filtering**: Role checking is optimized for performance

## Future Enhancements

1. **Role Priority**: Allow setting role priority for step ordering
2. **Role-specific UI**: Different UI elements per role
3. **Role switching**: Allow users to switch active role during session
4. **Advanced filtering**: More granular step filtering options
5. **Role-based permissions**: Fine-grained permissions per step
