/**
 * auth-common.js
 * Supabase Auth + 자격조건 저장/불러오기
 * CDN 없이 REST API 직접 사용 (fetch 방식)
 */

const SB_URL = 'https://ajgurlfgifvicvxsxzqh.supabase.co';
const SB_KEY = 'sb_publishable_VWYME33r2PPoiBgyA5Zsxw_6bW7Hh_5';
const SESSION_KEY = 'njg_auth_session';

// ── 세션 localStorage 관리 ──────────────────────────
function _saveSession(session) {
  if (session) localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  else localStorage.removeItem(SESSION_KEY);
}
function _loadSession() {
  try { return JSON.parse(localStorage.getItem(SESSION_KEY)); }
  catch { return null; }
}

// ── 인증 헤더 ────────────────────────────────────────
function _headers(token) {
  const h = { 'Content-Type': 'application/json', 'apikey': SB_KEY };
  if (token) h['Authorization'] = 'Bearer ' + token;
  else h['Authorization'] = 'Bearer ' + SB_KEY;
  return h;
}

// ── Auth state 변경 콜백 목록 ────────────────────────
const _listeners = [];
function _notify(user) {
  _listeners.forEach(fn => { try { fn('SIGNED_' + (user ? 'IN' : 'OUT'), user); } catch(e) {} });
}

// ── 토큰 갱신 ────────────────────────────────────────
async function _refreshToken(refresh_token) {
  try {
    const res = await fetch(`${SB_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: _headers(),
      body: JSON.stringify({ refresh_token })
    });
    if (!res.ok) { _saveSession(null); return null; }
    const data = await res.json();
    const session = { ...data, expires_at: Math.floor(Date.now()/1000) + (data.expires_in || 3600) };
    _saveSession(session);
    return session;
  } catch { _saveSession(null); return null; }
}

// ── 현재 유저 반환 ──────────────────────────────────
async function authGetUser() {
  let session = _loadSession();
  if (!session?.access_token) return null;

  // 토큰 만료 체크 (60초 여유)
  const now = Math.floor(Date.now() / 1000);
  if (session.expires_at && session.expires_at - 60 < now) {
    if (session.refresh_token) {
      session = await _refreshToken(session.refresh_token);
      if (!session) return null;
    } else { _saveSession(null); return null; }
  }
  return session.user || null;
}

// ── 회원가입 ────────────────────────────────────────
async function authSignUp(email, password) {
  const res = await fetch(`${SB_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: _headers(),
    body: JSON.stringify({
      email, password,
      options: { emailRedirectTo: 'https://homesubscribe.org/profile.html' }
    })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.msg || data.message || '회원가입 실패');
  if (data.access_token) {
    const session = { ...data, expires_at: Math.floor(Date.now()/1000) + (data.expires_in || 3600) };
    _saveSession(session);
    _notify(session.user);
  }
  return data;
}

// ── 로그인 ──────────────────────────────────────────
async function authSignIn(email, password) {
  const res = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: _headers(),
    body: JSON.stringify({ email, password })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error_description || data.msg || '로그인 실패');
  const session = { ...data, expires_at: Math.floor(Date.now()/1000) + (data.expires_in || 3600) };
  _saveSession(session);
  _notify(session.user);
  return data;
}

// ── 로그아웃 ────────────────────────────────────────
async function authSignOut() {
  const session = _loadSession();
  if (session?.access_token) {
    await fetch(`${SB_URL}/auth/v1/logout`, {
      method: 'POST',
      headers: _headers(session.access_token)
    }).catch(() => {});
  }
  _saveSession(null);
  _notify(null);
}

// ── 인증 상태 변경 리스너 ────────────────────────────
function authOnChange(callback) {
  _listeners.push(callback);
  // 현재 상태 즉시 통지
  authGetUser().then(user => {
    try { callback('INITIAL_SESSION', user); } catch(e) {}
  });
}

// ── 자격조건 저장 ────────────────────────────────────
async function saveConditions(conditions) {
  const user = await authGetUser();
  if (!user) return null;
  const session = _loadSession();
  const res = await fetch(`${SB_URL}/rest/v1/user_conditions`, {
    method: 'POST',
    headers: {
      ...(_headers(session.access_token)),
      'Prefer': 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify({ user_id: user.id, conditions })
  });
  if (!res.ok) { const e = await res.json(); throw new Error(e.message || '저장 실패'); }
  return await res.json();
}

// ── 자격조건 불러오기 ────────────────────────────────
async function loadConditions() {
  const user = await authGetUser();
  if (!user) return null;
  const session = _loadSession();
  const res = await fetch(
    `${SB_URL}/rest/v1/user_conditions?user_id=eq.${user.id}&select=conditions,updated_at&limit=1`,
    { headers: _headers(session.access_token) }
  );
  if (!res.ok) return null;
  const data = await res.json();
  return data[0] || null;
}

// ── 전역 공개 ────────────────────────────────────────
window.NJG_AUTH = {
  getUser: authGetUser,
  signUp: authSignUp,
  signIn: authSignIn,
  signOut: authSignOut,
  onChange: authOnChange,
  saveConditions,
  loadConditions,
};
