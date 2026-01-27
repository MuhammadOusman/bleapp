import axios from 'axios';
import cookie from 'cookie';
export default async function handler(req,res){
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  try{
    const token = cookie.parse(req.headers.cookie || '').token;
    if(!token) return res.status(401).json({ error: 'No token' });
    const r = await axios.get(`${base}/profiles/me`, { headers: { Authorization: `Bearer ${token}` } });
    res.status(200).json(r.data);
  }catch(e){ res.status(401).json({ error: e.response?.data?.error || e.message }); }
}