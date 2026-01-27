import cookie from 'cookie';
export default async function handler(req,res){
  // Clear token cookie
  res.setHeader('Set-Cookie', cookie.serialize('token', '', { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 0 }));
  res.status(200).json({ success: true });
}
