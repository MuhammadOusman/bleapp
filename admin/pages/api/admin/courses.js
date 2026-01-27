import axios from 'axios';
export default async function handler(req, res) {
  const base = process.env.BACKEND_BASE || 'http://localhost:3000/api';
  try {
    const r = await axios.get(`${base}/courses`, { headers: { Authorization: `Bearer ${req.cookies.token || ''}` } });
    res.status(200).json(r.data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
