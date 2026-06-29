const express = require('express');
const router = express.Router();
const { getMyNotifications, markAsRead, markAllAsRead } = require('../controllers/notificationController');
const { saveFcmToken, deleteFcmToken, setLanguage } = require('../controllers/fcmTokenController');
const { authenticate } = require('../middleware/auth');

router.get('/', authenticate, getMyNotifications);
router.post('/read-all', authenticate, markAllAsRead);
router.post('/fcm-token', authenticate, saveFcmToken);
router.delete('/fcm-token', authenticate, deleteFcmToken);
router.post('/language', authenticate, setLanguage);
router.post('/:id/read', authenticate, markAsRead);

module.exports = router;
