import useSWR from 'swr';
import axios from 'axios';

const fetcher = url => axios.get(url).then(r => r.data);

export default function CoursesPage() {
  const { data, error } = useSWR('/api/admin/courses', fetcher);
  if (error) return <div>Failed to load</div>;
  if (!data) return <div>Loading...</div>;
  return (
    <div style={{ padding: 20 }}>
      <h1>Courses</h1>
      <table>
        <thead><tr><th>Course Code</th><th>Name</th><th>Teacher</th></tr></thead>
        <tbody>
          {data.data.map(c => (
            <tr key={c.id}><td>{c.course_code}</td><td>{c.course_name}</td><td>{c.teacher_email}</td></tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
