-- ============================================================
-- programs 테이블 시드 데이터 (온통청년 API 연계 프로그램)
-- 작성일: 2026-03-25
-- 실행: Supabase Dashboard > SQL Editor에 붙여넣기
-- ============================================================

INSERT INTO programs (
  code, category, subcategory, institution, region,
  name, target_summary,
  eligibility, support_content, application_info,
  is_active, is_central, data_year, source_url, ontong_plcy_no
) VALUES

-- ① 신생아특례 버팀목 전세자금 대출
(
  'BABY_BUMOAK_JEONSE',
  '금융지원', '전세자금',
  '주택도시기금', '전국',
  '신생아특례 버팀목 전세자금 대출',
  '2세 이하 자녀 있는 무주택 가구, 연소득 1.3억 이하',
  '{
    "age_min": 19,
    "homeless_required": true,
    "newborn_required": true,
    "income_type": "절대금액(연소득)",
    "income_abs": 130000000,
    "income_abs_married": 130000000,
    "notes": ["출산 후 2년 이내 신청 가능", "기존 버팀목 대출 이용자도 전환 가능"]
  }',
  '{
    "loan_limit": 300000000,
    "loan_pct": 80,
    "interest_min": 1.1,
    "interest_max": 3.0,
    "period_years": 10,
    "deposit_limit": 500000000,
    "desc": "수도권 최대 3억원, 금리 연 1.1~3.0%"
  }',
  '{
    "method": ["온라인", "은행방문"],
    "url": "https://nhuf.molit.go.kr",
    "contact": "1599-0001",
    "bank": ["우리은행", "국민은행", "신한은행", "하나은행", "농협"]
  }',
  true, true, 2026,
  'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030301.jsp',
  '20240101000000000001'
),

-- ② 중소기업취업청년 전월세보증금 대출
(
  'SME_YOUTH_JEONSE',
  '금융지원', '전세자금',
  '주택도시기금', '전국',
  '중소기업취업청년 전월세보증금 대출',
  '만 19~34세 중소·중견기업 재직 청년, 연소득 5천만원 이하',
  '{
    "age_min": 19,
    "age_max": 34,
    "homeless_required": true,
    "income_type": "절대금액(연소득)",
    "income_abs": 50000000,
    "notes": ["중소·중견기업 재직자 또는 취업 예정자", "재직기간 1년 미만도 신청 가능", "퇴직 후 3개월 이내 재신청 가능"]
  }',
  '{
    "loan_limit": 100000000,
    "loan_pct": 100,
    "interest_min": 1.2,
    "interest_max": 2.1,
    "period_years": 10,
    "deposit_limit": 200000000,
    "desc": "최대 1억원, 금리 연 1.2~2.1% (중소기업 재직 확인 시)"
  }',
  '{
    "method": ["온라인", "은행방문"],
    "url": "https://nhuf.molit.go.kr",
    "contact": "1599-0001",
    "bank": ["우리은행", "국민은행", "신한은행", "하나은행", "농협"]
  }',
  true, true, 2026,
  'https://nhuf.molit.go.kr/FP/FP05/FP0503/FP05030201.jsp',
  '20220101000000000002'
),

-- ③ 청년 전세보증금 반환보증 (HUG)
(
  'YOUTH_JEONSE_GUARANTEE',
  '금융지원', '전세자금',
  '주택도시보증공사', '전국',
  '청년 전세보증금 반환보증 (HUG)',
  '만 19~39세 청년 임차인, 보증금 3억 이하',
  '{
    "age_min": 19,
    "age_max": 39,
    "income_type": "절대금액(연소득)",
    "income_abs": 60000000,
    "notes": ["전세계약 체결 후 잔금지급일로부터 3개월 이내 신청", "임차보증금 3억원 이하 (수도권 기준)"]
  }',
  '{
    "desc": "보증료 연 0.02% (일반의 1/5 수준), 전세금 미반환 시 HUG가 대신 반환",
    "guarantee_limit": 300000000,
    "fee_rate": 0.02
  }',
  '{
    "method": ["온라인"],
    "url": "https://www.khug.or.kr",
    "contact": "1566-9009"
  }',
  true, true, 2026,
  'https://www.khug.or.kr/hug/web/ig/rc/igrc001001.jsp',
  NULL
),

