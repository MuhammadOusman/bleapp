/**
 * Usage: node scripts/create_admin.js admin@dsu.edu.pk "Admin123!"
 * This script creates a Supabase auth user (if missing) and a profiles entry with role 'admin'.
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPA_URL = process.env.SUPABASE_URL;
const SUPA_KEY = process.env.SUPABASE_SERVICE_KEY;
if (!SUPA_URL || !SUPA_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env');
  process.exit(1);
}

const supabase = createClient(SUPA_URL, SUPA_KEY, { auth: { persistSession: false } });

async function main() {
  const args = process.argv.slice(2);
  const email = args[0] || process.env.ADMIN_EMAIL || 'admin@dsu.edu.pk';
  const password = args[1] || process.env.ADMIN_PASSWORD || 'Admin123!';

  console.log('Creating admin:', email);

  // Check if profile already exists
  const { data: existingProfiles, error: pErr } = await supabase.from('profiles').select('*').ilike('email', email).limit(1);
  if (pErr) {
    console.error('Failed to query profiles', pErr);
    process.exit(1);
  }

  // Check if auth user exists
  let authUser = null;
  try {
    const { data: userByEmail, error: ue } = await supabase.auth.admin.getUserByEmail(email);
    if (ue && ue.message && ue.message.includes('User not found')) {
      // ignore
    } else if (ue) {
      console.error('getUserByEmail error', ue);
      process.exit(1);
    } else {
      authUser = userByEmail.user;
    }
  } catch (err) {
    // Some versions of supabase-js return differently; try listing users
    // fallback: try signUp (may fail if exists)
  }

  if (!authUser) {
    // Try admin create first (requires service role key), otherwise fall back to signUp
    try {
      const { data, error } = await supabase.auth.admin.createUser({ email, password, email_confirm: true });
      if (error) {
        // If not authorized for admin actions, try signUp with the public key
        if (error.status === 401 || (error.code && error.code === 'no_authorization')) {
          console.warn('Admin create not authorized; falling back to signUp:', error.message || error);
          const { data: sdata, error: serror } = await supabase.auth.signUp({ email, password });
          if (serror) {
            console.error('signUp fallback failed:', serror);
            process.exit(1);
          }
          authUser = sdata.user || sdata;
          console.log('Auth user created via signUp:', authUser?.id || '(no id returned yet)');
        } else {
          console.error('Error creating auth user:', error);
          process.exit(1);
        }
      } else {
        authUser = data.user || data;
        console.log('Auth user created: ', authUser.id);
      }
    } catch (err) {
      // If admin API isn't reachable or other error, attempt signUp
      console.warn('createUser exception, attempting signUp fallback:', err?.message || err);
      const { data: sdata, error: serror } = await supabase.auth.signUp({ email, password });
      if (serror) {
        console.error('signUp fallback failed:', serror);
        process.exit(1);
      }
      authUser = sdata.user || sdata;
      console.log('Auth user created via signUp:', authUser?.id || '(no id returned yet)');
    }
  } else {
    console.log('Auth user already exists:', authUser.id);
  }

  const profileId = authUser.id;
  if (existingProfiles && existingProfiles.length > 0) {
    const prof = existingProfiles[0];
    // Update profile to ensure name and role = 'teacher' (admin privileges granted via ADMIN_EMAILS env)
    const updates = { full_name: prof.full_name || 'Admin' };
    if (prof.role !== 'teacher') updates.role = 'teacher';
    const { error: upd } = await supabase.from('profiles').update(updates).eq('id', profileId);
    if (upd) {
      console.error('Failed updating profile', upd);
      process.exit(1);
    }
    console.log('Profile ensured (role=teacher) and updated');
  } else {
    // insert profile with role 'teacher' (admin access controlled by ADMIN_EMAILS env variable)
    const { data: ins, error: insErr } = await supabase.from('profiles').insert([{ id: profileId, email: email, full_name: 'Admin', role: 'teacher' }]).select().single();
    if (insErr) {
      console.error('Failed inserting profile', insErr);
      process.exit(1);
    }
    console.log('Profile inserted with id', ins.id, '(role=teacher)');
  }

  // Insert audit log
  try {
    await supabase.from('audit_logs').insert([{ actor_profile_id: profileId, action: 'create_admin', target_type: 'profile', target_id: profileId, details: { email } }]);
  } catch (e) {}

  console.log('Admin creation completed. You can now login with the credentials.');
}

main().catch(e => { console.error(e); process.exit(1); });
