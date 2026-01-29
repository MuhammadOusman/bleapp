const supabase = require('../config/supabase');

// --- REGISTRATION (Mobile App Only) ---
// Strictly creates 'student' or 'teacher' roles. Never 'admin'.
exports.register = async (req, res) => {
    try {
        const { email, password, device_signature, full_name } = req.body;

        if (!email || !password || !device_signature) {
            return res.status(400).json({ error: 'Email, password, and device_signature are required.' });
        }

        // Domain Logic
        const testGmails = ['mhazibsheikh@gmail.com'];
        const isTestEmail = testGmails.includes(email);
        
        if (!email.endsWith('@dsu.edu.pk') && !isTestEmail) {
            return res.status(403).json({ error: 'Only DSU emails or authorized test emails are allowed.' });
        }

        const prefix = email.split('@')[0].toLowerCase();
        const isStudent = /^[a-z]+\d+$/.test(prefix) && !isTestEmail;
        
        // FORCE ROLE: Only Student or Teacher
        const role = isStudent ? 'student' : 'teacher';

        // Name Logic
        let final_name = full_name;
        if (!final_name) {
            final_name = role === 'teacher' 
                ? `Instructor ${prefix.toUpperCase()}` 
                : `Student ${prefix.toUpperCase()}`;
        }
        
        let lms_id = isStudent ? prefix : null;

        const { data: authData, error: authError } = await supabase.auth.signUp({ email, password });
        if (authError) return res.status(400).json({ error: authError.message });

        if (authData.user) {
            const { error: profileError } = await supabase
                .from('profiles')
                .insert([{
                    id: authData.user.id,
                    email: email,
                    role: role, // 'admin' is IMPOSSIBLE here
                    device_signature: device_signature,
                    lms_id: lms_id,
                    full_name: final_name,
                    blocked_signatures: []
                }]);

            if (profileError) return res.status(400).json({ error: profileError.message });
            return res.status(201).json({ message: 'Registration successful. Verify email OTP.' });
        }
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

// --- APP LOGIN (Mobile Only) ---
// Blocks Admins from logging in here
exports.login = async (req, res) => {
    try {
        const { email, password, device_signature } = req.body;
        
        // App requires device signature
        if (!device_signature) return res.status(400).json({ error: 'device_signature required' });

        const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });
        if (authError) return res.status(401).json({ error: 'Invalid credentials' });

        const { data: profile } = await supabase.from('profiles').select('*').eq('id', authData.user.id).single();

        if (!profile) return res.status(404).json({ error: "Profile not found" });

        // SECURITY: Prevent Admin from using the App Login
        if (profile.role === 'admin') {
            return res.status(403).json({ error: "Admins must use the Web Portal." });
        }

        // Student Security Checks
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

// --- ADMIN LOGIN (Web Panel Only) ---
// Blocks Students and Teachers
exports.adminLogin = async (req, res) => {
    try {
        const { email, password } = req.body;
        // No device_signature check needed for web admin usually

        const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });
        if (authError) return res.status(401).json({ error: 'Invalid credentials' });

        const { data: profile } = await supabase.from('profiles').select('*').eq('id', authData.user.id).single();

        if (!profile) return res.status(404).json({ error: "Profile not found" });

        // SECURITY: STRICTLY ADMIN ONLY
        if (profile.role !== 'admin') {
            return res.status(403).json({ error: "Access Denied: You are not an Admin." });
        }

        res.status(200).json({ 
            message: "Admin Login Successful",
            token: authData.session.access_token, 
            profile 
        });
    } catch (err) {
        console.error("Admin Login Error:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};