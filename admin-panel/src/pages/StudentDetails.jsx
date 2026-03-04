import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api from '../services/api';
import { ArrowLeft, GraduationCap } from 'lucide-react';

const StudentDetails = () => {
  const { id } = useParams();
  const [stats, setStats] = useState([]);

  useEffect(() => {
    api.get(`/admin/student-stats/${id}`)
      .then(res => setStats(res.data))
      .catch(console.error);
  }, [id]);

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col gap-6">
        <Link to="/users" className="text-slate-500 dark:text-slate-400 flex items-center gap-2 w-fit hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors font-medium">
          <ArrowLeft size={18} /> Back to Users
        </Link>
        <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm flex items-start gap-5">
          <div className="p-4 bg-indigo-50 dark:bg-indigo-500/10 rounded-2xl text-indigo-600 dark:text-indigo-400 border border-indigo-100 dark:border-indigo-500/20">
            <GraduationCap size={40} />
          </div>
          <div>
            <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">Student Performance</h1>
            <p className="text-slate-500 dark:text-slate-400 font-mono text-xs mt-2 bg-slate-50 dark:bg-slate-900/50 px-3 py-1.5 rounded-lg inline-block border border-slate-200 dark:border-slate-700/50 font-medium">
              ID: {id}
            </p>
          </div>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {stats.map((course, index) => {
          const percentage = parseFloat(course.percentage);
          const isDanger = percentage < 75;
          return (
            <div key={index} className="bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 md:p-8 rounded-2xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 transition-all duration-300 hover:shadow-lg hover:-translate-y-1">
              <div className="flex flex-col mb-6">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-xl font-bold text-slate-900 dark:text-white leading-tight">{course.course_name}</h3>
                  <span className="bg-slate-100 dark:bg-slate-900 text-slate-600 dark:text-slate-300 text-xs font-bold px-2.5 py-1 rounded-lg border border-slate-200/50 dark:border-slate-700 font-mono whitespace-nowrap ml-4">
                    {course.course_code}
                  </span>
                </div>
                
                <div className="flex justify-between items-end mt-4">
                  <div>
                    <span className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider block mb-1">Attendance</span>
                    <p className="text-sm text-slate-500 dark:text-slate-400 font-medium">
                      Attended <span className="text-slate-900 dark:text-white font-bold">{course.attendance_ratio}</span> Sessions
                    </p>
                  </div>
                  <div className={`text-4xl font-extrabold tracking-tighter ${isDanger ? 'text-red-500 dark:text-red-400' : 'text-emerald-500 dark:text-emerald-400'}`}>
                    {course.percentage}%
                  </div>
                </div>
              </div>
              
              {/* Progress Bar Container */}
              <div className="w-full bg-slate-100 dark:bg-slate-900/80 rounded-full h-4 p-0.5 shadow-inner">
                <div 
                  className={`h-full rounded-full transition-all duration-1000 ease-out relative overflow-hidden ${isDanger ? 'bg-gradient-to-r from-red-500 to-red-400' : 'bg-gradient-to-r from-emerald-500 to-emerald-400'}`} 
                  style={{ width: `${percentage}%` }}
                >
                  <div className="absolute top-0 left-0 right-0 bottom-0 bg-white/20" style={{ background: 'linear-gradient(45deg, rgba(255,255,255,0.15) 25%, transparent 25%, transparent 50%, rgba(255,255,255,0.15) 50%, rgba(255,255,255,0.15) 75%, transparent 75%, transparent)' }}></div>
                </div>
              </div>
            </div>
          )
        })}

        {stats.length === 0 && (
          <div className="col-span-full bg-white dark:bg-slate-800/80 backdrop-blur-md p-16 rounded-3xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 text-center flex flex-col items-center">
            <div className="p-6 rounded-full bg-slate-50 dark:bg-slate-900/50 mb-6 border border-slate-100 dark:border-slate-700/50">
              <GraduationCap size={48} className="text-slate-300 dark:text-slate-600" />
            </div>
            <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">No Enrollment Data</h3>
            <p className="text-slate-500 dark:text-slate-400 mt-2 font-medium max-w-sm">This student has not been enrolled in any courses or no sessions have been recorded yet.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default StudentDetails;