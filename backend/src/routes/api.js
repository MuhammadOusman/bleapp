
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

const authMiddleware = require('../middleware/authMiddleware');
const courseController = require('../controllers/courseController');
const attendanceController = require('../controllers/attendanceController');

router.post('/register', authController.register);
router.post('/login', authController.login);

// Protected Routes
router.get('/courses', authMiddleware, courseController.getCourses);
router.post('/sessions/start', authMiddleware, attendanceController.startSession);
router.post('/attendance/mark', authMiddleware, attendanceController.markAttendance);
// Teacher approval endpoint (approves by device_signature)
router.post('/attendance/approve', authMiddleware, attendanceController.approveByTeacher);

module.exports = router;