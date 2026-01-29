import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import toast from 'react-hot-toast';
import { Plus, X, Trash2, Pencil, Search } from 'lucide-react';

const Courses = () => {
  const [courses, setCourses] = useState([]);
  const [teachers, setTeachers] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [currentCourseId, setCurrentCourseId] = useState(null);
  const [formData, setFormData] = useState({ course_code: '', course_name: '', teacher_id: '' });

  useEffect(() => {
    fetchCourses();
    fetchTeachers();
  }, []);

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
    <div className="fade-in">
      <div className="flex flex-col md:flex-row justify-between items-center mb-8 gap-4">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white">Courses Management</h1>
          <p className="text-slate-500 dark:text-gray-400 mt-1">Manage curriculum and assign instructors</p>
        </div>
        
        <button 
          onClick={openCreateModal}
          className="bg-blue-600 hover:bg-blue-700 text-white px-5 py-2.5 rounded-lg flex items-center gap-2 transition-all shadow-md hover:shadow-lg"
        >
          <Plus size={20} /> Add New Course
        </button>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 overflow-hidden transition-colors duration-300">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-slate-50 dark:bg-gray-700/50 border-b dark:border-gray-700">
              <tr>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">Code</th>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">Course Name</th>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300">Instructor</th>
                <th className="p-5 font-semibold text-slate-600 dark:text-gray-300 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {courses.length === 0 ? (
                <tr><td colSpan="4" className="p-8 text-center text-gray-400 dark:text-gray-500">No courses found</td></tr>
              ) : (
                courses.map(course => (
                  <tr key={course.id} className="hover:bg-slate-50 dark:hover:bg-gray-700/50 transition-colors">
                    <td className="p-5 font-medium text-slate-700 dark:text-gray-200">
                      <span className="bg-slate-100 dark:bg-gray-700 px-2 py-1 rounded text-sm font-mono">
                        {course.course_code}
                      </span>
                    </td>
                    <td className="p-5">
                      <Link 
                        to={`/courses/${course.id}`} 
                        className="text-blue-600 dark:text-blue-400 font-semibold hover:underline"
                      >
                        {course.course_name}
                      </Link>
                    </td>
                    <td className="p-5 text-slate-600 dark:text-gray-400">
                      {course.teacher?.full_name || <span className="text-red-400 italic text-sm">Unassigned</span>}
                    </td>
                    <td className="p-5 text-right flex justify-end gap-3">
                      <button onClick={() => openEditModal(course)} className="text-slate-400 hover:text-blue-600 dark:hover:text-blue-400 transition" title="Edit">
                        <Pencil size={18} />
                      </button>
                      <button onClick={() => handleDelete(course.id)} className="text-slate-400 hover:text-red-600 dark:hover:text-red-400 transition" title="Delete">
                        <Trash2 size={18} />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 p-8 rounded-2xl w-full max-w-lg shadow-2xl border border-gray-100 dark:border-gray-700 transform transition-all">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-slate-800 dark:text-white">
                {isEditing ? 'Edit Course' : 'Create New Course'}
              </h2>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition">
                <X />
              </button>
            </div>
            
            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-sm font-medium mb-2 text-slate-700 dark:text-gray-300">Course Code</label>
                <input 
                  type="text" required placeholder="e.g. CS-101"
                  className="w-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none transition"
                  value={formData.course_code}
                  onChange={e => setFormData({...formData, course_code: e.target.value})}
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium mb-2 text-slate-700 dark:text-gray-300">Course Name</label>
                <input 
                  type="text" required placeholder="e.g. Introduction to AI"
                  className="w-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none transition"
                  value={formData.course_name}
                  onChange={e => setFormData({...formData, course_name: e.target.value})}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2 text-slate-700 dark:text-gray-300">Instructor</label>
                <select 
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white p-3 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none transition"
                  value={formData.teacher_id}
                  onChange={e => setFormData({...formData, teacher_id: e.target.value})}
                >
                  <option value="">-- Select Instructor --</option>
                  {teachers.map(t => (
                    <option key={t.id} value={t.id}>{t.full_name} ({t.email})</option>
                  ))}
                </select>
              </div>

              <div className="pt-4 flex gap-3 justify-end">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 text-slate-600 dark:text-gray-300 hover:bg-slate-100 dark:hover:bg-gray-700 rounded-lg transition">Cancel</button>
                <button type="submit" className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition shadow-md">{isEditing ? 'Save Changes' : 'Create Course'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Courses;