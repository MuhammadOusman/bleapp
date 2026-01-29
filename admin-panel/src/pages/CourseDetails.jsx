import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api, { downloadCourseReport } from '../services/api';
import toast from 'react-hot-toast';
import { Download, UserPlus, Calendar, Users, ArrowLeft, X, UserMinus, ChevronRight } from 'lucide-react';

const CourseDetails = () => {
  const { id } = useParams();
  const [course, setCourse] = useState(null);
  const [activeTab, setActiveTab] = useState('students');
  const [enrollments, setEnrollments] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [isEnrollModalOpen, setIsEnrollModalOpen] = useState(false);
  const [allStudents, setAllStudents] = useState([]);
  const [selectedStudentId, setSelectedStudentId] = useState('');

  useEffect(() => {
    fetchCourseDetails();
    fetchEnrollments();
    fetchSessions();
  }, [id]);

  const fetchCourseDetails = () => api.get(`/courses/${id}/details`).then(res => setCourse(res.data)).catch(console.error);
  const fetchEnrollments = () => api.get(`/admin/courses/${id}/enrollments`).then(({ data }) => setEnrollments(data || [])).catch(console.error);
  const fetchSessions = () => api.get(`/courses/${id}/sessions`).then(({ data }) => setSessions(data.sessions)).catch(console.error);

  const loadStudentsForDropdown = async () => {
    if (allStudents.length === 0) {
      const { data } = await api.get('/admin/users/students');
      setAllStudents(data);
    }
    setIsEnrollModalOpen(true);
  };

  const handleEnroll = async (e) => {
    e.preventDefault();
    if (!selectedStudentId) return;
    try {
      await api.post(`/admin/courses/${id}/enroll`, { student_id: selectedStudentId });
      toast.success('Student Enrolled');
      setIsEnrollModalOpen(false);
      setSelectedStudentId('');
      fetchEnrollments();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Enrollment Failed');
    }
  };

  const handleUnenroll = async (studentId) => {
    if(!window.confirm("Remove this student?")) return;
    try {
      await api.delete(`/admin/courses/${id}/unenroll`, { data: { student_id: studentId } });
      toast.success('Student Removed');
      fetchEnrollments();
    } catch (err) {
      toast.error('Failed to unenroll');
    }
  };

  const handleDownloadReport = async () => {
    if (sessions.length === 0 && enrollments.length === 0) {
      toast.error("No data available to export.");
      return;
    }
    toast.promise(downloadCourseReport(id), {
      loading: 'Generating CSV...',
      success: 'Downloaded!',
      error: 'Failed to download',
    });
  };

  if (!course) return <div className="p-10 text-slate-500 dark:text-gray-400">Loading...</div>;

  return (
    <div className="fade-in">
      <div className="mb-8">
        <Link to="/courses" className="text-slate-500 dark:text-gray-400 flex items-center gap-2 mb-4 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
          <ArrowLeft size={18} /> Back to Courses
        </Link>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-4">
          <div>
            <h1 className="text-3xl font-bold text-slate-800 dark:text-white">{course.course.course_name}</h1>
            <div className="flex items-center gap-3 mt-2">
              <span className="bg-slate-100 dark:bg-gray-700 text-slate-600 dark:text-gray-300 px-3 py-1 rounded-full text-sm font-mono border border-slate-200 dark:border-gray-600">
                {course.course.course_code}
              </span>
              <span className="text-slate-500 dark:text-gray-400 text-sm">
                Instructor: <span className="font-semibold text-slate-700 dark:text-gray-200">{course.teacher?.full_name || 'Unassigned'}</span>
              </span>
            </div>
          </div>
          <button 
            onClick={handleDownloadReport}
            className="flex items-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white px-5 py-2.5 rounded-lg transition shadow-md"
          >
            <Download size={18} /> Export CSV
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 min-h-[500px] transition-colors duration-300">
        <div className="flex border-b border-gray-100 dark:border-gray-700">
          <button
            onClick={() => setActiveTab('students')}
            className={`flex items-center gap-2 px-8 py-4 font-medium transition-all relative ${
              activeTab === 'students' ? 'text-blue-600 dark:text-blue-400' : 'text-slate-500 dark:text-gray-400 hover:text-slate-700 dark:hover:text-gray-200'
            }`}
          >
            <Users size={18} /> Enrolled Students ({enrollments.length})
            {activeTab === 'students' && <div className="absolute bottom-0 left-0 w-full h-1 bg-blue-600 dark:bg-blue-400 rounded-t-full"></div>}
          </button>
          <button
            onClick={() => setActiveTab('sessions')}
            className={`flex items-center gap-2 px-8 py-4 font-medium transition-all relative ${
              activeTab === 'sessions' ? 'text-blue-600 dark:text-blue-400' : 'text-slate-500 dark:text-gray-400 hover:text-slate-700 dark:hover:text-gray-200'
            }`}
          >
            <Calendar size={18} /> Sessions ({sessions.length})
            {activeTab === 'sessions' && <div className="absolute bottom-0 left-0 w-full h-1 bg-blue-600 dark:bg-blue-400 rounded-t-full"></div>}
          </button>
        </div>

        <div className="p-6">
          {activeTab === 'students' && (
            <>
              <div className="flex justify-end mb-6">
                <button 
                  onClick={loadStudentsForDropdown}
                  className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-semibold transition shadow-sm"
                >
                  <UserPlus size={16} /> Enroll New Student
                </button>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead className="bg-slate-50 dark:bg-gray-700/50">
                    <tr>
                      <th className="p-4 font-semibold text-slate-600 dark:text-gray-300 rounded-l-lg">Name</th>
                      <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">Email</th>
                      <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">LMS ID</th>
                      <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">Enrolled Date</th>
                      <th className="p-4 font-semibold text-slate-600 dark:text-gray-300 text-right rounded-r-lg">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                    {enrollments.map((record) => (
                      <tr key={record.id} className="hover:bg-slate-50 dark:hover:bg-gray-700/30 transition-colors">
                        <td className="p-4 font-medium">
                          <Link to={`/students/${record.student?.id}`} className="text-slate-800 dark:text-white hover:text-blue-600 dark:hover:text-blue-400 hover:underline">
                            {record.student?.full_name}
                          </Link>
                        </td>
                        <td className="p-4 text-slate-600 dark:text-gray-400">{record.student?.email}</td>
                        <td className="p-4 text-slate-600 dark:text-gray-400 font-mono text-sm">{record.student?.lms_id}</td>
                        <td className="p-4 text-slate-600 dark:text-gray-400">{new Date(record.enrolled_at).toLocaleDateString()}</td>
                        <td className="p-4 text-right">
                          <button onClick={() => handleUnenroll(record.student?.id)} className="text-slate-400 hover:text-red-600 dark:hover:text-red-400 transition bg-transparent p-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20">
                            <UserMinus size={18} />
                          </button>
                        </td>
                      </tr>
                    ))}
                    {enrollments.length === 0 && <tr><td colSpan="5" className="p-12 text-center text-slate-400 dark:text-gray-500">No students currently enrolled</td></tr>}
                  </tbody>
                </table>
              </div>
            </>
          )}

          {activeTab === 'sessions' && (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead className="bg-slate-50 dark:bg-gray-700/50">
                  <tr>
                    <th className="p-4 font-semibold text-slate-600 dark:text-gray-300 rounded-l-lg">Session</th>
                    <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">Date</th>
                    <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">Status</th>
                    <th className="p-4 font-semibold text-slate-600 dark:text-gray-300">Attendance</th>
                    <th className="p-4 rounded-r-lg"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                  {sessions.map(sess => (
                    <tr key={sess.id} className="hover:bg-slate-50 dark:hover:bg-gray-700/30 transition-colors group">
                      <td className="p-4 font-bold text-slate-800 dark:text-white">Session {sess.session_number}</td>
                      <td className="p-4 text-slate-600 dark:text-gray-400">{new Date(sess.created_at).toLocaleString()}</td>
                      <td className="p-4">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold ${sess.is_active ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400'}`}>
                          {sess.is_active ? 'ACTIVE' : 'CLOSED'}
                        </span>
                      </td>
                      <td className="p-4 font-mono text-blue-600 dark:text-blue-400 font-bold">{sess.attendance_count} Present</td>
                      <td className="p-4 text-right">
                        <Link to={`/sessions/${sess.id}`} className="inline-flex items-center gap-1 text-sm text-blue-600 dark:text-blue-400 hover:underline opacity-0 group-hover:opacity-100 transition-opacity">
                          View Details <ChevronRight size={14} />
                        </Link>
                      </td>
                    </tr>
                  ))}
                  {sessions.length === 0 && <tr><td colSpan="5" className="p-12 text-center text-slate-400 dark:text-gray-500">No sessions recorded</td></tr>}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {isEnrollModalOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 p-8 rounded-2xl w-full max-w-md shadow-2xl border border-gray-100 dark:border-gray-700 transform transition-all">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-bold text-slate-800 dark:text-white">Enroll Student</h2>
              <button onClick={() => setIsEnrollModalOpen(false)} className="text-gray-400 hover:text-red-500 transition"><X /></button>
            </div>
            
            <form onSubmit={handleEnroll}>
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2 text-slate-700 dark:text-gray-300">Select Student</label>
                <select 
                  className="w-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none transition appearance-none"
                  value={selectedStudentId}
                  onChange={e => setSelectedStudentId(e.target.value)}
                  required
                >
                  <option value="">-- Choose Student --</option>
                  {allStudents.map(s => (
                    <option key={s.id} value={s.id}>{s.full_name} ({s.lms_id})</option>
                  ))}
                </select>
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setIsEnrollModalOpen(false)} className="px-5 py-2.5 text-slate-600 dark:text-gray-300 hover:bg-slate-100 dark:hover:bg-gray-700 rounded-lg transition">Cancel</button>
                <button type="submit" className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition shadow-md">Confirm</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default CourseDetails;