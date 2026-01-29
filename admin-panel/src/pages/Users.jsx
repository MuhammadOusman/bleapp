import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';

const Users = () => {
  const [activeTab, setActiveTab] = useState('teachers'); // 'teachers' or 'students'
  const [data, setData] = useState([]);

  useEffect(() => {
    const endpoint = activeTab === 'teachers' ? '/admin/users/teachers' : '/admin/users/students';
    api.get(endpoint)
      .then(res => setData(res.data))
      .catch(console.error);
  }, [activeTab]);

  return (
    <div className="fade-in">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-800 dark:text-white mb-2">User Management</h1>
        <p className="text-slate-500 dark:text-gray-400">View and manage all registered accounts</p>
      </div>
      
      {/* Tabs */}
      <div className="flex gap-1 bg-slate-100 dark:bg-gray-800 p-1 rounded-xl w-fit mb-6 border border-slate-200 dark:border-gray-700">
        <button 
          onClick={() => setActiveTab('teachers')}
          className={`px-6 py-2.5 rounded-lg font-medium transition-all text-sm ${
            activeTab === 'teachers' 
              ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-white shadow-sm' 
              : 'text-slate-500 dark:text-gray-400 hover:text-slate-700 dark:hover:text-gray-200'
          }`}
        >
          Teachers
        </button>
        <button 
          onClick={() => setActiveTab('students')}
          className={`px-6 py-2.5 rounded-lg font-medium transition-all text-sm ${
            activeTab === 'students' 
              ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-white shadow-sm' 
              : 'text-slate-500 dark:text-gray-400 hover:text-slate-700 dark:hover:text-gray-200'
          }`}
        >
          Students
        </button>
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 overflow-hidden transition-colors duration-300">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-slate-50 dark:bg-gray-700/50 border-b dark:border-gray-700">
              <tr>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">Full Name</th>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">Email</th>
                {activeTab === 'students' && <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">LMS ID</th>}
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">UUID</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {data.map(user => (
                <tr key={user.id} className="hover:bg-slate-50 dark:hover:bg-gray-700/50 transition-colors">
                  
                  {/* Clickable Name for Students */}
                  <td className="p-5 font-medium text-slate-800 dark:text-white">
                    {activeTab === 'students' ? (
                      <Link 
                        to={`/students/${user.id}`} 
                        className="text-blue-600 dark:text-blue-400 hover:underline font-semibold"
                      >
                        {user.full_name}
                      </Link>
                    ) : (
                      <span className="text-slate-800 dark:text-white">{user.full_name}</span>
                    )}
                  </td>

                  <td className="p-5 text-slate-600 dark:text-gray-400">{user.email}</td>
                  {activeTab === 'students' && (
                    <td className="p-5 text-slate-600 dark:text-gray-400 font-mono text-sm bg-slate-50 dark:bg-transparent">
                      {user.lms_id}
                    </td>
                  )}
                  <td className="p-5 text-xs text-slate-400 dark:text-gray-500 font-mono">{user.id}</td>
                </tr>
              ))}
              {data.length === 0 && (
                <tr>
                  <td colSpan="4" className="p-12 text-center text-slate-400 dark:text-gray-500">
                    No {activeTab} found.
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