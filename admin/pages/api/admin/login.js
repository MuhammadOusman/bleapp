import axios from 'axios';
export default async function handler(req,res){
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  try{
    const r = await axios.post(`${base}/login`, req.body);
    // set cookie with token (HttpOnly) from backend's response body.token
    // For simplicity here we return token to client; in production, implement secure cookie
    res.status(200).json(r.data);
  }catch(e){ res.status(401).json({ error: e.response?.data?.error || e.message }); }
}
