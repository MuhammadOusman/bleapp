import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext'; // 1. Import this

// Components
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Courses from './pages/Courses';
import CourseDetails from './pages/CourseDetails';
import SessionDetails from './pages/SessionDetails';
import Users from './pages/Users';
import StudentDetails from './pages/StudentDetails';

function App() {
  return (
    <AuthProvider>
      {/* 2. Wrap the Router with ThemeProvider */}
      <ThemeProvider>
        <Router>
          <Toaster position="top-right" toastOptions={{
            className: 'dark:bg-gray-800 dark:text-white',
            style: {
              background: '#333',
              color: '#fff',
            },
          }} />
          <Routes>
            <Route path="/login" element={<Login />} />

            <Route path="/" element={<Layout />}>
              <Route index element={<Navigate to="/dashboard" replace />} />
              <Route path="dashboard" element={<Dashboard />} />
              
              {/* Courses */}
              <Route path="courses" element={<Courses />} />
              <Route path="courses/:id" element={<CourseDetails />} />
              
              {/* Sessions */}
              <Route path="sessions/:id" element={<SessionDetails />} />

              {/* Users */}
              <Route path="users" element={<Users />} />
              <Route path="students/:id" element={<StudentDetails />} />
            </Route>
          </Routes>
        </Router>
      </ThemeProvider>
    </AuthProvider>
  );
}

export default App;