const path = require('path');
const { resolveVerifiedUploadPath } = require('./resolveVerifiedUploadPath');

describe('resolveVerifiedUploadPath', () => {
  it('returns null for empty or non-matching prefix', () => {
    expect(resolveVerifiedUploadPath('', 'driver-docs')).toBeNull();
    expect(resolveVerifiedUploadPath('/uploads/union-docs/x', 'driver-docs')).toBeNull();
  });

  it('returns null for traversal, nested segments, or empty basename', () => {
    expect(resolveVerifiedUploadPath('/uploads/driver-docs/../x', 'driver-docs')).toBeNull();
    expect(resolveVerifiedUploadPath('/uploads/driver-docs/', 'driver-docs')).toBeNull();
    expect(resolveVerifiedUploadPath('/uploads/driver-docs/sub/x', 'driver-docs')).toBeNull();
    expect(resolveVerifiedUploadPath('/uploads/driver-docs/x\\y', 'driver-docs')).toBeNull();
  });

  it('returns null when basename is too long', () => {
    const long = 'a'.repeat(513);
    expect(resolveVerifiedUploadPath(`/uploads/driver-docs/${long}`, 'driver-docs')).toBeNull();
  });

  it('returns absolute file path under uploads subdir for valid basename', () => {
    const abs = resolveVerifiedUploadPath('/uploads/driver-docs/kyc.pdf', 'driver-docs');
    expect(abs).not.toBeNull();
    expect(path.isAbsolute(abs)).toBe(true);
    expect(abs.replace(/\\/g, '/')).toMatch(/uploads\/driver-docs\/kyc\.pdf$/);
  });
});
