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
    <div className="fade-in">
      <div className="mb-8">
        <Link to="/users" className="text-slate-500 dark:text-gray-400 flex items-center gap-2 mb-4 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
          <ArrowLeft size={18} /> Back to Users
        </Link>
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <div className="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg text-blue-600 dark:text-blue-400">
              <GraduationCap size={32} />
            </div>
            Student Performance
          </h1>
          <p className="text-slate-500 dark:text-gray-400 font-mono text-sm mt-2 ml-14 bg-slate-100 dark:bg-gray-800 px-3 py-1 rounded inline-block">
            UUID: {id}
          </p>
        </div>
      </div>

      <div className="grid gap-6">
        {stats.map((course, index) => (
          <div key={index} className="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 transition-colors duration-300 hover:shadow-md">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-4">
              <div>
                <div className="flex items-center gap-3 mb-1">
                  <h3 className="text-xl font-bold text-slate-800 dark:text-white">{course.course_name}</h3>
                  <span className="bg-slate-100 dark:bg-gray-700 text-slate-600 dark:text-gray-300 text-xs font-bold px-2 py-1 rounded border border-slate-200 dark:border-gray-600">
                    {course.course_code}
                  </span>
                </div>
              </div>
              <div className="text-right mt-2 md:mt-0">
                <div className="flex items-end gap-2 justify-end">
                  <span className="text-sm text-slate-500 dark:text-gray-400 mb-1">Attendance Rate</span>
                  <span className={`text-3xl font-bold ${parseFloat(course.percentage) < 75 ? 'text-red-500 dark:text-red-400' : 'text-emerald-600 dark:text-emerald-400'}`}>
                    {course.percentage}%
                  </span>
                </div>
                <p className="text-xs text-slate-400 dark:text-gray-500 font-medium">
                  Attended {course.attendance_ratio} Sessions
                </p>
              </div>
            </div>
            
            {/* Progress Bar */}
            <div className="w-full bg-slate-100 dark:bg-gray-700 rounded-full h-3 overflow-hidden">
              <div 
                className={`h-full rounded-full transition-all duration-1000 ease-out ${parseFloat(course.percentage) < 75 ? 'bg-red-500' : 'bg-emerald-500'}`} 
                style={{ width: `${course.percentage}%` }}
              ></div>
            </div>
          </div>
        ))}

        {stats.length === 0 && (
          <div className="bg-white dark:bg-gray-800 p-12 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 text-center">
            <div className="inline-block p-4 rounded-full bg-slate-50 dark:bg-gray-700 mb-4">
              <GraduationCap size={40} className="text-slate-300 dark:text-gray-500" />
            </div>
            <h3 className="text-lg font-medium text-slate-800 dark:text-white">No Enrollment Data</h3>
            <p className="text-slate-500 dark:text-gray-400 mt-1">This student is not enrolled in any courses yet.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default StudentDetails;