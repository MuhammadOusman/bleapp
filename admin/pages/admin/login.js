import axios from 'axios';
import { useState } from 'react';

export default function Login() {
  const [email,setEmail] = useState('');
  const [pass,setPass] = useState('');
  const [err,setErr] = useState(null);

  async function submit(e){
    e.preventDefault();
    try{
      const r = await axios.post('/api/admin/login', { email, password: pass });
      // server will set cookie; redirect
      window.location.href = '/admin/courses';
    }catch(e){ setErr(e.response?.data?.error || e.message); }
  }

  return (
    <div style={{padding:20}}>
      <h1>Admin Login</h1>
      <form onSubmit={submit}>
        <div><input value={email} onChange={e=>setEmail(e.target.value)} placeholder="email"/></div>
        <div><input value={pass} onChange={e=>setPass(e.target.value)} placeholder="password" type="password"/></div>
        <div><button type="submit">Login</button></div>
        {err && <div style={{color:'red'}}>{err}</div>}
      </form>
    </div>
  );
}
