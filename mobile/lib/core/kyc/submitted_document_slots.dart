/// Expected KYC slots (labels + categories) — must match [kycDocumentsCollect.js] on backend.
class SubmittedDocumentSlot {
  const SubmittedDocumentSlot({required this.label, required this.category});

  final String label;
  /// `driver` | `union` — same as API [documents].category
  final String category;
}

/// Order matches backend [collectFromDriverRow].
const List<SubmittedDocumentSlot> kDriverSubmittedDocumentSlots = [
  SubmittedDocumentSlot(label: 'Driving licence', category: 'driver'),
  SubmittedDocumentSlot(label: 'Driving licence (front)', category: 'driver'),
  SubmittedDocumentSlot(label: 'Driving licence (back)', category: 'driver'),
  SubmittedDocumentSlot(label: 'Vehicle RC', category: 'driver'),
  SubmittedDocumentSlot(label: 'Vehicle RC (front)', category: 'driver'),
  SubmittedDocumentSlot(label: 'Vehicle RC (back)', category: 'driver'),
  SubmittedDocumentSlot(label: 'Permit', category: 'driver'),
  SubmittedDocumentSlot(label: 'Insurance', category: 'driver'),
  SubmittedDocumentSlot(label: 'Aadhaar', category: 'driver'),
  SubmittedDocumentSlot(label: 'Aadhaar (front)', category: 'driver'),
  SubmittedDocumentSlot(label: 'Aadhaar (back)', category: 'driver'),
];

/// Order matches backend [collectFromUnionRow].
const List<SubmittedDocumentSlot> kUnionSubmittedDocumentSlots = [
  SubmittedDocumentSlot(label: 'Union — Aadhaar (head)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Aadhaar (front)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Aadhaar (back)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Office / centre photo', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Vehicle RC', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Vehicle RC (front)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Vehicle RC (back)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Licence (front)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Licence (back)', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Photo', category: 'union'),
  SubmittedDocumentSlot(label: 'Union — Driver list photo', category: 'union'),
];

List<SubmittedDocumentSlot> submittedSlotsForRoles({
  required bool includeUnion,
  required bool includeDriver,
}) {
  final out = <SubmittedDocumentSlot>[];
  if (includeUnion) out.addAll(kUnionSubmittedDocumentSlots);
  if (includeDriver) out.addAll(kDriverSubmittedDocumentSlots);
  return out;
}
