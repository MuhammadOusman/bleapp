import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, BookOpen, Users, LogOut, Moon, Sun, Bell } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { useNotifications } from '../context/NotificationContext'; // Import this
import NotificationPanel from './NotificationPanel'; // Import this

const Sidebar = () => {
  const location = useLocation();
  const { logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { unreadCount } = useNotifications(); // Access context
  const [isNotifOpen, setIsNotifOpen] = useState(false);

  const navItems = [
    { path: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={20} /> },
    { path: '/courses', label: 'Courses Management', icon: <BookOpen size={20} /> },
    { path: '/users', label: 'Students & Teachers', icon: <Users size={20} /> },
  ];

  return (
    <>
      <div className="h-screen w-64 bg-slate-900 dark:bg-gray-950 text-white flex flex-col fixed left-0 top-0 shadow-xl transition-colors duration-300 z-50">
        <div className="p-6 flex items-center justify-between border-b border-slate-700 dark:border-gray-800">
          <span className="text-xl font-bold tracking-wide">Admin</span>
          
          {/* Notification Bell */}
          <div className="relative">
            <button 
              onClick={() => setIsNotifOpen(!isNotifOpen)}
              className="p-2 hover:bg-slate-800 rounded-full transition relative"
            >
              <Bell size={20} className="text-slate-300 hover:text-white" />
              {unreadCount > 0 && (
                <span className="absolute top-0 right-0 h-2.5 w-2.5 bg-red-500 rounded-full border-2 border-slate-900 animate-pulse"></span>
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
                className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 group ${
                  isActive
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-900/20'
                    : 'text-slate-400 hover:bg-slate-800 hover:text-white dark:hover:bg-gray-800'
                }`}
              >
                <span className={`${isActive ? 'text-white' : 'text-slate-400 group-hover:text-white'}`}>
                  {item.icon}
                </span>
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-slate-700 dark:border-gray-800 space-y-3">
          <button onClick={toggleTheme} className="flex items-center gap-3 w-full px-4 py-3 text-slate-400 hover:bg-slate-800 hover:text-white rounded-lg transition-colors">
            {theme === 'dark' ? <Sun size={20} className="text-yellow-400" /> : <Moon size={20} />}
            <span className="font-medium">{theme === 'dark' ? 'Light Mode' : 'Dark Mode'}</span>
          </button>

          <button onClick={logout} className="flex items-center gap-3 w-full px-4 py-3 text-red-400 hover:bg-red-950/30 hover:text-red-300 rounded-lg transition-colors">
            <LogOut size={20} />
            <span className="font-medium">Logout</span>
          </button>
        </div>
      </div>

      {/* Render Panel outside the Sidebar div but linked logically */}
      <NotificationPanel isOpen={isNotifOpen} onClose={() => setIsNotifOpen(false)} />
    </>
  );
};

export default Sidebar;