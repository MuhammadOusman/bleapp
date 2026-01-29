import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api from '../services/api';
import { ArrowLeft, Clock, CheckCircle } from 'lucide-react';

const SessionDetails = () => {
  const { id } = useParams();
  const [session, setSession] = useState(null);
  const [attendees, setAttendees] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const sessRes = await api.get(`/sessions/${id}`);
        setSession(sessRes.data);

        const attRes = await api.get(`/sessions/${id}/attendance`);
        setAttendees(attRes.data.attendees || []); 
        
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id]);

  if (loading) return <div className="p-10 text-slate-500 dark:text-gray-400">Loading Session Data...</div>;
  if (!session) return <div className="p-10 text-slate-500 dark:text-gray-400">Session not found</div>;

  return (
    <div className="fade-in">
      <div className="mb-8">
        <Link to={session.course_id ? `/courses/${session.course_id}` : '/courses'} className="text-slate-500 dark:text-gray-400 flex items-center gap-2 mb-4 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
          <ArrowLeft size={18} /> Back to Course
        </Link>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            Session {session.session_number}
          </h1>
          <div className="flex items-center gap-3 bg-white dark:bg-gray-800 px-4 py-2 rounded-lg border border-gray-100 dark:border-gray-700 shadow-sm">
            <Clock size={18} className="text-slate-400" />
            <span className="text-slate-600 dark:text-gray-300 font-medium">{new Date(session.created_at).toLocaleString()}</span>
            <span className={`ml-2 px-2.5 py-0.5 rounded-full text-xs font-bold ${session.is_active ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400'}`}>
              {session.is_active ? 'ACTIVE' : 'CLOSED'}
            </span>
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 p-6 transition-colors duration-300">
        <h2 className="text-xl font-bold mb-6 pb-4 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center text-slate-800 dark:text-white">
          <span>Attendance Record</span>
          <span className="text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 px-3 py-1 rounded-full text-sm">{attendees.length} Present</span>
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {attendees.map(record => (
            <div key={record.student_id} className="bg-slate-50 dark:bg-gray-700/30 border border-gray-200 dark:border-gray-600 p-4 rounded-xl flex items-center justify-between hover:shadow-md hover:border-blue-200 dark:hover:border-blue-800 transition-all group">
              <div>
                <Link to={`/students/${record.profile?.id}`} className="font-semibold text-slate-800 dark:text-white hover:text-blue-600 dark:hover:text-blue-400 hover:underline">
                  {record.profile?.full_name || 'Unknown Student'}
                </Link>
                <p className="text-xs text-slate-500 dark:text-gray-400 font-mono mt-1">{record.profile?.lms_id || 'No ID'}</p>
              </div>
              <div className="text-right">
                <div className="text-emerald-600 dark:text-emerald-400 flex items-center gap-1 text-sm font-medium bg-emerald-50 dark:bg-emerald-900/20 px-2 py-0.5 rounded">
                  <CheckCircle size={14} /> Marked
                </div>
                <p className="text-xs text-slate-400 dark:text-gray-500 mt-1">
                  {new Date(record.marked_at).toLocaleTimeString()}
                </p>
              </div>
            </div>
          ))}
          
          {attendees.length === 0 && (
            <div className="col-span-full flex flex-col items-center justify-center py-16 text-slate-400 dark:text-gray-500">
              <div className="bg-slate-100 dark:bg-gray-700 p-4 rounded-full mb-3">
                <Clock size={32} />
              </div>
              <p>No attendance marked for this session yet.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default SessionDetails;