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
                expires_at: new Date(Date.now() + 15000).toISOString() // Exactly 15s from now
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

        if (new Date() > new Date(session.expires_at)) {
            return res.status(410).json({ error: 'Session Expired (15s window closed)' });
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