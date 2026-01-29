import { X, UserPlus, Check } from 'lucide-react';
import { useNotifications } from '../context/NotificationContext';
import { useNavigate } from 'react-router-dom';

const NotificationPanel = ({ isOpen, onClose }) => {
  const { notifications, markAllAsRead, clearNotifications } = useNotifications();
  const navigate = useNavigate();

  if (!isOpen) return null;

  const handleAction = () => {
    navigate('/courses'); // Jump to courses to assign them
    onClose();
  };

  return (
    <div className="absolute left-64 top-16 w-80 bg-white dark:bg-gray-800 rounded-xl shadow-2xl border border-gray-100 dark:border-gray-700 z-50 overflow-hidden ml-4 animate-in fade-in zoom-in-95 duration-200">
      <div className="p-4 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center bg-slate-50 dark:bg-gray-900/50">
        <h3 className="font-bold text-slate-800 dark:text-white">Notifications</h3>
        <div className="flex gap-3">
          <button onClick={markAllAsRead} className="text-xs text-blue-600 dark:text-blue-400 hover:underline">Mark read</button>
          <button onClick={clearNotifications} className="text-xs text-red-500 hover:underline">Clear</button>
          <button onClick={onClose}><X size={16} className="text-slate-400" /></button>
        </div>
      </div>

      <div className="max-h-96 overflow-y-auto">
        {notifications.length === 0 ? (
          <div className="p-8 text-center text-slate-400 dark:text-gray-500 text-sm">
            No new notifications
          </div>
        ) : (
          notifications.map((notif) => (
            <div 
              key={notif.id} 
              className={`p-4 border-b border-gray-50 dark:border-gray-700 hover:bg-slate-50 dark:hover:bg-gray-700/30 transition ${!notif.read ? 'bg-blue-50/50 dark:bg-blue-900/10' : ''}`}
            >
              <div className="flex gap-3">
                <div className="bg-blue-100 dark:bg-blue-900/30 p-2 rounded-full h-fit text-blue-600 dark:text-blue-400">
                  <UserPlus size={18} />
                </div>
                <div>
                  <h4 className="text-sm font-semibold text-slate-800 dark:text-white">{notif.title}</h4>
                  <p className="text-xs text-slate-500 dark:text-gray-400 mt-1">{notif.message}</p>
                  <p className="text-[10px] text-slate-400 mt-2">{notif.timestamp.toLocaleTimeString()}</p>
                  
                  <button 
                    onClick={handleAction}
                    className="mt-3 text-xs bg-slate-800 dark:bg-slate-200 text-white dark:text-slate-900 px-3 py-1.5 rounded-md hover:opacity-90 transition font-medium w-full"
                  >
                    Assign Courses
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default NotificationPanel;