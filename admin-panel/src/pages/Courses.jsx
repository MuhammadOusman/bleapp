import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import toast from 'react-hot-toast';
import { Plus, X, Trash2, Pencil } from 'lucide-react';

const Courses = () => {
  const [courses, setCourses] = useState([]);
  const [teachers, setTeachers] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const[isEditing, setIsEditing] = useState(false);
  const [currentCourseId, setCurrentCourseId] = useState(null);
  const [formData, setFormData] = useState({ course_code: '', course_name: '', teacher_id: '' });

  useEffect(() => {
    fetchCourses();
    fetchTeachers();
  },[]);

  const fetchCourses = () => {
    api.get('/admin/courses')
      .then(({ data }) => setCourses(data))
      .catch(err => console.error(err));
  };

  const fetchTeachers = () => {
    api.get('/admin/users/teachers')
      .then(({ data }) => setTeachers(data))
      .catch(err => console.error(err));
  };

  const openCreateModal = () => {
    setIsEditing(false);
    setCurrentCourseId(null);
    setFormData({ course_code: '', course_name: '', teacher_id: '' });
    setIsModalOpen(true);
  };

  const openEditModal = (course) => {
    setIsEditing(true);
    setCurrentCourseId(course.id);
    setFormData({
      course_code: course.course_code,
      course_name: course.course_name,
      teacher_id: course.teacher_id || (course.teacher ? course.teacher.id : '')
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/admin/courses/${currentCourseId}`, formData);
        toast.success('Course Updated');
      } else {
        await api.post('/admin/courses', formData);
        toast.success('Course Created');
      }
      setIsModalOpen(false);
      fetchCourses();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Operation failed');
    }
  };

  const handleDelete = async (courseId) => {
    if(!window.confirm("Delete this course and all its history?")) return;
    try {
      await api.delete(`/admin/courses/${courseId}`);
      toast.success('Course Deleted');
      fetchCourses();
    } catch (err) {
      toast.error('Failed to delete course');
    }
  };

  return (
    <div className="fade-in max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-white dark:bg-slate-800/80 backdrop-blur-md p-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/50 shadow-sm">
        <div>
          <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">Courses Management</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1 font-medium">Manage curriculum and assign instructors</p>
        </div>
        
        <button 
          onClick={openCreateModal}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-3 rounded-xl flex items-center gap-2 font-bold transition-all shadow-lg shadow-indigo-500/20 active:scale-95 hover:-translate-y-0.5"
        >
          <Plus size={20} /> Add New Course
        </button>
      </div>

      <div className="bg-white dark:bg-slate-800/80 backdrop-blur-md rounded-2xl shadow-sm border border-slate-200/60 dark:border-slate-700/50 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-slate-50/50 dark:bg-slate-900/20 border-b border-slate-100 dark:border-slate-700/50">
              <tr>
                <th className="p-5 pl-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Code</th>
                <th className="p-5 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Course Name</th>
                <th className="p-5 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs">Instructor</th>
                <th className="p-5 pr-6 font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-xs text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
              {courses.length === 0 ? (
                <tr><td colSpan="4" className="p-16 text-center text-slate-400 dark:text-slate-500 font-medium">No courses found</td></tr>
              ) : (
                courses.map(course => (
                  <tr key={course.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-700/20 transition-colors group">
                    <td className="p-5 pl-6 font-medium">
                      <span className="bg-slate-100 dark:bg-slate-900 text-slate-600 dark:text-slate-300 px-3 py-1.5 rounded-lg text-xs font-mono font-bold tracking-wide border border-slate-200/50 dark:border-slate-700">
                        {course.course_code}
                      </span>
                    </td>
                    <td className="p-5">
                      <Link 
                        to={`/courses/${course.id}`} 
                        className="text-slate-900 dark:text-white font-bold hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors text-base"
                      >
                        {course.course_name}
                      </Link>
                    </td>
                    <td className="p-5 text-slate-500 dark:text-slate-400 font-medium">
                      {course.teacher?.full_name || <span className="text-red-400 dark:text-red-400/80 italic text-sm bg-red-50 dark:bg-red-500/10 px-2 py-1 rounded-md">Unassigned</span>}
                    </td>
                    <td className="p-5 pr-6 text-right">
                      <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => openEditModal(course)} className="text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 bg-white dark:bg-slate-800 hover:bg-indigo-50 dark:hover:bg-indigo-500/10 p-2 rounded-lg border border-transparent hover:border-indigo-100 dark:hover:border-indigo-500/20 transition-all shadow-sm" title="Edit">
                          <Pencil size={18} />
                        </button>
                        <button onClick={() => handleDelete(course.id)} className="text-slate-400 hover:text-red-600 dark:hover:text-red-400 bg-white dark:bg-slate-800 hover:bg-red-50 dark:hover:bg-red-500/10 p-2 rounded-lg border border-transparent hover:border-red-100 dark:hover:border-red-500/20 transition-all shadow-sm" title="Delete">
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/40 dark:bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white dark:bg-slate-800 p-8 rounded-3xl w-full max-w-lg shadow-2xl border border-white/20 dark:border-slate-700 transform transition-all">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                {isEditing ? 'Edit Course' : 'Create New Course'}
              </h2>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-red-500 bg-slate-50 dark:bg-slate-900 hover:bg-red-50 dark:hover:bg-red-500/10 p-2 rounded-full transition-all">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-sm font-semibold mb-2 text-slate-700 dark:text-slate-300">Course Code</label>
                <input 
                  type="text" required placeholder="e.g. CS-101"
                  className="w-full border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-900/50 text-slate-900 dark:text-white px-4 py-3.5 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all font-medium placeholder:text-slate-400"
                  value={formData.course_code}
                  onChange={e => setFormData({...formData, course_code: e.target.value})}
                />
              </div>
              
              <div>
                <label className="block text-sm font-semibold mb-2 text-slate-700 dark:text-slate-300">Course Name</label>
                <input 
                  type="text" required placeholder="e.g. Introduction to AI"
                  className="w-full border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-900/50 text-slate-900 dark:text-white px-4 py-3.5 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all font-medium placeholder:text-slate-400"
                  value={formData.course_name}
                  onChange={e => setFormData({...formData, course_name: e.target.value})}
                />
              </div>

              <div>
                <label className="block text-sm font-semibold mb-2 text-slate-700 dark:text-slate-300">Instructor</label>
                <select 
                  required
                  className="w-full border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-900/50 text-slate-900 dark:text-white px-4 py-3.5 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all appearance-none font-medium"
                  value={formData.teacher_id}
                  onChange={e => setFormData({...formData, teacher_id: e.target.value})}
                >
                  <option value="">-- Select Instructor --</option>
                  {teachers.map(t => (
                    <option key={t.id} value={t.id}>{t.full_name} ({t.email})</option>
                  ))}
                </select>
              </div>

              <div className="pt-6 flex gap-3 justify-end">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-6 py-3 text-slate-600 dark:text-slate-300 font-semibold hover:bg-slate-100 dark:hover:bg-slate-700 rounded-xl transition-colors">Cancel</button>
                <button type="submit" className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-all shadow-md hover:shadow-lg active:scale-95">{isEditing ? 'Save Changes' : 'Create Course'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Courses;