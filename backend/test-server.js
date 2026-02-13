require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

// Test route
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Import auth routes
const simpleAuthRoutes = require('./src/routes/simpleAuth');
app.use('/api/simple-auth', simpleAuthRoutes);

// Import trip routes
const tripRoutes = require('./src/routes/trips');
app.use('/api/trips', tripRoutes);

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal server error'
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ Test server running on port ${PORT}`);
});
