import axios from 'axios';
import cookie from 'cookie';

export default async function handler(req,res){
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  const deviceSignature = process.env.ADMIN_DEVICE_SIGNATURE || 'admin-web';
  try{
    const body = { ...req.body, device_signature: deviceSignature };
    const r = await axios.post(`${base}/login`, body);
    const token = r.data?.token;
    if (token) {
      // Set HttpOnly cookie for the admin session
      res.setHeader('Set-Cookie', cookie.serialize('token', token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 // 1 hour
      }));
    }
    res.status(200).json(r.data);
  }catch(e){
    res.status(401).json({ error: e.response?.data?.error || e.message });
  }
}
