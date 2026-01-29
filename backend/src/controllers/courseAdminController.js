const supabase = require('../config/supabase');

// List all courses (for Admin Grid)
exports.listCourses = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('courses')
            .select('*, teacher:profiles!courses_teacher_id_fkey(full_name, email)') // Updated to use teacher_id FK
            .order('course_code', { ascending: true });

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Create Course (CRITICAL FIX: Uses teacher_id, not email)
exports.createCourse = async (req, res) => {
    const { course_code, course_name, teacher_id } = req.body;

    if (!course_code || !course_name || !teacher_id) {
        return res.status(400).json({ error: "Course Code, Name, and Teacher (ID) are required." });
    }

    try {
        const { data, error } = await supabase
            .from('courses')
            .insert([{ 
                course_code, 
                course_name, 
                teacher_id // Must be UUID from dropdown
            }])
            .select()
            .single();

        if (error) {
            if (error.code === '23505') return res.status(409).json({ error: "Course Code already exists." });
            if (error.message.includes('not a Teacher')) return res.status(400).json({ error: "Selected user is not a Teacher." });
            throw error;
        }

        res.status(201).json({ message: "Course created successfully", course: data });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Update Course
exports.updateCourse = async (req, res) => {
    const { id } = req.params;
    const { course_code, course_name, teacher_id } = req.body;

    try {
        const { data, error } = await supabase
            .from('courses')
            .update({ course_code, course_name, teacher_id })
            .eq('id', id)
            .select();

        if (error) throw error;
        res.json({ message: "Course updated", course: data });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Delete Course
exports.deleteCourse = async (req, res) => {
    const { id } = req.params;
    try {
        const { error } = await supabase.from('courses').delete().eq('id', id);
        if (error) throw error;
        res.json({ message: "Course deleted" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};