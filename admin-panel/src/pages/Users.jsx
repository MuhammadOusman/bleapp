import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';

const Users = () => {
  const [activeTab, setActiveTab] = useState('teachers');
  const [data, setData] = useState([]);

  useEffect(() => {
    const endpoint = activeTab === 'teachers' ? '/admin/users/teachers' : '/admin/users/students';
    api.get(endpoint)
      .then(res => setData(res.data))
      .catch(console.error);
  }, [activeTab]);

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-6">
      <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm">
        <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight mb-2">User Management</h1>
        <p className="text-slate-500 dark:text-slate-400 font-medium">View and manage all registered campus accounts</p>
      </div>
      
      <div className="flex gap-2 bg-slate-100 dark:bg-slate-800 p-1.5 rounded-xl w-fit border border-slate-200/50 dark:border-slate-700/50 shadow-inner">
        <button 
          onClick={() => setActiveTab('teachers')}
          className={`px-8 py-2.5 rounded-lg font-bold transition-all duration-300 text-sm tracking-wide ${
            activeTab === 'teachers' 
              ? 'bg-white dark:bg-slate-700 text-indigo-600 dark:text-indigo-400 shadow-sm' 
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
          }`}
        >
          Teachers
        </button>
        <button 
          onClick={() => setActiveTab('students')}
          className={`px-8 py-2.5 rounded-lg font-bold transition-all duration-300 text-sm tracking-wide ${
            activeTab === 'students' 
              ? 'bg-white dark:bg-slate-700 text-indigo-600 dark:text-indigo-400 shadow-sm' 
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
          }`}
        >
          Students
        </button>
      </div>

      <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md rounded-2xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-slate-50/50 dark:bg-slate-900/20 border-b border-slate-100 dark:border-slate-700/50">
              <tr>
                <th className="p-5 pl-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Full Name</th>
                <th className="p-5 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Email</th>
                {activeTab === 'students' && <th className="p-5 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">LMS ID</th>}
                <th className="p-5 pr-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">UUID</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
              {data.map(user => (
                <tr key={user.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-700/20 transition-colors group">
                  
                  <td className="p-5 pl-6 font-medium">
                    {activeTab === 'students' ? (
                      <Link 
                        to={`/students/${user.id}`} 
                        className="text-slate-900 dark:text-white font-bold hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors text-base"
                      >
                        {user.full_name}
                      </Link>
                    ) : (
                      <span className="text-slate-900 dark:text-white font-bold text-base">{user.full_name}</span>
                    )}
                  </td>

                  <td className="p-5 text-slate-500 dark:text-slate-400 font-medium">{user.email}</td>
                  
                  {activeTab === 'students' && (
                    <td className="p-5">
                      <span className="font-mono text-xs font-bold tracking-wide bg-slate-100 dark:bg-slate-900 text-slate-600 dark:text-slate-300 px-3 py-1.5 rounded-lg border border-slate-200/50 dark:border-slate-700">
                        {user.lms_id}
                      </span>
                    </td>
                  )}
                  <td className="p-5 pr-6 text-xs text-slate-400 dark:text-slate-500 font-mono font-medium truncate max-w-[150px]">{user.id}</td>
                </tr>
              ))}
              {data.length === 0 && (
                <tr>
                  <td colSpan={activeTab === 'students' ? 4 : 3} className="p-16 text-center text-slate-400 dark:text-slate-500 font-medium">
                    No {activeTab} found in the system.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Users;