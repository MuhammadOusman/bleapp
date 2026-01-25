# DSU BLE Attendance (Flutter)

Quick starter app implementing the BLE attendance flows described in the spec.

Features
- Login / Register (uses device signature from `device_info_plus`)
- Teacher: Start 15-second session -> app broadcasts beacon (session_id)
- Student: Scan for session -> call `/attendance/mark` with device_signature
- Supabase ready for streaming the `attendance` table (use Supabase Flutter SDK)

Setup
1. Ensure you have Flutter installed: https://flutter.dev/docs/get-started/install
2. Open a terminal and run:
   cd frontend
   flutter pub get

3. Required Android permissions/notes
- The project already adds Bluetooth and location permissions in `AndroidManifest.xml`.
- You must run the app on a real device for BLE advertisement (teacher) to work.
- Android 12+ requires runtime permissions for BLUETOOTH_SCAN / BLUETOOTH_ADVERTISE / BLUETOOTH_CONNECT.

4. Environment variables (recommended)
- Copy `.env.example` to `.env` at the project root (`frontend/.env`) and fill the values.

Example `.env` fields:
```
BACKEND_BASE=https://dsu-ble-attendance.vercel.app/api
SUPABASE_URL=https://<your-supabase-project>.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
```

- The app reads these variables at startup via `flutter_dotenv`.
- **Do not commit** your `.env` file. `.gitignore` already ignores `.env` and `.env.*`.

5. Backend & Supabase
- Backend (deployed): https://dsu-ble-attendance.vercel.app
- Supabase URL / ANON KEY are now sourced from your `.env` file. Do not commit your `.env` file. Update `frontend/.env` from `.env.example`.

How it maps to the spec
- `device_signature` uses `device_info_plus` (Android ID / identifierForVendor)
- Token is stored with `flutter_secure_storage`
- Teacher session start calls `POST /sessions/start` and uses returned `session_id` as beacon UUID
- Students scan and call `POST /attendance/mark` with detected `session_id` and their `device_signature`

Limitations / Notes
- The BLE scanning code is a simple heuristic for demo purposes. You may need to refine advertisement parsing for robust detection (iBeacon format, manufacturer data parsing).
- Production: move Supabase keys out of source and add proper error handling and permissions flow.

Happy hacking! 🚀
