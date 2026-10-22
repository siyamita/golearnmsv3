# GoLearnMS — demo lokal + fondasi database produksi

GoLearnMS adalah Learning Management System untuk tiga peran utama: **admin, guru, dan siswa**. Folder ini berisi aplikasi HTML mandiri yang bisa dibuka langsung, contoh skema Supabase/PostgreSQL dengan RLS, dan daftar konfigurasi yang diperlukan sebelum membangun integrasi cloud produksi.

## 1. Cara menjalankan HTML secara lokal

1. Unduh dan ekstrak paket ZIP.
2. Buka `index.html` dengan Chrome, Edge, atau Firefox. Tidak perlu Node.js, server, atau instalasi dependensi.
3. Pilih salah satu akun demo di halaman masuk.

### Akun demo

| Peran | Username | Password |
|---|---|---|
| Admin utama demo | `siya` | `12345siya` |
| Guru demo | `bu.rani` | `Guru123!` |
| Siswa demo | `andi.siswa` | `Siswa123!` |

Akun lain contoh: `nabila.siswa` dengan password `Siswa123!`. Kelas, pengguna contoh, aktivitas, dan nilai yang telah tersedia diberi label **DEMO**. Itu semua bukan data pengguna nyata.

Data demo disimpan pada `localStorage` browser yang sedang dipakai. Gunakan tombol ekspor CSV sebelum menghapus data browser bila ingin menyimpan hasil uji. Bila data contoh ingin direset, hapus *site data* untuk file/aplikasi tersebut di browser; pada beberapa browser, file lokal diperlakukan sebagai origin terpisah.

## 2. Fitur yang dapat dicoba pada demo lokal

- Login dengan validasi username/password/peran, registrasi guru/siswa, validasi duplikasi username/email, logout, dan blokir akun.
- UI responsif, tema terang/gelap, navigasi berdasarkan peran, profil dan penggantian password demo.
- Panel admin: daftar pengguna, pencarian, filter status, detail pengguna, promosi/cabut admin oleh superadmin, blokir/pulihkan akun, impor CSV dengan pratinjau serta ekspor CSV/XLSX dan cetak ke PDF melalui dialog browser.
- Analitik kunjungan dengan filter periode/peran, grafik, interpretasi berdasarkan data yang tersedia, ekspor CSV dan XLSX, serta cetak ke PDF melalui dialog browser.
- Maintenance: monitoring kelas/sesi/tugas/pengumpulan, log demo, tindakan status log, leaderboard lintas kelas, pemantauan presensi baca-saja.
- Kelas guru dan siswa, kode gabung kelas, sesi, materi tautan/file kecil, tugas, submit teks/tautan/file kecil, penilaian 0–100 dan umpan balik.
- Leaderboard kelas dengan skor akhir transparan: 70% rata-rata nilai dan 30% rata-rata poin kecepatan. Poin kecepatan berada pada rentang 10–100.
- Presensi guru, pertemuan 1+ yang dapat ditambah, status Hadir/Tidak Hadir/Izin/Sakit, tampilan baca-saja siswa, dan ekspor CSV/XLSX/cetak PDF.
- Pesan kepada admin dan percakapan balasan demo, serta antarmuka Asisten AI yang secara eksplisit menyatakan bahwa AI belum dikonfigurasi.

## 3. Batasan yang harus diketahui

**Ini adalah demo front-end lokal yang interaktif, bukan aplikasi produksi yang sudah terhubung ke backend.** Data persisten hanya di browser tersebut, tidak dibagikan ke perangkat lain. File kecil pada demo disimpan sebagai data URL di localStorage, dengan batas ukuran 1 MB (foto profil 400 KB). Batas ini sengaja rendah agar tidak menghabiskan kuota penyimpanan browser.

Hal-hal berikut belum diaktifkan dalam `index.html` dan tidak boleh dianggap telah bekerja secara cloud:

- Supabase Auth, database online PostgreSQL, Row Level Security pada server, serta Supabase Storage.
- Pengiriman email pemulihan password dan notifikasi pesan admin; demo tidak berpura-pura mengirim email.
- API asisten AI (OpenAI/Gemini), penyaringan konteks internal, dan rate limiting.
- Ekspor PPTX asli (Excel XLSX dan CSV sudah tersedia untuk tabel yang disediakan; PDF melalui dialog cetak browser).
- Heartbeat, analitik dan audit log server-side lintas perangkat yang tahan manipulasi.

HTML lokal dapat diperiksa atau dimodifikasi pengguna, jadi **tidak ada RBAC sisi server dan jangan gunakan data siswa nyata, password penting, maupun rahasia produksi pada demo ini**. Kredensial admin di atas hanya akun bootstrap demonstrasi yang terlihat dalam source lokal. Jangan deploy file demo ini dengan menganggap autentikasinya aman.

## 4. Fondasi integrasi produksi

- `supabase/schema.sql`: rancangan tabel inti, relasi, helper function, RLS, dan RPC untuk tindakan sensitif.
- `supabase/storage-policies.sql`: bucket privat dan kebijakan akses Storage berdasarkan kelas, tugas, dan pemilik profil.
- `.env.example`: daftar variabel environment untuk Supabase, email, dan AI (placeholder saja).
- `scripts/bootstrap-admin.mjs`: script server-side idempoten untuk inisialisasi akun superadmin Supabase.

SQL tersebut adalah **fondasi yang perlu diuji dan ditinjau sebelum migrasi produksi**, bukan bukti bahwa seluruh fitur sudah terhubung. Skrip Storage di `supabase/storage-policies.sql` adalah contoh policy privat yang perlu ditinjau dan dites sesuai struktur path file aplikasi; email memerlukan provider terkonfigurasi; pemulihan password menggunakan Supabase Auth; AI harus dipanggil dari route server; ekspor XLSX/PDF/PPTX membutuhkan library pada aplikasi server. Jangan pernah menaruh `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, atau rahasia lain pada frontend.

Untuk deployment produksi, langkah berikutnya adalah membungkus UI menjadi aplikasi Next.js App Router, memasang Supabase SSR/Auth, memindahkan semua mutasi/operasi sensitif ke server actions atau route handlers, mengaktifkan kebijakan Storage, menguji RLS per-peran, kemudian mengonfigurasi environment variables di Vercel. Seed admin utama dapat dijalankan memakai `scripts/bootstrap-admin.mjs` dari mesin tepercaya: instal `@supabase/supabase-js`, salin `.env.example` menjadi `.env.local` yang tidak di-commit, isi nilai rahasia yang kuat, lalu jalankan `node --env-file=.env.local scripts/bootstrap-admin.mjs`. Script ini tidak mereset password pada setiap eksekusi dan menandai akun wajib mengganti password saat inisialisasi. Aplikasi produksi tetap harus benar-benar menegakkan `must_change_password` di middleware/server route. Kata kunci admin terpisah tidak dipakai sebagai faktor login pada rancangan ini; gunakan password kuat dan MFA melalui penyedia autentikasi.

## 5. File

- `index.html` — aplikasi demo yang bisa langsung dibuka lokal.
- `supabase/schema.sql` — fondasi skema database produksi.
- `.env.example` — contoh nama environment variables, tanpa kredensial aktif.
