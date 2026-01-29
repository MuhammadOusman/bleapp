
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

const authMiddleware = require('../middleware/authMiddleware');
const courseController = require('../controllers/courseController');
const attendanceController = require('../controllers/attendanceController');
const adminMiddleware = require('../middleware/adminMiddleware');

router.post('/register', authController.register);
router.post('/login', authController.login);

// Protected Routes
router.get('/courses', authMiddleware, courseController.getCourses);
router.post('/sessions/start', authMiddleware, attendanceController.startSession);
router.post('/attendance/mark', authMiddleware, attendanceController.markAttendance);
// Teacher approval endpoint (approves by device_signature)
router.post('/attendance/approve', authMiddleware, attendanceController.approveByTeacher);
// Teacher approval endpoint (approves by student id)
router.post('/attendance/approve_by_student', authMiddleware, attendanceController.approveByStudent);

// Resolve an advertised string to a student profile (teacher helpers)
const profilesController = require('../controllers/profilesController');
router.post('/profiles/resolve', authMiddleware, profilesController.resolveByAdvertised);
router.get('/profiles/me', authMiddleware, profilesController.me);

// Admin course CRUD (example skeleton)
const courseAdminController = require('../controllers/courseAdminController');
router.post('/admin/courses', authMiddleware, adminMiddleware, courseAdminController.createCourse);
router.put('/admin/courses/:id', authMiddleware, adminMiddleware, courseAdminController.updateCourse);
router.delete('/admin/courses/:id', authMiddleware, adminMiddleware, courseAdminController.deleteCourse);
router.get('/admin/courses', authMiddleware, adminMiddleware, courseAdminController.listCourses);

// Get enrolled students for a course (protected)
router.get('/courses/:id/students', authMiddleware, require('../controllers/courseController').getCourseStudents);
// Get number of sessions started for a course
router.get('/courses/:id/sessions_count', authMiddleware, require('../controllers/courseController').getSessionCount);

// Admin routes - require admin role where specified
const enrollmentController = require('../controllers/enrollmentController');

router.get('/courses/:id/enrollments', authMiddleware, enrollmentController.listEnrollments);
router.post('/courses/:id/enrollments', authMiddleware, enrollmentController.enroll);
router.delete('/courses/:id/enrollments', authMiddleware, adminMiddleware, enrollmentController.unenroll);
router.post('/courses/:id/enrollments/bulk/preview', authMiddleware, adminMiddleware, enrollmentController.bulkEnrollPreview);
router.post('/courses/:id/enrollments/bulk/commit', authMiddleware, adminMiddleware, enrollmentController.bulkEnrollCommit);

// Pending students management
const adminController = require('../controllers/adminController');
router.get('/admin/pending_students', authMiddleware, adminMiddleware, adminController.listPendingStudents);
router.post('/admin/pending_students/:id/approve', authMiddleware, adminMiddleware, adminController.approvePendingStudent);

// Audit logs
const auditController = require('../controllers/auditController');
router.get('/admin/audit_logs', authMiddleware, adminMiddleware, auditController.listLogs);

module.exports = router;