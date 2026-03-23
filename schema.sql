-- ============================================================
-- 수도권 주거지원 통합 DB 스키마
-- 설계일: 2026-03-21
-- Supabase(PostgreSQL) 기준
-- ============================================================


-- ============================================================
-- 0. 기존 테이블 초기화 (재설계)
-- ============================================================
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS housing_products CASCADE;
DROP TABLE IF EXISTS income_standards CASCADE;
DROP TABLE IF EXISTS programs CASCADE;
DROP TABLE IF EXISTS user_conditions CASCADE;


-- ============================================================
-- 1. 소득 기준 참조 테이블
-- ============================================================
CREATE TABLE income_standards (
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
  ('중위소득', 2026, 6, 8555952);

-- 2025년 도시근로자 월평균소득 (원/월) ★2026-03-21 갱신
INSERT INTO income_standards (standard_type, year, household_size, amount) VALUES
  ('도시근로자월평균', 2025, 1, 4576036),
  ('도시근로자월평균', 2025, 2, 6452897),
  ('도시근로자월평균', 2025, 3, 8168429),
  ('도시근로자월평균', 2025, 4, 8802202),
  ('도시근로자월평균', 2025, 5, 9326985);


-- ============================================================
-- 2. 주거지원 프로그램 테이블 (핵심)
-- ============================================================
CREATE TABLE programs (
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
  -- 'LH' | 'SH' | 'GH' | 'iH' | '서울시' | '경기도' | '인천시' | '국토교통부' | '주택도시기금' | '성남시'
  region        TEXT NOT NULL DEFAULT '전국',
  -- '전국' | '서울' | '경기' | '인천' | '성남'
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
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE programs IS '주거지원 프로그램 마스터. 임대주택/금융지원/주거비지원/지자체사업 통합';

-- 자주 쓰는 조건 인덱스
CREATE INDEX idx_programs_category    ON programs (category);
CREATE INDEX idx_programs_institution ON programs (institution);
CREATE INDEX idx_programs_region      ON programs (region);
CREATE INDEX idx_programs_is_active   ON programs (is_active);
CREATE INDEX idx_programs_eligibility ON programs USING GIN (eligibility);


-- ============================================================
-- 3. 공고 테이블 (크롤링 + 수동 입력)
-- ============================================================
CREATE TABLE announcements (
  id          SERIAL PRIMARY KEY,
  program_id  INTEGER REFERENCES programs (id) ON DELETE SET NULL,
  -- 매칭된 프로그램 (null=미매칭)

  institution TEXT NOT NULL,  -- 'SH' | 'LH' | 'GH' | 'iH'
  seq         TEXT,           -- 원본 공고 번호
  title       TEXT NOT NULL,
  date        DATE,
  types       TEXT[],         -- 공고 분류 태그 (예: ['행복주택', '청년'])
  url         TEXT,
  status      TEXT,           -- '진행중' | '예정' | '마감' | '확인필요'
  apply_start DATE,
  apply_end   DATE,

  raw_data    JSONB,          -- 크롤링 원본 데이터 보관

  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (institution, seq)
);

CREATE INDEX idx_announcements_status     ON announcements (status);
CREATE INDEX idx_announcements_institution ON announcements (institution);
CREATE INDEX idx_announcements_program    ON announcements (program_id);
CREATE INDEX idx_announcements_apply_end  ON announcements (apply_end);


-- ============================================================
-- 4. 사용자 조건 테이블 (향후 맞춤 알림 서비스)
-- ============================================================
CREATE TABLE user_conditions (
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
  region              TEXT,   -- '서울' | '경기' | '인천'
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
  interested_regions  TEXT[],    -- ['서울', '경기', '인천']

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

CREATE TRIGGER trg_programs_updated_at
  BEFORE UPDATE ON programs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_announcements_updated_at
  BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_conditions_updated_at
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
CREATE POLICY "public read programs"
  ON programs FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "public read announcements"
  ON announcements FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "public read income_standards"
  ON income_standards FOR SELECT TO anon, authenticated USING (true);

-- user_conditions: 본인 데이터만 접근 (미래 인증 도입 시)
CREATE POLICY "user read own conditions"
  ON user_conditions FOR SELECT TO authenticated
  USING (auth.uid()::text = id::text);

CREATE POLICY "user insert own conditions"
  ON user_conditions FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = id::text);

CREATE POLICY "user update own conditions"
  ON user_conditions FOR UPDATE TO authenticated
  USING (auth.uid()::text = id::text);

-- service_role: 모든 테이블 full access (GitHub Actions 크롤러용)
CREATE POLICY "service full access programs"
  ON programs FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service full access announcements"
  ON announcements FOR ALL TO service_role USING (true) WITH CHECK (true);

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
 '{"marital_status":["미혼"],"homeless_required":true,"enrollment_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":108000000,"car_limit":0,"notes":["취업준비생: 졸업·중퇴 후 2년이내","1순위: 해당자치구 거주/대학소재지","2순위: 시·도 거주","자산평가: 본인만(부모 소득만 합산)","★2026년 자산기준 10,800만원"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":6,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 행복주택 청년
('LH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (청년·사회초년생)',
 '만19~39세 미혼 무주택 청년·사회초년생', TRUE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":251000000,"car_limit":45420000,"notes":["사회초년생: 소득활동 5년이내(나이무관)","청약저축 필수","1순위: 해당자치구 거주/소득근거지","2순위: 시·도 거주","신생아(2023.3.28이후): 소득·자산 최대20%p완화","★2026년 건설형 자산25,100만·차량4,542만"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 행복주택 신혼부부
('LH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (신혼부부·한부모)',
 '혼인7년이내 신혼부부·예비신혼·6세이하자녀 한부모', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":120,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":345000000,"car_limit":45420000,"marriage_years_max":7,"notes":["청약저축: 부부 중 1인 이상","자녀있으면 최장 14년","신생아(2023.3.28이후): 소득·자산 최대20%p완화","★2026년 건설형 차량4,542만"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":10,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 행복주택 고령자
('LH_HAPPY_ELDERLY', '임대주택', '공공임대', '행복주택', 'LH', '전국', 'LH 행복주택 (고령자)',
 '만65세이상 무주택세대구성원', TRUE,
 '{"age_min":65,"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":345000000,"car_limit":45420000,"notes":["★2026년 건설형 차량4,542만"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":20,"area_max_sqm":60}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 국민임대
('LH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'LH', '전국', 'LH 국민임대주택',
 '무주택 저소득 가구 (소득 70% 이하)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_1person":90,"income_pct_2person":80,"asset_limit":345000000,"car_limit":45420000,"notes":["청약저축: 50㎡이상 2년+24회(1순위)","우선공급: 신혼30%·장애인20%·다자녀10%·국가유공자10% 등","가점총점84점: 부양가족(35)+무주택기간(32)+납입횟수(17)+기타","감점: 최근1년 공공임대 이력 -5점"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30,"area_max_sqm":60}',
 '{"method":["온라인","방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 통합공공임대
('LH_INTEGRATED', '임대주택', '공공임대', '통합공공임대', 'LH', '전국', 'LH 통합공공임대주택',
 '중위소득 150% 이하 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"중위소득","income_pct_priority":100,"income_pct_general":150,"asset_limit":345000000,"car_limit":45420000,"notes":["우선공급: 중위100%이하","일반공급: 중위150%이하","임대료: 소득구간별 시세35~90%","우선공급배점: 소득·부양가족·거주기간·미성년자녀·납입횟수·이력감점"]}',
 '{"rent_pct_min":35,"rent_pct_max":90,"period_years":30,"area_max_sqm":85,"notes":["중위30%이하→시세35%","30~50%→45%","50~70%→50%","70~100%→65%","100~130%→80%","130~150%→90%"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 영구임대
('LH_PERMANENT', '임대주택', '공공임대', '영구임대', 'LH', '전국', 'LH 영구임대주택',
 '생계·의료수급자, 국가유공자, 한부모, 장애인 등 취약계층', TRUE,
 '{"homeless_required":true,"income_type":"없음(자격요건)","notes":["신청: 행정복지센터(주민센터) — LH청약플러스 아님","대상: 생계·의료수급자/국가유공자·유족/일본군위안부피해자/한부모가족/북한이탈주민/65세이상수급자·차상위/장애인(소득70%이하)","절차: 행정복지센터신청→지자체예비명단→LH통보→퇴거시입주"]}',
 '{"rent_pct":30,"period_years":50,"area_max_sqm":40,"notes":["2년단위 갱신시 자격 재확인"]}',
 '{"method":["방문"],"contact":"읍면동 행정복지센터","period_type":"상시(퇴거 발생 시)"}',
 'https://apply.lh.or.kr'),

-- LH 장기전세주택
('LH_LONG_JEONSE', '임대주택', '전세임대', '장기전세', 'LH', '전국', 'LH 장기전세주택 (시프트)',
 '무주택세대구성원 (서울은 SH 운영)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_60":100,"income_pct_60_1person":120,"income_pct_60_2person":110,"income_pct_over60":120,"asset_real_limit":215500000,"car_limit":45630000,"notes":["전용60㎡이하: 100%(1인120%,2인110%)","전용60~85㎡: 120%","서울 장기전세는 SH(시프트)로 공급"]}',
 '{"jeonse_pct_max":80,"period_years":20,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 5·10·50년 공공임대 (분양전환형)
('LH_PUBLIC_5_10', '임대주택', '공공임대', '분양전환공공임대', 'LH', '전국', 'LH 5·10·50년 공공임대 (분양전환형)',
 '무주택세대구성원 (소득 100% 이하)', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":130,"asset_real_limit":215500000,"car_limit":45630000,"notes":["특별공급: 신혼10%·생애최초15%·다자녀10%·노부모5%·기관추천20%·일반20%","선정: 2세미만자녀50%→배점30%→추첨20% (우선공급)"]}',
 '{"rent_pct":90,"period_type_5":5,"period_type_10":10,"period_type_50":50,"conversion_price_5":"(건설원가+감정평가)÷2","conversion_price_10":"감정평가액","area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 일반 매입임대 (다가구)
('LH_BUY_GENERAL', '임대주택', '매입임대', '매입임대', 'LH', '전국', 'LH 일반 매입임대주택',
 '수급자·한부모·장애인·고령자 등 취약계층', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"asset_limit":237000000,"car_limit":45630000,"notes":["1순위: 생계·의료수급자/한부모/65세이상수급자·차상위/소득70%이하장애인/주거지원시급가구","2순위: 소득50%이하 무주택세대구성원","임대기간: 1순위 무제한 / 2순위 최장20년(9회재계약)"]}',
 '{"rent_pct":30,"deposit_avg":4750000,"rent_avg_month":100000,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 청년 매입임대
('LH_BUY_YOUTH', '임대주택', '매입임대', '청년매입임대', 'LH', '전국', 'LH 청년 매입임대주택',
 '만19~39세 미혼 무주택 청년·대학생·취준생', TRUE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":345000000,"asset_limit_rank3":273000000,"car_limit":45630000,"notes":["1순위: 수급자·한부모·차상위(소득·자산심사완화)","2순위: 본인+부모 합산 100%이하, 자산34,500만","3순위: 본인 100%이하, 자산27,300만","부모 유주택이어도 신청 가능(가점차등)","청약저축 불필요"]}',
 '{"rent_pct_rank1_min":30,"rent_pct_rank1_max":40,"rent_pct_rank2":50,"deposit_rank1":1000000,"deposit_rank2":2000000,"period_max_years":10,"renewal_count":4}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 매입임대 Ⅰ형
('LH_BUY_NEWLYWED_1', '임대주택', '매입임대', '신혼매입임대', 'LH', '전국', 'LH 신혼·신생아 매입임대 Ⅰ형',
 '혼인7년이내·신생아가구·6세이하자녀 한부모 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":237000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼부부/6세이하자녀한부모","3순위: 미성년자녀없는신혼부부"]}',
 '{"rent_pct_min":30,"rent_pct_max":40,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 매입임대 Ⅱ형
('LH_BUY_NEWLYWED_2', '임대주택', '매입임대', '신혼매입임대', 'LH', '전국', 'LH 신혼·신생아 매입임대 Ⅱ형',
 '혼인7년이내·신생아가구·한부모 (소득 100% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":130,"asset_limit":345000000,"car_limit":45630000,"marriage_years_max":7}',
 '{"rent_pct_min":50,"rent_pct_max":70,"period_max_years":10,"renewal_count":4,"notes":["자녀있으면 최장 14년"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 기존주택 전세임대 (일반)
('LH_JEONSE_GENERAL', '임대주택', '전세임대', '전세임대', 'LH', '전국', 'LH 기존주택 전세임대 (일반)',
 '수급자·한부모·장애인·고령자 등 취약계층', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"notes":["1순위: 수급자/한부모/시급가구(RIR30%↑)/장애인70%이하/65세이상수급자·차상위","2순위: 소득50%이하","신청: 행정복지센터(수급자) 또는 LH청약플러스"]}',
 '{"loan_limit_metro":130000000,"loan_limit_metro_city":90000000,"loan_limit_other":70000000,"tenant_burden_pct":5,"interest_min":1.2,"interest_max":2.2,"period_max_years":30,"renewal_count":14,"notes":["65세이상·중증장애인·1순위: 재계약 횟수 무제한","입주자가 원하는 주택 직접 물색 후 LH 권리분석"]}',
 '{"method":["온라인","방문"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 청년전세임대
('LH_JEONSE_YOUTH', '임대주택', '전세임대', '청년전세임대', 'LH', '전국', 'LH 청년전세임대주택',
 '만19~39세 대학생·취준생·청년 무주택자', TRUE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"asset_limit":273000000,"car_limit":45630000,"notes":["1순위: 수급자·한부모·차상위","보증금: 1순위 100만원 / 2·3순위 200만원","아동복지·청소년시설 퇴소자 22세이하: 무이자"]}',
 '{"loan_limit_metro":120000000,"loan_limit_metro_city":95000000,"loan_limit_other":85000000,"loan_limit_share":200000000,"interest_min":1.0,"interest_max":2.0,"deposit_rank1":1000000,"deposit_rank2":2000000,"period_max_years":20,"renewal_count":4,"notes":["혼인시 5회 추가 재계약 가능"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 전세임대 Ⅰ형
('LH_JEONSE_NEWLYWED_1', '임대주택', '전세임대', '신혼전세임대', 'LH', '전국', 'LH 신혼·신생아 전세임대 Ⅰ형',
 '혼인7년이내·신생아가구 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":237000000,"car_limit":45630000,"marriage_years_max":7}',
 '{"loan_limit_metro":145000000,"loan_limit_metro_city":110000000,"loan_limit_other":95000000,"tenant_burden_pct":5,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼·신생아 전세임대 Ⅱ형
('LH_JEONSE_NEWLYWED_2', '임대주택', '전세임대', '신혼전세임대', 'LH', '전국', 'LH 신혼·신생아 전세임대 Ⅱ형',
 '혼인7년이내·신생아가구 (소득 100% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":130,"asset_limit":345000000,"car_limit":45630000,"marriage_years_max":7}',
 '{"loan_limit_metro":240000000,"loan_limit_metro_city":160000000,"loan_limit_other":130000000,"tenant_burden_pct":20,"period_max_years":10,"renewal_count":4,"notes":["자녀있으면 최장 14년"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 다자녀 전세임대
('LH_JEONSE_CHILDREN', '임대주택', '전세임대', '전세임대', 'LH', '전국', 'LH 다자녀 전세임대',
 '미성년 직계비속 2명 이상 무주택 가구', TRUE,
 '{"homeless_required":true,"children_min":2,"notes":["태아 포함 미성년 직계비속 2명 이상","2자녀 초과시: 자녀 1인당 2,000만원 추가 지원"]}',
 '{"loan_limit_metro":155000000,"loan_limit_metro_city":120000000,"loan_limit_other":105000000,"tenant_burden_pct":2,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼부부 매입임대 (기존 — Ⅰ·Ⅱ 통합 코드 유지)
('LH_BUY_NEWLYWED', '임대주택', '매입임대', '신혼매입임대', 'LH', '전국', 'LH 신혼부부 매입임대 (통합)',
 '혼인7년이내 신혼부부·예비신혼·신생아가구·한부모 (Ⅰ·Ⅱ형 통합 참조용)',
 TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"income_pct_2":100,"income_pct_2_married":130,"asset_limit":237000000,"asset_limit_2":345000000,"car_limit":45630000,"marriage_years_max":7,"notes":["Ⅰ형(소득70%,자산23,700만): LH_BUY_NEWLYWED_1 참조","Ⅱ형(소득100%,자산34,500만): LH_BUY_NEWLYWED_2 참조"]}',
 '{"rent_pct_1_min":30,"rent_pct_1_max":40,"rent_pct_2_min":50,"rent_pct_2_max":70}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- LH 신혼희망타운 (분양형)
('LH_HOPE_TOWN', '임대주택', '분양', '신혼희망타운', 'LH', '전국', 'LH 신혼희망타운 (분양형)',
 '혼인7년이내·예비신혼·6세이하자녀·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":362000000,"marriage_years_max":7,"notes":["청약저축 6개월이상·6회이상 납입 필수","전용 60㎡이하","선정3단계: 우선공급30%(혼인2년이내·2세이하자녀)+일반공급60%(혼인2~7년·3~6세자녀)+추첨공급10%","우선공급배점소득: 단독70%·맞벌이80% / 일반공급: 단독100%·맞벌이110%","★2026-03-21 총자산36,200만·맞벌이200%·선정방식3단계 확인"]}',
 '{"loan_interest":1.6,"loan_period_years":30,"area_max_sqm":60,"notes":["분양형 연1.6% 고정금리 30년","임대형 버팀목 1.2%"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

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
 '{"homeless_required":true,"children_min":2,"income_type":"도시근로자월평균","income_pct":70,"asset_limit":241000000,"car_limit":37080000,"notes":["미성년 자녀 2인 이상 (태아 포함)","신청: 지자체(행정복지센터)","1순위: 수급자·한부모·차상위/시급가구","2순위: 소득70%이하 무주택세대구성원"]}',
 '{"rent_pct_min":30,"rent_pct_max":40,"period_max_years":20,"renewal_count":9}',
 '{"method":["방문"],"contact":"지자체(행정복지센터)","period_type":"공고별","url":"https://apply.lh.or.kr"}',
 'https://apply.lh.or.kr'),

-- LH 전세임대형 든든주택 ★2026-03-21 신규 추가
('LH_DNDNT_JEONSE', '임대주택', '전세임대', '든든전세주택', 'LH', '전국', 'LH 전세임대형 든든주택',
 '중산층까지 확대한 비아파트(빌라·다세대) 전세임대 (소득·자산 무관)', TRUE,
 '{"homeless_required":true,"income_required":false,"asset_required":false,"notes":["소득·자산 기준 없음 (중산층까지 대상)","대상주택: 빌라·다세대·연립(非아파트)","순위: 신생아·다자녀→신혼부부→기타","1인 가구도 신청 가능"]}',
 '{"jeonse_pct_max":90,"period_max_years":10,"notes":["시세 90% 이하 전세","전세형으로 공급"]}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr'),

-- SH 행복주택 청년
('SH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (청년)',
 '만19~39세 서울 거주 청년 무주택자', TRUE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"asset_limit":254000000,"car_limit":45630000}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":6,"renewal_count":2}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr'),

-- SH 청년안심주택 공공임대
('SH_SAFETY_PUBLIC', '임대주택', '공공임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 (공공임대)',
 '만19~39세 청년·신혼부부, 역세권 무주택', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_youth":100,"income_pct_newlywed":120,"asset_limit":254000000,"car_limit":45630000,"notes":["1순위: 수급자·한부모·차상위 (소득·자산심사 없음)","2순위: 본인+부모 도시근로자 100%이하 (청년) / 120%이하 (신혼부부)","3순위: 본인 도시근로자 100%이하","소득120%초과시 일반공급만 가능"]}',
 '{"rent_pct_min":30,"rent_pct_max":70,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://soco.seoul.go.kr'),

-- SH 청년안심주택 민간임대
('SH_SAFETY_PRIVATE', '임대주택', '민간임대', '청년안심주택', 'SH', '서울', 'SH 청년안심주택 (민간임대)',
 '만19~39세 청년·신혼부부, 역세권 무주택', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_youth":100,"income_pct_newlywed":120,"asset_limit":254000000,"car_limit":45630000,"notes":["1순위: 수급자·한부모·차상위 (소득·자산심사 없음)","2순위: 본인+부모 도시근로자 100%이하 (청년) / 120%이하 (신혼부부)","3순위: 본인 도시근로자 100%이하","공급비율: 특별공급 20% / 일반공급 80%"]}',
 '{"special_supply_pct":20,"general_supply_pct":80,"rent_pct_special":75,"rent_pct_general":85}',
 '{"method":["온라인"],"url":"https://soco.seoul.go.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://soco.seoul.go.kr'),

-- SH 희망하우징
('SH_HOPE_HOUSING', '임대주택', '매입임대', '희망하우징', 'SH', '서울', 'SH 희망하우징',
 '서울 소재 대학 재학생 (미혼 무주택)', FALSE,
 '{"marital_status":["미혼"],"homeless_required":true,"region_required":"서울","enrollment_required":true,"income_type":"도시근로자월평균","income_pct_rank2":100,"income_pct_rank3":100,"asset_limit_rank2":337000000,"asset_limit_rank3":104000000,"car_limit_rank2":45630000,"car_limit_rank3":0,"notes":["1순위: 수급자·한부모·차상위","2순위: 본인+부모 100%이하·자산33,700만·차량4,563만","3순위: 본인 100%이하·자산10,400만·차량무소유","내발산기숙사: 수도권 대학원생 포함","시설: 연남·공릉원룸텔, 내발산·공릉·갈현·정릉기숙사"]}',
 '{"deposit_fixed":1090000,"rent_fixed_min":70000,"rent_fixed_max":140000,"period_years":2,"renewal_count":2,"period_max_years":6}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1591C592/contents.do'),

-- GH 행복주택 청년
('GH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'GH', '경기', 'GH 경기 행복주택 (청년)',
 '만19~39세 경기 무주택 청년', TRUE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"asset_limit":273000000,"car_limit":45630000}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":6,"renewal_count":2}',
 '{"method":["온라인"],"url":"https://apply.gh.or.kr","contact":"1588-7013","period_type":"공고별"}',
 'https://apply.gh.or.kr'),

-- GH 국민임대
('GH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'GH', '경기', 'GH 경기 국민임대주택',
 '무주택 저소득 가구', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"asset_limit":345000000,"car_limit":45630000}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30}',
 '{"method":["온라인"],"url":"https://apply.gh.or.kr","contact":"1588-7013","period_type":"공고별"}',
 'https://apply.gh.or.kr'),

-- iH 국민임대 ★2026-03-23 공식사이트 확인
('IH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'iH', '인천', 'iH 인천 국민임대주택',
 '무주택 저소득 가구 (인천 거주 우선)', FALSE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":70,"income_pct_1person":90,"income_pct_2person":80,"asset_limit":345000000,"car_limit":45630000,"notes":["총자산 34,500만원·자동차 4,563만원 (사용자 확인)","인천 거주자 우선 (비인천도 신청 가능)"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30}',
 '{"method":["방문"],"url":"https://www.ih.co.kr","contact":"1522-0072","period_type":"공고별"}',
 'https://www.ih.co.kr/main/sale_lease/management/nation.jsp'),

-- iH 행복주택 (청년) ★2026-03-23 공식사이트 확인
('IH_HAPPY_YOUTH', '임대주택', '공공임대', '행복주택', 'iH', '인천', 'iH 인천 행복주택 (청년)',
 '만 19~39세 미혼 무주택 청년 (인천 거주 우선)', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"notes":["자산기준 공고별 상이 — 공고문 확인","인천 거주자 우선"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years_max":6}',
 '{"method":["방문"],"url":"https://www.ih.co.kr","contact":"1522-0072","period_type":"공고별"}',
 'https://www.ih.co.kr/main/sale_lease/management/happy.jsp'),

-- iH 행복주택 (신혼부부) ★2026-03-23 공식사이트 확인
('IH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'iH', '인천', 'iH 인천 행복주택 (신혼부부)',
 '혼인 7년 이내 신혼부부·예비신혼·신생아가구 (인천 거주 우선)', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"marriage_years_max":7,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":120,"income_pct_2person":110,"notes":["자산기준 공고별 상이 — 공고문 확인","인천 거주자 우선"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years_max":10}',
 '{"method":["방문"],"url":"https://www.ih.co.kr","contact":"1522-0072","period_type":"공고별"}',
 'https://www.ih.co.kr/main/sale_lease/management/happy.jsp'),

-- iH 천원주택 매입임대
('IH_1000WON_BUY', '임대주택', '매입임대', '천원주택', 'iH', '인천', 'iH 천원주택 (매입임대)',
 '신혼부부·신생아·한부모가족 인천 거주', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"region_required":"인천","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"marriage_years_max":7}',
 '{"rent_fixed":30000,"deposit_limit":null,"period_years":6,"renewal_count":2,"area_max_sqm":85}',
 '{"method":["방문"],"contact":"1522-0072","period_type":"공고별","period_note":"2026년 5월 모집 예정"}',
 'https://www.ih.co.kr'),

-- iH 천원주택 전세임대 신혼신생아
('IH_1000WON_JEONSE', '임대주택', '전세임대', '천원주택', 'iH', '인천', 'iH 천원주택 (전세임대 신혼·신생아)',
 '혼인7년이내 신혼부부·신생아 인천 거주', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구"],"homeless_required":true,"region_required":"인천","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"marriage_years_max":7}',
 '{"rent_fixed":30000,"loan_limit":240000000,"loan_pct":80,"period_years":6}',
 '{"method":["방문"],"url":"https://www.incheon.go.kr/housing","contact":"1522-0072","period_type":"공고별"}',
 'https://www.incheon.go.kr/housing'),

-- iH 천원주택 든든주택 (소득기준 없음)
('IH_DUNDAN', '임대주택', '전세임대', '천원주택', 'iH', '인천', 'iH 전세임대형 든든주택',
 '신혼부부·신생아 인천 거주 (소득기준 없음)', FALSE,
 '{"marital_status":["신혼(7년이내)","신생아가구","한부모"],"homeless_required":true,"region_required":"인천","notes":["소득·자산 기준 없음"]}',
 '{"rent_fixed":30000,"loan_limit":200000000,"loan_pct":80,"period_years":6}',
 '{"method":["방문"],"contact":"1522-0072","period_type":"공고별"}',
 'https://www.incheon.go.kr/housing');


-- ============================================================
-- SH 임대주택 (장기전세, 미리내집, 국민임대, 매입임대, 희망하우징, 장기안심주택, 행복주택, 전세임대, 청년안심주택)
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central, eligibility, support_content, application_info, source_url) VALUES

-- SH 장기전세주택
('SH_JANGKI_JEONSE', '임대주택', '공공임대', '장기전세', 'SH', '서울', 'SH 장기전세주택',
 '서울 거주 무주택세대구성원, 청약저축 가입자', FALSE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_60":105,"income_pct_60_dual":140,"income_pct_over60":150,"income_pct_over60_dual":200,"asset_limit":640000000,"car_limit":45630000,"notes":["청약저축 1순위: 2년+24회","청약저축 2순위: 6개월+6회","신생아가산 +20%p (2023.3.28이후 출생)"]}',
 '{"jeonse_pct":80,"notes":["전세보증금 납부 방식","월세 없음","가점제 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1587C589/contents.do'),

-- SH 장기전세주택2 (미리내집) - 신혼부부 특화
('SH_MIRINAE_JIP', '임대주택', '공공임대', '장기전세', 'SH', '서울', 'SH 장기전세주택2 미리내집 (신혼부부)',
 '혼인7년이내 신혼부부·예비신혼부부, 서울 거주 무주택', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"region_required":"서울","marriage_years_max":7,"income_type":"도시근로자월평균","income_pct_60":120,"income_pct_60_dual":180,"income_pct_over60":150,"income_pct_over60_dual":200,"asset_limit":640000000,"car_limit":45630000,"notes":["공고 전 5년 무주택 이력 필요","저소득자 40% 우선배정"]}',
 '{"jeonse_pct":80,"notes":["전세보증금 납부","저소득자 우선 40%","가점제 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T6792C6812/contents.do'),

-- SH 국민임대주택
('SH_NATIONAL_RENT', '임대주택', '공공임대', '국민임대', 'SH', '서울', 'SH 국민임대주택',
 '서울 거주 무주택 저소득 세대', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"asset_limit":337000000,"car_limit":45630000,"notes":["유형: 국민임대·공공임대·재개발임대·도시형생활주택"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_years":30}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1588C590/sublink.do'),

-- SH 매입임대주택 (청년)
('SH_PURCHASE_RENT_YOUTH', '임대주택', '매입임대', '청년매입임대', 'SH', '서울', 'SH 청년 매입임대주택',
 '서울 거주 대학생·취준생·만19~39세 무주택 청년', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"asset_limit":273000000,"car_limit":45630000,"notes":["1순위: 수급자/한부모/시급가구/고령자/장애인70%","2순위: 소득50%이하/장애인100%"]}',
 '{"rent_pct_rank1":30,"rent_pct_rank2":50,"deposit_rank1_min":1000000,"deposit_rank1_max":2000000,"deposit_rank2_min":2000000,"deposit_rank2_max":4000000,"area_avg_sqm":30,"period_years":2,"renewal_count":4,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1589C1590/sublink.do'),

-- SH 장기안심주택 (보증금 지원형)
('SH_ANSIM_JEONSE', '임대주택', '전세임대', '장기안심주택', 'SH', '서울', 'SH 장기안심주택 (보증금 지원형)',
 '서울 거주 무주택, 전세보증금 4.9억이하 85㎡이하 주택 희망자', FALSE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_newlywed_single":120,"income_pct_newlywed_dual":180,"income_pct_generation":120,"asset_real_limit":21550000,"car_limit":45630000,"notes":["대상주택: 전용85㎡이하, 전세보증금4.9억이하"]}',
 '{"deposit_support_under150":0.5,"deposit_support_under150_max":45000000,"deposit_support_over150":0.3,"deposit_support_over150_max":60000000,"renewal_support":0.3,"period_years":2,"renewal_count":4,"period_max_years":10,"total_supply":10000}',
 '{"method":["온라인","방문"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"연2~3회","period_note":"연간 2~3회 1만호 공고"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1592C1533/contents.do'),

-- SH 전세임대주택
('SH_JEONSE_RENT', '임대주택', '전세임대', '전세임대', 'SH', '서울', 'SH 전세임대주택',
 '서울 거주 무주택 취약계층 (수급자·한부모·장애인·고령자)', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct_rank1":70,"income_pct_rank2":50,"asset_limit":273000000,"car_limit":45630000,"notes":["1순위: 수급자/한부모/시급가구/장애인70%/만65세이상","2순위: 소득50%이하/장애인100%","신생아가산: 10~20%p 상향"]}',
 '{"notes":["입주자가 원하는 주택 선택","SH가 집주인과 전세계약 후 저렴 재임대"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T572C3156/sublink.do'),

-- SH 행복주택 대학생
('SH_HAPPY_STUDENT', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (대학생)',
 '서울 소재 대학 재학생 (미혼 무주택)', TRUE,
 '{"marital_status":["미혼"],"homeless_required":true,"enrollment_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_1person":120,"income_pct_2person":110,"asset_limit":104000000,"car_limit":0,"region_required":"서울","notes":["1순위: 주택소재 자치구 대학 재학","2순위: 서울 내 타 자치구 대학"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"notes":["2세미만 자녀→순위→배점→추첨 순 선정"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1594C1603/sublink.do');


-- ── SH 주택분양 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 나눔형 분양주택 일반공급
('SH_NAMOOM_GENERAL', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (일반공급)',
 '수도권 거주 무주택세대구성원, 청약저축 가입자', FALSE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":200,"asset_limit":354000000,"notes":["주택청약종합저축 또는 청약저축 가입 필수","신생아(2023.3.28이후): 자녀1명 +10%p / 2명이상 +20%p","사전예약→본청약 2단계 진행","토지임대부: SH토지소유·수분양자건물소유","이익공유형: 처분손익 70% 수분양자귀속"]}',
 '{"notes":["분양가 저렴(토지비 제외)","처분시 SH환매조건"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T5553C5554/sublink.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5553C7333/contents.do'),

-- 나눔형 분양주택 청년 특별공급
('SH_NAMOOM_YOUTH', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (청년 특별공급)',
 '만19~39세 미혼 무주택 청년, 청약6개월이상', FALSE,
 '{"age_min":19,"age_max":39,"marital_status":["미혼"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":140,"asset_limit_self":270000000,"asset_limit_parents":1011000000,"notes":["청약저축 6개월이상 가입","본인자산 27,000만원 이하","부모자산 101,100만원 이하","생애 1회 제한","소득기준 약 503만원(본인기준)"]}',
 '{"once_per_life":true,"notes":["특별공급은 1개 유형만 신청가능"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T5554C7336/contents.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- 나눔형 분양주택 신혼부부 특별공급
('SH_NAMOOM_NEWLYWED', '분양주택', '공공분양', '나눔형분양', 'SH', '서울', 'SH 나눔형 분양주택 (신혼부부 특별공급)',
 '혼인7년이내·6세이하자녀 보유 무주택 신혼부부', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"marriage_years_max":7,"notes":["자녀유무에따라 1~2순위 구분","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T5554C7336/contents.do'),

-- 공공분양 일반공급
('SH_PUBLIC_SALE_GENERAL', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (일반공급)',
 '수도권 거주 무주택세대구성원, 청약저축 가입자', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":140,"asset_real_limit":215500000,"car_limit":45630000,"notes":["1단계: 신생아우선(2세미만자녀, 소득100%/맞벌이140%)","2단계: 우선공급(청약12개월이상, 소득100%/맞벌이140%)","3단계: 추첨(공통자격, 소득100%/맞벌이200%)","자산기준은 60㎡이하 기준"]}',
 '{"notes":["선정: 저축액·납입횟수·거주기간 기준"]}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별","source_page":"/app/lay2/S48T7334C1661/contents.do"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1661/contents.do'),

-- 공공분양 특별공급 (신혼부부)
('SH_PUBLIC_SALE_NEWLYWED', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (신혼부부 특별공급)',
 '혼인7년이내·6세이하자녀 무주택 신혼부부', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"marriage_years_max":7,"notes":["자녀유무에따라 1~2순위","생애 1회 제한","우선공급30%(2년이내혼인·2세이하자녀): 단독100%·맞벌이120%","일반공급70%: 단독130%·맞벌이200%"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (생애최초)
('SH_PUBLIC_SALE_FIRST', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 5년이상 소득세 납부 근로자·자영업자', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"notes":["세대원 전원 과거 주택 미소유","청약저축 600만원 이상","근로자·자영업자 5년이상 소득세 납부","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do'),

-- 공공분양 특별공급 (다자녀)
('SH_PUBLIC_SALE_CHILDREN', '분양주택', '공공분양', '공공분양', 'SH', '서울', 'SH 공공분양주택 (다자녀 특별공급)',
 '미성년 자녀 2명 이상 무주택 가구', TRUE,
 '{"homeless_required":true,"region_required":"수도권","income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"children_min":2,"notes":["청약저축 6개월이상·6회이상 납입","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T7334C1663/contents.do');


-- ── LH 공공분양 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- LH 공공분양 일반공급
('LH_PUBLIC_SALE_GENERAL', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (일반공급)',
 '청약저축·종합청약저축 가입 무주택 세대구성원', TRUE,
 '{"homeless_required":true,"subscription_required":true,"income_pct":null,"notes":["청약저축·종합청약저축 가입 필수","납입횟수·납입액에 따라 순위 결정","1순위: 납입24회이상 또는 지역우선","생애 1회 제한 없음(일반공급)"]}',
 '{"once_per_life":false,"discount_rate":85,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 신혼부부 특별공급
('LH_PUBLIC_SALE_NEWLYWED', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (신혼부부 특별공급)',
 '혼인7년이내·6세이하자녀 무주택 신혼부부', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"marriage_years_max":7,"notes":["우선공급30%(2년이내혼인·2세이하자녀): 단독100%·맞벌이120%","일반공급60%: 단독130%·맞벌이200%","추첨공급10%","청약저축 6개월이상·6회이상 납입","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 생애최초 특별공급
('LH_PUBLIC_SALE_FIRST', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (생애최초 특별공급)',
 '세대원 전원 주택 미소유, 5년이상 소득세 납부 근로자·자영업자', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"notes":["세대원 전원 과거 주택 미소유","근로자·자영업자 5년이상 소득세 납부","추첨공급 50%","청약저축 600만원 이상","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 다자녀 특별공급
('LH_PUBLIC_SALE_CHILDREN', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (다자녀 특별공급)',
 '미성년 자녀 2명 이상 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"children_min":2,"notes":["미성년자녀 3명이상 우선","청약저축 6개월이상·6회이상 납입","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 신생아 특별공급
('LH_PUBLIC_SALE_NEWBORN', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (신생아 특별공급)',
 '입주자모집공고일 기준 2세 이하 영아 보유 무주택 가구', TRUE,
 '{"homeless_required":true,"income_type":"도시근로자월평균","income_pct":200,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"notes":["입주자모집공고일 기준 2세(만24개월)이하 자녀 보유","신혼부부특공과 별도 쿼터","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048'),

-- LH 공공분양 노부모부양 특별공급
('LH_PUBLIC_SALE_ELDERLY', '분양주택', '공공분양', '공공분양', 'LH', '전국', 'LH 공공분양주택 (노부모부양 특별공급)',
 '65세이상 직계존속 3년이상 부양 무주택 세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"income_type":"도시근로자월평균","income_pct":120,"income_pct_married":200,"asset_real_limit":215500000,"car_limit":45630000,"notes":["65세이상 직계존속 3년이상 동일 주민등록 부양","청약저축 24회이상 납입","생애 1회 제한"]}',
 '{"once_per_life":true}',
 '{"method":["온라인"],"url":"https://apply.lh.or.kr","contact":"1600-1004","period_type":"공고별"}',
 'https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048');


-- ── 금융지원 ─────────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 디딤돌 대출
('HF_DIDIMDOL', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '내집마련 디딤돌대출',
 '연소득 6천만원 이하 무주택 세대주', TRUE,
 '{"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":60000000,"income_abs_married":70000000,"asset_limit":null,"notes":["주택가액 5억이하","전용85㎡이하"]}',
 '{"loan_limit":300000000,"loan_pct":70,"interest_min":2.35,"interest_max":3.65,"period_years":30,"house_price_limit":500000000,"area_max_sqm":85}',
 '{"method":["은행방문"],"contact":"1599-0001","period_type":"수시","bank":["우리","국민","신한","하나","농협","기업"]}',
 'https://www.myhome.go.kr'),

-- 신생아특례 디딤돌
('HF_DIDIMDOL_NEWBORN', '금융지원', '구입자금', '디딤돌', '주택도시기금', '전국', '신생아특례 디딤돌대출',
 '2년내 출산가구 연소득 1.3억 이하', TRUE,
 '{"income_type":"절대금액(연소득)","income_abs":130000000,"newborn_required":true,"notes":["출산일로부터 2년 이내","주택가액 9억이하"]}',
 '{"loan_limit":500000000,"loan_pct":70,"interest_min":1.6,"interest_max":3.3,"period_years":30,"house_price_limit":900000000}',
 '{"method":["은행방문"],"contact":"1599-0001","period_type":"수시"}',
 'https://www.myhome.go.kr'),

-- 청년 버팀목 전세자금
('HF_YOUTH_BUTIMOK', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '청년전용 버팀목 전세자금',
 '만19~34세 무주택 청년 연소득 5천만원 이하', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"is_household_head":true,"income_type":"절대금액(연소득)","income_abs":50000000,"asset_limit":337000000,"notes":["보증금 3억이하","전용85㎡이하"]}',
 '{"loan_limit":200000000,"loan_pct":80,"interest_min":1.5,"interest_max":2.9,"period_years":10,"deposit_limit":300000000,"area_max_sqm":85}',
 '{"method":["은행방문"],"contact":"1599-0001","period_type":"수시"}',
 'https://www.myhome.go.kr'),

-- 신혼부부 전세자금
('HF_NEWLYWED_JEONSE', '금융지원', '전세자금', '버팀목', '주택도시기금', '전국', '신혼부부전용 전세자금대출',
 '혼인7년이내 신혼부부 연소득 7.5천만원 이하', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"income_type":"절대금액(연소득)","income_abs":75000000,"asset_limit":337000000,"marriage_years_max":7}',
 '{"loan_limit":300000000,"loan_pct":80,"interest_min":1.2,"interest_max":2.4,"period_years":10,"deposit_limit":400000000}',
 '{"method":["은행방문"],"contact":"1599-0001","period_type":"수시"}',
 'https://www.myhome.go.kr'),

-- 청년 보증부 월세대출
('HF_YOUTH_MONTHLY', '금융지원', '월세자금', '버팀목', '주택도시기금', '전국', '청년 보증부 월세대출',
 '만19~34세 청년 연소득 5천만원 이하', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"income_type":"절대금액(연소득)","income_abs":50000000,"asset_limit":null,"notes":["보증금 1억이하","월세 60만이하"]}',
 '{"loan_limit":21600000,"interest_min":1.0,"interest_max":2.0,"monthly_rent_limit":600000,"deposit_limit":100000000}',
 '{"method":["은행방문"],"contact":"1599-0001","period_type":"수시"}',
 'https://www.myhome.go.kr');


-- ── 주거비지원 ───────────────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 중앙 청년월세 (HB009)
('GOV_YOUTH_MONTHLY_RENT', '주거비지원', '월세지원', '청년월세', '국토교통부', '전국', '청년월세 한시 특별지원',
 '만19~34세 독립거주 무주택 청년 중위소득 60% 이하', TRUE,
 '{"age_min":19,"age_max":34,"homeless_required":true,"income_type":"중위소득","income_pct":60,"income_pct_origin_family":100,"asset_limit":12200000,"asset_limit_origin_family":47000000,"excluded":["공공임대거주자","주택소유자","2촌이내혈족임차"]}',
 '{"monthly_support":200000,"max_months":24,"total_max":4800000,"once_per_life":true,"deposit_limit":50000000,"monthly_rent_limit":700000}',
 '{"method":["온라인","방문"],"url":"https://www.bokjiro.go.kr","contact":"1599-0001","period_type":"수시"}',
 'https://www.myhome.go.kr'),

-- 서울시 청년월세
('SEOUL_YOUTH_MONTHLY_RENT', '주거비지원', '월세지원', '청년월세', '서울시', '서울', '서울시 청년월세 지원',
 '만19~39세 서울거주 1인가구 무주택 청년 중위소득 150% 이하', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"region_required":"서울","income_type":"중위소득","income_pct":150,"notes":["1인가구만","보증금 8천만 이하","월세 60만 이하"],"excluded":["중앙청년월세수혜자","공공임대거주자"]}',
 '{"monthly_support":200000,"max_months":12,"total_max":2400000,"once_per_life":true,"deposit_limit":80000000,"monthly_rent_limit":600000}',
 '{"method":["온라인"],"url":"https://housing.seoul.go.kr","contact":"1833-2030","period_type":"정기","period_note":"연1회 6월 공고"}',
 'https://housing.seoul.go.kr'),

-- 인천시 청년월세 (35~39세 인천형)
('INCHEON_YOUTH_MONTHLY_RENT', '주거비지원', '월세지원', '청년월세', '인천시', '인천', '인천형 청년월세 지원 (35~39세)',
 '만35~39세 인천거주 무주택 청년 (전국 지원 연령 초과분)', FALSE,
 '{"age_min":35,"age_max":39,"homeless_required":true,"region_required":"인천","income_type":"중위소득","income_pct":60,"income_pct_origin_family":100,"asset_limit":12200000}',
 '{"monthly_support":200000,"max_months":24,"total_max":4800000,"once_per_life":true}',
 '{"method":["온라인","방문"],"url":"https://youth.incheon.go.kr","contact":"032-120","period_type":"정기","period_note":"2026년 3.30~5.29"}',
 'https://youth.incheon.go.kr'),

-- 주거급여
('GOV_HOUSING_BENEFIT', '주거비지원', '주거급여', '주거급여', '국토교통부', '전국', '주거급여',
 '기준중위소득 48% 이하 저소득 가구', TRUE,
 '{"income_type":"중위소득","income_pct":48,"notes":["부양의무자 기준 없음"]}',
 '{"monthly_support_seoul":369000,"monthly_support_gyeonggi":300000,"monthly_support_incheon":300000,"notes":["서울1인 36.9만","경기·인천1인 30만","가구원수별 차등"]}',
 '{"method":["방문","온라인"],"url":"https://www.bokjiro.go.kr","contact":"1600-0777","period_type":"수시"}',
 'https://www.myhome.go.kr');


-- ── 이자지원 (지자체 고유) ────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 서울시 청년 임차보증금 이자지원
('SEOUL_YOUTH_JEONSE_INTEREST', '이자지원', '이자지원', '임차보증금이자', '서울시', '서울', '서울시 청년 임차보증금 이자지원',
 '만19~39세 서울거주 연소득 4천만원 이하 무주택세대주', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"is_household_head":true,"region_required":"서울","income_type":"절대금액(연소득)","income_abs":40000000,"income_abs_married":50000000,"notes":["취업준비생: 근로1년이상 또는 부모소득7천만이하","보증금 3억이하·월세 70만이하 주택"],"excluded":["주택도시기금대출이용자","공공임대거주자"]}',
 '{"loan_limit":200000000,"loan_pct":90,"interest_min":1.0,"interest_max":1.0,"period_years":8,"once_per_life":true,"deposit_limit":300000000}',
 '{"method":["온라인","방문"],"url":"https://housing.seoul.go.kr","contact":"02-120","period_type":"수시","bank":["하나은행"]}',
 'https://housing.seoul.go.kr'),

-- 서울시 신혼부부 임차보증금 이자지원
('SEOUL_NEWLYWED_JEONSE_INTEREST', '이자지원', '이자지원', '임차보증금이자', '서울시', '서울', '서울시 신혼부부 임차보증금 이자지원',
 '혼인7년이내 신혼부부 부부합산 1.3억 이하 무주택', FALSE,
 '{"marital_status":["신혼(7년이내)","예비신혼"],"homeless_required":true,"region_required":"서울","income_type":"절대금액(연소득)","income_abs_married":130000000,"marriage_years_max":7,"notes":["보증금 7억이하 주택·오피스텔"],"excluded":["공공주택(LH·SH)","불법건축물"]}',
 '{"loan_limit":300000000,"loan_pct":90,"interest_min":1.0,"interest_max":4.5,"period_years":10,"once_per_life":true,"deposit_limit":700000000}',
 '{"method":["온라인","방문"],"url":"https://housing.seoul.go.kr","contact":"02-120","period_type":"수시","bank":["국민","하나","신한"]}',
 'https://housing.seoul.go.kr'),

-- 인천시 청년 임차보증금 이자지원
('INCHEON_YOUTH_JEONSE_INTEREST', '이자지원', '이자지원', '임차보증금이자', '인천시', '인천', '인천시 청년 임차보증금 이자지원',
 '만19~39세 인천거주 연소득 6천만원(미혼) 이하 무주택세대주', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"is_household_head":true,"region_required":"인천","income_type":"절대금액(연소득)","income_abs":60000000,"income_abs_married":80000000,"notes":["보증금 2.5억이하·전용85㎡이하"],"excluded":["주거급여수급자","주택소유자","주택도시기금대출이용자","부모소유주택임차"]}',
 '{"loan_limit":100000000,"loan_pct":90,"interest_min":3.0,"interest_max":3.5,"period_years":4,"deposit_limit":250000000,"area_max_sqm":85}',
 '{"method":["온라인"],"url":"https://youth.incheon.go.kr","contact":"032-120","period_type":"정기","period_note":"연1회 5월 예정","bank":["NH농협"]}',
 'https://youth.incheon.go.kr'),

-- 인천 i+집드림 1.0 이자지원
('INCHEON_IDREAM_INTEREST', '이자지원', '이자지원', 'i+집드림', '인천시', '인천', 'i+집드림 1.0 이자지원 (신생아 주택담보)',
 '2025년 이후 출생 자녀 있는 인천 1주택 가구', FALSE,
 '{"newborn_required":true,"region_required":"인천","income_type":"절대금액(연소득)","income_abs_married":130000000,"notes":["2025.1.1이후 출생 자녀","주택가액 6억이하","전용85㎡이하","주담대 3억이하","1가구1주택"]}',
 '{"annual_max":3000000,"period_years":5,"total_max":15000000,"notes":["1자녀: 시중 0.8%/정부 0.4~0.8%","2자녀이상: 시중 1.0%/정부 0.6~1.0%"]}',
 '{"method":["온라인"],"url":"https://www.incheon.go.kr/housing","contact":"032-440-4759","period_type":"정기","period_note":"신규 2026.7.16~8.31"}',
 'https://www.incheon.go.kr/housing');


-- ── 기타 지자체 고유 사업 ─────────────────────────────────────

INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

-- 서울시 청년안심주택 임대보증금 무이자 지원
('SH_SAFETY_DEPOSIT_SUPPORT', '이자지원', '이자지원', '임대보증금무이자', 'SH', '서울', 'SH 청년안심주택 임대보증금 무이자지원',
 '청년안심주택 신규 입주예정자', FALSE,
 '{"notes":["청년안심주택 신규 입주예정자","청년: 월359만·자산2.54억","신혼: 월657만·자산3.37억"]}',
 '{"loan_limit":45000000,"interest_min":0,"interest_max":0,"notes":["보증금 1억초과: 30%지원","보증금 1억이하: 50%지원","최대 4,500만원 무이자"]}',
 '{"method":["방문"],"contact":"02-793-0761","period_type":"수시","period_note":"입주예정일 3주전까지 종합지원센터 방문"}',
 'https://soco.seoul.go.kr'),

-- 경기도 청년 이사비·중개보수비
('GG_YOUTH_MOVING', '주거비지원', '이사비', '이사비지원', '경기도', '경기', '경기도 청년 이사비 및 중개보수비 지원',
 '만19~39세 경기 거주 무주택 청년 중위소득 120% 이하', FALSE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"is_household_head":true,"region_required":"경기","income_type":"중위소득","income_pct":120,"notes":["2억이하 전월세","경기 전입 또는 경기내 이사"],"excluded":["부모소유주택임차","기초생활수급자"]}',
 '{"total_max":250000,"once_per_life":true,"notes":["이사비+중개보수비 실비 지원","최대 25만원"]}',
 '{"method":["온라인"],"contact":"070-8834-7060","period_type":"공고별","period_note":"연2회 공고"}',
 NULL),

-- 인천 전세반환보증료 지원
('INCHEON_GUARANTEE_FEE', '보증료지원', '보증료지원', '보증료지원', '인천시', '인천', '인천 전세보증금반환보증 보증료 지원',
 '인천거주 무주택자 보증금 3억이하 보증 가입자', FALSE,
 '{"homeless_required":true,"region_required":"인천","income_type":"절대금액(연소득)","income_abs":50000000,"income_abs_married":75000000,"notes":["청년 만18~39세 5천만","신혼부부 7.5천만","일반 6천만","보증금 3억이하"]}',
 '{"total_max":400000,"notes":["2025.3.31이후 가입: 최대40만","이전가입: 최대30만","기납부 보증료 실비"]}',
 '{"method":["온라인","방문"],"url":"https://www.gov.kr","contact":"032-120","period_type":"수시","period_note":"예산 소진 시 조기 마감"}',
 'https://youth.incheon.go.kr');


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
