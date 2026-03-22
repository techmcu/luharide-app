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

  /// Cannot submit independent driver verification if user is union admin or union is pending/approved.
  static bool blocksIndependentDriver({
    required UserModel? user,
    required String? unionStatusFromApi,
  }) {
    if (user?.role == 'union_admin') return true;
    final u = unionStatusFromApi ?? 'none';
    return u == 'pending' || u == 'approved';
  }
}
