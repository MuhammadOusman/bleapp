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