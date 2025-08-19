# Multiple Roles Implementation

This document describes the implementation of multiple roles support in the NRC application.

## Overview

The application now supports users having multiple roles simultaneously. This allows users to access different parts of the system based on all their assigned roles, not just a single role.

## Key Changes

### 1. UserRoleManager Updates

The `UserRoleManager` class has been enhanced to support multiple roles:

- **Backward Compatibility**: Still supports single role for existing users
- **Multiple Roles Storage**: Stores roles as JSON array in SharedPreferences
- **Helper Methods**: Provides methods to check, add, and remove roles

#### New Methods:
- `setUserRoles(List<String> roles)` - Set multiple roles
- `addUserRole(String role)` - Add a role to existing roles
- `removeUserRole(String role)` - Remove a specific role
- `hasRole(String role)` - Check if user has a specific role
- `hasAnyRole(List<String> roles)` - Check if user has any of the specified roles
- `hasAllRoles(List<String> roles)` - Check if user has all of the specified roles
- `rolesDisplayString` - Get roles as formatted string
- `roleCount` - Get number of roles
- `hasMultipleRoles` - Check if user has multiple roles

### 2. HomeScreen Updates

The `HomeScreen` now displays and handles multiple roles:

- **Role Display**: Shows all user roles in the header
- **Primary Role**: Indicates the first role as primary (for backward compatibility)
- **Department Cards**: Shows cards for all user roles, not just one
- **Menu Items**: Shows menu items based on all user roles

### 3. Authentication Updates

The authentication system now handles multiple roles from the backend:

- **JSON Array Format**: `["planner", "admin", "printer"]`
- **Comma-separated Format**: `"planner,admin,printer"`
- **Single Role**: `"planner"` (backward compatible)

## Usage Examples

### Setting Multiple Roles
```dart
final userRoleManager = UserRoleManager();

// Set multiple roles
await userRoleManager.setUserRoles(['planner', 'admin', 'printer']);

// Add a role
await userRoleManager.addUserRole('qc_manager');

// Remove a role
await userRoleManager.removeUserRole('printer');
```

### Checking Roles
```dart
// Check specific role
if (userRoleManager.hasRole('admin')) {
  // Show admin features
}

// Check multiple roles
if (userRoleManager.hasAnyRole(['planner', 'admin'])) {
  // Show planning features
}

// Check all roles
if (userRoleManager.hasAllRoles(['planner', 'admin'])) {
  // User has both planner and admin roles
}
```

### Displaying Roles
```dart
// Get all roles as string
String roles = userRoleManager.rolesDisplayString; // "planner, admin, printer"

// Check if multiple roles
bool hasMultiple = userRoleManager.hasMultipleRoles;

// Get role count
int count = userRoleManager.roleCount;
```

## Role Types

The system supports the following roles:

- `admin` - Full system access
- `planner` - Planning and job management
- `printer` - Printing operations
- `production_head` - Production management
- `dispatch_executive` - Dispatch operations
- `qc_manager` - Quality control

## Backend Integration

The backend should return roles in one of these formats:

### JSON Array (Recommended)
```json
{
  "role": ["planner", "admin", "printer"]
}
```

### Comma-separated String
```json
{
  "role": "planner,admin,printer"
}
```

### Single Role (Backward Compatible)
```json
{
  "role": "planner"
}
```

## UI Behavior

### Single Role User
- Shows one role in header
- Shows department card for that role
- Shows menu items for that role

### Multiple Role User
- Shows all roles in header (e.g., "planner, admin, printer")
- Shows "Primary role: planner" (first role)
- Shows department cards for all roles
- Shows menu items for all roles

### Admin User
- Admin users see all department cards regardless of other roles
- Admin users see all menu items

## Testing

Use the test file `lib/test_multiple_roles.dart` to test the functionality:

```dart
// Run tests
await MultipleRolesTest.testMultipleRoles();

// Use test widget
TestMultipleRolesWidget()
```

## Migration

Existing users with single roles will continue to work without changes. The system automatically migrates single role data to the new multiple roles format.

## Future Enhancements

1. **Role Priority**: Allow setting role priority order
2. **Role-based Permissions**: Fine-grained permissions per role
3. **Role Management UI**: Admin interface to manage user roles
4. **Role-specific Settings**: Different settings per role
5. **Role Switching**: Allow users to switch between roles during session
