/// Role-based permissions for Irene Training App
///
/// MVP: Hardcoded permissions - ขยายเป็น database-driven ได้ใน Phase 2
/// Roles based on actual job positions at nursing home
class RolePermissions {
  // Permission constants - View
  static const String viewGeneral = 'view_general';
  static const String viewSensitive = 'view_sensitive';
  static const String viewReportsOwn = 'view_reports_own';
  static const String viewReportsAll = 'view_reports_all';
  static const String viewMedicalRecords = 'view_medical_records';

  // Permission constants - Create
  static const String createPost = 'create_post';
  static const String createContent = 'create_content';
  static const String createMedLog = 'create_med_log';
  static const String createVitalSigns = 'create_vital_signs';

  // Permission constants - Edit
  static const String editContent = 'edit_content';
  static const String editMedLog = 'edit_med_log';
  static const String editResidentInfo = 'edit_resident_info';

  // Permission constants - Delete
  static const String deleteContent = 'delete_content';
  static const String deleteMedLog = 'delete_med_log';

  // Permission constants - Admin
  static const String manageUsers = 'manage_users';
  static const String manageRoles = 'manage_roles';
  static const String manageSettings = 'manage_settings';

  /// Permissions per role (based on job positions)
  static const Map<String, Set<String>> _permissions = {
    // NA พาร์ทไทม์ - Basic care tasks
    'na_parttime': {
      viewGeneral,
      createVitalSigns,
    },

    // NA ประจำ - Full-time NA with more access
    'na_fulltime': {
      viewGeneral,
      viewReportsOwn,
      createVitalSigns,
      createMedLog,
      editMedLog,
    },

    // แม่บ้าน - Housekeeping, limited access
    'housekeeper': {
      viewGeneral,
    },

    // นักกายภาพบำบัด พาร์ทไทม์ - Part-time Physiotherapist
    'physiotherapist_parttime': {
      viewGeneral,
      viewMedicalRecords,
      createVitalSigns,
    },

    // นักกายภาพบำบัด ประจำ - Full-time Physiotherapist
    'physiotherapist': {
      viewGeneral,
      viewMedicalRecords,
      viewReportsOwn,
      createPost,
      createVitalSigns,
    },

    // สหวิชาชีพ พาร์ทไทม์ - Part-time Allied Health
    'allied_health_parttime': {
      viewGeneral,
      viewMedicalRecords,
      createVitalSigns,
    },

    // สหวิชาชีพ ประจำ - Full-time Allied Health
    'allied_health': {
      viewGeneral,
      viewMedicalRecords,
      viewReportsOwn,
      createPost,
      createVitalSigns,
    },

    // พยาบาล - Nurse with medical access
    'nurse': {
      viewGeneral,
      viewSensitive,
      viewMedicalRecords,
      viewReportsOwn,
      createPost,
      createMedLog,
      createVitalSigns,
      editMedLog,
      editResidentInfo,
    },

    // หัวหน้าเวร - Shift leader
    'shift_leader': {
      viewGeneral,
      viewSensitive,
      viewMedicalRecords,
      viewReportsOwn,
      viewReportsAll,
      createPost,
      createContent,
      createMedLog,
      createVitalSigns,
      editContent,
      editMedLog,
      editResidentInfo,
      deleteMedLog,
    },

    // ผู้จัดการ - Manager with most permissions
    'manager': {
      viewGeneral,
      viewSensitive,
      viewMedicalRecords,
      viewReportsOwn,
      viewReportsAll,
      createPost,
      createContent,
      createMedLog,
      createVitalSigns,
      editContent,
      editMedLog,
      editResidentInfo,
      deleteContent,
      deleteMedLog,
      manageUsers,
    },

    // เจ้าของ - Owner has all permissions
    'owner': {
      viewGeneral,
      viewSensitive,
      viewMedicalRecords,
      viewReportsOwn,
      viewReportsAll,
      createPost,
      createContent,
      createMedLog,
      createVitalSigns,
      editContent,
      editMedLog,
      editResidentInfo,
      deleteContent,
      deleteMedLog,
      manageUsers,
      manageRoles,
      manageSettings,
    },
  };

  /// Role hierarchy levels (matching database)
  static const Map<String, int> roleLevels = {
    'na_parttime': 10,
    'housekeeper': 10,
    'na_fulltime': 15,
    'physiotherapist_parttime': 18,
    'allied_health_parttime': 18,
    'physiotherapist': 20,
    'allied_health': 20,
    'nurse': 25,
    'shift_leader': 30,
    'manager': 40,
    'owner': 50,
  };

  /// Check if a role has a specific permission
  static bool hasPermission(String? roleName, String permission) {
    if (roleName == null) return false;
    if (roleName == 'owner') return true; // Owner has all permissions
    return _permissions[roleName]?.contains(permission) ?? false;
  }

  /// Check if role level is at least the specified level
  static bool isAtLeastLevel(String? roleName, int level) {
    if (roleName == null) return false;
    return (roleLevels[roleName] ?? 0) >= level;
  }

  /// Check if role is at least shift leader level
  static bool isAtLeastShiftLeader(String? roleName) {
    return isAtLeastLevel(roleName, roleLevels['shift_leader']!);
  }

  /// Check if role is at least nurse level
  static bool isAtLeastNurse(String? roleName) {
    return isAtLeastLevel(roleName, roleLevels['nurse']!);
  }

  /// Check if role is at least manager level
  static bool isAtLeastManager(String? roleName) {
    return isAtLeastLevel(roleName, roleLevels['manager']!);
  }

  /// Check if role is owner
  static bool isOwner(String? roleName) {
    return roleName == 'owner';
  }

  /// Get all permissions for a role
  static Set<String> getPermissions(String? roleName) {
    if (roleName == null) return {};
    if (roleName == 'owner') {
      // Return all permissions for owner
      return {
        viewGeneral,
        viewSensitive,
        viewMedicalRecords,
        viewReportsOwn,
        viewReportsAll,
        createPost,
        createContent,
        createMedLog,
        createVitalSigns,
        editContent,
        editMedLog,
        editResidentInfo,
        deleteContent,
        deleteMedLog,
        manageUsers,
        manageRoles,
        manageSettings,
      };
    }
    return _permissions[roleName] ?? {};
  }
}
