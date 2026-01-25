require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const apiRoutes = require('./src/routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

// Basic Health Check
app.get('/', (req, res) => res.send('DSU BLE Attendance System API is running'));

// Routes
app.use('/api', apiRoutes);

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server is running on http://0.0.0.0:${PORT}`);
    console.log(`🔗 API Base: http://localhost:${PORT}/api`);
});