const { sanitizeKycUploadUrl } = require('./sanitizeKycUploadUrl');

describe('sanitizeKycUploadUrl', () => {
  it('returns null for null, undefined, and empty', () => {
    expect(sanitizeKycUploadUrl(null)).toBeNull();
    expect(sanitizeKycUploadUrl(undefined)).toBeNull();
    expect(sanitizeKycUploadUrl('')).toBeNull();
  });

  it('trims and accepts /uploads/...', () => {
    expect(sanitizeKycUploadUrl('  /uploads/driver-docs/a.jpg  ')).toBe('/uploads/driver-docs/a.jpg');
  });

  it('accepts uploads/... without leading slash', () => {
    expect(sanitizeKycUploadUrl('uploads/union-docs/x.png')).toBe('/uploads/union-docs/x.png');
  });

  it('extracts pathname from http(s) URLs when under /uploads/', () => {
    expect(sanitizeKycUploadUrl('https://cdn.example.com/uploads/a/b?x=1')).toBe('/uploads/a/b');
    expect(sanitizeKycUploadUrl('http://localhost:3000/uploads/x/y')).toBe('/uploads/x/y');
  });

  it('rejects paths not under /uploads/', () => {
    expect(sanitizeKycUploadUrl('/static/evil.jpg')).toBeNull();
    expect(sanitizeKycUploadUrl('/uploads')).toBeNull();
    expect(sanitizeKycUploadUrl('ftp://x/uploads/a')).toBeNull();
  });

  it('rejects path traversal segments', () => {
    expect(sanitizeKycUploadUrl('/uploads/../etc/passwd')).toBeNull();
    expect(sanitizeKycUploadUrl('/uploads/a/../b')).toBeNull();
  });

  it('allows single dots in filenames', () => {
    expect(sanitizeKycUploadUrl('/uploads/docs/file.name.jpg')).toBe('/uploads/docs/file.name.jpg');
  });

  it('rejects oversized input', () => {
    const long = 'a'.repeat(2049);
    expect(sanitizeKycUploadUrl(long)).toBeNull();
  });

  it('rejects malformed URL when scheme is http(s)', () => {
    expect(sanitizeKycUploadUrl('https://')).toBeNull();
  });

  it('rejects non-uploads relative without uploads/ prefix', () => {
    expect(sanitizeKycUploadUrl('images/x')).toBeNull();
  });
});
