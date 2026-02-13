const express = require('express');
const router = express.Router();
const { getMyNotifications, markAsRead, markAllAsRead } = require('../controllers/notificationController');
const { authenticate } = require('../middleware/auth');

router.get('/', authenticate, getMyNotifications);
router.post('/read-all', authenticate, markAllAsRead);
router.post('/:id/read', authenticate, markAsRead);

module.exports = router;
