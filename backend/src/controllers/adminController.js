const supabase = require('../config/supabase');

// --- READ OPERATIONS ---

exports.getDashboardStats = async (req, res) => {
    try {
        const [students, teachers, courses, sessions] = await Promise.all([
            supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'student'),
            supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'teacher'),
            supabase.from('courses').select('*', { count: 'exact', head: true }),
            supabase.from('sessions').select('*', { count: 'exact', head: true }).eq('is_active', true)
        ]);

        res.json({
            total_students: students.count || 0,
            total_teachers: teachers.count || 0,
            total_courses: courses.count || 0,
            active_sessions: sessions.count || 0
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Dropdown Helper: Get all students
exports.getAllStudents = async (req, res) => {
    const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name, email, lms_id')
        .eq('role', 'student');
    
    if (error) return res.status(400).json({ error: error.message });
    res.json(data);
};

// Dropdown Helper: Get all teachers
exports.getAllTeachers = async (req, res) => {
    const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .eq('role', 'teacher');

    if (error) return res.status(400).json({ error: error.message });
    res.json(data);
};

// --- WRITE OPERATIONS ---

exports.createCourse = async (req, res) => {
    const { course_code, course_name, teacher_id } = req.body;

    // Validation: Ensure we are sending a UUID for teacher_id, not an email
    if (!course_code || !course_name || !teacher_id) {
        return res.status(400).json({ error: "Course Code, Name, and Teacher (ID) are required." });
    }

    try {
        const { data, error } = await supabase
            .from('courses')
            .insert([{ 
                course_code, 
                course_name, 
                teacher_id // UUID referencing profiles(id)
            }])
            .select()
            .single();

        if (error) {
            if (error.code === '23505') return res.status(409).json({ error: "Course Code already exists." });
            // This catches the trigger error if the UUID is not a teacher
            if (error.message.includes('not a Teacher')) return res.status(400).json({ error: "Selected user is not a Teacher." });
            return res.status(400).json({ error: error.message });
        }

        res.status(201).json({ message: "Course created successfully", course: data });
    } catch (err) {
        console.error("Create Course Error:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.enrollStudent = async (req, res) => {
    const { course_id, student_id } = req.body;

    if (!course_id || !student_id) {
        return res.status(400).json({ error: "Course and Student are required" });
    }

    try {
        const { data, error } = await supabase
            .from('enrollments')
            .insert([{ course_id, student_id }])
            .select();

        if (error) {
            if (error.code === '23505') return res.status(409).json({ error: "Student is already enrolled." });
            return res.status(400).json({ error: error.message });
        }

        res.status(201).json({ message: "Student enrolled successfully" });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// --- REPORTING ---

exports.getStudentStats = async (req, res) => {
    try {
        const { studentId } = req.params;
        
        const { data: enrollments } = await supabase
            .from('enrollments')
            .select('course:courses(id, course_code, course_name)')
            .eq('student_id', studentId);

        if (!enrollments) return res.json([]);

        const stats = await Promise.all(enrollments.map(async (enr) => {
            const course = enr.course;
            const { count: total } = await supabase.from('sessions').select('*', { count: 'exact', head: true }).eq('course_id', course.id);
            const { count: attended } = await supabase.from('attendance').select('session_id!inner(course_id)', { count: 'exact', head: true }).eq('student_id', studentId).eq('session_id.course_id', course.id);

            return {
                course_code: course.course_code,
                course_name: course.course_name,
                attendance_ratio: `${attended}/${total}`,
                percentage: total > 0 ? ((attended/total)*100).toFixed(1) : 0
            };
        }));

        res.json(stats);
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.downloadReport = async (req, res) => {
    try {
        const { courseId } = req.params;
        
        // 1. Fetch Data with Strict Filtering using !inner
        const { data, error } = await supabase
            .from('attendance')
            .select(`
                marked_at,
                session:sessions!inner(session_number, created_at, course_id),
                student:profiles(full_name, email, lms_id)
            `)
            .eq('session.course_id', courseId) // Filters by THIS course only
            .order('marked_at', { ascending: false });

        if (error) return res.status(400).json({ error: error.message });

        // 2. CHECK IF EMPTY
        if (!data || data.length === 0) {
            return res.status(404).json({ error: "No attendance records found for this course." });
        }

        // 3. Generate CSV
        const headers = "Student Name,Email,LMS ID,Session #,Date,Time Marked\n";
        const rows = data.map(row => {
            const date = new Date(row.session.created_at).toLocaleDateString();
            const time = new Date(row.marked_at).toLocaleTimeString();
            
            // Handle null profiles (if user deleted)
            const name = row.student?.full_name || "Unknown";
            const email = row.student?.email || "N/A";
            const lmsId = row.student?.lms_id || "N/A";

            return `"${name}","${email}","${lmsId}",${row.session.session_number},"${date}","${time}"`;
        }).join("\n");

        res.header('Content-Type', 'text/csv');
        res.attachment(`report_course_${courseId}.csv`);
        res.send(headers + rows);
    } catch (err) {
        console.error("Report Error:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};