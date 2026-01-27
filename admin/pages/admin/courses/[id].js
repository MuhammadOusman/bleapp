import axios from 'axios';
import { useState, useEffect } from 'react';
import useSWR from 'swr';
const fetcher = url => axios.get(url).then(r => r.data);

export default function CourseDetail({ query }) {
  const courseId = typeof window !== 'undefined' ? window.location.pathname.split('/').pop() : query?.id;
  const { data, error } = useSWR(`/api/admin/courses/${courseId}`, fetcher);
  const [enrollments, setEnrollments] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [email, setEmail] = useState('');
  const [lms, setLms] = useState('');

  useEffect(()=>{
    if(!courseId) return;
    async function load(){
      const r = await axios.get(`/api/admin/courses/${courseId}/enrollments`);
      setEnrollments(r.data.data || []);
    }
    load();
  }, [courseId]);

  const submitEnroll = async () => {
    try{
      await axios.post(`/api/admin/courses/${courseId}/enrollments`, { email, lms_id: lms });
      // refresh
      const r = await axios.get(`/api/admin/courses/${courseId}/enrollments`);
      setEnrollments(r.data.data || []);
      setShowModal(false);
    }catch(e){ alert(e.response?.data?.error || e.message); }
  };

  if(error) return <div>Error loading course</div>;
  if(!data) return <div>Loading...</div>;

  return (
    <div style={{padding:20}}>
      <h1>{data.course_name} ({data.course_code})</h1>
      <p>Teacher: {data.teacher_email}</p>
      <button onClick={()=>setShowModal(true)}>Enroll Student</button>
      <h2>Enrollments</h2>
      <table>
        <thead><tr><th>Name</th><th>Email</th><th>LMS ID</th><th>At</th></tr></thead>
        <tbody>
          {enrollments.map(e => (
            <tr key={e.student_id}><td>{e.profiles.full_name}</td><td>{e.profiles.email}</td><td>{e.profiles.lms_id}</td><td>{e.enrolled_at}</td></tr>
          ))}
        </tbody>
      </table>

      {showModal && (
        <div style={{position:'fixed',left:0,top:0,right:0,bottom:0, background:'rgba(0,0,0,0.2)'}}>
          <div style={{background:'#fff', margin:'40px auto', padding:20, width:400}}>
            <h3>Enroll Student</h3>
            <div><input placeholder="email" value={email} onChange={e=>setEmail(e.target.value)} /></div>
            <div><input placeholder="lms_id" value={lms} onChange={e=>setLms(e.target.value)} /></div>
            <div><button onClick={submitEnroll}>Enroll</button> <button onClick={()=>setShowModal(false)}>Cancel</button></div>
          </div>
        </div>
      )}
    </div>
  );
}
