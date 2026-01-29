import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import Sidebar from './Sidebar';

const Layout = () => {
  const { user } = useAuth();

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return (
    // Added transition-colors and dark mode background here
    <div className="flex min-h-screen bg-slate-50 dark:bg-gray-900 transition-colors duration-300">
      <Sidebar />
      <div className="ml-64 flex-1 p-8 text-slate-800 dark:text-gray-200">
        <Outlet />
      </div>
    </div>
  );
};

export default Layout;