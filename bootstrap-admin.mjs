/**
 * One-time, idempotent bootstrap for the production Supabase admin account.
 * Run only from a trusted machine/CI secret context. Never bundle this script in frontend JS.
 * Requires: npm install @supabase/supabase-js
 * Run: node --env-file=.env.local scripts/bootstrap-admin.mjs
 */
import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const username = (process.env.BOOTSTRAP_ADMIN_USERNAME || '').trim();
const password = process.env.BOOTSTRAP_ADMIN_PASSWORD || '';
const email = (process.env.BOOTSTRAP_ADMIN_EMAIL || '').trim().toLowerCase();

if (!url || !serviceKey || !username || !password || !email) {
  throw new Error('Set NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, BOOTSTRAP_ADMIN_USERNAME, BOOTSTRAP_ADMIN_PASSWORD, and BOOTSTRAP_ADMIN_EMAIL in your private environment file.');
}
if (password.length < 12 || ['12345siya', 'password123', 'admin123456'].includes(password.toLowerCase()) || /replace|use-a-unique|your-password/i.test(password)) {
  throw new Error('BOOTSTRAP_ADMIN_PASSWORD harus unik, kuat, dan minimal 12 karakter. Jangan gunakan password demo.');
}
if (!/^[A-Za-z0-9._-]{3,30}$/.test(username)) throw new Error('BOOTSTRAP_ADMIN_USERNAME tidak valid.');
if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('BOOTSTRAP_ADMIN_EMAIL tidak valid.');

const supabase = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false }
});

async function findAuthUserByEmail(targetEmail) {
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const found = (data.users || []).find(u => (u.email || '').toLowerCase() === targetEmail);
    if (found) return found;
    if (!data.users || data.users.length < 1000) return null;
  }
  throw new Error('Terlalu banyak akun untuk pencarian email; periksa akun melalui Supabase Dashboard.');
}

let user = await findAuthUserByEmail(email);
// Check the desired username before changing or creating credentials.
const { data: knownProfiles, error: profileListError } = await supabase
  .from('profiles').select('id, username');
if (profileListError) throw profileListError;
const usernameOwner = (knownProfiles || []).find(p => (p.username || '').toLowerCase() === username.toLowerCase());
if (usernameOwner && usernameOwner.id !== user?.id) {
  throw new Error(`Username "${username}" sudah dipakai profil lain. Ubah BOOTSTRAP_ADMIN_USERNAME lalu jalankan ulang.`);
}

let initializedNow = false;
if (!user) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: 'Admin GoLearnMS',
      username,
      base_role: 'guru',
      institution: 'GoLearnMS'
    },
    app_metadata: { golearnms_bootstrap_admin: true }
  });
  if (error) throw error;
  user = data.user;
  initializedNow = true;
} else if (user.app_metadata?.golearnms_bootstrap_admin !== true) {
  // One-time initialization of a matching existing auth user. Subsequent executions never reset the password.
  const { data, error } = await supabase.auth.admin.updateUserById(user.id, {
    password,
    email_confirm: true,
    user_metadata: {
      ...(user.user_metadata || {}),
      full_name: user.user_metadata?.full_name || 'Admin GoLearnMS',
      username,
      base_role: 'guru',
      institution: user.user_metadata?.institution || 'GoLearnMS'
    },
    app_metadata: { ...(user.app_metadata || {}), golearnms_bootstrap_admin: true }
  });
  if (error) throw error;
  user = data.user;
  initializedNow = true;
}

const profileFields = {
  full_name: user.user_metadata?.full_name || 'Admin GoLearnMS',
  username,
  email,
  base_role: 'guru',
  institution: user.user_metadata?.institution || 'GoLearnMS',
  is_admin: true,
  is_superadmin: true,
  blocked: false,
  updated_at: new Date().toISOString()
};
if (initializedNow) profileFields.must_change_password = true;
const { data: profile, error: profileError } = await supabase
  .from('profiles').update(profileFields).eq('id', user.id).select('id').maybeSingle();
if (profileError) throw profileError;
if (!profile) {
  const { error } = await supabase.from('profiles').insert({ id: user.id, ...profileFields });
  if (error) throw error;
}

console.log(`GoLearnMS bootstrap complete. Admin profile ID: ${user.id}`);
console.log(initializedNow
  ? 'Initial password is set from the private environment. Enforce must_change_password in your server-side app and ask the admin to change it at first login.'
  : 'Admin already initialized. Password was not reset; role flags were re-asserted safely.');
