const express = require('express');
const router = express.Router();
const { searchRoutes, getPopularRoutes } = require('../controllers/routeController');
const { redisCache } = require('../middleware/redisCache');
const { searchLimiter } = require('../middleware/rateLimiter');

router.get('/search', searchLimiter, redisCache(120), searchRoutes);
router.get('/popular', redisCache(300), getPopularRoutes);

module.exports = router;
