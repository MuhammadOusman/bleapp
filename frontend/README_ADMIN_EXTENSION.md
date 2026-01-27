Admin Dashboard Integration Notes

- The new Admin app lives in `/admin` and proxies requests through server-side API routes to the backend at `BACKEND_BASE`.
- Configure `admin/.env.local` with `BACKEND_BASE` before running.
- Add admin auth cookie handling: the admin app should set an HttpOnly token cookie after successful login with the backend `/login` endpoint which returns an admin profile and token.
