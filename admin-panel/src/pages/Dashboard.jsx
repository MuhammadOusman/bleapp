import { useEffect, useState } from 'react';
import api from '../services/api';
import { Users, BookOpen, Clock, UserCheck } from 'lucide-react';

const StatCard = ({ title, count, icon, colorClass, bgClass }) => (
  <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 group">
    <div className="flex items-center gap-5">
      <div className={`p-4 rounded-xl ${bgClass} ${colorClass} transition-colors duration-300`}>
        {icon}
      </div>
      <div>
        <p className="text-slate-500 dark:text-slate-400 text-xs font-bold uppercase tracking-wider mb-1">{title}</p>
        <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">{count}</h3>
      </div>
    </div>
  </div>
);

const Dashboard = () => {
  const[stats, setStats] = useState({
    total_students: 0,
    total_teachers: 0,
    total_courses: 0,
    active_sessions: 0
  });

  useEffect(() => {
    api.get('/admin/stats')
      .then(({ data }) => setStats(data))
      .catch(console.error);
  },[]);

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-8">
      <div>
        <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">Dashboard Overview</h1>
        <p className="text-slate-500 dark:text-slate-400 mt-2 font-medium">Welcome back, here is what is happening today.</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          title="Total Students" 
          count={stats.total_students} 
          icon={<Users size={28} />} 
          colorClass="text-blue-600 dark:text-blue-400" 
          bgClass="bg-blue-50 dark:bg-blue-500/10" 
        />
        <StatCard 
          title="Total Teachers" 
          count={stats.total_teachers} 
          icon={<UserCheck size={28} />} 
          colorClass="text-emerald-600 dark:text-emerald-400" 
          bgClass="bg-emerald-50 dark:bg-emerald-500/10" 
        />
        <StatCard 
          title="Active Courses" 
          count={stats.total_courses} 
          icon={<BookOpen size={28} />} 
          colorClass="text-indigo-600 dark:text-indigo-400" 
          bgClass="bg-indigo-50 dark:bg-indigo-500/10" 
        />
        <StatCard 
          title="Live Sessions" 
          count={stats.active_sessions} 
          icon={<Clock size={28} />} 
          colorClass="text-orange-600 dark:text-orange-400" 
          bgClass="bg-orange-50 dark:bg-orange-500/10" 
        />
      </div>
    </div>
  );
};

export default Dashboard;