import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api from '../services/api';
import { ArrowLeft, Clock, CheckCircle } from 'lucide-react';

const SessionDetails = () => {
  const { id } = useParams();
  const [session, setSession] = useState(null);
  const[attendees, setAttendees] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const sessRes = await api.get(`/sessions/${id}`);
        setSession(sessRes.data);

        const attRes = await api.get(`/sessions/${id}/attendance`);
        setAttendees(attRes.data.attendees ||[]); 
        
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id]);

  if (loading) return (
    <div className="flex justify-center items-center min-h-[400px]">
      <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-600"></div>
    </div>
  );
  if (!session) return <div className="p-10 text-slate-500 dark:text-slate-400 font-medium text-center">Session not found</div>;

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col gap-6">
        <Link to={session.course_id ? `/courses/${session.course_id}` : '/courses'} className="text-slate-500 dark:text-slate-400 flex items-center gap-2 w-fit hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors font-medium">
          <ArrowLeft size={18} /> Back to Course
        </Link>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm">
          <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight flex items-center gap-3">
            Session {session.session_number}
          </h1>
          <div className="flex items-center gap-3 bg-slate-50 dark:bg-slate-900/50 px-5 py-2.5 rounded-xl border border-slate-100 dark:border-slate-700/50 shadow-sm">
            <Clock size={18} className="text-indigo-500 dark:text-indigo-400" />
            <span className="text-slate-700 dark:text-slate-200 font-bold text-sm tracking-wide">{new Date(session.created_at).toLocaleString()}</span>
            <div className="w-px h-4 bg-slate-300 dark:bg-slate-700 mx-1"></div>
            <span className={`px-2.5 py-1 rounded-lg text-xs font-bold tracking-wider ${session.is_active ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-400' : 'bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-400'}`}>
              {session.is_active ? 'ACTIVE' : 'CLOSED'}
            </span>
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md rounded-2xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 p-6 md:p-8">
        <div className="flex justify-between items-center mb-8 pb-4 border-b border-slate-100 dark:border-slate-700/50">
          <h2 className="text-xl font-bold text-slate-900 dark:text-white">Attendance Record</h2>
          <span className="text-indigo-700 dark:text-indigo-300 bg-indigo-50 dark:bg-indigo-500/20 px-4 py-1.5 rounded-xl text-sm font-bold border border-indigo-100 dark:border-indigo-500/30 shadow-sm">
            {attendees.length} Present
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {attendees.map(record => (
            <div key={record.student_id} className="bg-white dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700/50 p-5 rounded-2xl flex items-center justify-between hover:shadow-lg hover:border-indigo-300 dark:hover:border-indigo-500/50 transition-all duration-300 group">
              <div>
                <Link to={`/students/${record.profile?.id}`} className="font-bold text-slate-900 dark:text-white hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors block text-base">
                  {record.profile?.full_name || 'Unknown Student'}
                </Link>
                <p className="text-xs text-slate-500 dark:text-slate-400 font-mono mt-1 font-medium bg-slate-50 dark:bg-slate-800 w-fit px-2 py-0.5 rounded">
                  {record.profile?.lms_id || 'No ID'}
                </p>
              </div>
              <div className="text-right">
                <div className="text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5 text-xs font-bold bg-emerald-50 dark:bg-emerald-500/10 px-2.5 py-1 rounded-lg border border-emerald-100 dark:border-emerald-500/20">
                  <CheckCircle size={14} /> Marked
                </div>
                <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-2 font-medium">
                  {new Date(record.marked_at).toLocaleTimeString()}
                </p>
              </div>
            </div>
          ))}
          
          {attendees.length === 0 && (
            <div className="col-span-full flex flex-col items-center justify-center py-20 text-slate-400 dark:text-slate-500">
              <div className="bg-slate-50 dark:bg-slate-900/50 p-5 rounded-3xl mb-4 border border-slate-100 dark:border-slate-700/50">
                <Clock size={40} className="text-slate-300 dark:text-slate-600" />
              </div>
              <p className="font-medium text-lg text-slate-500 dark:text-slate-400">No attendance marked for this session yet.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default SessionDetails;