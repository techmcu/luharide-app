const { pool, queryRead } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Get notifications for current user
 * GET /api/notifications
 */
const getMyNotifications = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  // Cleanup: read >24h, unread >12h, keep max 100 per user
  await pool.query(
    `DELETE FROM notifications
     WHERE user_id = $1
       AND (
         (is_read = TRUE AND created_at < (NOW() - INTERVAL '24 hours'))
         OR created_at < (NOW() - INTERVAL '12 hours')
       )`,
    [userId]
  );
  await pool.query(
    `DELETE FROM notifications WHERE id IN (
       SELECT id FROM notifications WHERE user_id = $1
       ORDER BY created_at DESC OFFSET 100
     )`,
    [userId]
  );

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

  const readResult = await pool.query(
    `UPDATE notifications
     SET is_read = TRUE
     WHERE id = $1 AND user_id = $2
     RETURNING id`,
    [id, userId]
  );
  if (readResult.rows.length === 0) {
    return ApiResponse.success(
      { message: 'Notification already removed' },
      'Notification not found'
    ).send(res);
  }

  // Product requirement: once opened/read, remove immediately from DB.
  await pool.query(
    'DELETE FROM notifications WHERE id = $1 AND user_id = $2',
    [id, userId]
  );

  ApiResponse.success(
    { message: 'Notification marked as read and removed' },
    'Marked and removed'
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
  await pool.query(
    'DELETE FROM notifications WHERE user_id = $1 AND is_read = TRUE',
    [userId]
  );

  ApiResponse.success(
    { message: 'All notifications marked as read and removed' },
    'Marked and removed all'
  ).send(res);
});

module.exports = {
  getMyNotifications,
  markAsRead,
  markAllAsRead
};
