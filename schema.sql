-- ============================================================
-- 수도권 주거지원 통합 DB 스키마
-- 설계일: 2026-03-21 | 최종수정: 2026-04-02
-- Supabase(PostgreSQL) 기준
-- ★ 멱등성 보장: 반복 실행해도 안전 (CREATE IF NOT EXISTS + ON CONFLICT DO UPDATE SET)
-- ============================================================


-- ============================================================
-- 1. 소득 기준 참조 테이블
-- ============================================================
CREATE TABLE IF NOT EXISTS income_standards (
  id            SERIAL PRIMARY KEY,
  standard_type TEXT    NOT NULL,  -- '중위소득' | '도시근로자월평균'
  year          INTEGER NOT NULL,
  household_size INTEGER NOT NULL, -- 1~6 (7인 이상은 별도 계산식)
  amount        BIGINT  NOT NULL,  -- 100% 기준 금액 (원/월)
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (standard_type, year, household_size)
);

COMMENT ON TABLE income_standards IS '연도별 소득기준 참조. 프로그램 자격판단 시 이 테이블 참조';
COMMENT ON COLUMN income_standards.amount IS '100% 기준값. 실제 적용 시 amount * (pct/100) 계산';

-- 2026년 기준중위소득 (원/월) ★2026-03-21 LH청약플러스 공식 확인
INSERT INTO income_standards (standard_type, year, household_size, amount) VALUES
  ('중위소득', 2026, 1, 2564238),
  ('중위소득', 2026, 2, 4199292),
  ('중위소득', 2026, 3, 5359036),
  ('중위소득', 2026, 4, 6494738),
  ('중위소득', 2026, 5, 7556719),
  ('중위소득', 2026, 6, 8555952)
ON CONFLICT (standard_type, year, household_size) DO NOTHING;

-- 2025년 도시근로자 월평균소득 (원/월) ★2026-03-21 갱신
INSERT INTO income_standards (standard_type, year, household_size, amount) VALUES
  ('도시근로자월평균', 2025, 1, 4576036),
  ('도시근로자월평균', 2025, 2, 6452897),
  ('도시근로자월평균', 2025, 3, 8168429),
  ('도시근로자월평균', 2025, 4, 8802202),
  ('도시근로자월평균', 2025, 5, 9326985)
ON CONFLICT (standard_type, year, household_size) DO NOTHING;


-- ============================================================
-- 2. 주거지원 프로그램 테이블 (핵심)
-- ============================================================
CREATE TABLE IF NOT EXISTS programs (
  id            SERIAL PRIMARY KEY,
  code          TEXT UNIQUE NOT NULL,  -- 내부 식별코드 (예: 'LH_HAPPY_YOUTH')

  -- 분류
  category      TEXT NOT NULL,
  -- '임대주택' | '금융지원' | '주거비지원' | '이자지원' | '보증료지원' | '기타복지'

  subcategory   TEXT,
  -- 임대주택: '공공임대' | '매입임대' | '전세임대' | '민간임대'
  -- 금융지원: '구입자금' | '전세자금' | '월세자금' | '청약통장'
  -- 주거비지원: '월세지원' | '주거급여' | '이사비'

  program_type  TEXT,
  -- 임대: '행복주택' | '국민임대' | '영구임대' | '통합공공임대' | '장기전세' | '매입임대' | '전세임대'
  -- 금융: '디딤돌' | '버팀목' | '보금자리론'
  -- 기타: '청년안심주택' | '천원주택' | '희망하우징'

  -- 기관 및 지역
  institution   TEXT NOT NULL,
  -- 'LH' | 'SH' | '서울시' | '국토교통부' | '주택도시기금' | '성남시'
  region        TEXT NOT NULL DEFAULT '전국',
  -- '전국' | '서울' | '성남'
  region_note   TEXT,                 -- 세부 지역 (예: '역세권', '인천 강화·옹진 제외')

  -- 기본 정보
  name          TEXT NOT NULL,        -- 프로그램 공식 명칭
  target_summary TEXT,               -- 대상 한줄 요약 (예: '만19~39세 청년 무주택자')
  description   TEXT,                -- 상세 설명

  -- ── 자격 조건 (JSONB) ──────────────────────────────────────
  eligibility   JSONB,
  /*
  {
    "age_min": 19,               -- 최소 연령 (null=제한없음)
    "age_max": 39,               -- 최대 연령
    "marital_status": ["미혼"],  -- 가능한 혼인상태 목록 (null=무관)
      -- 값: "미혼" | "기혼" | "신혼(7년이내)" | "예비신혼" | "한부모" | "신생아가구"
    "marriage_years_max": 7,     -- 신혼: 혼인 후 최대 년수
    "children_required": false,  -- 자녀 필수 여부
    "children_age_max": 6,       -- 자녀 나이 상한 (신생아: 2세 이하)
    "newborn_required": false,   -- 신생아(2세이하) 필수 여부
    "is_household_head": true,   -- 세대주 필수 (null=무관)
    "homeless_required": true,   -- 무주택 필수

    "income_type": "중위소득",   -- "중위소득" | "도시근로자월평균" | "절대금액(연소득)"
    "income_pct": 150,           -- 소득 상한 % (income_type이 중위소득/도시근로자 시)
    "income_pct_married": 200,   -- 기혼/맞벌이 적용 % (있으면)
    "income_abs": 40000000,      -- 절대 연소득 상한 (원/년, income_type=절대금액 시)
    "income_abs_married": 50000000,

    "asset_limit": 254000000,    -- 순자산 상한 (원)
    "car_limit": 45630000,       -- 자동차가액 상한 (원, 0=소유불가)

    "region_required": "서울",   -- 거주지 조건 (null=무관)
    "enrollment_required": false, -- 대학 재학 필수
    "employment_required": false, -- 취업 필수

    "special": ["자립준비청년", "국가유공자", "장애인"],  -- 특수자격 해당 시 추가 우대
    "excluded": ["주거급여수급자", "공공임대거주자", "주택도시기금대출이용자"],
    "notes": ["추가 조건 텍스트"]  -- 기타 특이사항
  }
  */

  -- ── 지원 내용 (JSONB) ──────────────────────────────────────
  support_content JSONB,
  /*
  임대주택 예시:
  {
    "rent_pct_min": 30,          -- 시세 대비 최소 %
    "rent_pct_max": 80,          -- 시세 대비 최대 %
    "rent_fixed": 30000,         -- 고정 월임대료 (원, 천원주택)
    "deposit_fixed": 1000000,    -- 고정 보증금 (원)
    "deposit_pct": null,         -- 보증금 시세 대비 % (없으면 null)
    "period_years": 6,           -- 거주 가능 기간 (년)
    "renewal_count": 2,          -- 재계약 가능 횟수
    "area_max_sqm": 85           -- 전용면적 상한 (㎡)
  }

  금융지원(전세자금) 예시:
  {
    "loan_limit": 200000000,     -- 최대 대출한도 (원)
    "loan_pct": 90,              -- 보증금 대비 대출 비율 (%)
    "interest_min": 1.0,         -- 최저 금리 (%)
    "interest_max": 3.0,         -- 최고 금리 (%)
    "period_years": 10,          -- 최장 대출기간 (년)
    "deposit_limit": 300000000,  -- 대상 보증금 상한 (원)
    "monthly_rent_limit": 700000 -- 대상 월세 상한 (원, 월세 대출 시)
  }

  금융지원(구입자금) 예시:
  {
    "loan_limit": 500000000,
    "loan_pct": 70,
    "interest_min": 1.2,
    "interest_max": 3.3,
    "period_years": 30,
    "house_price_limit": 900000000,
    "area_max_sqm": 85
  }

  주거비지원(월세) 예시:
  {
    "monthly_support": 200000,   -- 월 지원금 (원)
    "max_months": 24,            -- 최대 지원 개월
    "total_max": 4800000,        -- 최대 총 지원금 (원)
    "once_per_life": true,       -- 생애 1회 제한
    "deposit_limit": 50000000,   -- 대상 보증금 상한
    "monthly_rent_limit": 600000 -- 대상 월세 상한
  }

  이자지원 예시:
  {
    "annual_max": 3000000,       -- 연 최대 지원금 (원)
    "period_years": 5,           -- 지원 기간 (년)
    "total_max": 15000000,       -- 총 최대 지원금 (원)
    "interest_rate_supported": 1.0, -- 지원 금리 (%)
    "loan_limit": 200000000,     -- 대상 대출 상한
    "deposit_limit": 250000000   -- 대상 보증금 상한
  }
  */

  -- ── 신청 정보 (JSONB) ──────────────────────────────────────
  application_info JSONB,
  /*
  {
    "method": ["온라인", "방문"],
    "url": "https://apply.lh.or.kr",
    "contact": "1600-1004",
    "period_type": "수시" | "정기" | "공고별",
    "period_note": "연 1회, 6월 공고",
    "bank": ["하나은행", "국민은행", "신한은행"],
    "documents": ["임대차계약서", "소득확인서류"]
  }
  */

  -- 상태 관리
  is_active     BOOLEAN     DEFAULT TRUE,
  is_central    BOOLEAN     DEFAULT TRUE,  -- 중앙정부 사업 여부 (false=지자체 고유)
  data_year     INTEGER     DEFAULT 2026,
  source_url    TEXT,

  -- 외부 API 연계 키
  ontong_plcy_no TEXT,       -- 온통청년 API plcyNo (getPlcy 응답 필드)
  -- 온통청년 API: GET https://www.youthcenter.go.kr/go/ythip/getPlcy?apiKeyNm={KEY}&rtnType=json&lclsfNm=주거
  -- 신청기간(aplyYmd), 사업기간(bizPrdBgngYmd~bizPrdEndYmd) 실시간 업데이트 가능

  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE programs IS '주거지원 프로그램 마스터. 임대주택/금융지원/주거비지원/지자체사업 통합';

-- 자주 쓰는 조건 인덱스
CREATE INDEX IF NOT EXISTS idx_programs_category    ON programs (category);
CREATE INDEX IF NOT EXISTS idx_programs_institution ON programs (institution);
CREATE INDEX IF NOT EXISTS idx_programs_region      ON programs (region);
CREATE INDEX IF NOT EXISTS idx_programs_is_active   ON programs (is_active);
CREATE INDEX IF NOT EXISTS idx_programs_eligibility ON programs USING GIN (eligibility);


-- ============================================================
-- 3. 공고 테이블 (크롤링 + 수동 입력)
-- ============================================================
CREATE TABLE IF NOT EXISTS announcements (
  id          SERIAL PRIMARY KEY,
  program_id  INTEGER REFERENCES programs (id) ON DELETE SET NULL,
  -- 매칭된 프로그램 (null=미매칭)

  institution TEXT NOT NULL,  -- 'SH' | 'LH'
  seq         TEXT,           -- 원본 공고 번호
  title       TEXT NOT NULL,
  date        DATE,
  types       TEXT[],         -- 공고 분류 태그 (예: ['행복주택', '청년'])
  url         TEXT,
  status      TEXT,           -- '진행중' | '예정' | '마감' | '확인필요'
  apply_start DATE,
  apply_end   DATE,

  district    TEXT,           -- 공고 소재 구 (청년안심주택 민간임대 순위 판단용)
  raw_data    JSONB,          -- 크롤링 원본 데이터 보관

  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (institution, seq)
);

CREATE INDEX IF NOT EXISTS idx_announcements_status     ON announcements (status);
CREATE INDEX IF NOT EXISTS idx_announcements_institution ON announcements (institution);
CREATE INDEX IF NOT EXISTS idx_announcements_program    ON announcements (program_id);
CREATE INDEX IF NOT EXISTS idx_announcements_apply_end  ON announcements (apply_end);


-- ============================================================
-- 4. 사용자 조건 테이블 (향후 맞춤 알림 서비스)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_conditions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- 기본 인적사항
  birth_year    INTEGER,
  marital_status TEXT,
  -- '미혼' | '기혼' | '신혼(7년이내)' | '예비신혼' | '한부모'

  -- 자녀
  children_count      INTEGER DEFAULT 0,
  youngest_child_age  INTEGER,         -- 최연소 자녀 나이 (세)
  has_newborn         BOOLEAN DEFAULT FALSE,  -- 2세 이하 자녀 여부

  -- 소득 (연소득, 원)
  annual_income       BIGINT,
  spouse_income       BIGINT,
  income_pct_mid      INTEGER,  -- 기준중위소득 대비 % (계산값, 입력 후 자동계산)
  income_pct_urban    INTEGER,  -- 도시근로자월평균 대비 % (계산값)

  -- 자산
  total_assets        BIGINT,
  car_value           BIGINT,

  -- 주거 현황
  region              TEXT,   -- '서울'
  is_homeless         BOOLEAN DEFAULT TRUE,
  is_household_head   BOOLEAN DEFAULT TRUE,
  current_housing     TEXT,   -- '전세' | '월세' | '자가' | '비정상거처' | '기타'
  current_deposit     BIGINT,
  current_monthly_rent INTEGER,

  -- 학력/직업
  is_student          BOOLEAN DEFAULT FALSE,
  school_region       TEXT,   -- 재학 중인 학교 소재지
  is_employed         BOOLEAN,
  employment_years    DECIMAL(4,1),

  -- 특수자격
  is_basic_recipient  BOOLEAN DEFAULT FALSE,  -- 기초생활수급자
  is_near_poor        BOOLEAN DEFAULT FALSE,  -- 차상위계층
  is_independence_youth BOOLEAN DEFAULT FALSE, -- 자립준비청년
  is_disabled         BOOLEAN DEFAULT FALSE,
  is_national_merit   BOOLEAN DEFAULT FALSE,  -- 국가유공자
  is_single_parent    BOOLEAN DEFAULT FALSE,  -- 한부모가족
  military_service    TEXT,  -- 'serving' | 'done' | null

  -- 알림 설정
  alert_email         TEXT,
  interested_categories TEXT[],  -- ['임대주택', '금융지원', '주거비지원']
  interested_regions  TEXT[],    -- ['서울']

  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 5. updated_at 자동 갱신 트리거
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_programs_updated_at
  BEFORE UPDATE ON programs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER trg_announcements_updated_at
  BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER trg_user_conditions_updated_at
  BEFORE UPDATE ON user_conditions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- 6. Row Level Security (Supabase RLS)
-- ============================================================
ALTER TABLE programs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE income_standards  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_conditions   ENABLE ROW LEVEL SECURITY;

-- programs, announcements, income_standards: 누구나 읽기 가능
DROP POLICY IF EXISTS "public read programs" ON programs;
CREATE POLICY "public read programs"
  ON programs FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public read announcements" ON announcements;
CREATE POLICY "public read announcements"
  ON announcements FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public read income_standards" ON income_standards;
CREATE POLICY "public read income_standards"
  ON income_standards FOR SELECT TO anon, authenticated USING (true);

-- user_conditions: 본인 데이터만 접근 (미래 인증 도입 시)
DROP POLICY IF EXISTS "user read own conditions" ON user_conditions;
CREATE POLICY "user read own conditions"
  ON user_conditions FOR SELECT TO authenticated
  USING (auth.uid()::text = id::text);

DROP POLICY IF EXISTS "user insert own conditions" ON user_conditions;
CREATE POLICY "user insert own conditions"
  ON user_conditions FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = id::text);

