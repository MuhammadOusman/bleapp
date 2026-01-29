const supabase = require('../config/supabase');

exports.getCourses = async (req, res) => {
    try {
        const { role, email } = req.user;
        let query = supabase.from('courses').select('*');

        if (role === 'teacher') {
            query = query.eq('teacher_email', email);
        }

        const { data, error } = await query;
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