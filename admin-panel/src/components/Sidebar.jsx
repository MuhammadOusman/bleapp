import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, BookOpen, Users, LogOut, Moon, Sun, Bell } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { useNotifications } from '../context/NotificationContext'; 
import NotificationPanel from './NotificationPanel'; 

const Sidebar = () => {
  const location = useLocation();
  const { logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { unreadCount } = useNotifications(); 
  const[isNotifOpen, setIsNotifOpen] = useState(false);

  const navItems =[
    { path: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={20} /> },
    { path: '/courses', label: 'Courses Management', icon: <BookOpen size={20} /> },
    { path: '/users', label: 'Students & Teachers', icon: <Users size={20} /> },
  ];

  return (
    <>
      <div className="h-screen w-64 bg-white dark:bg-slate-900 flex flex-col fixed left-0 top-0 shadow-[4px_0_24px_rgba(0,0,0,0.02)] dark:shadow-none border-r border-slate-200 dark:border-slate-800 transition-colors duration-300 z-50">
        
        <div className="p-6 flex items-center justify-between border-b border-slate-100 dark:border-slate-800/80">
          <span className="text-2xl font-extrabold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-blue-500 tracking-tight">
            Admin
          </span>
          
          {/* Notification Bell */}
          <div className="relative">
            <button 
              onClick={() => setIsNotifOpen(!isNotifOpen)}
              className="p-2.5 bg-slate-50 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-indigo-50 dark:hover:bg-indigo-500/20 hover:text-indigo-600 dark:hover:text-indigo-400 rounded-xl transition-all duration-300 relative border border-slate-200 dark:border-slate-700"
            >
              <Bell size={20} className="transition-colors" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 h-3.5 w-3.5 bg-red-500 rounded-full border-2 border-white dark:border-slate-800 shadow-sm animate-pulse"></span>
              )}
            </button>
          </div>
        </div>

        <nav className="flex-1 p-4 space-y-2 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname.startsWith(item.path);
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 px-4 py-3.5 rounded-xl transition-all duration-300 group font-bold tracking-wide ${
                  isActive
                    ? 'bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-100 dark:border-indigo-500/20 shadow-sm'
                    : 'text-slate-500 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-800/50 hover:text-slate-900 dark:hover:text-white border border-transparent'
                }`}
              >
                <span className={`transition-colors duration-300 ${isActive ? 'text-indigo-600 dark:text-indigo-400' : 'text-slate-400 dark:text-slate-500 group-hover:text-indigo-500 dark:group-hover:text-indigo-400'}`}>
                  {item.icon}
                </span>
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-slate-100 dark:border-slate-800/80 space-y-2">
          <button onClick={toggleTheme} className="flex items-center gap-3 w-full px-4 py-3.5 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800/80 rounded-xl transition-all duration-300 font-bold border border-transparent hover:border-slate-200 dark:hover:border-slate-700 group">
            <div className="text-slate-400 dark:text-slate-500 group-hover:text-amber-500 dark:group-hover:text-indigo-400 transition-colors">
              {theme === 'dark' ? <Sun size={20} /> : <Moon size={20} />}
            </div>
            <span>{theme === 'dark' ? 'Light Mode' : 'Dark Mode'}</span>
          </button>

          <button onClick={logout} className="flex items-center gap-3 w-full px-4 py-3.5 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-500/10 rounded-xl transition-all duration-300 font-bold border border-transparent hover:border-red-100 dark:hover:border-red-500/20 group">
            <LogOut size={20} className="text-red-400 group-hover:text-red-600 dark:group-hover:text-red-400 transition-colors" />
            <span>Logout</span>
          </button>
        </div>
      </div>

      <NotificationPanel isOpen={isNotifOpen} onClose={() => setIsNotifOpen(false)} />
    </>
  );
};

export default Sidebar;