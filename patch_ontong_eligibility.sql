-- ============================================================
-- ONTONG_ 프로그램 eligibility 수동 보완
-- 실행: Supabase Dashboard → SQL Editor에 붙여넣고 Run
-- 기준일: 2026-03-24 / 출처: knowledge 파일 기반
-- ============================================================

-- 1. 청년 주택드림 디딤돌 대출 (HF222)
UPDATE programs SET eligibility = '{
  "age_max": 39,
  "homeless_required": true,
  "income_type": "절대금액(연소득)",
  "income_abs": 70000000,
  "income_abs_married": 100000000,
  "notes": ["청년주택드림 청약통장 1년이상 가입·1천만원이상 납입 필요", "청약 당첨자 대상", "순자산 5.11억원 이하"]
}'::jsonb WHERE code = 'ONTONG_20250514005400110811';

-- 2. 군포시 신혼부부·청년 전월세 보증금 대출이자 지원
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 39,
  "homeless_required": false,
  "region_required": "경기",
  "notes": ["군포시 거주 필요", "신혼부부 또는 청년 대상", "소득·자산 기준 군포시 공고 확인"]
}'::jsonb WHERE code = 'ONTONG_20260318005400212197';

-- 3. 생활안정자금 융자사업 (근로복지공단)
UPDATE programs SET eligibility = '{
  "homeless_required": false,
  "notes": ["재직 근로자 대상", "사업장 가입 근로자", "소득 기준 근로복지공단 공고 확인"]
}'::jsonb WHERE code = 'ONTONG_20250123005400110398';

-- 4. 전세보증금 반환보증 보증료 지원 (HF215)
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 39,
  "homeless_required": true,
  "income_type": "절대금액(연소득)",
  "income_abs": 50000000,
  "income_abs_married": 70000000,
  "notes": ["전세보증금 3억원 이하", "HUG·HF·SGI 전세보증금반환보증 가입 후 신청", "최대 30만원 환급"]
}'::jsonb WHERE code = 'ONTONG_20250714005400111223';

-- 5. 포천 청년 창업자 임차료 지원
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 49,
  "homeless_required": false,
  "region_required": "경기",
  "notes": ["포천시 거주 또는 창업 청년", "소득·자산 기준 포천시 공고 확인"]
}'::jsonb WHERE code = 'ONTONG_20240119005400200007';

-- 6. 청년 1인가구 전월세 안심계약 지원
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 39,
  "homeless_required": false,
  "region_required": "경기",
  "notes": ["군포시 거주 1인가구 청년", "금전 지원 아닌 전월세 계약 안심 서비스"]
}'::jsonb WHERE code = 'ONTONG_20260318005400212193';

-- 7. 대학생 연합생활관 (은행권, 고양)
UPDATE programs SET eligibility = '{
  "homeless_required": false,
  "enrollment_required": true,
  "notes": ["대학 재학생 대상", "소득분위 기준 공고 확인", "고양시 소재"]
}'::jsonb WHERE code = 'ONTONG_20260123005400112079';

-- 8. 미혼청년 주거급여 분리지급
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 29,
  "homeless_required": false,
  "marital_status": ["미혼"],
  "income_type": "중위소득",
  "income_pct": 46,
  "notes": ["주거급여 수급가구에 속한 청년 분리지급", "부모가구와 별도 거주 필요", "임차급여 별도 산정"]
}'::jsonb WHERE code = 'ONTONG_20250617005400110952';

-- 9. 청년주택드림청약통장 (HF218)
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 34,
  "homeless_required": true,
  "income_type": "절대금액(연소득)",
  "income_abs": 50000000,
  "notes": ["병역기간 최대 6년 나이 인정", "통장 가입 후 청년 주택드림 디딤돌대출 연계 가능"]
}'::jsonb WHERE code = 'ONTONG_20250226005400110565';

-- 10. i + 집드림 (인천도시공사)
UPDATE programs SET eligibility = '{
  "homeless_required": false,
  "region_required": "인천",
  "notes": ["인천시 주거지원 통합플랫폼", "세부 지원별 별도 자격 기준 적용", "iH 홈페이지 확인"]
}'::jsonb WHERE code = 'ONTONG_20250718005400211418';

-- 11. 청년층 임대주택 공급 확대 (통합공공임대, 인천도시공사)
UPDATE programs SET eligibility = '{
  "homeless_required": true,
  "region_required": "인천",
  "notes": ["인천도시공사 공급 통합공공임대주택", "소득·자산 기준 공고별 상이", "iH 홈페이지 확인"]
}'::jsonb WHERE code = 'ONTONG_20250718005400211417';

-- 12. 검단신도시 워라밸빌리지 특화구역 청년주거단지
UPDATE programs SET eligibility = '{
  "homeless_required": true,
  "region_required": "인천",
  "notes": ["청년·신혼부부 대상", "인천 검단신도시 특화 청년주거단지", "공급 일정 공고 확인"]
}'::jsonb WHERE code = 'ONTONG_20250718005400211414';

-- 13. 용인청년 부동산 중개 보수 감면
UPDATE programs SET eligibility = '{
  "age_min": 18, "age_max": 39,
  "homeless_required": false,
  "region_required": "경기",
  "notes": ["용인시 거주 청년", "전월세 계약 시 중개보수 감면 서비스"]
}'::jsonb WHERE code = 'ONTONG_20260313005400212147';

-- 14. 서울시 청년월세 지원사업 ★
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 39,
  "homeless_required": true,
  "region_required": "서울",
  "income_type": "중위소득",
  "income_pct": 150,
  "notes": ["1인가구 무주택자", "임차보증금 8천만원 이하 + 월세 60만원 이하", "국토부 청년월세와 중복 불가", "연 1회 6월 공고", "생애 1회"]
}'::jsonb WHERE code = 'ONTONG_20250903005400211614';

-- 15. 기초청년 주거급여(임차급여)
UPDATE programs SET eligibility = '{
  "age_min": 19, "age_max": 30,
  "homeless_required": false,
  "income_type": "중위소득",
  "income_pct": 46,
  "notes": ["주거급여 수급가구 청년 대상", "임차급여 분리지급", "복지로 신청"]
}'::jsonb WHERE code = 'ONTONG_20250903005400211608';
