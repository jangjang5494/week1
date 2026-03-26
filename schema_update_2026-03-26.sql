-- ============================================================
-- schema_update_2026-03-26.sql
-- 신규 임대주택 프로그램 추가 + 기존 데이터 수정
-- 사용법: Supabase SQL Editor → New query → 붙여넣기 → Run
-- ⚠️ schema.sql과 달리 이 파일은 DROP TABLE 없음 → 안전하게 실행 가능
-- ============================================================

-- ============================================================
-- 1. SH 임대주택 추가 (신혼·매입·전세 유형 8개)
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

('SH_BUY_GENERAL', '임대주택', '매입임대', '매입임대', 'SH', '서울', 'SH 일반 매입임대주택',
 '서울 거주 무주택 가구 (수급자·한부모·고령자·장애인 우선)', TRUE,
 '{"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_priority":50,"asset_limit":237000000,"car_limit":45630000,"notes":["1순위: 수급자/한부모/시급가구(RIR30%↑)/65세이상저소득/장애인(70%이하)","2순위: 소득50%이하/장애인(100%이하)","⚠️자산수치 공고문 확인 필요","자녀1명: 자산+2,400만/차+380만, 자녀2명이상: 자산+4,700만/차+760만"]}',
 '{"rent_pct_rank1":30,"rent_pct_rank2":50,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1589C1590/sublink.do'),

('SH_BUY_NEWLYWED_1', '임대주택', '매입임대', '신혼매입임대', 'SH', '서울', 'SH 신혼·신생아 매입임대 Ⅰ형',
 '서울 거주 신혼부부(7년이내)·신생아가구·한부모 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":337000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구/보호대상한부모","2순위: 미성년자녀있는신혼","3순위: 자녀없는신혼","소득50%이하: 시세30%"]}',
 '{"rent_pct_min":30,"rent_pct_max":50,"period_max_years":20}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1589C1590/sublink.do'),

('SH_BUY_NEWLYWED_2', '임대주택', '매입임대', '신혼매입임대', 'SH', '서울', 'SH 신혼·신생아 매입임대 Ⅱ형',
 '서울 거주 혼인가구·신생아가구·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"marriage_years_max":7,"notes":["자녀1명: 자산+5,000만 / 자녀2명이상: 자산+84,000만(공고문확인)","시세 70% (소득80%이하: 60%)"]}',
 '{"rent_pct_min":60,"rent_pct_max":70,"period_max_years":14}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1589C1590/sublink.do'),

('SH_LONG_UNOCCUPIED', '임대주택', '매입임대', '매입임대', 'SH', '서울', 'SH 장기미임대',
 '서울 거주 만19세이상 무주택 (6개월이상 미임대 물량)', FALSE,
 '{"age_min":19,"homeless_required":true,"region_required":"서울","income_required":false,"asset_required":false,"income_pct":130,"notes":["소득·자산 제한 없음 (소득130%이하 1순위)","6개월이상 미임대 국민임대·행복주택 등 물량","우편접수 가능","최장 4년 거주"]}',
 '{"period_max_years":4}',
 '{"method":["우편","온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"수시"}',
 'https://www.i-sh.co.kr'),

