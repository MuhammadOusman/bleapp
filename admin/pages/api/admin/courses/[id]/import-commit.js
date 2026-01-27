import axios from 'axios';
import cookie from 'cookie';

export default async function handler(req,res){
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  try{
    const token = cookie.parse(req.headers.cookie || '').token;
    const response = await axios.post(`${base}/courses/${req.query.id}/enrollments/bulk/commit`, req.body, { headers: { Authorization: token ? `Bearer ${token}` : '' } });
    res.status(200).json(response.data);
  }catch(e){
    res.status(500).json({ error: e.response?.data?.error || e.message });
  }
}