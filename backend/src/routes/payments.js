const express = require('express');
const router = express.Router();

/**
 * Payments are intentionally disabled for now.
 * Keep endpoints predictable so clients get a clear response instead of
 * accidental partial behaviour.
 */
const paymentsEnabled = String(process.env.PAYMENTS_ENABLED || 'false').toLowerCase() === 'true';

if (!paymentsEnabled) {
  router.use((req, res) => {
    return res.status(503).json({
      success: false,
      message: 'Online payment is temporarily disabled. Please pay offline to the driver.',
      code: 'PAYMENTS_DISABLED',
    });
  });
} else {
  // Placeholder routes for future online payment rollout.
  router.post('/create', (req, res) => {
    res.json({ message: 'Create payment endpoint - To be implemented' });
  });

  router.post('/verify', (req, res) => {
    res.json({ message: 'Verify payment endpoint - To be implemented' });
  });

  router.get('/history', (req, res) => {
    res.json({ message: 'Payment history endpoint - To be implemented' });
  });
}

module.exports = router;
