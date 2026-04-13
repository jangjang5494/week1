/**
 * auth-common.js
 * Supabase Auth + 사용자 자격조건 저장/불러오기 공통 모듈
 */

const SB_URL = 'https://ajgurlfgifvicvxsxzqh.supabase.co';
const SB_KEY = 'sb_publishable_VWYME33r2PPoiBgyA5Zsxw_6bW7Hh_5';

// Supabase JS SDK (CDN IIFE 방식 — window.supabase 전역 객체 사용)
let _sb = null;
function getSB() {
  if (!_sb) _sb = window.supabase.createClient(SB_URL, SB_KEY);
  return _sb;
}

// ── Auth ──────────────────────────────────────────────

/** 현재 로그인한 유저 반환 (null이면 비로그인) */
async function authGetUser() {
  const { data: { user } } = await getSB().auth.getUser();
  return user;
}

/** 이메일/비밀번호 회원가입 */
async function authSignUp(email, password) {
  const { data, error } = await getSB().auth.signUp({ email, password });
  if (error) throw error;
  return data;
}

/** 이메일/비밀번호 로그인 */
async function authSignIn(email, password) {
  const { data, error } = await getSB().auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

/** 로그아웃 */
async function authSignOut() {
  await getSB().auth.signOut();
}

/** 인증 상태 변경 콜백 등록 */
function authOnChange(callback) {
  getSB().auth.onAuthStateChange((event, session) => {
    callback(event, session?.user ?? null);
  });
}

// ── 자격조건 저장/불러오기 ────────────────────────────

/**
 * 현재 로그인 유저의 자격조건을 Supabase에 저장 (upsert)
 * @param {object} conditions - details.html의 폼 값 객체
 */
async function saveConditions(conditions) {
  const user = await authGetUser();
  if (!user) return null;
  const { data, error } = await getSB()
    .from('user_conditions')
    .upsert({ user_id: user.id, conditions }, { onConflict: 'user_id' })
    .select()
    .single();
  if (error) throw error;
  return data;
}

/**
 * 현재 로그인 유저의 저장된 자격조건 불러오기
 * @returns {object|null} conditions 객체 또는 null
 */
async function loadConditions() {
  const user = await authGetUser();
  if (!user) return null;
  const { data, error } = await getSB()
    .from('user_conditions')
    .select('conditions, updated_at')
    .eq('user_id', user.id)
    .single();
  if (error && error.code !== 'PGRST116') throw error; // PGRST116 = 결과 없음
  return data || null;
}

// ── 전역 공개 ─────────────────────────────────────────
window.NJG_AUTH = {
  getSB,
  getUser: authGetUser,
  signUp: authSignUp,
  signIn: authSignIn,
  signOut: authSignOut,
  onChange: authOnChange,
  saveConditions,
  loadConditions,
};
