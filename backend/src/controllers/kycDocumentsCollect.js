const { sanitizeKycUploadUrl } = require('../utils/sanitizeKycUploadUrl');

function pushDoc(bucket, seen, url, label, category) {
  const s = sanitizeKycUploadUrl(url);
  if (!s || seen.has(s)) return;
  seen.add(s);
  bucket.push({
    id: `${category}:${label}`.replace(/\s+/g, '_').toLowerCase(),
    label,
    url: s,
    category,
  });
}

function collectFromDriverRow(row, bucket, seen) {
  if (!row) return;
  pushDoc(bucket, seen, row.driving_license_url, 'Driving licence', 'driver');
  pushDoc(bucket, seen, row.driving_license_front_url, 'Driving licence (front)', 'driver');
  pushDoc(bucket, seen, row.driving_license_back_url, 'Driving licence (back)', 'driver');
  pushDoc(bucket, seen, row.rc_document_url, 'Vehicle RC', 'driver');
  pushDoc(bucket, seen, row.rc_front_url, 'Vehicle RC (front)', 'driver');
  pushDoc(bucket, seen, row.rc_back_url, 'Vehicle RC (back)', 'driver');
  pushDoc(bucket, seen, row.permit_document_url, 'Permit', 'driver');
  pushDoc(bucket, seen, row.insurance_document_url, 'Insurance', 'driver');
  pushDoc(bucket, seen, row.aadhaar_document_url, 'Aadhaar', 'driver');
  pushDoc(bucket, seen, row.aadhaar_front_url, 'Aadhaar (front)', 'driver');
  pushDoc(bucket, seen, row.aadhaar_back_url, 'Aadhaar (back)', 'driver');
}

function collectFromUnionRow(row, bucket, seen) {
  if (!row) return;
  pushDoc(bucket, seen, row.owner_aadhaar_url, 'Union — Aadhaar (head)', 'union');
  pushDoc(bucket, seen, row.owner_aadhaar_front_url, 'Union — Aadhaar (front)', 'union');
  pushDoc(bucket, seen, row.owner_aadhaar_back_url, 'Union — Aadhaar (back)', 'union');
  pushDoc(bucket, seen, row.office_photo_url, 'Union — Office / centre photo', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_url, 'Union — Vehicle RC', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_front_url, 'Union — Vehicle RC (front)', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_back_url, 'Union — Vehicle RC (back)', 'union');
  pushDoc(bucket, seen, row.leader_driving_license_front_url, 'Union — Licence (front)', 'union');
  pushDoc(bucket, seen, row.leader_driving_license_back_url, 'Union — Licence (back)', 'union');
  pushDoc(bucket, seen, row.union_photo_url, 'Union — Photo', 'union');
  pushDoc(bucket, seen, row.union_driver_list_photo_url, 'Union — Driver list photo', 'union');
}

module.exports = {
  pushDoc,
  collectFromDriverRow,
  collectFromUnionRow,
};
