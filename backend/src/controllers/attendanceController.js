const supabase = require('../config/supabase');

exports.startSession = async (req, res) => {
    try {
        const { course_id, session_number } = req.body;

        const { data, error } = await supabase
            .from('sessions')
            .insert([{
                course_id,
                session_number,
                is_active: true,
                // No hard expiry: allow null expires_at for manual end
                expires_at: null
            }])
            .select().single();

        if (error) return res.status(400).json({ error: error.message });
        res.json({ session_id: data.id });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.markAttendance = async (req, res) => {
    try {
        const { session_id, device_signature } = req.body;
        const student = req.user; // From middleware

        if (student.role !== 'student') return res.status(403).json({ error: 'Only students can mark attendance' });

        // 1. Hardware Lock Verification (Prevent API Spoofing)
        if (student.device_signature !== device_signature) {
            return res.status(403).json({ error: 'Device signature mismatch. Proxy detected.' });
        }

        // 2. Session Expiry Check
        const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single();
        if (!session) return res.status(404).json({ error: 'Session not found' });

        if (session.expires_at && new Date() > new Date(session.expires_at)) {
            return res.status(410).json({ error: 'Session Expired' });
        }

        // 3. Mark Attendance
        const { error: markError } = await supabase.from('attendance').insert([{
            session_id,
            student_id: student.id
        }]);

        if (markError?.code === '23505') return res.status(200).json({ message: 'Already marked' });
        if (markError) return res.status(400).json({ error: markError.message });

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Teacher-only endpoint: approve a detected device by device_signature
exports.approveByTeacher = async (req, res) => {
    try {
        const { session_id, device_signature } = req.body;
        const teacher = req.user;

        if (teacher.role !== 'teacher') return res.status(403).json({ error: 'Only teachers can approve attendance' });
        if (!session_id || !device_signature) return res.status(400).json({ error: 'session_id and device_signature are required' });

        // Find session
        const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single();
        if (!session) return res.status(404).json({ error: 'Session not found' });
        if (session.expires_at && new Date() > new Date(session.expires_at)) return res.status(410).json({ error: 'Session Expired' });

        // Resolve student by device_signature
        const { data: profiles } = await supabase.from('profiles').select('*').eq('device_signature', device_signature).limit(1);
        const studentProfile = (profiles || [])[0];
        if (!studentProfile) {
            return res.status(404).json({ error: 'Student with given device signature not found' });
        }

        if (studentProfile.role !== 'student') {
            return res.status(400).json({ error: 'Target user is not a student' });
        }

        // Insert attendance record for the student (do NOT assume device_signature column exists)
        const { error: markError } = await supabase.from('attendance').insert([{
            session_id,
            student_id: studentProfile.id
        }]);

        if (markError?.code === '23505') return res.status(200).json({ message: 'Already marked' });
        if (markError) return res.status(400).json({ error: markError.message });

        return res.json({ success: true });
    } catch (err) {
        console.error('approveByTeacher error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// Teacher-only endpoint: approve attendance by student_id
exports.approveByStudent = async (req, res) => {
    try {
        const { session_id, student_id } = req.body;
        const teacher = req.user;

        if (teacher.role !== 'teacher') return res.status(403).json({ error: 'Only teachers can approve attendance' });
        if (!session_id || !student_id) return res.status(400).json({ error: 'session_id and student_id are required' });

        // Find session
        const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single();
        if (!session) return res.status(404).json({ error: 'Session not found' });
        if (session.expires_at && new Date() > new Date(session.expires_at)) return res.status(410).json({ error: 'Session Expired' });

        // Find student profile
        const { data: profiles } = await supabase.from('profiles').select('*').eq('id', student_id).limit(1);
        const studentProfile = (profiles || [])[0];
        if (!studentProfile) return res.status(404).json({ error: 'Student not found' });
        if (studentProfile.role !== 'student') return res.status(400).json({ error: 'Target user is not a student' });

        // Insert attendance
        const { error: markError } = await supabase.from('attendance').insert([{
            session_id,
            student_id: studentProfile.id
        }]);

        if (markError?.code === '23505') return res.status(200).json({ message: 'Already marked' });
        if (markError) return res.status(400).json({ error: markError.message });

        return res.json({ success: true });
    } catch (err) {
        console.error('approveByStudent error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};