('SH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'SH', '서울', 'SH 행복주택 (신혼부부)',
 '서울 거주 혼인7년이내·6세이하자녀 한부모 무주택', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","한부모"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":100,"income_pct_married":130,"asset_limit":337000000,"marriage_years_max":7,"notes":["청약저축 필요","2세미만자녀→순위→배점→추첨","자녀1명이상: 최장14년"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":14}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T1594C1603/sublink.do'),

('SH_JEONSE_NEWLYWED_1', '임대주택', '전세임대', '신혼전세임대', 'SH', '서울', 'SH 신혼·신생아 전세임대 Ⅰ형',
 '서울 거주 신혼부부(7년이내)·신생아가구 (소득 70% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":70,"income_pct_married":90,"asset_limit":337000000,"car_limit":45630000,"marriage_years_max":7,"notes":["1순위: 신생아가구","SH 최대 1억3,800만원 지원 / 입주자 5% 부담"]}',
 '{"tenant_burden_pct":5,"loan_limit":138000000,"period_max_years":20,"renewal_count":9}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T572C3156/sublink.do'),

('SH_JEONSE_NEWLYWED_2', '임대주택', '전세임대', '신혼전세임대', 'SH', '서울', 'SH 신혼·신생아 전세임대 Ⅱ형',
 '서울 거주 혼인가구·신생아가구·한부모 (소득 130% 이하)', TRUE,
 '{"marital_status":["신혼(7년이내)","신생아가구","한부모","혼인가구"],"homeless_required":true,"region_required":"서울","income_type":"도시근로자월평균","income_pct":130,"income_pct_married":200,"asset_limit":354000000,"marriage_years_max":7,"notes":["SH 최대 6억원 지원 / 입주자 20% 부담","1순위: 신생아가구"]}',
 '{"tenant_burden_pct":20,"loan_limit":600000000,"period_max_years":14,"renewal_count":6}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr/app/lay2/S48T572C3156/sublink.do'),

('SH_DNDNT_JEONSE', '임대주택', '전세임대', '든든전세주택', 'SH', '서울', 'SH 전세임대형 든든주택',
 '서울 거주 무주택 세대구성원 (소득·자산 무관)', FALSE,
 '{"homeless_required":true,"region_required":"서울","income_required":false,"asset_required":false,"notes":["소득·자산 기준 없음","1순위: 신생아·다자녀","2순위: 신혼부부·예비신혼","3순위: 일반","SH 최대 2억원 지원 / 입주자 20% 부담"]}',
 '{"tenant_burden_pct":20,"loan_limit":200000000,"period_max_years":8,"renewal_count":3}',
 '{"method":["온라인"],"url":"https://www.i-sh.co.kr","contact":"1600-3456","period_type":"공고별"}',
 'https://www.i-sh.co.kr');


-- ============================================================
-- 2. GH 임대주택 추가 (신혼·매입 유형 2개)
-- ============================================================
INSERT INTO programs (code, category, subcategory, program_type, institution, region, name, target_summary, is_central,
  eligibility, support_content, application_info, source_url) VALUES

('GH_HAPPY_NEWLYWED', '임대주택', '공공임대', '행복주택', 'GH', '경기', 'GH 경기 행복주택 (신혼·신생아)',
 '혼인7년이내·신생아가구·한부모 무주택 (경기 거주 우선)', TRUE,
 '{"marital_status":["신혼(7년이내)","예비신혼","신생아가구","한부모"],"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"income_pct_married":120,"asset_limit":345000000,"car_limit":37080000,"marriage_years_max":7,"notes":["★GH 자동차 기준 3,708만원 (LH 4,542만원보다 엄격)","경기 거주 우선, 전국 신청 가능 (3순위)","자녀1명 소득+10%p / 2명이상 +20%p 완화"]}',
 '{"rent_pct_min":60,"rent_pct_max":80,"period_max_years":14}',
 '{"method":["온라인"],"url":"https://apply.gh.or.kr","contact":"1588-7013","period_type":"공고별"}',
 'https://apply.gh.or.kr'),

('GH_BUY_YOUTH', '임대주택', '매입임대', '청년매입임대', 'GH', '경기', 'GH 경기 청년 매입임대',
 '대학생·취준생·만19~39세 청년 무주택 (경기 거주 우선)', TRUE,
 '{"age_min":19,"age_max":39,"homeless_required":true,"income_type":"도시근로자월평균","income_pct":100,"asset_limit":345000000,"asset_limit_rank3":273000000,"car_limit":37080000,"notes":["1순위: 수급자·차상위·한부모 (소득·자산 없음)","2순위: 본인+부모 100%이하 / 자산34,500만원이하","3순위: 본인만 100%이하 / 자산27,300만원이하","★GH 자동차 기준 3,708만원","경기 거주 우선, 전국 신청 가능"]}',
 '{"rent_pct_min":30,"rent_pct_max":50,"period_max_years":10}',
 '{"method":["온라인"],"url":"https://apply.gh.or.kr","contact":"1588-7013","period_type":"공고별"}',
 'https://apply.gh.or.kr/sb/sr/sr7155/selectPbancRentHouseList.do');


-- ============================================================
-- 3. 기존 데이터 수정
-- ============================================================

-- GH 기존 행복주택(청년)·국민임대 자동차 기준 수정
-- 기존: 4,563만원 (LH와 동일하게 잘못 입력)
-- 수정: 3,708만원 (GH 공식 기준 ★2026-03-23 gh_rental_housing.md 확인)
UPDATE programs
SET eligibility = jsonb_set(eligibility, '{car_limit}', '37080000'::jsonb)
WHERE code IN ('GH_HAPPY_YOUTH', 'GH_NATIONAL_RENT');

-- SH 청년매입임대 자산기준 rank2/rank3 구조 추가
-- 코드 로직: parentIncome=true이면 rank2(33,700만원), false이면 rank3(25,400만원)
UPDATE programs
SET eligibility = (eligibility - 'asset_limit')
  || '{"asset_limit_rank2":337000000,"asset_limit_rank3":254000000}'::jsonb
WHERE code = 'SH_PURCHASE_RENT_YOUTH';


-- ============================================================
-- 확인
-- ============================================================
SELECT code, name, eligibility->>'asset_limit' AS asset, eligibility->>'car_limit' AS car
FROM programs
WHERE code IN (
  'SH_BUY_GENERAL','SH_BUY_NEWLYWED_1','SH_BUY_NEWLYWED_2','SH_LONG_UNOCCUPIED',
  'SH_HAPPY_NEWLYWED','SH_JEONSE_NEWLYWED_1','SH_JEONSE_NEWLYWED_2','SH_DNDNT_JEONSE',
  'GH_HAPPY_NEWLYWED','GH_BUY_YOUTH',
  'GH_HAPPY_YOUTH','GH_NATIONAL_RENT','SH_PURCHASE_RENT_YOUTH'
)
ORDER BY code;
