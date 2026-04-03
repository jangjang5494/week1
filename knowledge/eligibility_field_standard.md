# eligibility JSONB 표준 필드 목록

> 작성일: 2026-04-01
> 목적: schema.sql의 모든 programs.eligibility JSONB 필드를 이 표준으로 통일
> 원칙: 폼 입력값으로 판단 가능한 것은 모두 구조화 필드 / 판단 불가한 것만 notes

---

## 대원칙

| 구분 | 내용 |
|------|------|
| **구조화 필드** | 엔진이 자동 판단하는 모든 값 (현재 폼에 없어도 나중에 폼 추가 예정 포함) |
| **notes** | 상세보기 모달에 표시할 텍스트만 (판단에 사용 안 함) |
| **notes 금지** | 이미 구조화 필드로 있는 값의 반복 기재 금지 |
| **면적별 소득기준** | 폼에 면적 입력 없음 → income_pct에 최대(완화) 기준값 사용, 면적별 세부는 notes |
| **중복 질문 금지** | 입력받은 데이터로 한 번에 판단 (순위·우선공급도 소득/자산 입력값으로 동시 판단) |

---

## 1~4단계: 기본 자격 필드 (신청 가능 여부 판단)

### 기본 인적사항
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `age_min` | integer | 최소 나이 (null=제한없음) |
| `age_max` | integer | 최대 나이 |
| `marital_status` | array | 허용 혼인상태: "미혼"/"기혼"/"신혼(7년이내)"/"예비신혼"/"한부모" |
| `marriage_years_max` | integer | 신혼 인정 최대 혼인기간 (년) |

### 주거 조건
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `homeless_required` | boolean | 무주택 필수 |
| `is_household_head` | boolean | 세대주 필수 (null=무관) |
| `is_household_member_required` | boolean | 무주택세대구성원 필수 (세대원 전원 무주택) |
| `household_max` | integer | 최대 가구원 수 (예: 도시형생활주택 2인 이하) |
| `region_required` | string | 거주지역 필수: "서울"/"경기"/"인천"/"수도권"/"전국" |
| `school_region_required` | string | 학교 소재지 필수: "서울"/"수도권" |
| `enrollment_required` | boolean | 재학(복학·입학예정 포함) 필수 |
| `employed_required` | boolean | 재직 필수 |

### 소득 기준
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `income_type` | string | "도시근로자월평균" / "중위소득" / "절대금액(연소득)" |
| `income_pct` | integer | 기본 소득 상한 % (면적별 차이 있으면 최대 완화 기준값 사용) |
| `income_pct_1person` | integer | 1인 가구 가산 % (예: 120) |
| `income_pct_2person` | integer | 2인 가구 가산 % (예: 110) |
| `income_pct_married` | integer | 맞벌이 적용 % |
| `income_pct_married_2person` | integer | 맞벌이 2인 적용 % |
| `income_abs` | integer | 절대 연소득 상한 (원/년, income_type=절대금액 시) |
| `income_abs_married` | integer | 맞벌이 절대 연소득 상한 |

### 자산 기준
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `asset_limit` | integer | 총자산 상한 (원) |
| `asset_real_limit` | integer | 부동산 가액 상한 (원) — 총자산과 별도 체크 |
| `car_limit` | integer | 자동차 가액 상한 (원) |
| `asset_limit_seoul` | integer | 서울 거주자 총자산 상한 (지역별 다를 때) |
| `asset_limit_gyeonggi` | integer | 경기 거주자 총자산 상한 |

### 가구 구성 조건
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `children_required` | boolean | 자녀 필수 |
| `children_min` | integer | 최소 자녀 수 |
| `children_age_max` | integer | 자녀 나이 상한 (세) |
| `newborn_required` | boolean | 신생아(2세이하) 필수 |
| `life_first_required` | boolean | 생애최초 필수 |

---

## 5단계: 우대자격 필드 (순위·우선공급 판단)

> 소득/자산 입력값으로 한 번에 판단 — 별도 질문 없음

