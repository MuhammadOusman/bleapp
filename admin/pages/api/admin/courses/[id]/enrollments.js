import axios from 'axios';
export default async function handler(req,res){
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  try{
    if(req.method === 'GET'){
      const r = await axios.get(`${base}/courses/${req.query.id}/enrollments` , { headers: { Authorization: `Bearer ${req.cookies.token || ''}` } });
      res.status(200).json(r.data);
    } else if(req.method === 'POST'){
      const r = await axios.post(`${base}/courses/${req.query.id}/enrollments`, req.body, { headers: { Authorization: `Bearer ${req.cookies.token || ''}` } });
      res.status(200).json(r.data);
    }
  }catch(e){ res.status(500).json({ error: e.message }); }
}
