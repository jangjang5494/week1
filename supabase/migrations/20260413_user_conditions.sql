-- =============================================
-- user_conditions 테이블: 사용자 자격조건 저장
-- Supabase SQL Editor에서 실행하세요
-- =============================================

-- 1. 기존 테이블·정책 완전 초기화
drop table if exists public.user_conditions cascade;

-- 2. 테이블 생성
create table public.user_conditions (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid not null unique,
  conditions  jsonb not null default '{}',
  updated_at  timestamptz default now(),
  constraint fk_user foreign key (user_id) references auth.users(id) on delete cascade
);

-- 3. updated_at 자동 갱신 트리거
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_user_conditions_updated_at
  before update on public.user_conditions
  for each row execute function public.handle_updated_at();

-- 4. RLS 활성화
alter table public.user_conditions enable row level security;

-- 5. 정책: 본인 데이터만 읽기/쓰기/수정/삭제
create policy "select_own" on public.user_conditions
  for select using ((select auth.uid()) = user_id);

create policy "insert_own" on public.user_conditions
  for insert with check ((select auth.uid()) = user_id);

create policy "update_own" on public.user_conditions
  for update using ((select auth.uid()) = user_id);

create policy "delete_own" on public.user_conditions
  for delete using ((select auth.uid()) = user_id);
