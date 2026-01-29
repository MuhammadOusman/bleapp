const supabase = require('../config/supabase');

exports.getCourses = async (req, res) => {
    try {
        const { role, email, id: userId } = req.user;

        // Teachers: prefer matching by teacher_id (UUID) if present, fall back to teacher_email
        if (role === 'teacher') {
            // Try teacher_id -> supports new schema where courses.teacher_id stores teacher profile id
            const { data: byId, error: byIdErr } = await supabase.from('courses').select('*').eq('teacher_id', userId);
            if (byIdErr) {
                console.debug('getCourses: teacher_id query error, falling back to teacher_email', byIdErr.message);
            } else if (byId && byId.length > 0) {
                return res.json(byId);
            }

            // Fallback: resolve the teacher profile by email and query by teacher_id to avoid relying on a possibly-missing teacher_email column
            const { data: teacherProfile, error: profileErr } = await supabase.from('profiles').select('id').eq('email', email).limit(1).single();
            if (profileErr || !teacherProfile) {
                // No profile found for the teacher email - return empty list
                console.debug('getCourses: teacher profile not found for email, returning empty');
                return res.json([]);
            }
            const teacherId = teacherProfile.id;
            const { data: byTeacherId, error: byTeacherIdErr } = await supabase.from('courses').select('*').eq('teacher_id', teacherId);
            if (byTeacherIdErr) {
                console.error('getCourses: teacher_id query error', byTeacherIdErr.message);
                return res.status(400).json({ error: byTeacherIdErr.message });
            }
            return res.json(byTeacherId || []);
        }

        // Non-teacher: return all courses (or adjust later for enrollment filtering)
        const { data, error } = await supabase.from('courses').select('*');
        if (error) return res.status(400).json({ error: error.message });

        res.json(data);
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Returns the list of students for the course. NOTE: schema currently does not have course enrollments,
// so this returns all known student profiles (role='student'). Later this should be filtered by explicit
// enrollment data when available.
exports.getCourseStudents = async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase.from('profiles').select('id,full_name,email,lms_id').eq('role', 'student');
        if (error) return res.status(400).json({ error: error.message });
        res.json({ students: data });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Returns the number of sessions that have been started for a course
exports.getSessionCount = async (req, res) => {
  try {
    const { id } = req.params;
    const { count, error } = await supabase.from('sessions').select('*', { count: 'exact', head: true }).eq('course_id', id);
    if (error) return res.status(400).json({ error: error.message });
    res.json({ count: count || 0 });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

// Get sessions for a course (used by teacher dashboard)
exports.getCourseSessions = async (req, res) => {
    try {
        const { id } = req.params;
        const { data: sessions, error: sessionsErr } = await supabase.from('sessions').select('*').eq('course_id', id).order('created_at', { ascending: false });
        if (sessionsErr) return res.status(400).json({ error: sessionsErr.message });

        // For each session, fetch attendance count (simple implementation)
        const sessionsWithCounts = await Promise.all((sessions || []).map(async s => {
            const { count } = await supabase.from('attendance').select('*', { count: 'exact', head: true }).eq('session_id', s.id);
            return { ...s, attendance_count: count || 0 };
        }));

        res.json({ sessions: sessionsWithCounts });
    } catch (err) {
        console.error('getCourseSessions error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Get course details: teacher profile, totals
exports.getCourseDetails = async (req, res) => {
    try {
        const { id } = req.params;
        const { data: course, error: courseErr } = await supabase.from('courses').select('*').eq('id', id).single();
        if (courseErr || !course) return res.status(404).json({ error: 'Course not found' });

        // Teacher profile (if teacher_email exists)
        let teacher = null;
        if (course.teacher_email) {
            const { data: t, error: tErr } = await supabase.from('profiles').select('id,full_name,email').eq('email', course.teacher_email).limit(1).single();
            if (!tErr && t) teacher = t;
        }

        // Session count
        const { count: sessionCount } = await supabase.from('sessions').select('*', { count: 'exact', head: true }).eq('course_id', id);

        // Attendance total across all sessions
        const { data: sessions } = await supabase.from('sessions').select('id').eq('course_id', id);
        let attendanceCount = 0;
        if (sessions && sessions.length > 0) {
            const ids = sessions.map(s => s.id);
            const { count: attCount } = await supabase.from('attendance').select('*', { count: 'exact', head: true }).in('session_id', ids);
            attendanceCount = attCount || 0;
        }

        res.json({ course, teacher, total_sessions: sessionCount || 0, total_attendance: attendanceCount });
    } catch (err) {
        console.error('getCourseDetails error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};