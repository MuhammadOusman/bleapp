import { useState } from 'react';
import Papa from 'papaparse';
import axios from 'axios';

export default function ImportModal({ courseId, onClose, onDone }) {
  const [rows, setRows] = useState([]);
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleFile = (file) => {
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      complete: (results) => {
        setRows(results.data);
      }
    });
  };

  const doPreview = async () => {
    setLoading(true);
    try {
      const r = await axios.post(`/api/admin/courses/${courseId}/import-preview`, { rows });
      setPreview(r.data.preview || []);
    } catch (e) {
      alert(e.response?.data?.error || e.message);
    } finally { setLoading(false); }
  };

  const doCommit = async () => {
    // Collect profile ids from preview ok rows
    const profile_ids = preview.filter(p => p.ok && p.profile).map(p => p.profile.id);
    if (profile_ids.length === 0) return alert('No valid profiles to commit');
    setLoading(true);
    try {
      const r = await axios.post(`/api/admin/courses/${courseId}/import-commit`, { profile_ids });
      alert(`Inserted: ${r.data.inserted || 0}`);
      onDone && onDone();
    } catch (e) {
      alert(e.response?.data?.error || e.message);
    } finally { setLoading(false); }
  };

  return (
    <div className="modal-overlay">
      <div className="modal">
        <h3>Bulk Import Students</h3>
        <p className="small">CSV with headers: email,lms_id,full_name (email or lms_id required)</p>
        <div>
          <input type="file" accept="text/csv" onChange={(e)=>handleFile(e.target.files[0])} />
        </div>
        <div style={{marginTop:10}}>
          <button onClick={doPreview} disabled={loading || rows.length===0}>Preview</button>
          <button onClick={()=>{ onClose(); }} style={{marginLeft:8}}>Close</button>
        </div>
        {preview && (
          <div style={{marginTop:12}}>
            <h4>Preview</h4>
            <table>
              <thead><tr><th>#</th><th>email</th><th>lms_id</th><th>ok</th><th>reason</th></tr></thead>
              <tbody>
                {preview.map((p,i)=> (
                  <tr key={i}><td>{i+1}</td><td>{p.row?.email}</td><td>{p.row?.lms_id}</td><td>{p.ok? 'Yes':'No'}</td><td>{p.reason||''}</td></tr>
                ))}
              </tbody>
            </table>
            <div style={{marginTop:8}}>
              <button onClick={doCommit} disabled={loading}>Commit</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
