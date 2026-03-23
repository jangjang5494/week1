# 학습 데이터 재확인 가이드
> 최초 학습일: 2026-03-21
> 용도: 향후 세션에서 데이터 변경사항 확인 시 이 파일을 프롬프트로 제공

---

## ▶ 사용법 (복붙 프롬프트)

```
아래 가이드를 참고해서 각 URL을 방문하고,
knowledge/ 폴더의 해당 파일과 비교해서 변경된 내용이 있으면 업데이트해줘.
특히 신청기간·소득기준·지원금액·자산기준이 바뀌었는지 중점 확인.

[data_refresh_guide.md 내용 붙여넣기]
```

---

## 0. LH청약플러스 — 임대가이드 (apply.lh.or.kr) ★2026-03-21 학습완료

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `LH_임대주택_LLM학습용.md`, `schema.sql (programs 테이블)` |
| **메인 URL** | https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1201583&cntntsId=1201331 |

**재확인 시 핵심 체크 항목**:
- 기준중위소득 연도별 수치 (현행: 2026년 1인 256만·4인 649만)
- 도시근로자 월평균소득 수치 (현행: 2025년 1인 458만·4인 880만)
- 건설형 자산기준 (현행: 행복주택청년 25,100만·대학생 10,800만·자동차 4,542만)
- 매입임대형 자산기준 (현행: 청년매입3순위 27,300만·자동차 3,708만)
- 새로 추가된 임대유형 여부 (2026-03-21 신규: 다자녀매입임대, 전세임대형든든주택)

---

## 0-1. LH청약플러스 — 분양가이드 (apply.lh.or.kr) ★2026-03-21 학습완료

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `schema.sql (programs 테이블 LH_PUBLIC_SALE_*)` |
| **메인 URL** | https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1178&cntntsId=1048 |

**확인할 서브페이지**:
- 일반공급 자격 (청약저축 납입횟수·금액 기준)
- 신혼부부 특별공급 (우선30%/일반60%/추첨10% 비율)
- 생애최초 특별공급 (추첨 50% 여부)
- 다자녀 특별공급 (자녀수 우선순위)
- 신생아 특별공급 (2세이하 기준)
- 노부모부양 특별공급 (65세·3년 부양)

**핵심 확인 항목**:
- 신혼부부 특공 우선/일반/추첨 비율 (현행: 30%/60%/10%)
- 신혼부부 우선공급 소득기준 (현행: 단독100%·맞벌이120%)
- 공공분양 자산기준 (현행: 부동산 21,550만원·차량 4,563만원)
- 신생아특공 신설 여부·기준 변경
- 소득기준 연도별 갱신 여부

---

## 1. SH인터넷청약시스템 — 주택분양 (www.i-sh.co.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/sh_housing_sale.md` |
| **메인 URL** | https://www.i-sh.co.kr/app/lay2/S48T5553C7333/contents.do |
| **접근 방법** | WebFetch 직접 가능 |

**확인할 서브페이지**:
```
나눔형 일반공급 자격   /app/lay2/S48T5553C5554/sublink.do
나눔형 특별공급 자격   /app/lay2/S48T5554C7336/contents.do
나눔형 체크리스트      /app/lay2/S48T5553C7272/sublink.do
공공분양 일반공급      /app/lay2/S48T7334C1661/contents.do
공공분양 특별공급      /app/lay2/S48T7334C1663/contents.do
공공분양 유의사항      /app/lay2/S48T588C6752/contents.do
```

**핵심 확인 항목**:
- 나눔형 일반공급 자산기준 (35,400만원)
- 나눔형 청년 특별공급 소득기준 (140%) 및 자산 (본인 27,000만원 / 부모 101,100만원)
- 공공분양 자산기준 (부동산 21,550만원, 차량 4,563만원)
- 본청약 유의사항 카드뉴스 업데이트 여부

---

## 1-2. SH인터넷청약시스템 — 주택임대 (www.i-sh.co.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/sh_rental_housing.md` |
| **메인 URL** | https://www.i-sh.co.kr/app/lay2/S48T1587C1455/contents.do |
| **접근 방법** | WebFetch 직접 가능 |

**확인할 서브페이지 (청약자격)**:
```
장기전세주택     /app/lay2/S48T1587C589/contents.do
장기전세주택2    /app/lay2/S48T6792C6812/contents.do
국민임대주택     /app/lay2/S48T1588C590/sublink.do
매입임대주택     /app/lay2/S48T1589C1590/sublink.do
희망하우징       /app/lay2/S48T1591C592/contents.do
장기안심주택     /app/lay2/S48T1592C1593/sublink.do
행복주택         /app/lay2/S48T1594C1603/sublink.do
전세임대주택     /app/lay2/S48T572C3156/sublink.do
청년안심주택     /app/lay2/S48T2731C3396/sublink.do
```