DROP POLICY IF EXISTS "user update own conditions" ON user_conditions;
CREATE POLICY "user update own conditions"
  ON user_conditions FOR UPDATE TO authenticated
  USING (auth.uid()::text = id::text);

-- service_role: 모든 테이블 full access (GitHub Actions 크롤러용)
DROP POLICY IF EXISTS "service full access programs" ON programs;
CREATE POLICY "service full access programs"
  ON programs FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service full access announcements" ON announcements;
CREATE POLICY "service full access announcements"
  ON announcements FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service full access income_standards" ON income_standards;
CREATE POLICY "service full access income_standards"
  ON income_standards FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ============================================================
-- 7. programs 초기 데이터 (학습 완료된 주요 프로그램)
-- ============================================================

-- ── 임대주택 ─────────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- LH 행복주택 대학생
('LH_HAPPY_STUDENT', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (대학생)',
 '대학 재학생·취업준비생 미혼 무주택', TRUE,
 '{"marital_status":["미혼"],"homeless_required":true,"enrollment_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":108000000,"car_limit":0,"notes":["입·복학 예정자(다음 학기) 포함","취업준비생: 졸업·중퇴 후 2년이내","자산평가: 본인만(부모 소득만 합산)","1순위: 해당자치구 거주/대학소재지","2순위: 시·도 거주"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 행복주택 청년
('LH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (청년·사회초년생)',
 '만19~39세 미혼 무주택 청년·사회초년생', TRUE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":251000000,"car_limit":45420000,"social_newcomer_eligible":true,"social_newcomer_years_max":5,"newborn_income_bonus_pct":20,"newborn_asset_bonus_pct":20,"notes":["사회초년생: 소득활동 5년이내(나이무관)","청약저축 미가입자: 입주 전까지 가입 필수","1순위: 해당자치구 거주/소득근거지","2순위: 시·도 거주","신생아(2023.3.28이후 출생) 보유 시 소득·자산기준 각 +20%p 완화"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 행복주택 신혼부부
('LH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (신혼부부·한부모)',
 '혼인7년이내 신혼부부·예비신혼·6세이하자녀 한부모', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"is_household_member_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":120,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":345000000,"car_limit":45420000,"marriage_years_max":7,"newborn_income_bonus_pct":20,"newborn_asset_bonus_pct":20,"notes":["무주택세대구성원 필수 (신청자 및 세대원 전원 무주택)","예비신혼부부: 혼인 예정 상대방도 무주택 필수","청약저축 미가입자: 부부 중 1인 이상 입주 전까지 가입 필수","자녀있으면 최장 14년","신생아(2023.3.28이후 출생) 보유 시 소득·자산기준 각 +20%p 완화"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),


-- LH 국민임대
('LH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'LH', '전국', 'LH 국민임대주택',
 '무주택세대구성원 저소득 가구 (소득 70% 이하)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":345000000,"car_limit":45420000,"notes":["60㎡이하: 소득70%(1인90%·2인80%) / 60㎡초과: 소득100%(1인120%·2인110%)","50㎡미만: 청약저축 불필요 / 50~60㎡: 1순위 24회이상·2순위 6회이상","우선공급: 신혼30%·장애인등20%·다자녀10%·국가유공자10%·철거민10% 등","가점: 세대주나이·부양가족·거주기간·자녀수·납입횟수·취약계층 각 최대3점","감점: 최근1년 -5점 / 최근3년 -3점"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30,"area_max_sqm":85}',
 '{"method":["온라인","방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 통합공공임대
('LH_INTEGRATED', '임대주택', '공공임대', '통합공공임대', 'LH', '전국', 'LH 통합공공임대주택',
 '만18~39세 청년·신혼부부·한부모 등 중위소득 150% 이하 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"중위소득",
   "youth_priority_pct":100,"youth_priority_pct_1person":120,"youth_priority_pct_2person":110,
   "youth_general_pct":150,"youth_general_pct_1person":170,"youth_general_pct_2person":160,
   "newlywed_priority_pct":100,"newlywed_priority_pct_2person":110,
   "newlywed_general_pct":150,"newlywed_general_pct_2person":160,"newlywed_general_dual_pct":180,"newlywed_general_dual_pct_2person":190,
   "general_pct":150,"general_pct_1person":170,"general_pct_2person":160,
   "asset_limit":345000000,"car_limit":45420000,
   "age_min_youth":18,"age_max_youth":39,
   "notes":["우선공급(60%): 청년 중위100%(1인120%·2인110%) / 신혼부부·한부모 중위100%(2인110%)","일반공급(40%): 청년·일반 중위150%(1인170%·2인160%) / 신혼부부 중위150%(2인160%) 맞벌이180%(2인190%)","청년: 만18~39세 미혼 무주택자 (자립준비청년 퇴소 5년 이내 포함)","신혼부부·예비신혼: 세대원 전원 무주택 필수 (예비신혼은 상대방도 무주택)","임대료: 소득구간별 시세35~90%","배점: 소득·부양가족·거주기간·미성년자녀·납입횟수 / 감점: 최근1년 -5점·최근3년 -3점"]}',
 '{"rent_pct_min":35,"rent_pct_max":90,"period_years":30,"area_max_sqm":85,"notes":["중위30%이하→시세35%","30~50%→45%","50~70%→50%","70~100%→65%","100~130%→80%","130~150%→90%"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 영구임대
('LH_PERMANENT', '임대주택', '공공임대', '영구임대', 'LH', '전국', 'LH 영구임대주택',
 '생계·의료수급자, 국가유공자, 한부모, 장애인 등 취약계층', TRUE,
 '{"homeless_required":true,"income_type":"없음(자격요건)","asset_limit":241000000,"car_limit":37080000,"notes":["신청: 행정복지센터(주민센터) — LH청약플러스 아님","대상: 생계·의료수급자/국가유공자·유족/일본군위안부피해자/한부모가족/북한이탈주민/65세이상수급자·차상위/장애인(소득70%이하)","자산: 총24,100만원·자동차3,708만원 이하","절차: 행정복지센터신청→지자체예비명단→LH통보→퇴거시입주"]}',
 '{"rent_pct":30,"period_years":50,"area_max_sqm":40,"notes":["2년단위 갱신시 자격 재확인"]}',
 '{"method":["방문"],"contact":"읍면동 행정복지센터","period_type":"상시(퇴거 발생 시)"}',
 'https://apply.lh.or.kr'),

-- LH 장기전세주택
('LH_LONG_JEONSE', '임대주택', '전세임대', '장기전세', 'LH', '전국', 'LH 장기전세주택',
 '무주택세대구성원 (소득 100% 이하, 서울·경기 공급)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":120,"asset_limit_seoul":662000000,"asset_limit_gyeonggi":417000000,"car_limit":45420000,"notes":["60㎡이하: 소득100%이하 (50㎡이하 우선공급 50%, 50~60㎡ 우선공급 70%)","60㎡초과: 소득120%이하 (우선공급 100%)","50㎡미만: 청약저축 불필요 / 50~60㎡: 1순위 24회·2순위 6회","서울 장기전세는 SH(시프트)로 공급 — LH는 경기 등 비서울 지역","배점: 무주택기간·나이·부양가족·거주기간·자녀수·납입횟수 각 최대5점","감점: 최근1년 -10점 / 최근3년 -5점","★2026년 기준: 서울 66,200만/경기 41,700만"]}',
 '{"jeonse_pct_max":80,"period_years":20,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 5·10·50년 공공임대 (분양전환형)
('LH_PUBLIC_5_10', '임대주택', '공공임대', '분양전환공공임대', 'LH', '전국', 'LH 5·10·50년 공공임대 (분양전환형)',
 '무주택세대구성원 (소득 100% 이하)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":130,"asset_real_limit":215500000,"car_limit":45630000,"savings_min_rank1":24,"savings_min_rank2":1,"savings_amount_min":6000000,"notes":["특별공급: 신혼10%·생애최초15%·다자녀10%·노부모5%·기관추천20%·일반20%","일반공급 1순위: 청약저축 24회 이상 (투기과열지구 기준)","생애최초 특공: 저축액 600만원+·기혼·소득세5년납부","선정: 2세미만자녀50%→배점30%→추첨20% (우선공급)"]}',
 '{"rent_pct":90,"period_type_5":5,"period_type_10":10,"period_type_50":50,"conversion_price_5":"(건설원가+감정평가)÷2","conversion_price_10":"감정평가액","area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 일반 매입임대 (다가구)
('LH_BUY_GENERAL', '임대주택', '매입임대', '매입임대', 'LH', '전국', 'LH 일반 매입임대주택',
 '수급자·한부모·장애인 등 취약계층 무주택자', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"asset_limit":241000000,"car_limit":37080000,"notes":["1순위: 생계·의료수급자/한부모/차상위/소득70%이하장애인/주거지원시급가구","2순위: 소득50%이하 무주택세대구성원 또는 소득100%이하 장애인","임대기간: 1순위 무제한 / 2순위 최장20년(9회재계약)","신청: 지자체(주민센터)"]}',
 '{"rent_pct":30,"deposit_avg":4750000,"rent_avg_month":100000,"period_max_years":20,"renewal_count":9}',
 '{"method":["방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별","note":"신청: 지자체(주민센터)"}',
 'https://apply.lh.or.kr'),

-- LH 청년 매입임대
('LH_BUY_YOUTH', '임대주택', '매입임대', '청년매입임대', 'LH', '전국', 'LH 청년 매입임대주택',
 '만19~39세 미혼 무주택 청년·대학생·취준생', TRUE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":337000000,"asset_limit_rank3":254000000,"car_limit":45630000,"notes":["1순위: 수급자·한부모·차상위(소득·자산 심사 완화)","2순위: 본인+부모 합산 100%이하, 자산33,700만원(국민임대기준)","3순위: 본인 100%이하, 자산25,400만원(행복주택청년기준)","부모 유주택이어도 신청 가능(가점차등)","청약저축 불필요"]}',
 '{"rent_pct_rank1_min":30,"rent_pct_rank1_max":40,"rent_pct_rank2":50,"deposit_rank1":1000000,"deposit_rank2":2000000,"period_max_years":10,"renewal_count":4}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 매입임대 Ⅰ형
('LH_BUY_NEWLYWED_1', '임대주택', '매입임대', '신혼매입임대', 'LH', '전국', 'LH 신혼·신생아 매입임대 Ⅰ형',
 '혼인7년이내·신생아가구·6세이하자녀 한부모 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":337000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/지원대상한부모","2순위: 자녀있는신혼부부·예비신혼부부/6세이하자녀한부모","3순위: 자녀없는신혼부부(예비신혼부부)","4순위: 6세이하자녀있는혼인가구","자산: 국민임대기준 33,700만원(매입형)"]}',
 '{"rent_pct_min":30,"rent_pct_max":40,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 매입임대 Ⅱ형 (전세형)
('LH_BUY_NEWLYWED_2', '임대주택', '매입임대', '신혼매입임대', 'LH', '전국', 'LH 신혼·신생아 매입임대 Ⅱ형 (전세형)',
 '혼인7년이내·신생아가구·한부모 (소득 130% 이하, 맞벌이 200%)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":379000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/지원대상한부모","2순위: 자녀있는신혼부부·예비신혼부부/6세이하자녀한부모","3순위: 자녀없는신혼부부(예비신혼부부)","4순위: 6세이하자녀있는혼인가구","5순위: 1~4순위외혼인가구","자산: 분양전환공공임대기준 37,900만원","소득: 외벌이130%/맞벌이200%","전세형으로 공급(시세70~80%)"]}',
 '{"rent_pct_min":70,"rent_pct_max":80,"period_max_years":10,"renewal_count":4,"notes":["자녀있으면 최장 14년(재계약6회)"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 기존주택 전세임대 (일반)
('LH_JEONSE_GENERAL', '임대주택', '전세임대', '전세임대', 'LH', '전국', 'LH 기존주택 전세임대 (일반)',
 '수급자·한부모·장애인 등 취약계층 무주택자', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"notes":["1순위: 생계·의료수급자/보호대상한부모/최저주거미달차상위/장애인70%이하/차상위","2순위: 소득50%이하 무주택세대구성원 또는 소득100%이하 장애인","신청: 1·2순위 모두 지자체(주민센터) 또는 LH청약플러스"]}',
 '{"loan_limit_metro":130000000,"loan_limit_metro_city":90000000,"loan_limit_other":70000000,"tenant_burden_pct_min":2,"tenant_burden_pct_max":5,"interest_min":1.2,"interest_max":2.2,"period_max_years":30,"renewal_count":14,"notes":["65세이상·중증장애인·1순위: 재계약 횟수 무제한","입주자가 원하는 주택 직접 물색 후 LH 권리분석"]}',
 '{"method":["온라인","방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 청년전세임대
('LH_JEONSE_YOUTH', '임대주택', '전세임대', '청년전세임대', 'LH', '전국', 'LH 청년전세임대주택',
 '만19~39세 미혼 무주택 청년·대학생·취준생', TRUE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":337000000,"asset_limit_rank3":254000000,"car_limit":45630000,"notes":["1순위: 생계·의료·주거급여수급자/보호대상한부모/차상위/자립준비청년(퇴소5년이내)/청소년복지시설퇴소자(이용2년이상퇴소5년이내) — 소득·자산 완화","2순위: 본인+부모 합산 100%이하, 자산33,700만원(국민임대기준)","3순위: 본인 100%이하, 자산25,400만원(행복주택청년기준)","보증금: 1순위 100만원 / 2·3순위 200만원","혼인시 5회 추가 재계약 가능"]}',
 '{"loan_limit_metro":120000000,"loan_limit_metro_city":95000000,"loan_limit_other":85000000,"loan_limit_share":150000000,"interest_min":1.0,"interest_max":2.0,"deposit_rank1":1000000,"deposit_rank2":2000000,"period_max_years":10,"renewal_count":4,"notes":["혼인시 5회 추가 재계약 가능 → 최장 20년","공동거주 2인 수도권 1.5억 지원","자립준비청년·22세이하 시설퇴소자: 무이자 + 5년간 50% 감면"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 전세임대 Ⅰ형
('LH_JEONSE_NEWLYWED_1', '임대주택', '전세임대', '신혼전세임대', 'LH', '전국', 'LH 신혼·신생아 전세임대 Ⅰ형',
 '혼인7년이내·신생아가구·한부모 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":337000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 자녀있는신혼부부·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼부부(예비신혼)","4순위: 6세이하자녀있는혼인가구","자산: 국민임대기준 33,700만원"]}',
 '{"loan_limit_metro":145000000,"loan_limit_metro_city":110000000,"loan_limit_other":95000000,"tenant_burden_pct":5,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 전세임대 Ⅱ형
('LH_JEONSE_NEWLYWED_2', '임대주택', '전세임대', '신혼전세임대', 'LH', '전국', 'LH 신혼·신생아 전세임대 Ⅱ형',
 '혼인7년이내·신생아가구·한부모 (소득 130% 이하, 맞벌이 200%)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 자녀있는신혼부부·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼부부(예비신혼)","4순위: 6세이하자녀있는혼인가구","자산: 35,400만원(신혼전세Ⅱ기준)","소득: 외벌이130%/맞벌이200%"]}',
 '{"loan_limit_metro":240000000,"loan_limit_metro_city":160000000,"loan_limit_other":130000000,"tenant_burden_pct":20,"period_max_years":10,"renewal_count":4,"notes":["자녀 있을 경우 2회 추가 재계약 → 최장 14년"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 다자녀 전세임대 ⚠️ LH 공식 전세임대 페이지 목록엔 없지만 마이홈포털 확인됨 (2026-03-28)
('LH_JEONSE_CHILDREN', '임대주택', '전세임대', '전세임대', 'LH', '전국', 'LH 다자녀 전세임대',
 '미성년 직계비속 2명 이상 무주택 가구 (소득 70% 이하)', TRUE,
 '{"homeless_required":true,"children_min":2,"income_type":"도시근로자월평균","income_pct":70,"asset_limit":337000000,"car_limit":45630000,"notes":["미성년 직계비속 2명 이상 (태아 포함)","2자녀: 수도권 1.55억 지원 / 3자녀이상: 자녀 1인당 +2,000만원 추가 지원","소득·자산 기준 ⚠️ 마이홈포털 기준(다자녀 매입임대 동일 기준 추정)","신청: 지자체(주민센터)"]}',
 '{"loan_limit_metro":155000000,"loan_limit_metro_city":120000000,"loan_limit_other":105000000,"tenant_burden_pct":2,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼희망타운 (분양형)
('LH_HOPE_TOWN', '분양주택', '공공분양', '신혼희망타운', 'LH', '전국', 'LH 신혼희망타운 (분양형)',
 '혼인7년이내·예비신혼·6세이하자녀·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모","혼인가구(6세이하자녀)"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":140,"asset_limit":362000000,"car_limit":45630000,"marriage_years_max":7,"savings_min_rank1":6,"newborn_income_bonus_pct":20,"newborn_asset_bonus_pct":20,"notes":["우선공급30%(혼인2년이내 OR 2세이하자녀): 단독130%·맞벌이140%, 배점제","일반공급60%(혼인2~7년·3~6세자녀): 단독130%·맞벌이140%, 배점제","추첨공급10%: 단독130%·맞벌이200%","신생아(2023.3.28이후): 소득·자산 완화 (1명 +10%p / 2명이상 +20%p)","예비신혼부부: 공고일로부터 1년 내 혼인증명 필요","6세이하 자녀 둔 혼인가구도 대상 포함","생애 1회 제한"]}',
 '{"area_max_sqm":60,"notes":["신혼희망타운 전용 주택담보대출 주택가격 30%이상 가입 필수(총자산이 공급가격 초과 시)"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1243&cntntsId=1132'),

-- LH 주거취약계층 주거지원
('LH_VULNERABLE', '임대주택', '매입임대', '주거취약계층', 'LH', '전국', 'LH 주거취약계층 주거지원',
 '쪽방·고시원·여인숙 등 비정상거처 3개월이상 거주 취약계층', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":50,"asset_limit":24100000,"car_limit":45630000,"notes":["대상: 쪽방·고시원·여인숙·비닐하우스·노숙인쉼터 3개월이상/범죄피해자/최저주거기준미달아동가구","총자산 2,410만원 이하"]}',
 '{"rent_pct":30,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인","방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 다자녀 매입임대 ★2026-03-21 신규 추가
('LH_BUY_MULTICHILDREN', '임대주택', '매입임대', '매입임대', 'LH', '전국', 'LH 다자녀 매입임대주택',
 '미성년 자녀 2인 이상 양육 무주택 가구 (소득 70% 이하)', TRUE,
 '{"homeless_required":true,"children_min":2,"income_type":"도시근로자월평균","income_pct":70,"asset_limit":337000000,"car_limit":45630000,"notes":["미성년 자녀 2인 이상 (태아 포함)","신청: 지자체(주민센터)","1순위: 신생아가구+수급자/한부모/차상위(AND조건)","2순위: 신생아가구만 or 수급자/한부모/차상위만","3순위: 소득70%이하 기타 다자녀가구","자산: 국민임대기준 33,700만원(매입형)"]}',
 '{"rent_pct_min":30,"rent_pct_max":40,"period_max_years":20,"renewal_count":9}',
 '{"method":["방문"],"contact":"지자체(행정복지센터)","period_type":"공고별","url":"https://apply.lh.or.kr"}',
 'https://apply.lh.or.kr'),

-- LH 든든전세주택 ★2026-03-21 신규 추가
('LH_DNDNT_JEONSE', '임대주택', '전세임대', '든든전세주택', 'LH', '전국', 'LH 든든전세주택',
 '중산층까지 확대한 비아파트(빌라·다세대) 전세임대 (소득·자산 무관)', TRUE,
 '{"homeless_required":true,"income_required":false,"asset_required":false,"notes":["소득·자산 기준 없음 (중산층까지 대상)","대상주택: 빌라·다세대·연립(非아파트)","순위: 신생아·다자녀→신혼부부→기타","1인 가구도 신청 가능"]}',
 '{"jeonse_pct_max":90,"period_max_years":8,"renewal_count":3,"notes":["시세 90% 이하 전세","전세형으로 공급","2년+재계약3회=최장8년"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 기숙사형 매입임대 ★2026-03-24 신규 추가
('LH_DORM_YOUTH', '임대주택', '매입임대', '기숙사형매입임대', 'LH', '전국', 'LH 기숙사형 매입임대',
 '대학생·대학원생 무주택자 (입학·복학 예정자 포함)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":337000000,"asset_limit_rank3":254000000,"car_limit":45630000,"age_max_rank3":39,"notes":["1순위: 생계·주거·의료급여수급자/차상위/한부모(소득·자산 심사 완화)","2순위: 본인+부모 합산 도시근로자 100% 이하, 자산33,700만원","3순위: 본인 도시근로자 100% 이하, 자산25,400만원 (만19~39세 미혼자)","주 대상: 대학생·대학원생 (입학·복학 예정자 포함)","시세 약 40% 수준"]}',
 '{"rent_pct":40,"period_max_years":10,"renewal_count":4,"notes":["시세 약 40%","공급시기: 반기별(6월·12월)"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"반기별"}',
 'https://apply.lh.or.kr'),

-- LH 집주인 임대주택 ★2026-03-28 신규 추가
('LH_LANDLORD_RENT', '임대주택', '매입임대', '집주인임대', 'LH', '전국', 'LH 집주인 임대주택',
 '청년(19~39세)·신혼부부(혼인7년이내)·고령자(65세이상) (소득 120% 이하)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":120,"age_min_youth":19,"age_max_youth":39,"marriage_years_max":7,"notes":["청년(만19~39세): 소득 있으면 본인 120%이하 / 소득 없으면 부모 120%이하","신혼부부(혼인7년이내): 소득 120%이하","고령자(만65세이상): 소득 120%이하","민간 소유 주택을 LH가 위탁받아 임대하는 방식"]}',
 '{"rent_pct":85,"notes":["시중시세 85% 수준"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),


-- SH 행복주택 청년
('SH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (청년)',
 '만19~39세 서울 거주 청년 무주택자', TRUE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":251000000,"car_limit":45420000,"social_newcomer_eligible":true,"social_newcomer_years_max":5,"notes":["사회초년생: 나이무관·근무경력5년이내","청약종합저축 가입 필요 (미가입자 입주 전까지 가입)","1순위: 행복주택 소재 자치구 거주지 또는 소득근거지","2순위: 서울 내 타 자치구 거주지 또는 소득근거지","가점: 거주기간(최대3점)·청약통장가입기간(최대3점)","★자산: 25,100만원·차량: 4,542만원 (2026 건설형 기준)"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":10,"renewal_count":4}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr'),

-- SH 청년안심주택 공공임대 (청년)
('SH_SAFETY_PUBLIC_YOUTH', '임대주택', '공공임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 공공임대 (청년)',
 '만19~39세 미혼 무주택 청년, 역세권', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":345000000,"asset_limit_rank3":251000000,"car_limit":45630000,"notes":["1순위: 수급자·보호대상한부모·차상위 (소득·자산심사 없음)","2순위: 본인+부모 소득100%이하·자산 국민임대기준(34,500만)","3순위: 본인 소득100%이하·자산 행복주택청년기준(25,100만)","서울 거주 요건 없음 (역세권 민관협력 사업)","★3순위 자산: 25,100만원 (2026 건설형 기준)"]}',
 '{"rent_pct_1rank":30,"rent_pct_2to3rank":50,"area_max_sqm":85,"period_years":2,"renewal_count":4,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3396C3532/contents.do'),

-- SH 청년안심주택 공공임대 (신혼부부)
('SH_SAFETY_PUBLIC_NEWLYWED', '임대주택', '공공임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 공공임대 (신혼부부)',
 '만19~39세 무주택 신혼부부·예비신혼부부·신생아가구, 역세권', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":345000000,"car_limit":45630000,"marriage_years_max":7,"notes":["신혼I: 소득70%(맞벌이90%)·자산34,500만 / 신혼II: 소득130%(맞벌이200%)·자산 분양전환공공임대기준","신청자격: 혼인7년이내·예비신혼·신생아가구(2년이내)·한부모·6세이하자녀혼인가구","1순위: 신생아가구·보호대상한부모","2순위: 자녀있는(예비)신혼·6세이하자녀한부모","3순위: 자녀없는(예비)신혼부부","4순위: 6세이하자녀혼인가구 (신혼II는 5순위: 기타혼인가구 추가)","서울 거주 요건 없음 (역세권 민관협력 사업)","★신혼Ⅰ 자산: 34,500만원 (2026년 기준 갱신)"]}',
 '{"rent_pct_under50":30,"rent_pct_under70":50,"rent_pct_under90":50,"area_max_sqm":85,"period_years":2,"renewal_count":9,"period_max_years":20}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3396C3533/contents.do'),

-- SH 청년안심주택 민간임대 (청년) — 공공지원민간임대 특별공급
('SH_SAFETY_PRIVATE_YOUTH', '임대주택', '민간임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 민간임대 (청년)',
 '만19~39세 미혼 무주택 청년, 역세권', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":100,"income_pct_rank2":110,"income_pct_rank3":120,"asset_limit":345000000,"car_limit":45630000,"notes":["특별공급 1순위: 소득100%이하·해당소재지(거주·대학·직장)","특별공급 2순위: 소득110%이하·서울 내 타지역","특별공급 3순위: 소득120%이하·그 외 지역","동일순위 경쟁: 소득순위→지역순위→추첨","일반공급: 소득·자산 무관 무작위 추첨","특별공급 시세75% / 일반공급 시세85%"]}',
 '{"special_supply_pct":20,"general_supply_pct":80,"rent_pct_special":75,"rent_pct_general":85}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://housing.seoul.go.kr/site/main/content/sh02_05'),

-- SH 청년안심주택 민간임대 (신혼부부) — 공공지원민간임대 특별공급
('SH_SAFETY_PRIVATE_NEWLYWED', '임대주택', '민간임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 민간임대 (신혼부부)',
 '만19~39세 무주택 신혼부부·예비신혼부부·신생아가구, 역세권', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":100,"income_pct_rank2":110,"income_pct_rank3":120,"asset_limit":345000000,"car_limit":45630000,"notes":["특별공급 1순위: 소득100%이하·해당소재지(거주·대학·직장)","특별공급 2순위: 소득110%이하·서울 내 타지역","특별공급 3순위: 소득120%이하·그 외 지역","동일순위 경쟁: 소득순위→지역순위→추첨","일반공급: 소득·자산 무관 무작위 추첨","특별공급 시세75% / 일반공급 시세85%"]}',
 '{"special_supply_pct":20,"general_supply_pct":80,"rent_pct_special":75,"rent_pct_general":85}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://soco.seoul.go.kr'),


-- SH 희망하우징
('SH_HOPE_HOUSING', '임대주택', '매입임대', '희망하우징', 'SH', '서울', 'SH 희망하우징',
 '서울 소재 대학 재학생 (미혼 무주택)', FALSE,
 '{"marital_status":["미혼"],"homeless_required":true,"school_region_required":"서울","enrollment_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit_rank2":337000000,"asset_limit_rank3":104000000,"car_limit_rank2":45630000,"car_limit_rank3":0,"notes":["거주지 조건 없음 - 서울 소재 대학 재학이 핵심 조건","복학·입학 예정자(다음 학기) 포함","1순위: 수급자·한부모·차상위 (소득·자산 무관)","2순위: 본인+부모 합산 100%이하·자산33,700만·차량4,563만","3순위: 본인 소득 100%이하·자산10,400만·차량무소유","가점: 생계의료급여3점·부모무주택2점·장애인(본인)2점·소득50%이하3점·청약저축24회이상3점","시설: 연남·공릉원룸텔, 공릉·갈현·정릉기숙사"]}',
 '{"deposit_fixed":1090000,"rent_fixed_min":70000,"rent_fixed_max":140000,"period_years":2,"renewal_count":2,"period_max_years":6}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1591C592/contents.do'),

-- SH 사회주택 (토지지원형·리모델링형 공통)
('SH_SOCIAL_HOUSING', '임대주택', '사회주택', '사회주택', 'SH', '서울', 'SH 사회주택',
 '서울 거주 무주택 세대구성원, 도시근로자 월평균소득 120% 이하', FALSE,
 '{"homeless_required":true,"seoul_residence_required":true,"income_type":"도시근로자월평균","income_pct":120,"asset_limit":337000000,"asset_limit_youth":254000000,"car_limit":45630000,"notes":["서울 거주 무주택 세대구성원 전체 대상","소득: 전년도 도시근로자 월평균소득 120% 이하","총자산: 만19~39세 2억5,400만원 / 그 외 3억3,700만원 이하","자동차가액: 4,563만원 이하","유형: 토지지원형(토지임대부) / 리모델링형","임대료: 시세 80% 수준 / 최장 10년 거주"]}',
 '{"rent_pct":80,"period_years_max":10}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"02-2133-7300","period_type":"공고별"}',
 'https://soco.seoul.go.kr/soHouse/main/contents.do?menuNo=300007')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- SH 임대주택 (장기전세, 미리내집, 국민임대, 매입임대, 희망하우징, 행복주택, 전세임대, 청년안심주택)
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central, eligibility, support_content, application_info, source_url) VALUES

-- SH 장기전세주택
('SH_JANGKI_JEONSE', '임대주택', '공공임대', '장기전세', 'SH', '서울', 'SH 장기전세주택',
 '서울 거주 무주택세대구성원, 청약저축 가입자', FALSE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":150,"income_pct_married":200,"asset_limit":662000000,"car_limit":45420000,"newborn_income_bonus_pct":20,"notes":["60㎡이하: 소득105%이하 (맞벌이 140%) — 70%이하 우선공급","60~85㎡: 소득150%이하 (맞벌이 200%)","85㎡초과: 소득150%이하 (청약예금 2년이상)","청약저축 1순위: 2년이상+24회이상 / 2순위: 6개월이상+6회이상","신생아(2023.3.28이후) 소득기준 +20%p 완화","★총자산: 66,200만원·자동차: 4,542만원 (2026 건설형 기준)"]}',
 '{"jeonse_pct":80,"notes":["전세보증금 납부 방식","월세 없음","가점제 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1587C589/contents.do'),

-- SH 장기전세주택2 (미리내집) - 신혼부부 특화
('SH_MIRINAE_JIP', '임대주택', '공공임대', '장기전세', 'SH', '서울', 'SH 장기전세주택2 미리내집 (신혼부부)',
 '혼인7년이내 신혼부부·예비신혼부부, 서울 거주 무주택', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"region_required":"서울","marriage_years_max":7,"income_type":"도시근로자월평균","income_pct":150,"income_pct_married":200,"asset_limit":662000000,"car_limit":45420000,"newborn_income_bonus_pct":20,"notes":["60㎡이하: 소득120%이하 (맞벌이 180%)","60~85㎡: 소득150%이하 (맞벌이 200%)","공고 전 5년 무주택 이력 필요","저소득자 40% 우선배정","자녀 있을 경우 자산기준 20% 완화","★총자산: 66,200만원·자동차: 4,542만원 (2026 건설형 기준)"]}',
 '{"jeonse_pct":80,"notes":["전세보증금 납부","저소득자 우선 40%","가점제 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T6792C6812/contents.do'),

-- SH 국민임대주택
('SH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'SH', '서울', 'SH 국민임대주택',
 '서울 거주 무주택 저소득 세대', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":345000000,"car_limit":45420000,"newborn_income_bonus_pct":20,"notes":["60㎡이하: 소득70%(1인90%·2인80%) / 60㎡초과: 소득100%(1인120%·2인110%)","1순위: 소득50%이하(1인70%·2인60%) / 2순위: 소득70%이하(1인90%·2인80%)","50㎡미만: 청약저축 불필요 / 50~60㎡: 1순위 24회이상·2순위 6회이상","가점: 세대주나이·부양가족·서울거주기간·청약저축납입횟수 등","신생아(2023.3.28이후) 소득·자산 +20%p 완화 / 임대기간 30년"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T590C1479/contents.do'),

-- SH 매입임대주택 (청년)
('SH_PURCHASE_RENT_YOUTH', '임대주택', '매입임대', '청년매입임대', 'SH', '서울', 'SH 청년 매입임대주택',
 '서울 거주 대학생·취준생·만19~39세 무주택 청년', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":337000000,"asset_limit_rank3":254000000,"car_limit":45630000,"notes":["1순위: 생계·의료·주거급여수급자/보호대상한부모/차상위계층 (소득·자산 조건 완화)","2순위: 본인+부모 합산 100%이하, 자산33,700만원","3순위: 본인 소득 100%이하, 자산25,400만원","가점: 수급(3점)/한부모(3점)/부모무주택(2점)/청약저축24회이상(3점) 등"]}',
 '{"rent_pct_rank1":30,"rent_pct_rank2":50,"deposit_rank1_min":1000000,"deposit_rank1_max":2000000,"deposit_rank2_min":2000000,"deposit_rank2_max":4000000,"area_avg_sqm":30,"period_years":2,"renewal_count":4,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T591C1483/contents.do'),

-- SH 전세임대주택
('SH_JEONSE_RENT', '임대주택', '전세임대', '전세임대', 'SH', '서울', 'SH 전세임대주택',
 '서울 거주 무주택 취약계층 (수급자·한부모·장애인)', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"asset_limit":245000000,"car_limit":45630000,"notes":["1순위: 생계·의료수급자/한부모/시급가구/장애인70%/만65세이상","2순위: 소득50%이하/장애인100%","신생아가산: 10~20%p 상향","★총자산: 24,500만원 (SH 사이트 원문 확인 2026-06-22)"]}',
 '{"notes":["입주자가 원하는 주택 선택","SH가 집주인과 전세계약 후 저렴 재임대"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3156C3157/contents.do'),

-- SH 행복주택 대학생
('SH_HAPPY_STUDENT', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (대학생)',
 '서울 소재 대학 재학생 (미혼 무주택)', TRUE,
 '{"marital_status":["미혼"],"homeless_required":true,"enrollment_required":true,"school_region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":108000000,"car_limit":0,"notes":["소득: 본인+부모 합산 기준","서울 거주 요건 없음 (전국 신청 가능)","1순위: 주택소재 자치구에 재학대학 소재 또는 본인 거주지","2순위: 서울 내 타 자치구에 재학대학 소재 또는 거주지","배점(1순위): 대학생-부모 모두 서울 외 3점/1인 서울 외 1점","배점(1순위): 취업준비생-해당자치구 3년이상거주 3점/미만 1점","선정순서: 2세미만자녀→순위→배점→추첨","취업준비생: 대학·고교 졸업·중퇴 2년 이내"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"notes":["2세미만 자녀→순위→배점→추첨 순 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1594C1603/sublink.do')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- SH 국민·공공임대 추가 유형 ★2026-03-30 공식사이트 확인
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- SH 공공·주거환경임대주택
('SH_PUBLIC_ENV_RENT', '임대주택', '공공임대', '공공임대', 'SH', '서울', 'SH 공공·주거환경임대주택',
 '서울 거주 무주택 성년, 청약저축 가입자 (분양전환 없음)', TRUE,
 '{"homeless_required":true,"region_required":"서울","age_min":19,"income_type":"도시근로자월평균","income_pct":120,"asset_limit":345000000,"asset_real_limit":215500000,"car_limit":45630000,"notes":["60㎡이하: 소득70%(1인90%·2인80%) / 60㎡초과: 소득120%","청약저축 필수: 1순위 2년이상+24회이상 / 2순위 6개월이상+6~23회","부동산 자산 별도 한도: 21,550만원 이하 (자녀수에 따라 최대 25,860만원)","분양전환 없음 (임대전용), 2년 단위 계약 갱신"]}',
 '{"rent_pct_min":50,"rent_pct_max":80,"notes":["2년 단위 재계약 갱신"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T590C1480/contents.do'),

-- SH 재개발임대주택 (일반공급)
('SH_REDEVELOP_RENT', '임대주택', '공공임대', '공공임대', 'SH', '서울', 'SH 재개발임대주택 (일반공급)',
 '서울 거주 무주택 저소득세대, 재개발 철거 후 잔여물량', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_1person":90,"income_pct_2person":80,"asset_limit":337000000,"car_limit":45630000,"newborn_income_bonus_pct":20,"notes":["재개발 철거세입자 우선공급 후 잔여 물량 일반공급","1순위: 소득50%이하(1인70%·2인60%) / 2순위: 소득70%이하(1인90%·2인80%)","가점: 세대주나이·부양가족수·서울거주기간·청약저축납입횟수","신생아(2023.3.28이후) 소득·자산 +20%p 완화","분양전환 없음 (임대전용)","★총자산: 33,700만원 (SH 사이트 확인 2026-06-22)"]}',
 '{"rent_pct_min":50,"rent_pct_max":80,"period_years":30}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T590C1481/contents.do'),

-- SH 도시형생활주택
('SH_URBAN_LIVING', '임대주택', '공공임대', '공공임대', 'SH', '서울', 'SH 도시형생활주택',
 '서울 거주 1~2인 무주택 가구 (300세대 미만 소규모)', TRUE,
 '{"homeless_required":true,"region_required":"서울","household_max":2,"income_type":"도시근로자월평균","income_pct":70,"income_pct_rank1":50,"asset_limit":345000000,"car_limit":45630000,"notes":["1~2인 가구 전용 (300세대 미만 소규모 단지)","1순위: 소득50%이하 / 2순위: 소득50~70%","가점: 세대주나이·서울거주기간·청약저축납입횟수 등","분양전환 없음 (임대전용)"]}',
 '{"rent_pct_min":50,"rent_pct_max":80}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T590C7493/contents.do')

ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- SH 임대주택 추가 ★2026-03-26 신혼·매입·전세 유형 DB 연동
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- SH 일반 매입임대주택
('SH_BUY_GENERAL', '임대주택', '매입임대', '매입임대', 'SH', '서울', 'SH 일반 매입임대주택',
 '서울 거주 무주택 가구 (수급자·한부모·장애인 우선)', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_priority":50,"asset_limit":237000000,"car_limit":45630000,"notes":["1순위: 수급자/한부모/시급가구(RIR30%↑)/65세이상저소득/장애인(70%이하)","2순위: 소득50%이하/장애인(100%이하)","자녀1명: 자산+2,400만/차+380만 완화, 자녀2명이상: 자산+4,700만/차+760만 완화"]}',
 '{"rent_pct_rank1":30,"rent_pct_rank2":50,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1589C1590/sublink.do'),

-- SH 신혼·신생아 매입임대 Ⅰ형
('SH_BUY_NEWLYWED_1', '임대주택', '매입임대', '신혼매입임대', 'SH', '서울', 'SH 신혼·신생아 매입임대 Ⅰ형',
 '서울 거주 신혼부부(7년이내)·신생아가구·한부모 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":337000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼(예비신혼)","⚠️4순위: 6세이하자녀있는혼인가구 포함 여부 공고문 확인 필요","소득50%이하: 시세30%"]}',
 '{"rent_pct_min":30,"rent_pct_max":50,"period_max_years":20}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1590C1484/contents.do'),

-- SH 신혼·신생아 매입임대 Ⅱ형
('SH_BUY_NEWLYWED_2', '임대주택', '매입임대', '신혼매입임대', 'SH', '서울', 'SH 신혼·신생아 매입임대 Ⅱ형',
 '서울 거주 혼인가구·신생아가구·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"car_limit":45630000,"marriage_years_max":7,"newborn_asset_bonus":{"1child":34000000,"2plus":68000000},"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼(예비신혼)","⚠️4순위: 6세이하자녀있는혼인가구 포함 여부 공고문 확인 필요","신생아 자산완화: 1명 +3,400만 / 2명이상 +6,800만 (2023.3.28이후 출생)","시세 70% (소득80%이하: 60%)"]}',
 '{"rent_pct_min":60,"rent_pct_max":70,"period_max_years":14}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1590C1484/contents.do'),

-- SH 장기미임대
('SH_LONG_UNOCCUPIED', '임대주택', '매입임대', '매입임대', 'SH', '서울', 'SH 장기미임대',
 '서울 거주 만19세이상 무주택 (6개월이상 미임대 물량)', FALSE,
 '{"age_min":19,"homeless_required":true,"region_required":"서울","income_required":false,"asset_required":false,"income_pct":130,"notes":["소득·자산 제한 없음 (소득130%이하 1순위, 130%초과 2순위)","공가발생 6개월 이상 경과한 매입임대주택 물량","우편접수 가능","최장 4년 거주"]}',
 '{"period_max_years":4}',
 '{"method":["우편","온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"수시"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1590C4352/contents.do'),

-- SH 행복주택 (신혼부부)
('SH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (신혼부부)',
 '서울 거주 혼인7년이내·6세이하자녀 한부모 무주택', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"is_household_member_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_2person":110,"income_pct_married":120,"income_pct_married_2person":130,"asset_limit":345000000,"car_limit":45420000,"marriage_years_max":7,"notes":["본인 또는 배우자 1인 청약종합저축 가입 필요","한부모: 만6세이하 자녀(태아포함) 양육","2세미만자녀→순위→배점→추첨","자녀1명이상: 최장14년","★차량: 4,542만원 (2026 건설형 기준)"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":14}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1594C1603/sublink.do'),

-- SH 신혼·신생아 전세임대 Ⅰ형
('SH_JEONSE_NEWLYWED_1', '임대주택', '전세임대', '신혼전세임대', 'SH', '서울', 'SH 신혼·신생아 전세임대 Ⅰ형',
 '서울 거주 신혼부부(7년이내)·신생아가구 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":345000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼(예비신혼)","⚠️4순위: 6세이하자녀있는혼인가구 포함 여부 공고문 확인 필요","SH 최대 1억4,500만원 지원 / 입주자 5% 부담","★총자산: 34,500만원 (2026년 기준 갱신)"]}',
 '{"tenant_burden_pct":5,"loan_limit":138000000,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3156C3158/contents.do'),

-- SH 신혼·신생아 전세임대 Ⅱ형
('SH_JEONSE_NEWLYWED_2', '임대주택', '전세임대', '신혼전세임대', 'SH', '서울', 'SH 신혼·신생아 전세임대 Ⅱ형',
 '서울 거주 혼인가구·신생아가구·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼·예비신혼/6세이하자녀한부모","3순위: 자녀없는신혼(예비신혼)","⚠️4순위: 6세이하자녀있는혼인가구 포함 여부 공고문 확인 필요","SH 최대 6억원 지원 / 입주자 20% 부담"]}',
 '{"tenant_burden_pct":20,"loan_limit":600000000,"period_max_years":14,"renewal_count":6}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3156C3158/contents.do'),

-- SH 전세임대형 든든주택
('SH_DNDNT_JEONSE', '임대주택', '전세임대', '든든전세주택', 'SH', '서울', 'SH 전세임대형 든든주택',
 '서울 거주 무주택 세대구성원 (소득·자산 무관)', FALSE,
 '{"homeless_required":true,"region_required":"서울","income_required":false,"asset_required":false,"notes":["소득·자산 기준 없음","1순위: 신생아가구(2년이내출산)/다자녀(미성년2명이상)","2순위: 신혼부부(7년이내)/예비신혼","3순위: 일반","SH 최대 2억원 지원 / 입주자 20% 부담"]}',
 '{"tenant_burden_pct":20,"loan_limit":200000000,"period_max_years":8,"renewal_count":3}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T3156C7392/contents.do')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- ★2026-03-26 기존 데이터 수정
-- ============================================================

-- SH 청년매입임대 자산기준 rank2/rank3 구조 추가
-- 코드 로직: rank2(본인+부모소득)=33,700만원 / rank3(본인소득)=25,400만원
UPDATE programs
SET eligibility = (eligibility - 'asset_limit')
  || '{"asset_limit_rank2":337000000,"asset_limit_rank3":254000000}'::jsonb
WHERE code = 'SH_PURCHASE_RENT_YOUTH';


-- ── SH 주택분양 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 나눔형 분양주택 일반공급
('SH_NAMOOM_GENERAL', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (일반공급)',
 '수도권 거주 무주택세대구성원, 청약저축 가입자', FALSE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":200,"asset_limit":354000000,"newborn_income_bonus_pct":20,"notes":["주택청약종합저축 또는 청약저축 가입 필수","신생아(2023.3.28이후): 자녀1명 +10%p / 2명이상 +20%p","사전예약→본청약 2단계 진행","토지임대부: SH토지소유·수분양자건물소유","이익공유형: 처분손익 70% 수분양자귀속"]}',
 '{"notes":["분양가 저렴(토지비 제외)","처분시 SH환매조건"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T5553C5554/sublink.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7335/contents.do'),

-- 나눔형 분양주택 청년 특별공급
('SH_NAMOOM_YOUTH', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (청년 특별공급)',
 '만19~39세 미혼 무주택 청년, 청약6개월이상', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"asset_limit_self":270000000,"asset_limit_parents":1011000000,"savings_min_rank1":6,"notes":["본인자산 27,000만원 이하 / 부모자산 101,100만원 이하","생애 1회 제한"]}',
 '{"once_per_life":true,"notes":["특별공급은 1개 유형만 신청가능"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T5554C7336/contents.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- 나눔형 분양주택 신혼부부 특별공급
('SH_NAMOOM_NEWLYWED', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (신혼부부 특별공급)',
 '혼인7년이내·예비신혼·6세이하자녀 한부모 무주택, 청약6개월이상', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"marriage_years_max":7,"savings_min_rank1":6,"notes":["자녀 있으면 1순위 / 없으면 2순위","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- 나눔형 분양주택 신생아 특별공급
('SH_NAMOOM_NEWBORN', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (신생아 특별공급)',
 '2세 미만 자녀(태아·입양아 포함) 보유 무주택가구', FALSE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"income_pct_married":200,"asset_limit":354000000,"newborn_required":true,"newborn_income_bonus_pct":20,"savings_min_rank1":6,"notes":["2세 미만 자녀(태아·입양아 포함) 보유 필수","신생아(2023.3.28이후): 소득·자산기준 +20%p 완화","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- 나눔형 분양주택 생애최초 특별공급
('SH_NAMOOM_FIRST', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 혼인 중이거나 자녀 보유, 소득세 5년 납부', FALSE,
 '{"homeless_required":true,"life_first_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"savings_amount_min":6000000,"notes":["세대원 전원 과거·현재 주택 미소유 필수 (생애최초)","혼인 중이거나 자녀 보유 조건","근로자·자영업자 5년이상 소득세 납부","청약저축 600만원 이상 (투기과열지구 2년·24회 / 비과열지구 1년·12회)","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- ── SH 토지임대부 분양주택 ────────────────────────────────────

-- 토지임대부 일반공급
('SH_LAND_LEASE_GENERAL', '분양주택', '공공분양', '토지임대부', 'SH', '서울', 'SH 토지임대부 분양주택 (일반공급)',
 '수도권 거주 무주택세대구성원, 청약저축 가입자', FALSE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":200,"asset_limit":354000000,"newborn_income_bonus_pct":20,"notes":["토지는 SH 소유, 건물만 분양 (토지 임대료 월 납부)","SH 환매 조건 (처분 시 SH에 우선 매각)","청약저축 또는 주택청약종합저축 가입 필수"]}',
 '{"notes":["분양가 저렴(토지비 제외)","토지 임대료 월 납부 조건"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/main/lay2/S1T5832C5893/contents.do"}',
 'https://www.i-sh.co.kr/main/lay2/S1T5832C5893/contents.do'),

-- 토지임대부 청년 특별공급
('SH_LAND_LEASE_YOUTH', '분양주택', '공공분양', '토지임대부', 'SH', '서울', 'SH 토지임대부 분양주택 (청년 특별공급)',
 '만19~39세 미혼 무주택 청년, 청약6개월이상', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"asset_limit_self":270000000,"asset_limit_parents":1011000000,"savings_min_rank1":6,"notes":["본인자산 27,000만원 이하 / 부모자산 101,100만원 이하","토지는 SH 소유, 건물만 분양","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/main/lay2/S1T5832C5893/contents.do'),

-- 토지임대부 신혼부부 특별공급
('SH_LAND_LEASE_NEWLYWED', '분양주택', '공공분양', '토지임대부', 'SH', '서울', 'SH 토지임대부 분양주택 (신혼부부 특별공급)',
 '혼인7년이내·예비신혼·6세이하자녀 한부모 무주택, 청약6개월이상', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"marriage_years_max":7,"savings_min_rank1":6,"notes":["자녀 있으면 1순위 / 없으면 2순위","토지는 SH 소유, 건물만 분양","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/main/lay2/S1T5832C5893/contents.do'),

-- 토지임대부 신생아 특별공급
('SH_LAND_LEASE_NEWBORN', '분양주택', '공공분양', '토지임대부', 'SH', '서울', 'SH 토지임대부 분양주택 (신생아 특별공급)',
 '2세 미만 자녀(태아·입양아 포함) 보유 무주택가구', FALSE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"income_pct_married":200,"asset_limit":354000000,"newborn_required":true,"newborn_income_bonus_pct":20,"savings_min_rank1":6,"notes":["2세 미만 자녀(태아·입양아 포함) 보유 필수","토지는 SH 소유, 건물만 분양","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/main/lay2/S1T5832C5893/contents.do'),

-- 토지임대부 생애최초 특별공급
('SH_LAND_LEASE_FIRST', '분양주택', '공공분양', '토지임대부', 'SH', '서울', 'SH 토지임대부 분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 혼인 중이거나 자녀 보유, 소득세 5년 납부', FALSE,
 '{"homeless_required":true,"life_first_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"savings_amount_min":6000000,"notes":["세대원 전원 과거·현재 주택 미소유 필수 (생애최초)","혼인 중이거나 자녀 보유 조건","근로자·자영업자 5년이상 소득세 납부","청약저축 600만원 이상","토지는 SH 소유, 건물만 분양","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/main/lay2/S1T5832C5893/contents.do'),

-- 공공분양 일반공급
('SH_PUBLIC_SALE_GENERAL', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (일반공급)',
 '수도권 거주 무주택세대구성원, 청약저축 가입자', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_min_rank1":12,"newborn_income_bonus_pct":20,"notes":["1단계: 신생아우선(2세미만자녀, 소득100%/맞벌이140%)","2단계: 우선공급(청약12개월·12회이상, 소득100%/맞벌이140%)","3단계: 추첨(소득100%/맞벌이200%)","투기과열지구: 청약 24개월·24회 이상","신생아(2023.3.28이후): 자녀1명 +10%p / 2명이상 +20%p","자산기준: 부동산 21,550만원 / 자동차 4,563만원"]}',
 '{"notes":["선정: 저축액·납입횟수·거주기간 기준"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T7334C1661/contents.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1661/contents.do'),

-- 공공분양 특별공급 (신혼부부)
('SH_PUBLIC_SALE_NEWLYWED', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (신혼부부 특별공급)',
 '혼인7년이내·6세이하자녀 무주택 신혼부부', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"marriage_years_max":7,"savings_min_rank1":6,"notes":["1순위: 자녀있는신혼부부·6세이하자녀한부모 / 2순위: 예비신혼·자녀없는신혼","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (생애최초)
('SH_PUBLIC_SALE_FIRST', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 혼인 중이거나 자녀 보유, 소득세 5년 납부', TRUE,
 '{"homeless_required":true,"life_first_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_amount_min":6000000,"notes":["세대원 전원 과거·현재 주택 미소유 필수","혼인 중이거나 미혼 자녀(태아·입양 포함) 보유","근로자·자영업자 5년이상 소득세 납부","청약저축 600만원 이상 (투기과열 2년·24회 / 비과열 1년·12회)","선정: 추첨","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (다자녀)
('SH_PUBLIC_SALE_CHILDREN', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (다자녀 특별공급)',
 '미성년 자녀 2명 이상 무주택 가구', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"children_min":2,"savings_min_rank1":6,"notes":["배점제 선정: 미성년자녀수·무주택기간·저축가입기간 등","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (신생아)
('SH_PUBLIC_SALE_NEWBORN', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (신생아 특별공급)',
 '2세 미만 자녀(태아·입양 포함) 보유 무주택가구', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"newborn_required":true,"newborn_income_bonus_pct":20,"savings_min_rank1":6,"notes":["2세 미만 자녀(태아·입양 포함) 보유 필수","신생아(2023.3.28이후): 소득·자산기준 +20%p 완화","배점제 선정: 자녀수·무주택기간·저축기간 등","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (노부모부양)
('SH_PUBLIC_SALE_ELDERLY', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (노부모부양 특별공급)',
 '65세이상 직계존속 3년이상 부양 무주택세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_min_rank1":12,"notes":["65세이상 직계존속 3년이상 계속 부양 (같은 주민등록표 등재)","피부양 직계존속 포함 전원 무주택","청약저축 1순위 (1년이상·12회이상 납입 / 투기과열 2년·24회)","선정: 일반공급 1순위와 동일 (저축총액·납입횟수 기준)","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── LH 공공분양 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- LH 공공분양 일반공급
('LH_PUBLIC_SALE_GENERAL', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (일반공급)',
 '청약저축·종합청약저축 가입 무주택 세대구성원', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_min_rank1":12,"newborn_income_bonus_pct":20,"notes":["소득기준 전용60㎡이하만 적용: 100%(맞벌이200%), 85㎡이하 소득제한 없음","청약저축 1순위(수도권): 1년이상+12회이상 / 투기과열지구: 2년+24회","신생아(2023.3.28이후): 자녀1명 +10%p / 2명이상 +20%p 완화","당첨자 선정: 무주택3년이상→저축총액(40㎡초과)·납입횟수(40㎡이하) 순"]}',
 '{"once_per_life":false,"discount_rate":85,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 신혼부부 특별공급
('LH_PUBLIC_SALE_NEWLYWED', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (신혼부부 특별공급)',
 '혼인7년이내·6세이하자녀 무주택 신혼부부', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모","혼인가구(6세이하자녀)"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"marriage_years_max":7,"savings_min_rank1":6,"newborn_income_bonus_pct":20,"notes":["우선공급70%: 단독100%·맞벌이120% / 일반공급20%: 단독130%·맞벌이140% / 추첨10%: 단독130%·맞벌이200%","혼인7년초과+6세이하자녀 혼인가구도 대상 포함","신생아(2023.3.28이후): 소득·자산 완화 (1명 +10%p / 2명이상 +20%p)","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 생애최초 특별공급
('LH_PUBLIC_SALE_FIRST', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 5년이상 소득세 납부 근로자·자영업자', TRUE,
 '{"homeless_required":true,"life_first_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_amount_min":6000000,"newborn_income_bonus_pct":20,"notes":["세대원 전원 과거·현재 주택 미소유 필수","혼인 중이거나 자녀 보유","근로자·자영업자 5년이상 소득세 납부","우선70%: 단독100% / 일반20%: 단독130% / 추첨10%: 단독130%·맞벌이200%","신생아(2023.3.28이후): 소득·자산 +20%p 완화","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 다자녀 특별공급
('LH_PUBLIC_SALE_CHILDREN', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (다자녀 특별공급)',
 '미성년 자녀 2명 이상 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"children_min":2,"savings_min_rank1":6,"newborn_income_bonus_pct":20,"notes":["미성년자녀 2명이상(태아·입양 포함), 3명이상 우선","우선공급90%: 단독120%·맞벌이130% (배점제) / 추첨10%: 단독120%·맞벌이200%","신생아(2023.3.28이후): 소득·자산 +20%p 완화","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 신생아 특별공급
('LH_PUBLIC_SALE_NEWBORN', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (신생아 특별공급)',
 '입주자모집공고일 기준 2세 이하 영아 보유 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":140,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"newborn_required":true,"savings_min_rank1":6,"newborn_income_bonus_pct":20,"notes":["2세 미만(만24개월이하) 자녀 보유 필수 (태아·입양 포함)","우선70%: 단독100%·맞벌이120% / 일반20%: 단독140%·맞벌이150% / 추첨10%: 단독140%·맞벌이200%","신생아(2023.3.28이후): 소득·자산 +20%p 완화","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 노부모부양 특별공급
('LH_PUBLIC_SALE_ELDERLY', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (노부모부양 특별공급)',
 '만65세이상 직계존속 3년이상 부양 무주택 세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"savings_min_rank1":12,"newborn_income_bonus_pct":20,"notes":["만65세이상 직계존속(배우자 직계존속 포함) 3년이상 계속 부양, 동일 주민등록표 등재","피부양 직계존속 포함 세대원 전원 무주택","우선90%: 단독120%·맞벌이130% (일반공급 1순위 기준) / 추첨10%: 단독120%·맞벌이200%","신생아(2023.3.28이후): 소득·자산 +20%p 완화","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();
-- ※ LH 공공분양에 청년 특별공급 없음 (LH청약플러스 공식 확인 2026-03-29)
--   청년 특별공급은 SH 나눔형(SH_NAMOOM_YOUTH)에만 존재


-- ── 청약홈 기타 유형 (오피스텔·도시형·민간임대·공공지원민간임대) ──────
-- 기준: 2026-04-09 | 청약통장 불필요, 재당첨 제한 없음

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 오피스텔 (민간분양)
('CHEONGYAK_OFFICETEL', '분양주택', '민간분양', '오피스텔', '청약홈', '전국', '오피스텔 청약 (민간분양)',
 '만 19세 이상 누구나 (청약통장 불필요)', TRUE,
 '{"age_min":19,"notes":["청약통장 불필요 — 일반 계좌에서 청약금 납부","소득·자산·무주택 기준 없음","APT 재당첨 제한 미적용, 복수 당첨 가능","투기과열지구(서울): 해당지역 2년 이상 거주자 우선 분양","APT 청약 시 오피스텔 소유는 주택 미소유로 간주","당첨자 선정: 100% 무작위 전산 추첨"]}',
 '{"notes":["시세 100% 분양","업무용·주거용 혼용 가능"]}',
 '{"method":["온라인"],"contact":"1644-7445","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈 공고 확인 후 신청"}',
 'https://www.applyhome.co.kr'),

-- 도시형생활주택 (민간분양)
('CHEONGYAK_URBAN_LIVING', '분양주택', '민간분양', '도시형생활주택', '청약홈', '전국', '도시형생활주택 청약 (민간분양)',
 '만 19세 이상 누구나 (청약통장 불필요)', TRUE,
 '{"age_min":19,"notes":["청약통장 불필요 — 일반 계좌에서 청약금 납부","소득·자산·무주택 기준 없음","APT 재당첨 제한 미적용, 복수 당첨 가능","300세대 미만 소형주택: 원룸형·단지형 연립·단지형 다세대","당첨자 선정: 100% 무작위 전산 추첨"]}',
 '{"notes":["시세 100% 분양","소형·원룸 위주 (1인 가구 적합)"]}',
 '{"method":["온라인"],"contact":"1644-7445","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈 공고 확인 후 신청"}',
 'https://www.applyhome.co.kr'),

-- 민간임대
('CHEONGYAK_PRIVATE_RENTAL', '임대주택', '민간임대', '민간임대', '청약홈', '전국', '민간임대주택 청약',
 '만 19세 이상 누구나 (청약통장 불필요)', TRUE,
 '{"age_min":19,"notes":["청약통장 불필요","소득·자산·무주택 기준 없음 (공고마다 상이할 수 있음)","APT 재당첨 제한 미적용, 복수 당첨 가능","조건은 공고마다 다름 — 공고문 반드시 확인","당첨자 선정: 100% 무작위 전산 추첨"]}',
 '{"notes":["임대료·기간은 공고별 상이"]}',
 '{"method":["온라인"],"contact":"1644-7445","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈 공고 확인 후 신청"}',
 'https://www.applyhome.co.kr'),

-- 공공지원민간임대
('CHEONGYAK_PUBLIC_SUPPORT_RENTAL', '임대주택', '민간임대', '공공지원민간임대', '청약홈', '전국', '공공지원민간임대주택 청약',
 '만 19세 이상 누구나 | 특별공급: 소득 120% 이하 우선', TRUE,
 '{"age_min":19,"income_type":"도시근로자월평균","income_pct":120,"notes":["청약통장 불필요","특별공급(소득기준 순위): 1순위 소득100%이하 → 2순위 110%이하 → 3순위 120%이하, 같은 순위 내 추첨","일반공급: 소득 무관, 100% 추첨","같은 단지에 중복 청약 불가 (위반 시 전부 무효)","임대료 시세 이하 제한, 10년 이상 임대 의무","APT 재당첨 제한 미적용"]}',
 '{"notes":["임대료 시세보다 저렴 (임대료 상한 있음)","임대기간: 10년 이상"]}',
 '{"method":["온라인"],"contact":"1644-7445","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈 공고 확인 후 신청 — 중복 청약 전부 무효 주의"}',
 'https://www.applyhome.co.kr')

ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── 민간분양 (아파트) — 민영주택 청약홈 ──────────────────────────
-- 기준: 투기과열지구(서울) 기준 | 2026-04-09

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 민간분양 특별공급 (6종: 신생아·신혼부부·다자녀·생애최초·노부모부양·기관추천)
('CHEONGYAK_PRIVATE_SPECIAL', '분양주택', '민간분양', '민영주택특별공급', '청약홈', '수도권', '민간분양 (아파트) — 특별공급',
 '무주택 세대구성원 중 특별공급 자격 해당자 (유형별 소득 기준 상이)', TRUE,
 '{"homeless_required":true,"lottery_real_estate_limit":331000000,"notes":["신생아: 2세이하자녀·무주택·소득130%(일반160%,맞벌이구분없음)·청약6회이상·물량10% (2026.6.15신설)","신혼부부: 혼인7년이내·무주택·소득140%(맞벌이160%)·청약6회이상·물량15%","다자녀: 무주택·미성년2명이상·청약6회이상·소득제한없음·물량10%","생애최초: 전원무주택·소득160%·소득세5년납부·청약12회이상·저축600만원이상(투기과열지구)·물량7%","노부모부양: 세대주·무주택·65세이상직계존속3년부양·1순위자격·물량3%","기관추천: 관계기관추천대상자·소득제한없음·물량10%","★추첨공급(신생아·신혼·생애최초): 소득무관, 부동산 3.31억 이하면 자격","신혼부부 5단계선정: 신생아우선(25%)→신생아일반(10%)→우선(25%)→일반(10%)→추첨(30%)","생애최초 5단계선정: 신생아우선(15%)→신생아일반(5%)→우선(35%)→일반(15%)→추첨(30%)","생애최초 1인가구: 추첨제만 가능","투기과열지구(서울): 전매제한·재당첨제한 강화 적용"]}',
 '{"supply_types":["신생아(10%)","신혼부부(15%)","다자녀(10%)","생애최초(7%)","노부모부양(3%)","기관추천(10%)"],"notes":["시세 100% 분양","특별공급 당첨 후 일반공급 신청 불가","특별공급 미당첨 시 일반공급 신청 가능"]}',
 '{"method":["온라인"],"contact":"1588-2188","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈(applyhome.co.kr) 공고 확인 후 신청 — 공고마다 일정 상이"}',
 'https://www.applyhome.co.kr'),

-- 민간분양 1순위 일반공급
('CHEONGYAK_PRIVATE_1ST', '분양주택', '민간분양', '민영주택1순위', '청약홈', '수도권', '민간분양 (아파트) — 일반공급 1순위',
 '무주택 세대구성원, 청약저축 2년 이상, 예치금 300만원 이상 (투기과열지구 기준)', TRUE,
 '{"homeless_required":true,"household_head_required":true,"deposit_min_won":3000000,"notes":["★투기과열지구(서울): 세대주 필수 + 2년이상 경과 + 예치금 충족 (납입횟수 무관·24회는 국민주택 기준)","예치금 기준: 85㎡이하 300만원/102㎡이하 600만원/135㎡이하 1,000만원/모든면적 1,500만원","1순위 제한자(2순위로 처리): 세대주 아닌 자·5년내 당첨이력 세대원·2주택이상소유 세대원","가점제(투기과열지구): 60㎡이하 가점40%+추첨60% / 60~85㎡ 가점70%+추첨30% (무주택기간32점+부양가족35점+가입기간17점=최대84점)","추첨제 시 무주택세대 75% 우선 배정","지역우선: 서울2년거주자 우선, 기타수도권(경기·인천) 차순위"]}',
 '{"notes":["시세 100% 분양","가점제 커트라인 매 공고별 상이 (청약홈 당첨가점 조회 가능)"]}',
 '{"method":["온라인"],"contact":"1588-2188","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈(applyhome.co.kr) 공고 확인 후 신청"}',
 'https://www.applyhome.co.kr'),

-- 민간분양 2순위 일반공급
('CHEONGYAK_PRIVATE_2ND', '분양주택', '민간분양', '민영주택2순위', '청약홈', '수도권', '민간분양 (아파트) — 일반공급 2순위',
 '1순위 미해당 청약저축 가입자 (100% 추첨)', TRUE,
 '{"notes":["청약저축 가입자 중 1순위 미해당자 전원 해당","100% 추첨 선정 (가점 무관)","1순위 청약 마감 다음날 청약 가능","지역우선: 서울2년거주자 우선"]}',
 '{"notes":["시세 100% 분양","추첨 경쟁률에 따라 당첨 확률 낮을 수 있음"]}',
 '{"method":["온라인"],"contact":"1588-2188","period_type":"공고별","url":"https://www.applyhome.co.kr","period_note":"청약홈(applyhome.co.kr) 공고 확인 후 신청"}',
 'https://www.applyhome.co.kr')

ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── 금융지원 ─────────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 내집마련 디딤돌대출 (2026년 기준: 금리 2.85~4.15%, 한도 일반2억/신혼3.2억, 주택가 5억이하)
('HF_DIDIMDOL', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '내집마련 디딤돌대출',
 '연소득 6천만원(신혼 8.5천) 이하 무주택 세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":60000000,"income_abs_married":85000000,"asset_limit":511000000,"notes":["주택가액 5억이하(신혼6억)","전용85㎡이하","LTV 70%(생애최초80%)","중도상환수수료 2026.12.31까지 면제"]}',
 '{"loan_limit":200000000,"loan_limit_newlywed":320000000,"loan_pct":70,"interest_min":2.85,"interest_max":4.15,"period_years":30,"house_price_limit":500000000,"area_max_sqm":85,"desc":"연 2.85~4.15% / 일반 2억·신혼 3.2억 (LTV 70%)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","신한","하나","농협","대구","부산"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030101.jsp'),

-- 신생아특례 디딤돌대출 (2026년 기준: 금리 1.80~4.50%, 한도 4억, 주택가 9억이하, 특례 5년)
('HF_DIDIMDOL_NEWBORN', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '신생아특례 디딤돌대출',
 '2년내 출산가구 연소득 1.3억(맞벌이2억) 이하 무주택', TRUE,
 '{"income_type":"절대금액(연소득)","income_abs":130000000,"income_abs_married":200000000,"newborn_required":true,"homeless_required":true,"asset_limit":511000000,"notes":["출산일로부터 2년 이내","주택가액 9억이하","전용85㎡이하","특례금리 5년(추가출산시 연장)"]}',
 '{"loan_limit":400000000,"loan_pct":70,"interest_min":1.80,"interest_max":4.50,"period_years":30,"house_price_limit":900000000,"desc":"연 1.80~4.50% / 최대 4억 (특례금리 5년)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","신한","국민","농협","하나"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030801.jsp'),

-- 청년전용 버팀목 전세자금 (2026년 기준: 금리 2.2~3.3%, 한도 1.5억, 보증금 3억이하)
('HF_YOUTH_BUTIMOK', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '청년전용 버팀목 전세자금',
 '만19~34세 무주택 청년 연소득 5천만원 이하', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":50000000,"asset_limit":345000000,"notes":["보증금 수도권 3억이하","전용85㎡이하","예비세대주 포함"]}',
 '{"loan_limit":150000000,"loan_pct":80,"interest_min":2.2,"interest_max":3.3,"period_years":10,"deposit_limit":300000000,"area_max_sqm":85,"desc":"연 2.2~3.3% / 최대 1.5억 (임차보증금 80%)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","농협","신한","하나","대구","부산"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05020301.jsp'),

-- 신혼부부전용 버팀목 전세자금 (2026년 기준: 금리 1.9~3.3%, 한도 수도권 2.5억)
('HF_NEWLYWED_JEONSE', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '신혼부부전용 버팀목 전세자금',
 '혼인7년이내 신혼부부 연소득 7.5천만원 이하', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"income_type":"절대금액(연소득)","income_abs":75000000,"asset_limit":345000000,"marriage_years_max":7,"notes":["보증금 수도권 4억이하","전용85㎡이하"]}',
 '{"loan_limit":250000000,"loan_pct":80,"interest_min":1.9,"interest_max":3.3,"period_years":10,"deposit_limit":400000000,"desc":"연 1.9~3.3% / 수도권 최대 2.5억 (임차보증금 80%)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","농협","신한","하나","대구","부산"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05020401.jsp'),

-- 청년전용 보증부월세대출 (월세금 연0%, 보증금 연1.3%)
('HF_YOUTH_MONTHLY', '금융지원', '월세자금', '버팀목', '주택도시기금', '전국', '청년전용 보증부월세대출',
 '만19~34세 청년 연소득 5천만원 이하 월세거주자', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":50000000,"asset_limit":345000000,"notes":["보증금 6,500만이하","월세 70만이하","전용60㎡이하"]}',
 '{"deposit_loan_limit":45000000,"monthly_loan_limit":1200000,"interest_deposit":1.3,"interest_monthly_low":0.0,"interest_monthly_high":1.0,"monthly_rent_limit":500000,"desc":"월세금 연 0%(월20만↓)·보증금 연 1.3% / 보증금 최대 4,500만"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","신한"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05020701.jsp'),

-- 버팀목 전세자금 대출 (일반, 연소득 5천만원 이하)
('HF_BUTIMOK_GENERAL', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '버팀목 전세자금 대출',
 '연소득 5천만원(다자녀6천·신혼7.5천) 이하 무주택 세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":50000000,"income_abs_married":75000000,"asset_limit":345000000,"notes":["보증금 수도권 3억이하","전용85㎡이하"]}',
 '{"loan_limit":120000000,"loan_limit_family":250000000,"loan_pct":80,"interest_min":2.5,"interest_max":3.5,"period_years":10,"deposit_limit":300000000,"desc":"연 2.5~3.5% / 수도권 1.2억(신혼·2자녀 2.5억)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","신한","하나","농협"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05020101.jsp'),

-- 신생아특례 버팀목 전세자금 (금리 1.3~4.3%, 한도 2.4억, 특례 4년)
('HF_BUTIMOK_NEWBORN', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '신생아특례 버팀목 전세자금',
 '2년내 출산가구 연소득 1.3억(맞벌이2억) 이하 무주택', TRUE,
 '{"newborn_required":true,"homeless_required":true,"income_type":"절대금액(연소득)","income_abs":130000000,"income_abs_married":200000000,"asset_limit":345000000,"notes":["특례금리 4년(추가출산시 연장)","최장 12년 이용 가능"]}',
 '{"loan_limit":240000000,"loan_pct":80,"interest_min":1.3,"interest_max":4.3,"period_years":12,"desc":"연 1.3~4.3% / 최대 2.4억 (특례금리 4년)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","신한","국민","농협","하나"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05021401.jsp'),

-- 주거안정월세대출 (사회초년생·취준생 월세, 연 1.3~1.8%, 생애 1회)
('HF_MONTHLY_STABILITY', '금융지원', '월세자금', '월세대출', '주택도시기금', '전국', '주거안정월세대출',
 '무주택 사회초년생·취업준비생 연소득 5천만원 이하', TRUE,
 '{"homeless_required":true,"social_newcomer_eligible":true,"income_type":"절대금액(연소득)","income_abs":50000000,"asset_limit":345000000,"notes":["생애 1회","우대형: 만35세이하 연소득4천이하 사회초년생","매월 임대인 직접 지급"]}',
 '{"loan_limit":14400000,"interest_min":1.3,"interest_max":1.8,"monthly_limit":600000,"period_years":10,"desc":"연 1.3~1.8% / 월 최대 60만원 (생애 1회)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","신한","국민","농협","하나"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0502/FP05020201.jsp'),

-- 청년 주택드림 디딤돌 대출 (청약통장 1천만원 이상, 금리 2.4~4.15%)
('HF_YOUTH_DREAM_DIDIMDOL', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '청년 주택드림 디딤돌 대출',
 '만39세이하 청약당첨자, 청년주택드림통장 1년+1천만원 이상', TRUE,
 '{"age_max":39,"homeless_required":true,"savings_amount_min":10000000,"income_type":"절대금액(연소득)","income_abs":70000000,"income_abs_married":100000000,"asset_limit":511000000,"notes":["청년주택드림 청약통장 1년이상+1천만이상 납입 필수","LTV 70%(생애최초80%)","중도상환수수료 면제(~2026.12.31)"]}',
 '{"loan_limit":300000000,"loan_limit_newlywed":400000000,"loan_pct":70,"interest_min":2.4,"interest_max":4.15,"period_years":40,"desc":"연 2.4~4.15% / 미혼 3억·신혼 4억 (최장 40년)"}',
 '{"method":["은행방문"],"url":"https://nhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","신한","국민","농협","하나"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030901.jsp'),

-- 신혼부부전용 구입자금 대출 (생애최초, LTV 80%, 금리 2.55~3.85%)
('HF_NEWLYWED_PURCHASE', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '신혼부부 구입자금 (생애최초)',
 '신혼부부 생애최초 주택구입자 연소득 8.5천만원 이하', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"income_type":"절대금액(연소득)","income_abs":85000000,"asset_limit":511000000,"life_first_required":true,"notes":["생애최초 주택구입자 필수","주택가액 6억이하","전용85㎡이하","LTV 80%(수도권규제지역70%)"]}',
 '{"loan_limit":320000000,"loan_pct":80,"interest_min":2.55,"interest_max":3.85,"period_years":30,"house_price_limit":600000000,"desc":"연 2.55~3.85% / 최대 3.2억 (LTV 80%, 생애최초)"}',
 '{"method":["은행방문","비대면"],"url":"https://enhuf.molit.go.kr","contact":"1599-0001","period_type":"수시","bank":["우리","국민","농협","신한","하나","대구","부산"]}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030601.jsp')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── 주거비지원 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 중앙 청년월세 (2026년 / 온통청년 plcyNo: 20260319005400112218)
('GOV_YOUTH_MONTHLY_RENT', '주거비지원', '월세지원', '청년월세', '국토교통부', '전국', '청년월세 지원사업 (2026년)',
 '만19~34세 독립거주 무주택 청년 중위소득 60% 이하', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"income_type":"중위소득","income_pct":60,"asset_limit":12200000,"notes":["원가구(부모) 중위소득 100% 이하 조건","원가구 자산 4,700만원 이하 조건","공공임대거주자·주택소유자·2촌이내혈족임차 제외"]}',
 '{"monthly_support":200000,"max_months":24,"total_max":4800000,"once_per_life":true,"deposit_limit":50000000,"monthly_rent_limit":700000}',
 '{"method":["온라인","방문"],"url":"https://www.bokjiro.go.kr","contact":"1599-0001","period_type":"정기","period_note":"2026년 신청 2026.03.30~05.29 / 지원기간 2026.09~2028.12"}',
 'https://www.bokjiro.go.kr'),

-- 서울시 청년월세
('SEOUL_YOUTH_MONTHLY_RENT', '주거비지원', '월세지원', '청년월세', '서울시', '서울', '서울시 청년월세 지원',
 '만19~39세 서울거주 1인가구 무주택 청년 중위소득 150% 이하', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"중위소득","income_pct":150,"household_max":1,"notes":["1인가구만","보증금 8천만 이하","월세 60만 이하","중앙청년월세 수혜자·공공임대거주자 제외"]}',
 '{"monthly_support":200000,"max_months":12,"total_max":2400000,"once_per_life":true,"deposit_limit":80000000,"monthly_rent_limit":600000}',
 '{"method":["온라인"],"url":"https://housing.seoul.go.kr","contact":"1833-2030","period_type":"정기","period_note":"연1회 6월 공고"}',
 'https://housing.seoul.go.kr'),


-- 주거급여
('GOV_HOUSING_BENEFIT', '주거비지원', '주거급여', '주거급여', '국토교통부', '전국', '주거급여',
 '기준중위소득 48% 이하 저소득 가구', TRUE,
 '{"income_type":"중위소득","income_pct":48,"notes":["부양의무자 기준 없음"]}',
 '{"monthly_support_seoul":369000,"monthly_support_gyeonggi":300000,"monthly_support_incheon":300000,"notes":["서울1인 36.9만","경기·인천1인 30만","가구원수별 차등"]}',
 '{"method":["방문","온라인"],"url":"https://www.bokjiro.go.kr","contact":"1600-0777","period_type":"수시"}',
 'https://www.myhome.go.kr')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── 이자지원 (지자체 고유) ────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 서울시 청년 임차보증금 이자지원
('SEOUL_YOUTH_JEONSE_INTEREST', '이자지원', '이자지원', '임차보증금이자', '서울시', '서울', '서울시 청년 임차보증금 이자지원',
 '만19~39세 서울거주 연소득 4천만원 이하 무주택세대주', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"is_household_head":true,"region_required":"서울","income_type":"절대금액(연소득)","income_abs":40000000,"income_abs_married":50000000,"notes":["취업준비생: 근로1년이상 또는 부모소득7천만이하","보증금 3억이하·월세 70만이하 주택","주택도시기금대출이용자·공공임대거주자 제외"]}',
 '{"loan_limit":200000000,"loan_pct":90,"interest_min":1.0,"interest_max":1.0,"period_years":8,"once_per_life":true,"deposit_limit":300000000}',
 '{"method":["온라인","방문"],"url":"https://housing.seoul.go.kr","contact":"02-120","period_type":"수시","bank":["하나은행"]}',
 'https://housing.seoul.go.kr'),

-- 서울시 신혼부부 임차보증금 이자지원
('SEOUL_NEWLYWED_JEONSE_INTEREST', '이자지원', '이자지원', '임차보증금이자', '서울시', '서울', '서울시 신혼부부 임차보증금 이자지원',
 '혼인7년이내 신혼부부 부부합산 1.3억 이하 무주택', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"region_required":"서울","income_type":"절대금액(연소득)","income_abs_married":130000000,"marriage_years_max":7,"notes":["보증금 7억이하 주택·오피스텔","공공주택(LH·SH) 입주자·불법건축물 제외"]}',
 '{"loan_limit":300000000,"loan_pct":90,"interest_min":1.0,"interest_max":4.5,"period_years":10,"once_per_life":true,"deposit_limit":700000000}',
 '{"method":["온라인","방문"],"url":"https://housing.seoul.go.kr","contact":"02-120","period_type":"수시","bank":["국민","하나","신한"]}',
 'https://housing.seoul.go.kr')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ── 기타 지자체 고유 사업 ─────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 서울시 청년안심주택 임대보증금 무이자 지원
('SH_SAFETY_DEPOSIT_SUPPORT', '이자지원', '이자지원', '임대보증금무이자', 'SH', '서울', 'SH 청년안심주택 임대보증금 무이자지원',
 '청년안심주택 신규 입주예정자', FALSE,
 '{"region_required":"서울","income_type":"도시근로자월평균","income_pct":120,"notes":["청년안심주택 신규 입주예정자 전용","청년: 도시근로자 100%·자산2.54억 이하","신혼: 도시근로자 120%·자산3.37억 이하"]}',
 '{"loan_limit":45000000,"interest_min":0,"interest_max":0,"notes":["보증금 1억초과: 30%지원","보증금 1억이하: 50%지원","최대 4,500만원 무이자"]}',
 '{"method":["방문"],"contact":"02-793-0761","period_type":"수시","period_note":"입주예정일 3주전까지 종합지원센터 방문"}',
 'https://soco.seoul.go.kr')
ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- ★2026-03-26 신규 8개 추가 (취약계층·자립준비·분리지급·보증료 등)
-- ============================================================

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 신혼희망타운 전용 주담대
('HF_HOPE_TOWN_JEONSE', '금융지원', '구입자금', '주담대', '주택도시기금', '전국', '신혼희망타운 전용 주택담보대출',
 'LH 신혼희망타운 분양계약 체결자 (세대원 전원 무주택)', TRUE,
 '{"homeless_required":true,"is_household_member_required":true,"notes":["LH 신혼희망타운 분양계약 체결자 전용","세대원 전원 무주택 필수","소득·자산 별도 기준 없음","처분이익 공유 조건 있음"]}',
 '{"loan_limit":400000000,"ltv_max":70,"interest_fixed":1.6,"interest_early":1.3,"period_years_options":[20,30],"notes":["고정금리 연 1.6%","2023.8.30이전 사전청약 사업장 연 1.3%","처분이익 50% 이내 공유","조기상환수수료 없음"]}',
 '{"method":["은행방문"],"contact":"1600-0800","period_type":"수시","bank":["우리","KB국민","신한"],"period_note":"잔금지급일 약 2개월 전부터 신청"}',
 'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030701.jsp'),

-- 청년가구 주거급여 분리지급
('GOV_SEPARATION_HOUSING_BENEFIT', '주거비지원', '주거급여', '주거급여분리지급', '국토교통부', '전국', '청년가구 주거급여 분리지급',
 '주거급여 수급가구 내 만19~30세 미만 미혼 자녀 (부모와 별거)', TRUE,
 '{"age_min":19,"age_max":29,"marital_status":["미혼"],"income_type":"중위소득","income_pct":48,"notes":["부모와 시·군 상이하게 거주 필수","청년 명의 임대차계약+임차료납부+전입신고 필수","예외: 대중교통 편도 90분 초과, 장애·만성질환"]}',
 '{"monthly_support_seoul":369000,"monthly_support_gyeonggi":300000,"monthly_support_incheon":300000,"notes":["기준임대료 지역별 지급","서울1인 36.9만","경기·인천1인 30만","별도 청년 계좌로 직접 지급"]}',
 '{"method":["방문","온라인"],"contact":"1600-0777","period_type":"수시","period_note":"부모 거주지 읍면동 행정복지센터 신청"}',
 'https://www.myhome.go.kr'),

-- 긴급주거지원
('GOV_EMERGENCY_HOUSING', '주거비지원', '긴급지원', '긴급주거지원', '국토교통부', '전국', '긴급주거지원',
 '위기상황 발생으로 거주공간이 필요한 중위소득 75% 이하 가구', TRUE,
 '{"income_type":"중위소득","income_pct":75,"asset_limit_metro":31000000,"asset_limit_mid":19400000,"asset_limit_rural":16500000,"notes":["위기사유: 주소득자 사망·가출·구금·중한질병·가정폭력·화재 등 9가지","소득기준: 1인 167만·2인 276만·3인 354만·4인 430만원"]}',
 '{"monthly_metro_12":398900,"monthly_metro_34":662500,"monthly_metro_56":874100,"monthly_mid_12":299100,"monthly_mid_34":435600,"monthly_mid_56":574200,"notes":["대도시 1~2인 39.9만/월","위기상황 완화시까지 지원"]}',
 '{"method":["방문","전화"],"contact":"129","period_type":"수시","period_note":"시·군·구청 또는 보건복지콜센터 129"}',
 'https://www.myhome.go.kr'),

-- 비정상거처 이사비 지원
('GOV_VULNERABLE_RELOCATION', '주거비지원', '이사비', '이사비지원', '국토교통부', '전국', '비정상거처 거주자 이사비 지원',
 '쪽방·고시원 등 비정상거처 3개월 이상 거주 후 이주한 자', TRUE,
 '{"notes":["비정상거처(쪽방·고시원·여인숙·비닐하우스·컨테이너·지하층 등) 3개월 이상 거주 후 이주 필수","소득·자산 기준 없음","전입일 기준 3개월 내 신청"]}',
 '{"total_max":400000,"once_per_life":true,"notes":["이사비+생필품 구입비","일회성 지원"]}',
 '{"method":["방문"],"contact":"1600-1004","period_type":"수시","period_note":"새 주택 소재지 읍면동 주민센터 방문"}',
 'https://www.myhome.go.kr'),

-- 주거취약계층 주거지원
('GOV_VULNERABLE_HOUSING', '임대주택', '공공임대', '취약계층임대', '국토교통부', '전국', '주거취약계층 주거지원',
 '쪽방·고시원 등 비정상거처 3개월이상 거주 저소득 가구 (소득 50% 이하)', TRUE,
 '{"income_type":"도시근로자월평균","income_pct":50,"asset_limit":241000000,"car_limit":37080000,"notes":["비정상거처(쪽방·고시원·여인숙·비닐하우스·노숙인시설 등) 3개월이상 거주 또는 범죄피해자 또는 최저주거기준미달 아동가구","소득 50%이하: 1인 174만·2인 271만·3인 360만·4인 412만원"]}',
 '{"deposit":500000,"rent_pct_of_market":null,"period_max_years":20,"renewal_count":9,"notes":["보증금 50만원","매입임대·전세임대·국민임대 연계","2년 단위 재계약, 최장 20년"]}',
 '{"method":["방문"],"contact":"1600-1004","period_type":"수시","period_note":"주민센터 방문 신청"}',
 'https://www.myhome.go.kr'),

-- 자립준비청년 주거지원
('GOV_INDEPENDENCE_YOUTH', '임대주택', '공공임대', '자립준비청년임대', '국토교통부', '전국', '자립준비청년 주거지원',
 '아동복지시설·가정위탁 퇴소 예정 또는 퇴소 후 5년 이내 청년', TRUE,
 '{"notes":["아동복지시설·가정위탁 퇴소 예정 또는 퇴소 후 5년 이내 청년","아동권리보장원 추천 필요","영구임대 자산: 총23,700만·차4,563만","국민임대 자산: 총33,700만·차4,563만","행복주택 자산: 총25,400만·차량미보유"]}',
 '{"deposit":1000000,"notes":["보증금 100만원","건설임대: 영구50년·국민30년·행복6년","매입임대: 최장 20년","전세임대: 수도권 최대 1.2~1.3억","22세이하 전세임대 무이자·5년내 50% 감면"]}',
 '{"method":["방문","온라인"],"contact":"1600-1004","period_type":"수시","period_note":"LH청약플러스 또는 행정복지센터"}',
 'https://www.myhome.go.kr'),

-- 서울시 신혼부부 전세보증금반환보증 보증료 지원
('SEOUL_NEWLYWED_GUARANTEE', '보증료지원', '보증료지원', '보증료지원', '서울시', '서울', '서울시 신혼부부 전세보증금반환보증 보증료 지원',
 '서울 거주 혼인7년이내 신혼부부 (보증 가입자)', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"region_required":"서울","marriage_years_max":7,"notes":["소득·자산 기준 없음","전세보증금반환보증 가입 필수","보증서 발급일로부터 90일 이내 신청"]}',
 '{"total_max":300000,"once_per_life":true,"notes":["중앙정부 보증료 지원과 별도 추가 지원","일회성"]}',
 '{"method":["방문","전화"],"contact":"02-120","period_type":"수시","period_note":"다산콜센터 02-120 또는 서울시 주택정책과 02-2133-7026"}',
 'https://housing.seoul.go.kr')

ON CONFLICT (code) DO UPDATE SET
  category = EXCLUDED.category, subcategory = EXCLUDED.subcategory,
  program_type = EXCLUDED.program_type, institution = EXCLUDED.institution,
  region = EXCLUDED.region, name = EXCLUDED.name,
  target_summary = EXCLUDED.target_summary, is_central = EXCLUDED.is_central,
  eligibility = EXCLUDED.eligibility, support_content = EXCLUDED.support_content,
  application_info = EXCLUDED.application_info, source_url = EXCLUDED.source_url,
  updated_at = NOW();


-- ============================================================
-- 온통청년 API 연계 (plcyNo 매핑)
-- API: GET https://www.youthcenter.go.kr/go/ythip/getPlcy
--      ?apiKeyNm={ONTONG_API_KEY}&rtnType=json&lclsfNm=주거&pageSize=200
-- 기준일: 2026-03-24 | 주거 정책 총 156개
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_programs_ontong ON programs (ontong_plcy_no)
  WHERE ontong_plcy_no IS NOT NULL;

-- 확인된 매핑 (온통청년 plcyNo ↔ programs.code)
UPDATE programs SET ontong_plcy_no = '20260319005400112218'
  WHERE code = 'GOV_YOUTH_MONTHLY_RENT';
-- (국토부) 26년 청년월세 지원사업 | 신청: 2026.03.30~05.29


-- ============================================================
-- 완료 확인
-- ============================================================
SELECT
  category,
  COUNT(*) AS count,
  STRING_AGG(name, ' | ' ORDER BY name) AS programs
FROM programs
GROUP BY category
ORDER BY category;
