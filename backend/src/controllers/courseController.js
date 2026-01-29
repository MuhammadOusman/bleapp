const supabase = require('../config/supabase');

// 1. GET COURSES
// Logic:
// - If Teacher: Return only courses where teacher_id matches their ID.
// - If Student: Return courses they are enrolled in (via enrollments table).
// - If Admin: Return all courses.
exports.getCourses = async (req, res) => {
    try {
        const { role, id: userId } = req.user;

        // Base selection: Get course info + teacher details
        let query = supabase
            .from('courses')
            .select(`
                *,
                teacher:profiles!courses_teacher_id_fkey (
                    full_name,
                    email
                )
            `);

        // A. TEACHER LOGIC
        if (role === 'teacher') {
            query = query.eq('teacher_id', userId);
        }
        
        // B. STUDENT LOGIC
        // Note: If you want students to see ALL available courses (like a catalog), remove this block.
        // If you want them to only see courses they are taking, keep this.
        else if (role === 'student') {
            // We first find the course IDs from enrollments
            const { data: enrollments, error: enrError } = await supabase
                .from('enrollments')
                .select('course_id')
                .eq('student_id', userId);

            if (enrError) throw enrError;

            // Extract IDs: ['uuid-1', 'uuid-2']
            const courseIds = enrollments.map(e => e.course_id);
            
            // Filter the main course query by these IDs
            query = query.in('id', courseIds);
        }

        const { data, error } = await query;
        if (error) return res.status(400).json({ error: error.message });

        res.json(data);
    } catch (err) {
        console.error('getCourses Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 2. GET STUDENTS (For a specific course)
// Logic: Query 'enrollments' table, join with 'profiles'
exports.getCourseStudents = async (req, res) => {
    try {
        const { id } = req.params; // Course ID

        const { data, error } = await supabase
            .from('enrollments')
            .select(`
                enrolled_at,
                student:profiles!enrollments_student_fkey (
                    id,
                    full_name,
                    email,
                    lms_id
                )
            `)
            .eq('course_id', id);

        if (error) return res.status(400).json({ error: error.message });

        // Flatten the structure for the frontend
        const students = data.map(item => ({
            ...item.student,
            enrolled_at: item.enrolled_at
        }));

        res.json({ students });
    } catch (err) {
        console.error('getCourseStudents Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 3. GET SESSION COUNT
// Logic: Standard count query on sessions table
exports.getSessionCount = async (req, res) => {
    try {
        const { id } = req.params;
        const { count, error } = await supabase
            .from('sessions')
            .select('*', { count: 'exact', head: true })
            .eq('course_id', id);

        if (error) return res.status(400).json({ error: error.message });
        res.json({ count: count || 0 });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 4. GET SESSIONS (Teacher Dashboard)
// Logic: Get sessions + calculate attendance count for each
exports.getCourseSessions = async (req, res) => {
    try {
        const { id } = req.params;

        // Fetch all sessions for this course
        const { data: sessions, error: sessionsErr } = await supabase
            .from('sessions')
            .select('*')
            .eq('course_id', id)
            .order('created_at', { ascending: false });

        if (sessionsErr) return res.status(400).json({ error: sessionsErr.message });

        // Augment each session with its attendance count
        // Note: For very large datasets, a Supabase RPC function (SQL view) is faster, 
        // but this works fine for typical class sizes.
        const sessionsWithCounts = await Promise.all((sessions || []).map(async s => {
            const { count } = await supabase
                .from('attendance')
                .select('*', { count: 'exact', head: true })
                .eq('session_id', s.id);
            return { ...s, attendance_count: count || 0 };
        }));

        res.json({ sessions: sessionsWithCounts });
    } catch (err) {
        console.error('getCourseSessions error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 5. GET COURSE DETAILS (Header Stats)
// Logic: Single join to get Teacher details, then aggregate stats
exports.getCourseDetails = async (req, res) => {
    try {
        const { id } = req.params;

        // 1. Fetch Course & Teacher Profile in one go
        const { data: course, error: courseErr } = await supabase
            .from('courses')
            .select(`
                *,
                teacher:profiles!courses_teacher_id_fkey (
                    id,
                    full_name,
                    email
                )
            `)
            .eq('id', id)
            .single();

        if (courseErr || !course) return res.status(404).json({ error: 'Course not found' });

        // 2. Get Total Sessions Count
        const { count: sessionCount } = await supabase
            .from('sessions')
            .select('*', { count: 'exact', head: true })
            .eq('course_id', id);

        // 3. Get Total Attendance Count (All students across all sessions)
        // We use a subquery approach via the JS client
        const { count: attendanceCount } = await supabase
            .from('attendance')
            .select('id', { count: 'exact', head: true })
            .in('session_id', (
                 // Subquery: Get all session IDs for this course
                 supabase.from('sessions').select('id').eq('course_id', id)
            ));

        res.json({
            course: {
                id: course.id,
                course_code: course.course_code,
                course_name: course.course_name,
            },
            teacher: course.teacher, // Object: { full_name, email, id }
            total_sessions: sessionCount || 0,
            total_attendance: attendanceCount || 0
        });

    } catch (err) {
        console.error('getCourseDetails error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};