**핵심 확인 항목**:
- 소득기준 적용 연도 (2025→2026년 도시근로자 월평균소득 갱신 시)
- 자산기준 변경 여부 (장기전세 64,000만원, 행복주택청년 25,400만원 등)
- 장기안심주택 보증금 지원한도 (1.5억이하→50%/4,500만, 초과→30%/6,000만)
- 희망하우징 임대료 (보증금 109만원, 월 7~14만원)
- 청년안심주택 콜센터: 02-793-0761~8

---

## 2. 서울시 청년안심주택 (soco.seoul.go.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/seoul_youth_housing.md` |
| **메인 URL** | https://soco.seoul.go.kr/youth/main/contents.do?menuNo=400012 |
| **접근 방법** | WebFetch 직접 가능 |

**확인할 서브페이지**:
```
menuNo=400012  → 청년안심주택 개요 (사업 설명)
menuNo=400039  → 입주자격안내 (소득·자산·연령 기준)
menuNo=400015  → 모집공고 목록 (진행중 공고)
menuNo=400009  → FAQ
```

**핵심 확인 항목**:
- 청년형 소득기준: 도시근로자 월평균소득 120% (1인 약 431만원 기준)
- 신혼부부형 자산기준: 총자산 3억3,700만원 / 자동차 4,563만원
- 민간임대 특별공급 20% / 일반공급 80% 비율
- 청년 임차보증금: 보증금 3억 이하, 월세 70만 이하, 하나은행, 연 2.0%
- 서울시 청년월세 신청기간 (2026년: 6.11~6.24)

---

## 2. 인천청년포털 — 주거·복지 (youth.incheon.go.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/incheon_youth_housing.md` |
| **메인 URL** | https://youth.incheon.go.kr/dwelling/interest.jsp |
| **접근 방법** | WebFetch 직접 가능 |

**확인할 서브페이지**:
```
/dwelling/interest.jsp       → 청년 주택임차보증금 이자지원
/dwelling/interest_faq.jsp   → 이자지원 FAQ
/dwelling/monthly.jsp        → 청년월세 지원사업
/dwelling/monthly_faq.jsp    → 청년월세 FAQ
/dwelling/guarantee.jsp      → 전세보증금반환보증 보증료 지원
/dwelling/lease.jsp          → 기존 주택매입임대 (iH)
/dwelling/military.jsp       → 군복무 인천청년 상해보험
/dwelling/addict.jsp         → 청년중독관리사업
/dwelling/future.jsp         → 인천광역시 청년미래센터
```

**핵심 확인 항목**:
- 청년 임차보증금 이자지원 신청기간 (2026년 5월 중 예정)
- 소득기준: 미혼 6천만원 / 기혼 8천만원 이하
- 대출한도: 최대 1억원, 금리 연 3.0~3.5%
- 청년월세 2026년 신청기간: 2026.3.30~5.29
- 대출연장 신청기간: 2025.4.9~2026.12.31 (변경 여부)

---

## 3. 인천주거포털 — 공공임대·i+집드림·주거복지 (www.incheon.go.kr/housing)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/incheon_housing_portal.md` |
| **메인 URL** | https://www.incheon.go.kr/housing/index |
| **접근 방법** | ⚠️ WebFetch 실패 → `curl -H "User-Agent: Mozilla/5.0 ..."` 필요 |

**확인할 서브페이지**:
```
공공임대
  /housing/hou010101  → 천원주택 매입임대 (인천 고유 ⭐)
  /housing/hou010102  → 천원주택 전세임대 신혼·신생아
  /housing/hou010103  → 천원주택 전세임대 든든주택
  /housing/hou010201  → LH 매입임대
  /housing/hou010205  → LH 전세임대

i+집드림
  /housing/hou020101  → i+집드림 1.0 이자지원 (출생자녀 가구)
  /housing/hou020201  → i+집드림 2.0 (내용 확인 필요)

주거복지
  /housing/hou030101  → 장애인 주택개조 지원
  /housing/hou040101  → 긴급복지 인천형SOS
  /housing/hou050101  → 전세반환보증 보증료 지원
```