### 순위별 소득·자산 기준
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `income_pct_rank1` | integer | 1순위 소득 상한 % |
| `income_pct_rank2` | integer | 2순위 소득 상한 % |
| `income_pct_rank3` | integer | 3순위 소득 상한 % |
| `asset_limit_rank2` | integer | 2순위 자산 상한 (원) |
| `asset_limit_rank3` | integer | 3순위 자산 상한 (원) |
| `car_limit_rank2` | integer | 2순위 차량 상한 (원) |
| `car_limit_rank3` | integer | 3순위 차량 상한 (원) |

### 통합공공임대 전용 (청년/신혼 우선·일반 구분)
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `youth_priority_pct` | integer | 청년 우선공급 소득 상한 % |
| `youth_priority_pct_1person` | integer | 청년 우선공급 1인 가산 % |
| `youth_priority_pct_2person` | integer | 청년 우선공급 2인 가산 % |
| `youth_general_pct` | integer | 청년 일반공급 소득 상한 % |
| `youth_general_pct_1person` | integer | 청년 일반공급 1인 가산 % |
| `youth_general_pct_2person` | integer | 청년 일반공급 2인 가산 % |
| `newlywed_priority_pct` | integer | 신혼 우선공급 소득 상한 % |
| `newlywed_priority_pct_2person` | integer | 신혼 우선공급 2인 가산 % |
| `newlywed_general_pct` | integer | 신혼 일반공급 소득 상한 % |
| `newlywed_general_pct_2person` | integer | 신혼 일반공급 2인 가산 % |
| `newlywed_general_dual_pct` | integer | 신혼 일반공급 맞벌이 % |
| `newlywed_general_dual_pct_2person` | integer | 신혼 일반공급 맞벌이 2인 % |

### 신생아 완화
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `newborn_income_bonus_pct` | integer | 신생아 보유 시 소득기준 완화 +%p |
| `newborn_asset_bonus_pct` | integer | 신생아 보유 시 자산기준 완화 +%p |

### 청약저축 기준
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `savings_min_rank1` | integer | 1순위 최소 납입 횟수 |
| `savings_min_rank2` | integer | 2순위 최소 납입 횟수 |
| `savings_amount_min` | integer | 최소 납입 금액 (원, 예: 생애최초 6,000,000) |

### 사회초년생
| 필드명 | 타입 | 설명 |
|--------|------|------|
| `social_newcomer_eligible` | boolean | 사회초년생 자격 허용 여부 |
| `social_newcomer_years_max` | integer | 사회초년생 인정 소득활동 기간 (년) |

---

## notes 작성 기준

### notes에 넣는 것 ✅
- 정의 설명: "사회초년생: 소득활동 5년이내(나이무관)"
- 면적별 소득 세부 안내: "60㎡이하 100% / 60㎡초과 120%"
- 청약저축 안내: "입주 전까지 가입 필수"
- 중요 주의사항: "세대원 전원 무주택 필수"
- 복잡한 예외: "내발산기숙사는 수도권 대학원생 포함"

### notes에 넣지 않는 것 ❌
- 이미 구조화 필드로 있는 소득%·자산 값의 반복
- 우선공급 배분 비율 (20%, 30% 등) — 사용자에게 불필요
- 기관 연락처, 신청 URL — application_info에 별도 관리

---

## 제거할 비표준 필드 (발견 시 표준으로 교체)

| 비표준 필드 | 교체 방향 |
|------------|---------|
| `income_pct_nwed1`, `income_pct_nwed2` | `income_pct_rank1`, `income_pct_rank2`로 통일 |
| `income_pct_special_rank1/2/3` | `income_pct_rank1/2/3`으로 통일 |
| `income_pct_over60sqm` 등 면적별 | `income_pct`에 최대값, 세부는 notes |
| `income_pct_60_priority_under50` 등 | notes로 이동 |
| `car_limit_alt`, `asset_limit_alt` | 순위별 필드(`rank2`, `rank3`)로 교체 |
| `income_pct_priority`, `income_pct_general` | 유형에 따라 `rank1/2` 또는 `youth_priority/general`로 교체 |
| `income_pct_newlywed_single`, `income_pct_newlywed_dual` | `income_pct`, `income_pct_married`로 통일 |
