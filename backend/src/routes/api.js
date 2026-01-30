const express = require('express');
const router = express.Router();

// Controllers
const authController = require('../controllers/authController');
const courseController = require('../controllers/courseController');
const attendanceController = require('../controllers/attendanceController');
const profilesController = require('../controllers/profilesController');
const courseAdminController = require('../controllers/courseAdminController'); // Logic moved here
const enrollmentController = require('../controllers/enrollmentController');   // Logic moved here
const adminController = require('../controllers/adminController');

// Middlewares
const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');

// ==========================================
// 1. AUTHENTICATION
// ==========================================
router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/profiles/me', authMiddleware, profilesController.me);

// Admin Login
router.post('/admin/login', authController.adminLogin);

// ==========================================
// 2. TEACHER & STUDENT (Core Features)
// ==========================================

// Courses
router.get('/courses', authMiddleware, courseController.getCourses);
router.get('/courses/:id/details', authMiddleware, courseController.getCourseDetails);
router.get('/courses/:id/students', authMiddleware, courseController.getCourseStudents);
router.get('/courses/:id/sessions', authMiddleware, courseController.getCourseSessions);
router.get('/courses/:id/sessions_count', authMiddleware, courseController.getSessionCount);

// Session Management
router.post('/sessions/start', authMiddleware, attendanceController.startSession);
router.post('/sessions/:id/end', authMiddleware, attendanceController.endSession);
router.delete('/sessions/:id', authMiddleware, attendanceController.deleteSession);
router.get('/sessions/:id', authMiddleware, attendanceController.getSessionById);

// Attendance
router.get('/sessions/:id/attendance', authMiddleware, attendanceController.getSessionAttendance);
router.post('/attendance/mark', authMiddleware, attendanceController.markAttendance);
router.post('/attendance/approve', authMiddleware, attendanceController.approveByTeacher);
router.post('/attendance/approve_by_student', authMiddleware, attendanceController.approveByStudent);

// Helpers
router.post('/profiles/resolve', authMiddleware, profilesController.resolveByAdvertised);

// ==========================================
// 3. ADMIN PANEL (Protected by adminMiddleware)
// ==========================================

// A. Dashboard & Reports
router.get('/admin/stats', authMiddleware, adminMiddleware, adminController.getDashboardStats);
router.get('/admin/reports/:courseId', authMiddleware, adminMiddleware, adminController.downloadReport);
router.get('/admin/student-stats/:studentId', authMiddleware, adminMiddleware, adminController.getStudentStats);
router.get('/admin/users/students', authMiddleware, adminMiddleware, adminController.getAllStudents);
router.get('/admin/users/teachers', authMiddleware, adminMiddleware, adminController.getAllTeachers);

// B. Course Management (CRUD)
router.get('/admin/courses', authMiddleware, adminMiddleware, courseAdminController.listCourses);
router.post('/admin/courses', authMiddleware, adminMiddleware, courseAdminController.createCourse);
router.put('/admin/courses/:id', authMiddleware, adminMiddleware, courseAdminController.updateCourse);
router.delete('/admin/courses/:id', authMiddleware, adminMiddleware, courseAdminController.deleteCourse);

// C. Enrollment Management
router.get('/admin/courses/:id/enrollments', authMiddleware, adminMiddleware, enrollmentController.listEnrollments);
router.post('/admin/courses/:id/enroll', authMiddleware, adminMiddleware, enrollmentController.enroll);
router.delete('/admin/courses/:id/unenroll', authMiddleware, adminMiddleware, enrollmentController.unenroll);

// Bulk Enrollments
router.post('/admin/courses/bulk-preview', authMiddleware, adminMiddleware, enrollmentController.bulkEnrollPreview);
router.post('/admin/courses/:id/bulk-commit', authMiddleware, adminMiddleware, enrollmentController.bulkEnrollCommit);

module.exports = router;