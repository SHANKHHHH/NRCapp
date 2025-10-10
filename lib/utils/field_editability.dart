/**
 * Utility to handle field editability in the frontend
 * Works with the backend's field editability system
 */

class FieldEditability {
  final Map<String, bool> _editableFields;
  
  FieldEditability(this._editableFields);
  
  /// Check if a field is editable
  bool isEditable(String fieldName) {
    return _editableFields[fieldName] ?? true; // Default to editable if not specified
  }
  
  /// Check if a field is read-only
  bool isReadOnly(String fieldName) {
    return !isEditable(fieldName);
  }
  
  /// Get all editable field names
  List<String> get editableFields {
    return _editableFields.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get all read-only field names
  List<String> get readOnlyFields {
    return _editableFields.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Filter data to only include editable fields
  Map<String, dynamic> filterEditableData(Map<String, dynamic> data) {
    final filtered = <String, dynamic>{};
    data.forEach((key, value) {
      if (isEditable(key)) {
        filtered[key] = value;
      }
    });
    return filtered;
  }
  
  /// Create from backend response
  static FieldEditability fromBackendResponse(Map<String, dynamic> response) {
    final editableFields = response['editableFields'] as Map<String, dynamic>? ?? {};
    return FieldEditability(Map<String, bool>.from(editableFields));
  }
  
  /// Create empty (all fields editable)
  static FieldEditability empty() {
    return FieldEditability({});
  }
}

/// Wrapper class for step data with editability information
class StepDataWithEditability {
  final Map<String, dynamic> data;
  final FieldEditability editability;
  
  StepDataWithEditability({
    required this.data,
    required this.editability,
  });
  
  /// Create from backend response
  static StepDataWithEditability fromBackendResponse(Map<String, dynamic> response) {
    return StepDataWithEditability(
      data: response['data'] as Map<String, dynamic>? ?? {},
      editability: FieldEditability.fromBackendResponse(response),
    );
  }
  
  /// Create list from backend response list
  static List<StepDataWithEditability> fromBackendResponseList(List<dynamic> responseList) {
    return responseList
        .map((item) => StepDataWithEditability.fromBackendResponse(item as Map<String, dynamic>))
        .toList();
  }
  
  /// Check if a field is editable
  bool isFieldEditable(String fieldName) {
    return editability.isEditable(fieldName);
  }
  
  /// Check if a field is read-only
  bool isFieldReadOnly(String fieldName) {
    return editability.isReadOnly(fieldName);
  }
  
  /// Get field value
  dynamic getFieldValue(String fieldName) {
    return data[fieldName];
  }
  
  /// Get editable fields only
  Map<String, dynamic> getEditableFields() {
    return editability.filterEditableData(data);
  }
  
  /// Get read-only fields only
  Map<String, dynamic> getReadOnlyFields() {
    final readOnly = <String, dynamic>{};
    data.forEach((key, value) {
      if (editability.isReadOnly(key)) {
        readOnly[key] = value;
      }
    });
    return readOnly;
  }
}