**핵심 확인 항목**:
- 천원주택 모집 일정 (2026년 5월 예정 → 실제 공고 여부)
- 천원주택 매입임대 300호 / 전세임대 700호 규모 변경 여부
- i+집드림 1.0: 연최대 300만원×5년, 1자녀 0.8%/2자녀 1.0% 금리보전
- i+집드림 2.0 신규 내용 확인 (2026년 시작 여부)
- 전세반환보증료: 2025.3.31 이후 최대 40만원 기준 유지 여부

**접근 방법 (bash)**:
```bash
curl -s -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
     "https://www.incheon.go.kr/housing/hou010101"
```

---

## 4. 경기도 주거복지포털 (housing.gg.go.kr) ⚠️ 차단

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/gg_housing_welfare.md` |
| **메인 URL** | https://housing.gg.go.kr |
| **접근 방법** | ❌ TCP 차단 (해외 서버 IP 차단) — WebSearch로 대체 |

**대체 접근 방법**:
```
WebSearch: "경기도 청년 이사비 중개보수비 지원 2026"
WebSearch: "housing.gg.go.kr 청년주거복지 2026"
WebSearch: "경기복지재단 잡아바 어플라이 청년이사비"
```

**핵심 확인 항목** (비공식 출처 → 공식 확인 필요):
- 청년 이사비·중개보수비 지원: 최대 25만원, 중위소득 120% 이하
- 2026년 공고 시기 및 선정 규모 (2024년: 1차 800명)
- 소규모 노후주택 집수리: 최대 1,600만원 — 2026년 변경 여부

---

## 5. SH공사 임대주택 (i-sh.co.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `sh_임대주택/` 폴더, `sh_임대주택_QA.md` |
| **메인 URL** | https://www.i-sh.co.kr |
| **접근 방법** | WebFetch 직접 가능 |

**핵심 확인 항목**:
- 연간 소득기준 (도시근로자 월평균소득 → 매년 갱신)
- 자동차 기준: SH 3,803만원 (타 기관과 다름)
- 청년안심주택 SH 직접공급분 모집 공고

---

## 6. LH청약플러스 (apply.lh.or.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `LH_임대주택_LLM학습용.md`, `lh_임대주택_정리.md` |
| **메인 URL** | https://apply.lh.or.kr |
| **접근 방법** | WebFetch 직접 가능 |

**핵심 확인 항목**:
- 행복주택 소득기준 연도 갱신 (2025년 도시근로자 → 2026년 발표 시)
- 청년매입임대 자산기준: 총자산 27,300만원 / 자동차 4,563만원
- LH 전국 임대 모집 공고 신규 여부

---

## 7. GH 임대주택 (apply.gh.or.kr)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/gh_rental_housing.md` ★2026-03-23 신규 작성 |
| **GH 청약 URL** | https://apply.gh.or.kr |
| **GH 홈 URL** | https://www.gh.or.kr |
| **접근 방법** | ⚠️ WebFetch 타임아웃 — WebSearch 보완 / 공식 URL은 확인됨 |

**핵심 확인 항목**:
- GH 행복주택 청년 자산기준: 총자산 27,300만원 / 자동차 3,708만원 (공식 확인)
- GH 행복주택 대학생 자산기준: 10,000만원 (LH 10,800만원과 다름 — 재확인 필요)
- GH 국민임대 자동차 기준: 3,708만원 (LH 4,542만원과 다름 — 재확인 필요)
- 2026년 공고문 기준으로 자산기준 변경 여부 확인

**확인할 서브페이지**:
```
경기행복주택 입주자격  /gh/gyeonggi-happy-house-eligibility-to-move-in.do
국민임대 입주자격      /gh/nationalpermanent-rental-eligibility-to-move-in.do
통합공공임대 입주자격  /gh/integration-public-lease-house-eligibility-to-move-in.do
분양·임대 공고 목록    /gh/announcement-of-salerental001.do
```

