-- =============================================
-- user_conditions 테이블: 사용자 자격조건 저장
-- Supabase SQL Editor에서 실행하세요
-- =============================================

create table if not exists public.user_conditions (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users(id) on delete cascade not null unique,
  conditions  jsonb not null default '{}',
  updated_at  timestamptz default now()
);

-- updated_at 자동 갱신 트리거
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_user_conditions_updated_at on public.user_conditions;
create trigger set_user_conditions_updated_at
  before update on public.user_conditions
  for each row execute function public.set_updated_at();

-- RLS 활성화
alter table public.user_conditions enable row level security;

-- 정책: 본인 데이터만 읽기/쓰기/수정/삭제
create policy "user_conditions_select" on public.user_conditions
  for select using (auth.uid() = user_id);

create policy "user_conditions_insert" on public.user_conditions
  for insert with check (auth.uid() = user_id);

create policy "user_conditions_update" on public.user_conditions
  for update using (auth.uid() = user_id);

create policy "user_conditions_delete" on public.user_conditions
  for delete using (auth.uid() = user_id);
