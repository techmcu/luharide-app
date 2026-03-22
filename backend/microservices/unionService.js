/**
 * Union microservice — /api/union/*
 * Port: UNION_SERVICE_PORT (default 3003)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');

const unionRoutes = require('../src/routes/union');

const app = createBaseApp('union');
app.use('/api/union', unionRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.UNION_SERVICE_PORT || '3003', 10);
app.listen(PORT, () => {
  console.log(`[union-service] listening on ${PORT}`);
});
