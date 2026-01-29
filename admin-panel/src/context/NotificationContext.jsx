import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../services/supabase';
import toast from 'react-hot-toast';

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    // 1. Subscribe to INSERT events on the 'profiles' table
    const channel = supabase
      .channel('teacher-alerts')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'profiles',
          filter: 'role=eq.teacher', // ONLY trigger if the new user is a teacher
        },
        (payload) => {
          const newTeacher = payload.new;
          
          // 2. Create a notification object
          const newNotification = {
            id: Date.now(),
            title: 'New Teacher Registered',
            message: `${newTeacher.full_name} has joined.`,
            teacherId: newTeacher.id,
            timestamp: new Date(),
            read: false,
          };

          // 3. Update State
          setNotifications((prev) => [newNotification, ...prev]);
          setUnreadCount((prev) => prev + 1);
          
          // 4. Show a popup Toast
          toast.success(`New Teacher: ${newTeacher.full_name}`, {
            duration: 5000,
            icon: '👨‍🏫',
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const markAllAsRead = () => {
    setUnreadCount(0);
    setNotifications((prev) => prev.map(n => ({ ...n, read: true })));
  };

  const clearNotifications = () => {
    setNotifications([]);
    setUnreadCount(0);
  };

  return (
    <NotificationContext.Provider value={{ notifications, unreadCount, markAllAsRead, clearNotifications }}>
      {children}
    </NotificationContext.Provider>
  );
};

export const useNotifications = () => useContext(NotificationContext);