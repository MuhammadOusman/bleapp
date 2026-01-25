const supabase = require('../config/supabase');

exports.register = async (req, res) => {
    try {
        // 1. MUST destructure full_name from req.body here
        const { email, password, device_signature, full_name } = req.body;

        if (!email || !password || !device_signature) {
            return res.status(400).json({ error: 'Email, password, and device_signature are required.' });
        }

        const testGmails = ['mhazibsheikh@gmail.com'];
        const isTestEmail = testGmails.includes(email);
        
        if (!email.endsWith('@dsu.edu.pk') && !isTestEmail) {
            return res.status(403).json({ error: 'Only DSU emails or authorized test emails are allowed.' });
        }

        const prefix = email.split('@')[0].toLowerCase();
        const isStudent = /^[a-z]+\d+$/.test(prefix) && !isTestEmail;
        const role = isStudent ? 'student' : 'teacher';

        let final_name = ""; 
        let lms_id = isStudent ? prefix : null;

        // 2. Logic to pick the name
        if (role === 'teacher') {
            const { data: masterTeacher } = await supabase
                .from('master_teachers')
                .select('*')
                .eq('email', email)
                .single();

            if (!masterTeacher) {
                return res.status(403).json({ error: "Teacher email not found in university records." });
            }
            final_name = masterTeacher.full_name; 
        } else {
            // FOR STUDENTS: Use the full_name from the request body
            // If full_name is missing in the JSON, it will fall back to the "Student CSD..." format
            final_name = full_name || `Student ${prefix.toUpperCase()}`;
        }

        const { data: authData, error: authError } = await supabase.auth.signUp({ email, password });
        if (authError) return res.status(400).json({ error: authError.message });

        if (authData.user) {
            const { error: profileError } = await supabase
                .from('profiles')
                .insert([{
                    id: authData.user.id,
                    email: email,
                    role: role,
                    device_signature: device_signature,
                    lms_id: lms_id,
                    full_name: final_name, // This now uses the variable we set above
                    blocked_signatures: []
                }]);

            if (profileError) return res.status(400).json({ error: profileError.message });

            return res.status(201).json({ message: 'Registration successful. Verify email OTP.' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.login = async (req, res) => {
    try {
        const { email, password, device_signature } = req.body;
        if (!device_signature) return res.status(400).json({ error: 'device_signature required' });

        const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });
        if (authError) return res.status(401).json({ error: 'Invalid credentials' });

        const { data: profile } = await supabase.from('profiles').select('*').eq('id', authData.user.id).single();

        if (profile.role === 'student') {
            if (profile.blocked_signatures?.includes(device_signature)) {
                return res.status(403).json({ error: "This device is permanently blocked." });
            }

            if (profile.device_signature && profile.device_signature !== device_signature) {
                const updatedBlocks = [...(profile.blocked_signatures || []), profile.device_signature];
                await supabase.from('profiles').update({ 
                    device_signature: device_signature, 
                    blocked_signatures: updatedBlocks 
                }).eq('id', profile.id);
            }
        }

        res.status(200).json({ token: authData.session.access_token, profile });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};