## 7-2. iH 임대주택 (ih.co.kr) ★2026-03-23 학습완료

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/ih_rental_housing.md` ★신규 작성 |
| **iH URL** | https://www.ih.co.kr |
| **접근 방법** | ✅ WebFetch 직접 가능 |

**확인된 서브페이지**:
```
건설형(영구임대)   /main/sale_lease/management/build.jsp
국민임대/장기전세  /main/sale_lease/management/nation.jsp
행복주택          /main/sale_lease/management/happy.jsp
매입형            /main/sale_lease/management/buy.jsp
임차형(보증금지원) /main/sale_lease/management/lease.jsp
주거복지사업      /main/sale_lease/welfare/ih.jsp
입주자모집공고    /main/sale_lease/notice.jsp
```

**확인된 핵심 수치 (2026-03-23)**:
- iH 국민임대 자동차: **4,563만원** (기존 3,500만원 오기재 → 수정 필요)
- iH 국민임대 총자산: **33,700만원** (코드 34,500만원 → 불일치)
- iH 행복주택 소득: 100%(맞벌이120%, 1인120%, 2인110%)
- iH 행복주택 자산: 공고별 상이 (HTML 미게재)

**다음 재확인 시 체크 항목**:
- 천원주택 2026년 하반기 모집 공고 여부
- 행복주택 자산기준 공고문(PDF) 확인
- 국민임대 자산기준 연도 변경 여부 (현재 2025년 기준)

---

## 8. 공통 소득·자산 기준 (매년 갱신)

| 항목 | 내용 |
|------|------|
| **knowledge 파일** | `knowledge/common_standards.md` |
| **출처** | 보건복지부 고시(중위소득) / 국토교통부 고시(도시근로자) |

**갱신 시점**:
- 기준중위소득: 매년 **8월** 다음연도 기준 발표 → 그해 **1월 1일** 적용
- 도시근로자 월평균소득: 매년 **3~4월** 전년도 기준 발표 → 공공임대 소득기준에 적용

**핵심 확인 항목**:
- 2027년 기준중위소득 (2026년 8월 발표 예정)
- 2026년 도시근로자 월평균소득 (2026년 상반기 발표 예정)

---

## ▶ 미학습 목록 (서버 IP 차단으로 접근 불가 — 사용자 직접 복붙 또는 추후 시도)

> 마지막 시도일: 2026-03-21 / 원인: 한국 공공기관 해외 서버 IP 차단

### ❌ LH청약플러스 — 임대가이드 전체

| 항목 | 내용 |
|------|------|
| **메인 URL** | https://apply.lh.or.kr/lhapply/cm/cntnts/cntntsView.do?mi=1201583&cntntsId=1201331 |
| **knowledge 파일** | `LH_임대주택_LLM학습용.md`, `lh_임대주택_정리.md` (기존 md 기반으로 schema 반영 완료) |
| **접근 방법** | ❌ TCP 차단 — 사용자 직접 복붙 또는 한국 IP 환경 필요 |

**학습 못한 서브탭** (클릭해서 확인해야 하는 인터랙티브 요소):
```
임대가이드 메인       mi=1201583&cntntsId=1201331
├── 공공임대 탭       (국민임대·통합공공임대·행복주택·장기전세·분양전환 등)
├── 매입임대 탭       (청년·신혼·일반·든든전세 등)
├── 전세임대 탭       (청년·신혼·일반·다자녀 등)
└── 유형별 자격요건   (각 탭 내 상세 소득·자산·순위 수치)
```

**핵심 확인 항목**:
- 2026년 소득기준 업데이트 여부 (도시근로자 월평균소득 연도 갱신)
- 자산기준 변경 여부 (매년 소폭 상향 추세)
- 신규 유형 추가 여부 (든든전세주택 등 최근 신설)
- 차량기준 최신값 확인 (현재 schema: 4,563만원)

---

### ❌ 경기도 주거복지포털 (housing.gg.go.kr)

| 항목 | 내용 |
|------|------|
| **메인 URL** | https://housing.gg.go.kr |
| **knowledge 파일** | `knowledge/gg_housing_welfare.md` |
| **접근 방법** | ❌ TCP 차단 — WebSearch로 대체 또는 한국 IP 환경 필요 |

**학습 못한 항목**:
```
청년 이사비·중개보수비 지원  (최대 25만원, 중위소득 120%)
소규모 노후주택 집수리        (최대 1,600만원)
2026년 공고 일정 및 선정 규모
```

---

**해결 방법 (우선순위 순)**:
1. 사용자가 해당 사이트 열고 `Ctrl+A` → `Ctrl+C` → 대화창에 붙여넣기
2. 공공데이터포털 API 연동 (공고 데이터 한정, 자격기준은 불가)
3. WebSearch로 최신 블로그·뉴스에서 수치 확인 (비공식)

---

## ▶ 재확인 우선순위

| 우선순위 | 이유 |
|---------|------|
| ⭐⭐⭐ 인천청년포털 | 신청기간이 짧음 (월세: 3.30~5.29) |
| ⭐⭐⭐ 인천주거포털 | 천원주택 2026년 5월 모집 예정 |
| ⭐⭐ 서울 청년안심주택 | 월세 신청기간 6.11~6.24 |
| ⭐⭐ 공통소득기준 | 연도 바뀌면 모든 프로그램 기준 변경 |
| ⭐ 경기도 | 차단 문제 해결 후 재시도 |
