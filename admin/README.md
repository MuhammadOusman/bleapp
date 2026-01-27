Admin Dashboard (Next.js)

Setup:
- cd admin
- cp .env.example .env.local and set BACKEND_BASE and any tokens
- npm install
- npm run dev

Pages:
- /admin/login
- /admin/courses
- /admin/courses/[id]
- /admin/pending
- /admin/import

Security:
- Admin app should be run server-side and keep Supabase service key in server env only; do not expose it to the browser.
