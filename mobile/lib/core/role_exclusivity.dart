import '../models/user_model.dart';

/// Union representative path vs independent taxi driver path — mutually exclusive
/// once one application is pending or approved.
class RoleExclusivity {
  RoleExclusivity._();

  /// Cannot register / manage union if independent verification is pending or approved.
  static bool blocksUnionRegistration(UserModel? user) {
    final s = user?.driverVerificationStatus ?? 'none';
    return s == 'pending' || s == 'approved';
  }

  /// Cannot submit independent driver verification if union is pending/approved.
  /// When [unionStatusFromApi] is set (from GET /union/me), it wins over JWT role so a
  /// rejected/cancelled union does not block after admin action.
  static bool blocksIndependentDriver({
    required UserModel? user,
    required String? unionStatusFromApi,
  }) {
    if (unionStatusFromApi != null) {
      final s = unionStatusFromApi;
      return s == 'pending' || s == 'approved';
    }
    return user?.role == 'union_admin';
  }
}
