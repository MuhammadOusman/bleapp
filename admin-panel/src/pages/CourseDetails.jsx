import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api, { downloadCourseReport } from '../services/api';
import toast from 'react-hot-toast';
import { Download, UserPlus, Calendar, Users, ArrowLeft, X, UserMinus, ChevronRight } from 'lucide-react';

const CourseDetails = () => {
  const { id } = useParams();
  const [course, setCourse] = useState(null);
  const[activeTab, setActiveTab] = useState('students');
  const [enrollments, setEnrollments] = useState([]);
  const[sessions, setSessions] = useState([]);
  const [isEnrollModalOpen, setIsEnrollModalOpen] = useState(false);
  const [allStudents, setAllStudents] = useState([]);
  const[selectedStudentId, setSelectedStudentId] = useState('');

  useEffect(() => {
    fetchCourseDetails();
    fetchEnrollments();
    fetchSessions();
  }, [id]);

  const fetchCourseDetails = () => api.get(`/courses/${id}/details`).then(res => setCourse(res.data)).catch(console.error);
  const fetchEnrollments = () => api.get(`/admin/courses/${id}/enrollments`).then(({ data }) => setEnrollments(data ||[])).catch(console.error);
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

  if (!course) return (
    <div className="flex justify-center items-center min-h-[400px]">
      <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-600"></div>
    </div>
  );

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col gap-6">
        <Link to="/courses" className="text-slate-500 dark:text-slate-400 flex items-center gap-2 w-fit hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors font-medium">
          <ArrowLeft size={18} /> Back to Courses
        </Link>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-4 bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <span className="bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 px-3 py-1 rounded-lg text-sm font-bold tracking-wide border border-indigo-100 dark:border-indigo-500/20">
                {course.course.course_code}
              </span>
            </div>
            <h1 className="text-3xl md:text-4xl font-extrabold text-slate-900 dark:text-white tracking-tight">{course.course.course_name}</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-2 font-medium">
              Instructor: <span className="text-slate-800 dark:text-slate-200">{course.teacher?.full_name || 'Unassigned'}</span>
            </p>
          </div>
          <button 
            onClick={handleDownloadReport}
            className="group flex items-center gap-2 bg-slate-900 dark:bg-white hover:bg-slate-800 dark:hover:bg-slate-100 text-white dark:text-slate-900 px-6 py-2.5 rounded-xl font-semibold transition-all shadow-md active:scale-95"
          >
            <Download size={18} className="group-hover:-translate-y-0.5 transition-transform" /> Export Report
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md rounded-2xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 min-h-[500px] overflow-hidden">
        <div className="p-4 border-b border-slate-100 dark:border-slate-700/50">
          <div className="flex gap-2 bg-slate-100 dark:bg-slate-900/50 p-1.5 rounded-xl w-fit">
            <button
              onClick={() => setActiveTab('students')}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-lg font-semibold transition-all duration-300 ${
                activeTab === 'students' 
                  ? 'bg-white dark:bg-slate-800 text-indigo-600 dark:text-indigo-400 shadow-sm' 
                  : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
              }`}
            >
              <Users size={18} /> Students ({enrollments.length})
            </button>
            <button
              onClick={() => setActiveTab('sessions')}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-lg font-semibold transition-all duration-300 ${
                activeTab === 'sessions' 
                  ? 'bg-white dark:bg-slate-800 text-indigo-600 dark:text-indigo-400 shadow-sm' 
                  : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
              }`}
            >
              <Calendar size={18} /> Sessions ({sessions.length})
            </button>
          </div>
        </div>

        <div className="p-0">
          {activeTab === 'students' && (
            <div className="animate-in fade-in duration-300">
              <div className="flex justify-end p-4">
                <button 
                  onClick={loadStudentsForDropdown}
                  className="flex items-center gap-2 bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 hover:bg-indigo-100 dark:hover:bg-indigo-500/20 px-5 py-2.5 rounded-xl text-sm font-bold transition-all"
                >
                  <UserPlus size={18} /> Enroll Student
                </button>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead className="bg-slate-50/50 dark:bg-slate-900/20 border-y border-slate-100 dark:border-slate-700/50">
                    <tr>
                      <th className="p-4 pl-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Name</th>
                      <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Email</th>
                      <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">LMS ID</th>
                      <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Enrolled Date</th>
                      <th className="p-4 pr-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
                    {enrollments.map((record) => (
                      <tr key={record.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-700/20 transition-colors group">
                        <td className="p-4 pl-6 font-medium">
                          <Link to={`/students/${record.student?.id}`} className="text-slate-900 dark:text-white hover:text-indigo-600 dark:hover:text-indigo-400 font-semibold transition-colors">
                            {record.student?.full_name}
                          </Link>
                        </td>
                        <td className="p-4 text-slate-500 dark:text-slate-400">{record.student?.email}</td>
                        <td className="p-4">
                          <span className="font-mono text-xs font-medium bg-slate-100 dark:bg-slate-900 text-slate-600 dark:text-slate-300 px-2.5 py-1 rounded-md">
                            {record.student?.lms_id}
                          </span>
                        </td>
                        <td className="p-4 text-slate-500 dark:text-slate-400 text-sm font-medium">{new Date(record.enrolled_at).toLocaleDateString()}</td>
                        <td className="p-4 pr-6 text-right">
                          <button onClick={() => handleUnenroll(record.student?.id)} className="text-slate-400 hover:text-red-500 dark:hover:text-red-400 transition-colors p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-500/10">
                            <UserMinus size={18} />
                          </button>
                        </td>
                      </tr>
                    ))}
                    {enrollments.length === 0 && <tr><td colSpan="5" className="p-16 text-center text-slate-400 dark:text-slate-500 font-medium">No students currently enrolled</td></tr>}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {activeTab === 'sessions' && (
            <div className="animate-in fade-in duration-300 overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead className="bg-slate-50/50 dark:bg-slate-900/20 border-b border-slate-100 dark:border-slate-700/50">
                  <tr>
                    <th className="p-4 pl-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Session</th>
                    <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Date</th>
                    <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Status</th>
                    <th className="p-4 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Attendance</th>
                    <th className="p-4 pr-6"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
                  {sessions.map(sess => (
                    <tr key={sess.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-700/20 transition-colors group">
                      <td className="p-4 pl-6 font-bold text-slate-900 dark:text-white">Session {sess.session_number}</td>
                      <td className="p-4 text-slate-500 dark:text-slate-400 text-sm font-medium">{new Date(sess.created_at).toLocaleString()}</td>
                      <td className="p-4">
                        <span className={`px-3 py-1 rounded-lg text-xs font-bold tracking-wide ${sess.is_active ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10 dark:text-emerald-400 border border-emerald-200/50 dark:border-emerald-500/20' : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400 border border-slate-200/50 dark:border-slate-700/50'}`}>
                          {sess.is_active ? 'ACTIVE' : 'CLOSED'}
                        </span>
                      </td>
                      <td className="p-4 text-slate-600 dark:text-slate-300 font-medium">{sess.attendance_count} Present</td>
                      <td className="p-4 pr-6 text-right">
                        <Link to={`/sessions/${sess.id}`} className="inline-flex items-center gap-1 text-sm font-bold text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 transition-colors">
                          View Details <ChevronRight size={16} />
                        </Link>
                      </td>
                    </tr>
                  ))}
                  {sessions.length === 0 && <tr><td colSpan="5" className="p-16 text-center text-slate-400 dark:text-slate-500 font-medium">No sessions recorded</td></tr>}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {isEnrollModalOpen && (
        <div className="fixed inset-0 bg-slate-900/40 dark:bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white dark:bg-slate-800 p-8 rounded-3xl w-full max-w-md shadow-2xl border border-white/20 dark:border-slate-700 transform transition-all scale-100">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-slate-900 dark:text-white">Enroll Student</h2>
              <button onClick={() => setIsEnrollModalOpen(false)} className="text-slate-400 hover:text-red-500 bg-slate-50 dark:bg-slate-900 hover:bg-red-50 dark:hover:bg-red-500/10 p-2 rounded-full transition-all"><X size={20} /></button>
            </div>
            
            <form onSubmit={handleEnroll}>
              <div className="mb-8">
                <label className="block text-sm font-semibold mb-2 text-slate-700 dark:text-slate-300">Select Student</label>
                <select 
                  className="w-full border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-900/50 text-slate-900 dark:text-white px-4 py-3.5 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all appearance-none font-medium"
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
                <button type="button" onClick={() => setIsEnrollModalOpen(false)} className="px-6 py-3 text-slate-600 dark:text-slate-300 font-semibold hover:bg-slate-100 dark:hover:bg-slate-700 rounded-xl transition-colors">Cancel</button>
                <button type="submit" className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-all shadow-md hover:shadow-lg active:scale-95">Confirm</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default CourseDetails;