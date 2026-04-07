const {
  pushDoc,
  collectFromDriverRow,
  collectFromUnionRow,
} = require('./kycDocumentsCollect');

describe('kycDocumentsCollect', () => {
  describe('pushDoc', () => {
    it('skips invalid or duplicate URLs', () => {
      const bucket = [];
      const seen = new Set();
      pushDoc(bucket, seen, '/uploads/x/a.jpg', 'A', 'driver');
      expect(bucket).toHaveLength(1);
      pushDoc(bucket, seen, '/uploads/x/a.jpg', 'B', 'driver');
      expect(bucket).toHaveLength(1);
      pushDoc(bucket, seen, '/etc/passwd', 'C', 'driver');
      expect(bucket).toHaveLength(1);
    });
  });

  describe('collectFromDriverRow', () => {
    it('returns nothing when row is null', () => {
      const bucket = [];
      collectFromDriverRow(null, bucket, new Set());
      expect(bucket).toEqual([]);
    });

    it('maps known columns to driver entries with sanitized paths', () => {
      const bucket = [];
      const seen = new Set();
      collectFromDriverRow(
        {
          driving_license_url: 'https://ex.com/uploads/dl.pdf?q=1',
          rc_front_url: '/uploads/driver-docs/rcf.png',
          insurance_document_url: null,
        },
        bucket,
        seen
      );
      expect(bucket.map((d) => d.category)).toEqual(['driver', 'driver']);
      expect(bucket.map((d) => d.label)).toEqual(['Driving licence', 'Vehicle RC (front)']);
      expect(bucket[0].url).toBe('/uploads/dl.pdf');
      expect(bucket[1].url).toBe('/uploads/driver-docs/rcf.png');
    });
  });

  describe('collectFromUnionRow', () => {
    it('includes rejected union uploads when row present', () => {
      const bucket = [];
      const seen = new Set();
      collectFromUnionRow(
        {
          status: 'rejected',
          office_photo_url: '/uploads/union-docs/office.pdf',
          union_photo_url: '  /uploads/union-docs/u.png  ',
        },
        bucket,
        seen
      );
      expect(bucket).toHaveLength(2);
      expect(bucket.every((d) => d.category === 'union')).toBe(true);
    });

    it('deduplicates same path across driver and union collectors', () => {
      const path = '/uploads/shared/watermark.pdf';
      const bucket = [];
      const seen = new Set();
      collectFromDriverRow({ driving_license_url: path }, bucket, seen);
      collectFromUnionRow({ owner_aadhaar_url: path }, bucket, seen);
      expect(bucket).toHaveLength(1);
    });
  });
});
