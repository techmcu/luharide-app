const { pool, queryRead } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Get notifications for current user
 * GET /api/notifications
 */
const getMyNotifications = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  // Use body (001 schema); if your table has message instead, run migration 012 to add body.
  const result = await queryRead(
    `SELECT id, type, title, 
            body AS message, 
            is_read, created_at,
            data 
     FROM notifications 
     WHERE user_id = $1 
     ORDER BY created_at DESC 
     LIMIT 50`,
    [userId]
  );

  ApiResponse.success(
    { notifications: result.rows },
    'Notifications retrieved'
  ).send(res);
});

/**
 * Mark notification as read
 * POST /api/notifications/:id/read
 */
const markAsRead = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  await pool.query(
    'UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2',
    [id, userId]
  );

  ApiResponse.success(
    { message: 'Notification marked as read' },
    'Marked as read'
  ).send(res);
});

/**
 * Mark all notifications as read
 * POST /api/notifications/read-all
 */
const markAllAsRead = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  await pool.query(
    'UPDATE notifications SET is_read = TRUE WHERE user_id = $1',
    [userId]
  );

  ApiResponse.success(
    { message: 'All notifications marked as read' },
    'Marked all as read'
  ).send(res);
});

module.exports = {
  getMyNotifications,
  markAsRead,
  markAllAsRead
};
