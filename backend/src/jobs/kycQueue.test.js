const { enqueueBuildPdf, enqueueCopyPdf } = require('./kycQueue');

jest.mock('../config/redis', () => ({
  isRedisEnabled: jest.fn(() => false),
  getRedisClient: jest.fn(() => null),
}));

jest.mock('../utils/kycBuildPdfFromUploadUrls', () => ({
  buildWatermarkedPdfFromUploadUrls: jest.fn(
    (_urls, _sub, prefix) => Promise.resolve(`/uploads/${prefix}.pdf`)
  ),
  copyAndWatermarkExistingPdf: jest.fn(
    (_url, prefix) => Promise.resolve(`/uploads/${prefix}_copy.pdf`)
  ),
}));

const {
  buildWatermarkedPdfFromUploadUrls,
  copyAndWatermarkExistingPdf,
} = require('../utils/kycBuildPdfFromUploadUrls');

describe('kycQueue – Redis disabled (direct fallback)', () => {
  beforeEach(() => jest.clearAllMocks());

  test('enqueueBuildPdf delegates to buildWatermarkedPdfFromUploadUrls', async () => {
    const result = await enqueueBuildPdf(
      ['/uploads/front.jpg'],
      'driver-docs',
      'aadhaar_merged'
    );
    expect(buildWatermarkedPdfFromUploadUrls).toHaveBeenCalledWith(
      ['/uploads/front.jpg'],
      'driver-docs',
      'aadhaar_merged'
    );
    expect(result).toBe('/uploads/aadhaar_merged.pdf');
  });

  test('enqueueCopyPdf delegates to copyAndWatermarkExistingPdf', async () => {
    const result = await enqueueCopyPdf(
      '/uploads/existing.pdf',
      'owner_aadhaar'
    );
    expect(copyAndWatermarkExistingPdf).toHaveBeenCalledWith(
      '/uploads/existing.pdf',
      'owner_aadhaar'
    );
    expect(result).toBe('/uploads/owner_aadhaar_copy.pdf');
  });

  test('enqueueBuildPdf passes multiple URLs', async () => {
    await enqueueBuildPdf(
      ['/uploads/front.jpg', '/uploads/back.jpg'],
      'union-raw',
      'dl_merged'
    );
    expect(buildWatermarkedPdfFromUploadUrls).toHaveBeenCalledWith(
      ['/uploads/front.jpg', '/uploads/back.jpg'],
      'union-raw',
      'dl_merged'
    );
  });
});
