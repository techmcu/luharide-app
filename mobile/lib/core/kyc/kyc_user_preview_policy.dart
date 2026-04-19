/// User-side KYC file preview: open in-app only within [window] after last submit
/// (reduces repeat full-file downloads). Admins are not subject to this policy.
const Duration kKycUserInAppPreviewWindow = Duration(days: 4);

bool kycUserInAppPreviewIsOpen(DateTime? submittedAt) {
  if (submittedAt == null) return true;
  final deadline = submittedAt.add(kKycUserInAppPreviewWindow);
  return DateTime.now().isBefore(deadline);
}

DateTime? kycSubmittedAtFromDocMap(Map<String, dynamic>? d) {
  if (d == null) return null;
  final raw = d['submitted_at'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
