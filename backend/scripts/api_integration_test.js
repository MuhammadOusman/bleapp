require('dotenv').config();
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;
const BASE = process.env.TEST_BASE || 'http://localhost:3000/api';

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('Supabase env vars missing. Set SUPABASE_URL and SUPABASE_SERVICE_KEY in backend/.env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, { auth: { persistSession: false } });

async function post(path, body, token) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: Object.assign({ 'Content-Type': 'application/json' }, token ? { 'Authorization': `Bearer ${token}` } : {}),
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) {}
  return { status: res.status, body: json || text };
}

async function main() {
  console.log('Starting integration test against', BASE);

  // 1) Register student
  const student = { email: 'csd231002-test@dsu.edu.pk', password: 'Password123!', device_signature: 'student-sig-1', full_name: 'Test Student' };
  console.log('Registering student...');
  const regS = await post('/register', student);
  console.log('Register student:', regS.status, regS.body);

  // 2) Login student
  console.log('Logging in student...');
  const loginS = await post('/login', { email: student.email, password: student.password, device_signature: student.device_signature });
  console.log('Login student:', loginS.status, loginS.body);
  const studentToken = loginS.body && loginS.body.token ? loginS.body.token : null;

  // 3) Create teacher using admin (service key) if register fails
  const teacher = { email: 'testteacher1@dsu.edu.pk', password: 'Password123!', device_signature: 'teacher-sig-1', full_name: 'Test Teacher' };
  console.log('Ensuring teacher exists (admin)...');

  // try admin create user
  let teacherUser = null;
  try {
    const { data: created, error } = await supabase.auth.admin.createUser({ email: teacher.email, password: teacher.password });
    if (error) {
      console.warn('admin.createUser error (may already exist):', error.message || error);
    } else {
      teacherUser = created;
      console.log('Created teacher user via admin.createUser');
    }
  } catch (e) {
    console.warn('admin.createUser threw', e.message || e);
  }

  // Ensure profile exists
  try {
    const { data: profilesExisting } = await supabase.from('profiles').select('*').eq('email', teacher.email).limit(1);
    if (!profilesExisting || profilesExisting.length === 0) {
      const { error: insertErr } = await supabase.from('profiles').insert([{ id: teacherUser ? teacherUser.id : undefined, email: teacher.email, role: 'teacher', device_signature: teacher.device_signature, full_name: teacher.full_name }]);
      if (insertErr) console.warn('Insert teacher profile error:', insertErr.message || insertErr);
      else console.log('Inserted teacher profile');
    } else {
      console.log('Teacher profile already present');
    }
  } catch (e) {
    console.warn('Error ensuring teacher profile', e.message || e);
  }

  // 4) Login teacher (if possible via auth.signInWithPassword)
  console.log('Logging in teacher...');
  const loginT = await post('/login', { email: teacher.email, password: teacher.password, device_signature: teacher.device_signature });
  console.log('Login teacher:', loginT.status, loginT.body);
  const teacherToken = loginT.body && loginT.body.token ? loginT.body.token : null;

  if (!teacherToken) {
    console.error('Teacher login failed, cannot proceed with teacher-only flows');
  }

  // 5) Create a test course via admin so we have a valid course_id
  console.log('Creating test course via supabase admin...');
  const courseInsert = await supabase.from('courses').insert([{ name: 'Test Course', course_code: 'TEST101' }]).select().single();
  console.log('Course insert:', courseInsert.error ? courseInsert.error : 'ok');
  const courseId = courseInsert.data ? courseInsert.data.id : null;
  if (!courseId) {
    console.error('Failed to create course; aborting');
    process.exit(1);
  }

  // 6) Teacher starts session
  console.log('Teacher starting session...');
  const startRes = await post('/sessions/start', { course_id: courseId, session_number: 1 }, teacherToken);
  console.log('Start session:', startRes.status, startRes.body);
  const sessionId = startRes.body && startRes.body.session_id ? startRes.body.session_id : null;
  if (!sessionId) { console.error('Start session failed'); process.exit(1); }

  // 7) Test profiles/resolve with device_signature
  console.log('Testing profiles/resolve with device_signature...');
  const resolveRes = await post('/profiles/resolve', { advertised: 'student-sig-1' }, teacherToken);
  console.log('Resolve by advertised:', resolveRes.status, resolveRes.body);

  // 8) Student marks attendance
  console.log('Student marking attendance...');
  const markRes = await post('/attendance/mark', { session_id: sessionId, device_signature: student.device_signature }, studentToken);
  console.log('Student mark:', markRes.status, markRes.body);

  // 9) Teacher approves by signature
  console.log('Teacher approving attendance by signature...');
  const apprRes = await post('/attendance/approve', { session_id: sessionId, device_signature: student.device_signature }, teacherToken);
  console.log('Teacher approve:', apprRes.status, apprRes.body);

  console.log('Integration test complete');
}

main().catch(err => { console.error('Test failed', err); process.exit(1); });
