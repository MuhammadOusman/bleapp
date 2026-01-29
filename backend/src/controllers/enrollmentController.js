const supabase = require('../config/supabase');

// List Enrollments for a Course
exports.listEnrollments = async (req, res) => {
    const { id } = req.params; // courseId
    try {
        const { data, error } = await supabase
            .from('enrollments')
            .select('id, enrolled_at, student:profiles(id, full_name, email, lms_id)')
            .eq('course_id', id);

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Enroll Student (Single)
exports.enroll = async (req, res) => {
    // Logic handles both params (if used in URL) or body
    const course_id = req.params.id || req.body.course_id; 
    const { student_id } = req.body;

    if (!course_id || !student_id) {
        return res.status(400).json({ error: "Course ID and Student ID are required" });
    }

    try {
        // Check if student exists and is valid role
        const { data: student } = await supabase.from('profiles').select('role').eq('id', student_id).single();
        if (!student || student.role !== 'student') {
            return res.status(400).json({ error: "Invalid Student ID" });
        }

        const { data, error } = await supabase
            .from('enrollments')
            .insert([{ course_id, student_id }])
            .select();

        if (error) {
            if (error.code === '23505') return res.status(409).json({ error: "Student is already enrolled." });
            throw error;
        }

        res.status(201).json({ message: "Student enrolled successfully" });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Unenroll Student
exports.unenroll = async (req, res) => {
    const { id } = req.params; // This is the COURSE ID based on route: /admin/courses/:id/unenroll
    const { student_id } = req.body; 

    try {
        const { error } = await supabase
            .from('enrollments')
            .delete()
            .eq('course_id', id)
            .eq('student_id', student_id);

        if (error) throw error;
        res.json({ message: "Student unenrolled" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Bulk Preview (Placeholder to prevent crash)
exports.bulkEnrollPreview = async (req, res) => {
    res.status(501).json({ message: "Bulk Preview Not Implemented Yet" });
};

// Bulk Commit (Placeholder to prevent crash)
exports.bulkEnrollCommit = async (req, res) => {
    res.status(501).json({ message: "Bulk Commit Not Implemented Yet" });
};