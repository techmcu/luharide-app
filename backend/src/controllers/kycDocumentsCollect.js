const { sanitizeKycUploadUrl } = require('../utils/sanitizeKycUploadUrl');

function toIsoSubmittedAt(value) {
  if (!value) return null;
  try {
    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    return d.toISOString();
  } catch {
    return null;
  }
}

function pushDoc(bucket, seen, url, label, category, submittedAt) {
  const s = sanitizeKycUploadUrl(url);
  if (!s || seen.has(s)) return;
  seen.add(s);
  bucket.push({
    id: `${category}:${label}`.replace(/\s+/g, '_').toLowerCase(),
    label,
    url: s,
    category,
    /** When this slot was last updated (driver/union row). Used for client-side preview window. */
    submitted_at: toIsoSubmittedAt(submittedAt),
  });
}

function collectFromDriverRow(row, bucket, seen) {
  if (!row) return;
  const ts = row.updated_at || row.created_at;
  pushDoc(bucket, seen, row.driving_license_url, 'Driving licence', 'driver', ts);
  pushDoc(bucket, seen, row.driving_license_front_url, 'Driving licence (front)', 'driver', ts);
  pushDoc(bucket, seen, row.driving_license_back_url, 'Driving licence (back)', 'driver', ts);
  pushDoc(bucket, seen, row.rc_document_url, 'Vehicle RC', 'driver', ts);
  pushDoc(bucket, seen, row.rc_front_url, 'Vehicle RC (front)', 'driver', ts);
  pushDoc(bucket, seen, row.rc_back_url, 'Vehicle RC (back)', 'driver', ts);
  pushDoc(bucket, seen, row.permit_document_url, 'Permit', 'driver', ts);
  pushDoc(bucket, seen, row.insurance_document_url, 'Insurance', 'driver', ts);
  pushDoc(bucket, seen, row.aadhaar_document_url, 'Aadhaar', 'driver', ts);
  pushDoc(bucket, seen, row.aadhaar_front_url, 'Aadhaar (front)', 'driver', ts);
  pushDoc(bucket, seen, row.aadhaar_back_url, 'Aadhaar (back)', 'driver', ts);
}

function collectFromUnionRow(row, bucket, seen) {
  if (!row) return;
  const ts = row.updated_at || row.created_at;
  pushDoc(bucket, seen, row.owner_aadhaar_url, 'Union — Aadhaar (head)', 'union', ts);
  pushDoc(bucket, seen, row.owner_aadhaar_front_url, 'Union — Aadhaar (front)', 'union', ts);
  pushDoc(bucket, seen, row.owner_aadhaar_back_url, 'Union — Aadhaar (back)', 'union', ts);
  pushDoc(bucket, seen, row.office_photo_url, 'Union — Office / centre photo', 'union', ts);
  pushDoc(bucket, seen, row.owner_vehicle_rc_url, 'Union — Vehicle RC', 'union', ts);
  pushDoc(bucket, seen, row.owner_vehicle_rc_front_url, 'Union — Vehicle RC (front)', 'union', ts);
  pushDoc(bucket, seen, row.owner_vehicle_rc_back_url, 'Union — Vehicle RC (back)', 'union', ts);
  pushDoc(bucket, seen, row.leader_driving_license_front_url, 'Union — Licence (front)', 'union', ts);
  pushDoc(bucket, seen, row.leader_driving_license_back_url, 'Union — Licence (back)', 'union', ts);
  pushDoc(bucket, seen, row.union_photo_url, 'Union — Photo', 'union', ts);
  pushDoc(bucket, seen, row.union_driver_list_photo_url, 'Union — Driver list photo', 'union', ts);
}

module.exports = {
  pushDoc,
  collectFromDriverRow,
  collectFromUnionRow,
};