-- ④ 인천시 청년 월세 지원
(
  'INCHEON_YOUTH_RENT',
  '주거비지원', '월세지원',
  '인천시', '인천',
  '인천시 청년 월세 지원',
  '인천 거주 만 19~39세 청년, 월세 거주자',
  '{
    "age_min": 19,
    "age_max": 39,
    "homeless_required": true,
    "region_required": "인천",
    "income_type": "중위소득",
    "income_pct": 150,
    "notes": ["월세 주택 거주자 (전세·자가 제외)", "인천시 거주기간 1년 이상 권장"]
  }',
  '{
    "monthly_support": 100000,
    "max_months": 12,
    "total_max": 1200000,
    "desc": "월 최대 10만원, 최대 12개월 지원"
  }',
  '{
    "method": ["온라인", "방문"],
    "url": "https://www.incheon.go.kr",
    "contact": "032-120",
    "period_type": "정기",
    "period_note": "연 1~2회 공고"
  }',
  true, false, 2026,
  'https://www.incheon.go.kr',
  NULL
),

-- ⑤ 경기도 청년 주거비 지원
(
  'GG_YOUTH_HOUSING',
  '주거비지원', '월세지원',
  '경기도', '경기',
  '경기도 청년 주거비 지원',
  '경기 거주 만 18~34세 청년, 월세·반전세 거주자',
  '{
    "age_min": 18,
    "age_max": 34,
    "homeless_required": true,
    "region_required": "경기",
    "income_type": "중위소득",
    "income_pct": 150,
    "notes": ["월세 또는 반전세 주택 거주", "경기도 거주기간 1년 이상", "1인 가구 우선"]
  }',
  '{
    "monthly_support": 200000,
    "max_months": 12,
    "total_max": 2400000,
    "desc": "월 최대 20만원, 최대 12개월 지원"
  }',
  '{
    "method": ["온라인"],
    "url": "https://apply.gyeonggi.go.kr",
    "contact": "031-120",
    "period_type": "정기",
    "period_note": "연 1회 공고 (상반기)"
  }',
  true, false, 2026,
  'https://apply.gyeonggi.go.kr',
  NULL
),

-- ⑥ 서울시 청년 임차보증금 이자지원
(
  'SEOUL_YOUTH_INTEREST',
  '이자지원', NULL,
  '서울시', '서울',
  '서울시 청년 임차보증금 이자지원',
  '서울 거주 만 19~39세 청년, 전월세 보증금 대출 이용자',
  '{
    "age_min": 19,
    "age_max": 39,
    "homeless_required": true,
    "region_required": "서울",
    "income_type": "도시근로자월평균",
    "income_pct": 150,
    "notes": ["임차보증금 대출을 받은 경우", "서울 거주 1년 이상", "1인 가구 우선 (단, 신혼 등도 가능)"]
  }',
  '{
    "annual_max": 3600000,
    "period_years": 2,
    "total_max": 7200000,
    "interest_rate_supported": 2.0,
    "loan_limit": 150000000,
    "deposit_limit": 300000000,
    "desc": "연 최대 360만원, 최대 2년 지원 (금리 2% 상당)"
  }',
  '{
    "method": ["온라인", "방문"],
    "url": "https://housing.seoul.go.kr",
    "contact": "1600-3456",
    "period_type": "정기",
    "period_note": "연 1~2회 공고"
  }',
  true, false, 2026,
  'https://housing.seoul.go.kr',
  NULL
),

-- ⑦ 전세사기피해자 긴급주거지원
(
  'JEONSE_FRAUD_SUPPORT',
  '주거비지원', '긴급지원',
  '국토교통부', '전국',
  '전세사기피해자 긴급주거지원',
  '전세사기 피해 인정된 임차인',
  '{
    "age_min": 19,
    "homeless_required": false,
    "notes": ["전세사기피해자 지원 및 주거안정에 관한 특별법 피해자", "피해주택에 계속 거주 원하는 경우 LH 매입·경락 지원", "긴급 임시주거 또는 공공임대 우선 배정"]
  }',
  '{
    "desc": "공공임대 우선 공급, 경락대금 지원, 최장 2년 긴급 임시거처",
    "priority_public_rental": true,
    "emergency_housing_months": 24
  }',
  '{
    "method": ["방문", "온라인"],
    "url": "https://www.lh.or.kr",
    "contact": "1600-1004",
    "period_type": "수시",
    "period_note": "피해 확인 즉시 신청 가능"
  }',
  true, true, 2026,
  'https://www.molit.go.kr/jeonse',
  NULL
)

ON CONFLICT (code) DO UPDATE SET
  name            = EXCLUDED.name,
  eligibility     = EXCLUDED.eligibility,
  support_content = EXCLUDED.support_content,
  application_info= EXCLUDED.application_info,
  is_active       = EXCLUDED.is_active,
  updated_at      = NOW();
