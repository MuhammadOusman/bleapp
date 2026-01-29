import { useEffect, useState } from 'react';
import api from '../services/api';
import { Users, BookOpen, Clock, UserCheck } from 'lucide-react';

const StatCard = ({ title, count, icon, color }) => (
  <div className="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 flex items-center gap-4 transition-colors duration-300">
    <div className={`p-4 rounded-full ${color} text-white shadow-lg`}>{icon}</div>
    <div>
      <p className="text-gray-500 dark:text-gray-400 text-sm font-medium uppercase tracking-wider">{title}</p>
      <h3 className="text-2xl font-bold text-slate-800 dark:text-white mt-1">{count}</h3>
    </div>
  </div>
);

const Dashboard = () => {
  const [stats, setStats] = useState({
    total_students: 0,
    total_teachers: 0,
    total_courses: 0,
    active_sessions: 0
  });

  useEffect(() => {
    api.get('/admin/stats')
      .then(({ data }) => setStats(data))
      .catch(console.error);
  }, []);

  return (
    <div className="fade-in">
      <h1 className="text-3xl font-bold text-slate-800 dark:text-white mb-8">Dashboard Overview</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="Total Students" count={stats.total_students} icon={<Users size={24} />} color="bg-blue-500" />
        <StatCard title="Total Teachers" count={stats.total_teachers} icon={<UserCheck size={24} />} color="bg-emerald-500" />
        <StatCard title="Active Courses" count={stats.total_courses} icon={<BookOpen size={24} />} color="bg-violet-500" />
        <StatCard title="Live Sessions" count={stats.active_sessions} icon={<Clock size={24} />} color="bg-orange-500" />
      </div>
    </div>
  );
};

export default Dashboard;