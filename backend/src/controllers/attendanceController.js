const supabase = require('../config/supabase');

// 1. START SESSION
exports.startSession = async (req, res) => {
    try {
        const { course_id, session_number } = req.body;
        const user = req.user;

        // Security: Ensure the user is a teacher or admin
        if (user.role !== 'teacher' && user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized to start sessions' });
        }

        const { data, error } = await supabase
            .from('sessions')
            .insert([{
                course_id,
                session_number,
                is_active: true,
                expires_at: null // Manual end
            }])
            .select().single();

        if (error) return res.status(400).json({ error: error.message });
        res.json({ session_id: data.id });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 2. MARK ATTENDANCE (Student Only)
exports.markAttendance = async (req, res) => {
    try {
        const { session_id, device_signature } = req.body;
        const student = req.user; 

        if (student.role !== 'student') return res.status(403).json({ error: 'Only students can mark attendance' });

        // A. Hardware Lock
        if (student.device_signature !== device_signature) {
            return res.status(403).json({ error: 'Device signature mismatch. Proxy detected.' });
        }

        // B. Expiry Check
        const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single();
        if (!session) return res.status(404).json({ error: 'Session not found' });

        if (!session.is_active || (session.expires_at && new Date() > new Date(session.expires_at))) {
            return res.status(410).json({ error: 'Session Expired or Inactive' });
        }

        // C. Mark
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

// 3. APPROVE BY DEVICE (Teacher/Admin)
exports.approveByTeacher = async (req, res) => {
    try {
        const { session_id, device_signature } = req.body;
        const user = req.user;

        // Allow Admin to override
        if (user.role !== 'teacher' && user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        if (!session_id || !device_signature) return res.status(400).json({ error: 'Missing requirements' });

        const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single();
        if (!session) return res.status(404).json({ error: 'Session not found' });
        // Teachers can approve even if session is expired, so we don't strictly check expiry here

        // Find student
        const { data: profiles } = await supabase.from('profiles').select('*').eq('device_signature', device_signature).limit(1);
        const studentProfile = (profiles || [])[0];
        
        if (!studentProfile || studentProfile.role !== 'student') {
            return res.status(404).json({ error: 'Valid student not found for this device' });
        }

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

// 4. APPROVE BY STUDENT ID (Teacher/Admin)
exports.approveByStudent = async (req, res) => {
    try {
        const { session_id, student_id } = req.body;
        const user = req.user;

        if (user.role !== 'teacher' && user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        if (!session_id || !student_id) return res.status(400).json({ error: 'Missing requirements' });

        // Insert directly
        const { error: markError } = await supabase.from('attendance').insert([{
            session_id,
            student_id
        }]);

        if (markError?.code === '23505') return res.status(200).json({ message: 'Already marked' });
        if (markError) return res.status(400).json({ error: markError.message });

        return res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 5. END SESSION (Teacher/Admin) - **UPDATED FOR NEW SCHEMA**
exports.endSession = async (req, res) => {
    try {
        const sessionId = req.params.id;
        const user = req.user;

        if (user.role !== 'teacher' && user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });

        // Get Session
        const { data: session, error: sessionErr } = await supabase.from('sessions').select('*').eq('id', sessionId).single();
        if (sessionErr || !session) return res.status(404).json({ error: 'Session not found' });

        // If Teacher, verify ownership using TEACHER_ID (UUID) not email
        if (user.role === 'teacher') {
            const { data: course } = await supabase
                .from('courses')
                .select('id, teacher_id')
                .eq('id', session.course_id)
                .single();

            if (course && course.teacher_id !== user.id) {
                return res.status(403).json({ error: 'You do not own this course' });
            }
        }

        // Update
        const nowIso = new Date().toISOString();
        const { error: updateError } = await supabase
            .from('sessions')
            .update({ expires_at: nowIso, is_active: false })
            .eq('id', sessionId);

        if (updateError) return res.status(400).json({ error: updateError.message });

        return res.json({ success: true, ended_at: nowIso });
    } catch (err) {
        console.error('endSession error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 6. GET SESSION BY ID
exports.getSessionById = async (req, res) => {
    try {
        const { id } = req.params;
        const { data: session, error: sessionErr } = await supabase.from('sessions').select('*').eq('id', id).single();
        if (sessionErr || !session) return res.status(404).json({ error: 'Session not found' });

        const { data: course, error: courseErr } = await supabase.from('courses').select('id,course_name,course_code').eq('id', session.course_id).single();
        if (courseErr) return res.status(400).json({ error: courseErr.message });

        res.json({ session, course });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 7. GET ATTENDANCE LIST (Updated syntax for safety)
exports.getSessionAttendance = async (req, res) => {
    try {
        const { id } = req.params;
        
        // Use explicit join syntax for clarity
        const { data: rows, error } = await supabase
            .from('attendance')
            .select(`
                student_id,
                marked_at,
                student:profiles!attendance_student_id_fkey (id, full_name, email, lms_id)
            `)
            .eq('session_id', id);

        if (error) return res.status(400).json({ error: error.message });

        // Normalize
        const result = (rows || []).map(r => ({
            student_id: r.student_id,
            marked_at: r.marked_at,
            profile: r.student
        }));

        res.json({ attendees: result });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 8. [NEW FOR ADMIN] DELETE ATTENDANCE (Un-mark)
// Useful if a student was marked by mistake
exports.deleteAttendance = async (req, res) => {
    try {
        const { session_id, student_id } = req.body;
        const user = req.user;

        if (user.role !== 'admin' && user.role !== 'teacher') return res.status(403).json({ error: 'Unauthorized' });

        const { error } = await supabase
            .from('attendance')
            .delete()
            .eq('session_id', session_id)
            .eq('student_id', student_id);

        if (error) return res.status(400).json({ error: error.message });
        res.json({ success: true, message: 'Attendance record removed' });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// 9. DELETE SESSION (Teacher/Admin) with attendance cleanup
exports.deleteSession = async (req, res) => {
    const sessionId = req.params.id;
    const user = req.user;
    console.log('[deleteSession] requested', { sessionId, userId: user?.id, role: user?.role });

    try {
        if (user.role !== 'teacher' && user.role !== 'admin') {
            console.warn('[deleteSession] unauthorized role', user?.role);
            return res.status(403).json({ error: 'Unauthorized' });
        }

        const { data: session, error: sessionErr } = await supabase
            .from('sessions')
            .select('*')
            .eq('id', sessionId)
            .single();

        if (sessionErr || !session) {
            console.warn('[deleteSession] session not found', sessionErr);
            return res.status(404).json({ error: 'Session not found' });
        }

        // If teacher, ensure they own the course
        if (user.role === 'teacher') {
            const { data: course, error: courseErr } = await supabase
                .from('courses')
                .select('id, teacher_id')
                .eq('id', session.course_id)
                .single();

            if (courseErr) {
                console.error('[deleteSession] course fetch failed', courseErr);
                return res.status(400).json({ error: courseErr.message });
            }

            if (course && course.teacher_id !== user.id) {
                console.warn('[deleteSession] teacher does not own course', { courseId: course.id, teacherId: course.teacher_id, userId: user.id });
                return res.status(403).json({ error: 'You do not own this course' });
            }
        }

        const { error: attendanceErr } = await supabase
            .from('attendance')
            .delete()
            .eq('session_id', sessionId);

        if (attendanceErr) {
            console.error('[deleteSession] failed to delete attendance', attendanceErr);
            return res.status(400).json({ error: attendanceErr.message });
        }

        const { error: sessionDelErr } = await supabase
            .from('sessions')
            .delete()
            .eq('id', sessionId);

        if (sessionDelErr) {
            console.error('[deleteSession] failed to delete session', sessionDelErr);
            return res.status(400).json({ error: sessionDelErr.message });
        }

        console.log('[deleteSession] deleted session and attendance', { sessionId });
        return res.json({ success: true, message: 'Session deleted', session_id: sessionId });
    } catch (err) {
        console.error('[deleteSession] internal error', err);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};