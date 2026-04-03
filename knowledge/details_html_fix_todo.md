# details.html 수정 필요 항목 추적

> 최초 작성: 2026-03-28
> schema.sql 전면 검토와 병행하여 details.html에도 반영 필요한 항목 기록
> ✅ = 수정 완료 / ❌ = 수정 필요 / ⚠️ = 확인 필요

---

## 배경: getE() 함수 구조
```javascript
function getE(code) {
    const e = sbPrograms.find(x => x.code === code)?.eligibility;
    return {
        asset:     m(e.asset_limit),          // 원→만원
        asset2:    m(e.asset_limit_rank2),
        asset3:    m(e.asset_limit_rank3),
        assetReal: m(e.asset_real_limit),
        car:       m(e.car_limit),
        inc:       e.income_pct,
        incM:      e.income_pct_married,
        incPri:    e.income_pct_priority,
        incGen:    e.income_pct_general,
    };
}
```
→ DB 업데이트하면 자동 반영되는 키: `asset_limit`, `asset_limit_rank2/3`, `car_limit`, `income_pct`, `income_pct_married`
→ **getE()에 매핑이 없어서 코드를 고쳐야 하는 키**: `asset_limit_seoul`, `asset_limit_gyeonggi`, `youth_priority_pct` 등

---

## LH 행복주택

### LH 행복주택 - 대학생 (`LH_HAPPY_STUDENT`)
- ❌ 거주기간 표시 `6년` → `10년` 으로 수정 (add() 5번째 인자)
- ❌ 자격 조건에 **입·복학 예정자(다음 학기)** 포함 안내 추가 (typeDetailData 설명)
- ❌ 소득기준 설명: "가구원수별 100% 적용, 1인 120%·2인 110% 가산" 명시
- ⚠️ 청약통장 조건: 대학생 유형은 청약통장 불필요 여부 재확인 필요

### LH 행복주택 - 청년 (`LH_HAPPY_YOUTH`)
- ❌ 자격 판단에서 자산기준 fallback 수정:
  ```javascript
  const aLim22=db22.asset||27300  →  ||25100
  ```
  (schema `asset_limit` 25,100만원으로 수정됨, DB 업데이트 후 자동 반영되지만 fallback도 맞춰야 함)
- ❌ 청약통장 안내: typeDetailData에 "현재 미가입자는 입주 전까지 가입하면 됨" 으로 수정
- ❌ 소득기준: 가구원수별 100% (1인 120%·2인 110% 가산) 명시

### LH 행복주택 - 신혼부부 (`LH_HAPPY_NEWLYWED`)
- ❌ **무주택세대구성원** 조건 명시 (세대원 전원 무주택)
- ❌ **예비신혼부부**: 혼인 예정 상대방도 무주택이어야 함 안내 (typeDetailData)
- ❌ 청약통장 안내: "부부 중 1인 이상, 입주 전까지 가입하면 됨" 으로 수정

### LH 행복주택 - 고령자 (`LH_HAPPY_ELDERLY`)
- ✅ schema에서 삭제 완료
- ❌ details.html 자격 판단 엔진에서 `add('LH 행복주택 (고령자)', ...)` 블록 전체 제거

---

## LH 국민임대 (`LH_NATIONAL_RENT`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ typeDetailData: 청약저축 안내 "50㎡ 미만 불필요 / 50~60㎡ 24회이상(1순위)·6회이상(2순위)" 로 수정
- ❌ typeDetailData: 가점 구조 실제 체계로 수정
- ❌ typeDetailData: 감점 "최근1년 -5점 / 최근3년 -3점" 추가
- ❌ typeDetailData: 60㎡ 초과 소득기준 100% 별도 안내 추가

---

## LH 통합공공임대 (`LH_INTEGRATED`)
- ✅ schema 수정 완료 (2026-03-28)
- ⚠️ 추가 학습 필요 후 반영
- ❌ getE()에 없는 키들을 직접 e에서 읽어야 함:
  ```javascript
  // 현재: const db19 = getE('LH_INTEGRATED'); 로 inc/incM만 사용
  // 수정: p.eligibility에서 직접 youth_priority_pct, newlywed_priority_pct 등 읽기
  ```
- ❌ 청년 나이 기준 코드에 **만 18세** 이상 반영 (`age_min_youth:18`)
- ❌ 자립준비청년(퇴소 5년 이내) 자격 조건 추가
- ❌ 예비신혼부부 상대방 무주택 안내
- ❌ 소득기준 표시: 청년 우선/일반공급, 신혼 우선/일반공급 구분 표시

---

## LH 장기전세주택 (`LH_LONG_JEONSE`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ **details.html 엔진에 블록 자체가 없음 → 신규 추가 필요**
  - `getE('LH_LONG_JEONSE')`로 데이터 읽기
  - getE()에 없는 `asset_limit_seoul`, `asset_limit_gyeonggi`는 `p.eligibility`에서 직접 읽어야 함
  - 소득 조건: 60㎡ 이하 100%, 60㎡ 이하 우선(50㎡미만 50%·50~60㎡ 70%), 60㎡초과 120%, 60㎡초과 우선 100%
  - 감점: 최근1년 -10점 / 최근3년 -5점
  - 청약저축: 50~60㎡만 필요 (24회 이상)
  - 대상 지역: 서울·경기 (SH 유형 아님, LH 전국)
- ❌ typeDetailData 추가 ('LH 장기전세주택')
- ❌ applyGuideData 추가 ('LH 장기전세주택')

---

## LH 영구임대 (검토 예정)
- ⚠️ 미검토

---

## LH 매입임대

### LH 일반 매입임대 (`LH_BUY_GENERAL`)
- ✅ schema 수정 완료 (2026-03-28): car_limit 4,563만→3,708만
- ❌ 자격 판단 코드에서 fallback 수정:
  ```javascript
  // 현재 SH_BUY_GENERAL로 읽는 블록과 구분 필요 (LH 버전은 getE('LH_BUY_GENERAL'))
  // car fallback: ||4563 → ||3708
  ```
- ❌ 2순위 안내에 "소득 100% 이하 장애인" 추가
- ❌ 신청 방법 안내: "지자체(주민센터) 방문 신청" 명시 (applyGuideData)

### LH 청년 매입임대 (`LH_BUY_YOUTH`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ fallback 값 수정 (DB 연결 실패 시 안전망):
  ```javascript
  // 현재: const aLim24_2=db24.asset2||34500, aLim24_3=db24.asset3||27300
  // 수정: aLim24_2=db24.asset2||33700, aLim24_3=db24.asset3||25400
  ```
  (DB 업데이트 후에는 자동 반영됨 — fallback만 맞추면 됨)

### LH 신혼·신생아 매입임대 Ⅰ형 (`LH_BUY_NEWLYWED_1`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ fallback 값 수정:
  ```javascript
  // 현재: const aLim25=db25.asset||34500
  // 수정: aLim25=db25.asset||33700
  ```
- ❌ rank 로직에 4순위 구분 추가:
  ```javascript
  // 현재: infant||singleParent → 1순위, 자녀있는신혼 → 2순위, 자녀없는신혼 → 3순위
  // 수정: youngChild&&isMarried (혼인가구) 는 4순위로 별도 표시
  ```

### LH 신혼·신생아 매입임대 Ⅱ형 (`LH_BUY_NEWLYWED_2`)
- ✅ schema 수정 완료 (2026-03-28): 소득 130%/200%, 자산 37,900만
- ❌ fallback 값 수정:
  ```javascript
  // 현재: const aLim26=db26.asset||34500
  // 수정: aLim26=db26.asset||37900
  ```
  (소득 130%/200% 체크 로직은 이미 올바름: `dualInc ? under(200) : under(130)`)
- ❌ add() 호출에서 이름 수정: `'LH 신혼·신생아 매입임대 Ⅱ형'` → `'LH 신혼·신생아 매입임대 Ⅱ형 (전세형)'`
- ❌ typeDetailData / applyGuideData 키도 동일하게 이름 변경
- ❌ rank 로직에 4·5순위 구분 추가

### LH 다자녀 매입임대 (`LH_BUY_MULTICHILDREN`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ 자격 판단 블록 확인: `getE('LH_BUY_MULTICHILDREN')` 쓰는지 확인 후 fallback 수정
  ```javascript
  // asset fallback: ||34500 → ||33700
  // car fallback: ||4542 → ||4563
  ```
- ❌ rank 로직: 신생아 포함 여부로 1순위/2순위 구분 추가

### LH 기숙사형 매입임대 (`LH_DORM_YOUTH`)
- ✅ schema 수정 완료 (2026-03-28): 자산 순위별 분리, sub_type 매입임대
- ❌ **details.html 엔진에 블록이 있는지 확인 필요** (현재 없는 것으로 보임)
  - 없으면 신규 추가: `getE('LH_DORM_YOUTH')` 사용
  - asset2(33,700만) / asset3(25,400만) / car(4,563만) 적용
  - 1순위: 수급자·한부모·차상위, 2순위: 본인+부모 100%, 3순위: 본인 100% (만19~39세)
- ❌ typeDetailData 추가 ('LH 기숙사형 매입임대')
- ❌ applyGuideData 추가 ('LH 기숙사형 매입임대')

### LH 집주인 임대주택 (`LH_LANDLORD_RENT`) ★신규
- ✅ schema 추가 완료 (2026-03-28)
- ❌ **details.html 엔진에 신규 블록 추가 필요**
  - 청년(19~39세, 소득120%) / 신혼부부(혼인7년이내, 소득120%)
  - 임대료: 시세 85% 수준
- ❌ typeDetailData 추가 ('LH 집주인 임대주택')
- ❌ applyGuideData 추가 ('LH 집주인 임대주택')

---

## LH 전세임대

### LH 기존주택 전세임대 (`LH_JEONSE_GENERAL`)
- ✅ schema 수정 완료 (2026-03-28)
- ❌ 2순위 안내에 "소득100% 이하 장애인" 추가
- ❌ 신청 방법: 지자체(주민센터) 또는 LH청약플러스 명시

### LH 청년 전세임대 (`LH_JEONSE_YOUTH`)
- ✅ schema 수정 완료 (2026-03-28): 자산기준 단일값→순위별 분리, 1순위 자립준비청년 추가
- ❌ fallback 값 수정:
  ```javascript
  // 현재: asset_limit 단일값 사용 중 → asset2/asset3로 분리
  // const aLim_2=db.asset2||33700, aLim_3=db.asset3||25400
  ```
- ❌ 1순위 안내에 자립준비청년, 청소년복지시설퇴소자 추가 (typeDetailData)

### LH 신혼·신생아 전세임대 Ⅰ형 (`LH_JEONSE_NEWLYWED_1`)
- ✅ schema 수정 완료 (2026-03-28): asset 23,700만→33,700만, 순위구조·한부모·혼인가구 추가
- ❌ fallback 값 수정:
  ```javascript
  // 현재: db.asset||34500 (또는 다른 값)
  // 수정: db.asset||33700
  ```
- ❌ 4순위(6세이하자녀 혼인가구) rank 표시 추가

### LH 신혼·신생아 전세임대 Ⅱ형 (`LH_JEONSE_NEWLYWED_2`)
- ✅ schema 수정 완료 (2026-03-28): 소득 100%/130%→130%/200%, 자산 34,500만→35,400만
- ❌ fallback 값 수정:
  ```javascript
  // 소득 체크: dualInc ? under(200) : under(130)  ← 이미 맞을 가능성 있음 (코드 재확인 필요)
  // 자산 fallback: ||34500 → ||35400
  ```
- ❌ 4순위(6세이하자녀 혼인가구) rank 표시 추가

### LH 다자녀 전세임대 (`LH_JEONSE_CHILDREN`)
- ✅ schema 수정 완료 (2026-03-28): 재활성화, 소득70%·자산33,700만·차량4,563만 추가, 3자녀 추가지원 명시
- ⚠️ LH 공식 전세임대 목록에는 없지만 마이홈포털에 확인됨 — 소득·자산 기준은 다자녀 매입임대와 동일 추정 (추후 재확인 필요)
- ❌ details.html 엔진에 자격 판단 블록 확인 필요 (있으면 자산 fallback 수정, 없으면 신규 추가)
- ❌ typeDetailData: "3자녀이상 자녀 1인당 +2,000만원 추가 지원" 안내 추가

## LH 공공분양 ✅ schema 수정완료 (2026-04-02)

### LH_PUBLIC_SALE_GENERAL
- ✅ `subscription_required` 비표준 제거 → `income_pct:100`, `income_pct_married:200`, `savings_min_rank1:12`, `newborn_income_bonus_pct:20` 추가
- ❌ details.html 엔진 블록 확인 → 소득 기준 60㎡이하만 적용 (notes 안내), newborn 완화 로직 추가

### LH_PUBLIC_SALE_NEWLYWED
- ✅ `savings_min_rank1:6`, `newborn_income_bonus_pct:20` 추가

### LH_PUBLIC_SALE_FIRST
- ✅ `life_first_required:true`, `savings_amount_min:6000000` 추가

### LH_PUBLIC_SALE_CHILDREN
- ✅ `savings_min_rank1:6`, `newborn_income_bonus_pct:20` 추가

### LH_PUBLIC_SALE_NEWBORN
- ✅ `newborn_required:true`, `savings_min_rank1:6`, `newborn_income_bonus_pct:20` 추가

### LH_PUBLIC_SALE_ELDERLY
- ✅ `savings_min_rank1:12`, `newborn_income_bonus_pct:20` 추가

## LH 신혼희망타운 (`LH_HOPE_TOWN`) ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct_married` 140→200 (추첨공급 최대값 기준)
- ✅ `savings_min_rank1:6`, `newborn_income_bonus_pct:20`, `newborn_asset_bonus_pct:20` 추가
- ✅ source_url 공식 링크로 업데이트
- ❌ details.html 엔진 블록 확인 → `newborn_asset_bonus_pct` 반영 (자산기준 완화 계산)

---

## SH 국민임대주택 (`SH_NATIONAL_RENT`) ✅ schema 수정완료 (2026-03-30)
- ❌ 소득 1인(90%)/2인(80%) 가산 → getE()에 매핑 없음 (`income_pct_1person`, `income_pct_2person`)
- ❌ 60㎡초과 소득기준(100%/1인120%/2인110%) → getE()에 매핑 없음 (`income_pct_over60sqm` 등)
- ❌ details.html 엔진에 해당 블록이 있는지 확인 후 순위별 소득기준 분기 처리 추가

---

## SH 공공·주거환경임대주택 (`SH_PUBLIC_ENV_RENT`) ★신규 (2026-03-30)
- ❌ **details.html 엔진에 블록 자체 없음 → 신규 추가 필요**
  - 기본 자격: 서울 거주 성년 무주택, `baseOk && age >= 19`
  - 소득: 60㎡이하 70%(1인90%·2인80%) / 60㎡초과 120%
  - 청약저축 필수 (1순위 2년+24회 / 2순위 6개월+6~23회)
  - 자산: 총자산 34,500만 + 부동산 별도 21,550만 (`asset_real_limit`) 체크 필요
- ❌ typeDetailData 추가 ('SH 공공·주거환경임대주택')
- ❌ applyGuideData 추가 ('SH 공공·주거환경임대주택')

---

## SH 재개발임대주택 (`SH_REDEVELOP_RENT`) ★신규 (2026-03-30)
- ❌ **details.html 엔진에 블록 자체 없음 → 신규 추가 필요**
  - 기본 자격: 서울 거주 무주택, `baseOk`
  - 소득: 70% (1순위 50%이하/1인70%·2인60%, 2순위 70%이하/1인90%·2인80%)
  - 자산: 총자산 34,500만
  - rank 표시: 1순위/2순위 소득구간으로 구분
- ❌ typeDetailData 추가 ('SH 재개발임대주택 (일반공급)')
- ❌ applyGuideData 추가 ('SH 재개발임대주택 (일반공급)')
- ⚠️ 공급량이 적고 철거세입자 우선이므로 일반 청년 대상으로는 낮은 우선순위 유형

---

## SH 도시형생활주택 (`SH_URBAN_LIVING`) ★신규 (2026-03-30)
- ❌ **details.html 엔진에 블록 자체 없음 → 신규 추가 필요**
  - 기본 자격: 서울 거주 무주택 1~2인 가구 (`baseOk && householdSize <= 2`)
  - 소득: 70% (1순위 50%이하 / 2순위 50~70%)
  - 자산: 총자산 34,500만
  - `household_max: 2` 조건 → 입력값(가구원수)으로 필터링 필요
- ❌ typeDetailData 추가 ('SH 도시형생활주택')
- ❌ applyGuideData 추가 ('SH 도시형생활주택')

---

## SH 매입임대주택

### SH 일반 매입임대 (`SH_BUY_GENERAL`) ✅ schema 수정완료 (2026-03-30)
- ❌ 자격 판단 코드에서 1순위 구성 확인: 수급자/한부모/시급가구(RIR30%↑)/65세이상저소득/장애인(70%이하)
- ❌ 2순위: 소득50%이하 또는 장애인100%이하 → 두 조건 OR 처리
- ❌ 자녀별 자산 완화(자녀1명+2,400만/2명이상+4,700만) 로직 추가

### SH 청년 매입임대 (`SH_PURCHASE_RENT_YOUTH`) ✅ schema 수정완료 (2026-03-30)
- ✅ asset_limit_rank2(33,700만)/rank3(25,400만) 이미 반영
- ❌ 자격 판단 코드 income 수정:
  ```javascript
  // 2순위: 본인+부모 합산 100%이하 (기존 50%→100% 수정)
  // 3순위 블록 추가: 본인 소득 100%이하, 자산25,400만
  ```
- ❌ 1순위 판단: 수급자/한부모/차상위 (시급가구·장애인은 일반매입 기준, 청년매입에는 해당 없음)

### SH 신혼·신생아 매입임대 Ⅰ형 (`SH_BUY_NEWLYWED_1`) ✅ schema 수정완료 (2026-03-30)
- ❌ 혼인가구(6세이하자녀) 4순위 포함 여부 공고문 확인 후 rank 로직 추가

### SH 신혼·신생아 매입임대 Ⅱ형 (`SH_BUY_NEWLYWED_2`) ✅ schema 수정완료 (2026-03-30)
- ❌ car_limit 추가됨 (45,630,000) → getE() 통해 자동 반영
- ❌ 자산기준 35,400만원 공고문 재확인 필요 (LH Ⅱ형 기준 37,900만원과 다름)
- ❌ 예비신혼부부 marital_status 추가됨 → 자격 판단 코드 확인
- ❌ rank 로직: 4순위(6세이하자녀 혼인가구) 추가 필요 (공고문 확인 후)

### SH 희망하우징 (`SH_HOPE_HOUSING`) ✅ schema 수정완료 (2026-04-01)
- ❌ 자격 판단 코드에 "복학·입학 예정자 포함" 안내 추가 (typeDetailData)
- ❌ 순위별 소득 기준: 2순위=본인+부모 합산, 3순위=본인만 — 분기 처리 확인
- ❌ 소득 가산 반영: 1인 120%, 2인 110% (getE()에 inc1p/inc2p 매핑 필요)
- ❌ 3순위 자산기준 10,400만원 (asset_limit_rank3) — getE()에 asset3 매핑 확인
- ❌ 가점 항목 안내 추가 (typeDetailData): 생계의료3점·부모무주택2점·장애인2점·소득50%3점·청약저축24회3점

### SH 장기미임대 (`SH_LONG_UNOCCUPIED`) ✅ schema 수정완료 (2026-03-30)
- ❌ details.html에서 2순위(130%초과) 표시 방식 확인 필요 (소득 제한 없음 처리와 구분)

---

## SH 행복주택

### SH 행복주택 청년 (`SH_HAPPY_YOUTH`) ✅ schema 수정완료 (2026-03-29)
- ❌ `income_pct_1person`, `income_pct_2person`은 getE()에 매핑 없음 → 소득 체크 로직에 미반영
  ```javascript
  // getE()에 추가 필요:
  inc1p: e.income_pct_1person,
  inc2p: e.income_pct_2person,
  ```
  또는 소득 체크 코드에서 `p.eligibility`에서 직접 읽어야 함
- ❌ 사회초년생(근무경력5년이내) 자격 조건 판단 추가 (나이 40세 이상이어도 취업 5년 이내면 자격 됨)
- ❌ typeDetailData: 1·2순위 구조, 가점 항목 안내 추가

### SH 행복주택 대학생 (`SH_HAPPY_STUDENT`) ✅ schema 추가수정 (2026-04-01)
- ✅ `school_region_required:"서울"` 추가 (2026-04-01)
- ✅ support_content에 `period_max_years:10` 추가 (2026-04-01)
- ✅ notes에 "소득: 본인+부모 합산 기준" 추가 (2026-04-01)
- ❌ `school_region_required` 판단 로직 추가 필요 (학교 소재지 폼값으로 체크)
- ❌ `income_pct_1person`, `income_pct_2person` getE() 매핑 없음 (위와 동일 이슈)

### SH 행복주택 신혼부부 (`SH_HAPPY_NEWLYWED`) ✅ schema 추가수정 (2026-04-01)
- ✅ `is_household_member_required:true` 추가 (2026-04-01)
- ✅ 중복 소득 note 제거 (2026-04-01)
- ❌ `is_household_member_required` 판단 로직 추가 필요 (세대원 전원 무주택 체크)
- ❌ `income_pct_2person`(110%), `income_pct_married`(120%), `income_pct_married_2person`(130%) — getE()에 매핑 없음
  ```javascript
  // getE()에 추가 필요:
  inc2p:    e.income_pct_2person,
  incM:     e.income_pct_married,       // 기존 incM은 이미 있음 → 값 갱신됨
  incM2p:   e.income_pct_married_2person,
  ```
- ❌ 소득 체크 로직: 가구원수 2인 여부에 따라 inc2p/incM2p 분기 처리 필요
- ❌ car_limit 추가됨 → evalProg() 자산 체크 구현 시 함께 반영

---

## SH 전세임대주택

### SH 기존주택 전세임대 (`SH_JEONSE_RENT`) ✅ schema 수정완료 (2026-03-30)
- ❌ 자격 판단 코드 1순위 구성 확인: 수급자/한부모/시급가구(RIR30%↑)/장애인(70%이하)/만65세이상저소득
- ❌ 2순위: 소득50%이하 또는 장애인100%이하 OR 처리
- ❌ 신생아 가산(+10~20%p) 로직 확인

### SH 신혼·신생아 전세임대 Ⅰ형 (`SH_JEONSE_NEWLYWED_1`) ✅ schema 수정완료 (2026-03-30)
- ❌ 순위 구조 notes 추가됨 → 자격 판단 코드에 rank 표시 반영
- ❌ 혼인가구(6세이하자녀) 4순위 포함 여부 공고문 확인 후 rank 로직 추가

### SH 신혼·신생아 전세임대 Ⅱ형 (`SH_JEONSE_NEWLYWED_2`) ✅ schema 수정완료 (2026-03-30)
- ❌ car_limit 추가됨 → getE() 통해 자동 반영
- ❌ 예비신혼부부 marital_status 추가됨 → 자격 판단 코드 확인
- ❌ rank 로직: 4순위(6세이하자녀 혼인가구) 추가 필요 (공고문 확인 후)

### SH 전세임대형 든든주택 (`SH_DNDNT_JEONSE`) ✅ schema 수정완료 (2026-03-30)
- ❌ 1순위 신생아(2년이내출산)/다자녀(미성년2명이상) 조건 → 자격 판단 코드에 반영
- ❌ 소득·자산 기준 없음이므로 evalProg 자산 체크 적용 제외 처리 필요

---

## SH 장기전세·미리내집

### SH 장기전세주택 (`SH_JANGKI_JEONSE`) ✅ schema 수정완료 (2026-04-02)
- ✅ 비표준 면적별 소득 필드(`income_pct_60` 등) → `income_pct:150`, `income_pct_married:200`, `newborn_income_bonus_pct:20`으로 표준화
- ❌ 우선공급(60㎡이하 소득70%이하) 해당 여부 결과 카드에 표시
- ❌ 85㎡ 초과는 청약예금 필요 — 청약저축만 있는 사용자에게 안내 필요

### SH 장기전세주택2 미리내집 (`SH_MIRINAE_JIP`) ✅ schema 수정완료 (2026-04-02)
- ✅ 비표준 면적별 소득 필드 → `income_pct:150`, `income_pct_married:200`, `newborn_income_bonus_pct:20`으로 표준화
- ❌ 자녀 있을 경우 자산기준 20% 완화 — 자녀 여부 입력값에 따라 자산 기준 상향 계산 필요

## SH 장기안심주택

### SH 장기안심주택 (`SH_ANSIM_JEONSE`) ✅ schema 수정완료 (2026-03-31)
- 수정: `asset_real_limit` 21,550,000 → 215,500,000 (21,550만원, 0 하나 빠진 오류 수정)
- `car_limit` 45,630,000 (4,563만원) — 공식확인, 변경 없음
- 추가: 특별공급 선정기준 (신혼부부·세대통합), 가산점 항목 notes에 추가
- 공식확인 URL: https://www.i-sh.co.kr/app/lay2/S48T1593C1534/contents.do
- ❌ typeDetailData: 가산점 구조, 특별공급(신혼·세대통합) 선정기준 추가
- ❌ applyGuideData: 특별공급·일반공급 중복신청 불가, 탈락 시 자동전환 없음 안내

## SH 청년안심주택

### SH 청년안심주택 공공임대 청년 (`SH_SAFETY_PUBLIC_YOUTH`) ✅ schema 수정완료 (2026-03-31)
- 기존 `SH_SAFETY_PUBLIC`/`SH_SAFETY_PRIVATE` → 4개로 분리
- 청년: 미혼 조건 추가, 2순위 국민임대기준(34,500만) / 3순위 행복주택청년기준(25,400만) 분리
- car_limit: 45,630,000 (4,563만원)
- 공식확인 URL: https://www.i-sh.co.kr/app/lay2/S48T3396C3532/contents.do
- 2순위 자산 34,500만원 ✅ 확정 (housing.seoul.go.kr은 단순화 표기, i-sh.co.kr 기준이 정확)
- ❌ details.html: `SH_SAFETY_PUBLIC` key → `SH_SAFETY_PUBLIC_YOUTH` 변경, 순위별 자산 분기 로직 추가

### SH 청년안심주택 공공임대 신혼부부 (`SH_SAFETY_PUBLIC_NEWLYWED`) ✅ schema 수정완료 (2026-03-31)
- 신혼I(70%/맞벌이90%·자산33,700만) · 신혼II(130%/맞벌이200%·자산 분양전환기준) 반영
- car_limit: 45,630,000 (4,563만원)
- 거주기간: 신혼부부 최장 20년 (청년 10년과 다름)
- 공식확인 URL: https://www.i-sh.co.kr/app/lay2/S48T3396C3533/contents.do
- ❌ details.html 신규 블록 추가 필요, 신혼I/II 표시 방식 설계 필요

### SH 청년안심주택 민간임대 청년 (`SH_SAFETY_PRIVATE_YOUTH`) ✅ schema 수정완료 (2026-03-31)
- 특별공급: 소득 100%/110%/120% 지역별 순위, 자산 34,500만원, 차량 4,563만원
- 일반공급: 제한 없음, 무작위 추첨
- 공식확인 URL: https://housing.seoul.go.kr/site/main/content/sh02_05
- ❌ details.html 신규 블록 추가: 특별공급 지역별 순위(100%/110%/120%) 판단 + 일반공급 안내
- ❌ 공고 매칭: `[민간임대]` 공고에 `youthPrivateRank(ann.district)` 순위 표시 ← ✅ 이미 구현됨 (2026-03-31)

### SH 청년안심주택 민간임대 신혼부부 (`SH_SAFETY_PRIVATE_NEWLYWED`) ✅ schema 수정완료 (2026-03-31)
- 특별공급: 소득 100%/110%/120% 지역별 순위, 자산 34,500만원, 차량 4,563만원
- 일반공급: 제한 없음, 무작위 추첨
- 공식확인 URL: https://housing.seoul.go.kr/site/main/content/sh02_05
- ❌ details.html 신규 블록 추가 필요

### 청년안심주택 공통 (2026-03-31 구현 완료)
- ✅ 폼: 직장 소재 구 / 학교 소재 구 select 추가 (서울 선택 시 표시)
- ✅ runAnalysis(): `residenceGu` / `workplaceGu` / `schoolGu` 변수, `youthPrivateRank()` 함수
- ✅ 결과 카드: `[민간임대]` 공고에 `🏷 1/2/3순위` 표시
- ✅ scraper.py: 상세 페이지에서 `district` 파싱 → announcements 저장
- ✅ schema.sql: `announcements.district TEXT` 컬럼 추가
- ✅ Supabase: `ALTER TABLE announcements ADD COLUMN district TEXT` 실행 완료

---

## SH 나눔형 분양주택

### SH_NAMOOM_GENERAL ✅ schema 수정완료 (2026-04-02)
- ✅ `newborn_income_bonus_pct:20` 구조화 필드 추가
- ❌ details.html 엔진에 블록 있는지 확인 → `getE('SH_NAMOOM_GENERAL')` 사용, `newborn_income_bonus_pct` 반영

### SH_NAMOOM_YOUTH ✅ schema 수정완료 (2026-04-02)
- ✅ `savings_min_rank1:6` 추가, notes 정리
- ❌ `asset_limit_self`, `asset_limit_parents` 비표준 필드 → getE()에 별도 매핑 필요
  ```javascript
  assetSelf:    p.eligibility.asset_limit_self    != null ? Math.round(p.eligibility.asset_limit_self / 10000) : null,
  assetParents: p.eligibility.asset_limit_parents != null ? Math.round(p.eligibility.asset_limit_parents / 10000) : null,
  ```
- ❌ `savings_min_rank1` → getE()에 매핑 추가 필요

### SH_NAMOOM_NEWLYWED ✅ schema 수정완료 (2026-04-02)
- ✅ `savings_min_rank1:6` 추가, notes 정리 (청약저축 조건·순위 구조)

### SH_NAMOOM_NEWBORN ★신규 추가 (2026-04-02)
- ❌ details.html 엔진에 블록 없음 → 신규 추가 필요
  - `newborn_required:true` 조건 체크 (2세 미만 자녀)
  - 소득 140%/맞벌이200%, 자산 35,400만, savings_min_rank1:6

### SH_NAMOOM_FIRST ★신규 추가 (2026-04-02)
- ❌ details.html 엔진에 블록 없음 → 신규 추가 필요
  - `life_first_required:true` 조건 체크
  - 소득 130%/맞벌이200%, 자산 35,400만, `savings_amount_min:6000000`
- ❌ getE()에 `savings_amount_min` 매핑 추가 필요

---

## SH 공공분양주택

### SH_PUBLIC_SALE_GENERAL ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct_married` 140→200, `savings_min_rank1:12`, `newborn_income_bonus_pct:20` 추가
- ❌ details.html 엔진 블록 확인 → `savings_min_rank1`, `newborn_income_bonus_pct` 반영

### SH_PUBLIC_SALE_NEWLYWED ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct` 130→**120** 수정, `savings_min_rank1:6` 추가
- ❌ details.html 소득 체크 로직 120% 기준으로 수정 확인

### SH_PUBLIC_SALE_FIRST ✅ schema 수정완료 (2026-04-02)
- ✅ `life_first_required:true`, `savings_amount_min:6000000` 추가
- ❌ `life_first_required` 판단 로직 추가 (현재 폼에 생애최초 여부 입력 없음 → 미적용 안내)
- ❌ `savings_amount_min` getE() 매핑 추가 필요

### SH_PUBLIC_SALE_CHILDREN ✅ schema 수정완료 (2026-04-02)
- ✅ `savings_min_rank1:6` 추가

### SH_PUBLIC_SALE_NEWBORN ★신규 추가 (2026-04-02)
- ❌ details.html 엔진에 블록 없음 → 신규 추가 필요
  - `newborn_required:true` 조건 체크
  - 소득 140%/맞벌이200%, 자산(부동산) 21,550만, 차량 4,563만

### SH_PUBLIC_SALE_ELDERLY ★신규 추가 (2026-04-02)
- ❌ details.html 엔진에 블록 없음 → 신규 추가 필요
  - 65세이상 직계존속 3년 부양 조건 (현재 폼에 입력 없음 → 안내만)
  - 소득 120%/맞벌이200%, 자산(부동산) 21,550만, 차량 4,563만

---

## GH/iH 임대주택

### GH_HAPPY_YOUTH ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct_1person:120`, `income_pct_2person:110` 추가
- ✅ `car_limit` 45,630,000 (전 기관 통일 적용)
- ✅ notes에 "경기 거주 우선" 추가
- ❌ details.html 엔진 블록: income_pct_1person/2person 반영 확인

### GH_NATIONAL_RENT ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct_1person:90`, `income_pct_2person:80` 추가
- ✅ `car_limit` 45,630,000 (전 기관 통일 적용)
- ✅ notes에 "경기 거주 우선" 추가
- ❌ UPDATE문 (37,080,000 재설정) 제거 완료

### GH_HAPPY_NEWLYWED ✅ schema 수정완료 (2026-04-02)
- ✅ `income_pct_2person:110`, `newborn_income_bonus_pct:20` 추가
- ✅ `car_limit` 37,080,000 → **45,630,000** (전 기관 통일)
- ✅ notes에서 "GH 자동차 기준 3,708만원" 제거

### GH_BUY_YOUTH ✅ schema 수정완료 (2026-04-02)
- ✅ `asset_limit` → `asset_limit_rank2:345000000` (2순위 자산 구조화 필드로 교체)
- ✅ `car_limit` 37,080,000 → **45,630,000** (전 기관 통일)
- ✅ notes에서 "GH 자동차 기준 3,708만원" 제거
- ❌ details.html 엔진 블록: asset_limit_rank2/rank3 분기 확인

### iH 유형 (IH_NATIONAL_RENT, IH_HAPPY_YOUTH, IH_HAPPY_NEWLYWED 등)
- ✅ 이전 세션에서 car_limit 45,630,000 이미 적용 확인
- ✅ income_pct_1person/2person 이미 적용 확인
- ⚠️ iH 1000원 주택(IH_1000WON_BUY/JEONSE), IH_DUNDAN: 자산기준 없음 (소득기준만) — 현 상태 유지

---

## 공통 수정 사항

### income_standards 오류
- ❌ schema.sql `income_standards` 1인·2인 값 오류
  - 현재 1인: `4,576,036` (실제는 1인 120% 가산값)
  - 올바른 1인 100%: `3,813,363`
  - 현재 2인: `6,452,897` (실제는 2인 110% 가산값)
  - 올바른 2인 100%: `5,866,270`
  - → details.html 소득 계산 로직(`under()` 함수) 에도 영향 → 함께 검토

### details.html 전체 적용 필요
- ❌ **고령자 관련 판단 로직** 전부 제거 (타겟: 2030 청년)
  - SH 고령자, LH 행복주택 고령자, `add('LH 행복주택 (고령자)', ...)` 등 제거
- ❌ 청약통장 안내 문구 통일: "미가입자는 입주 전까지 가입 필요"
- ❌ **신생아 완화 계산**: 신생아 자녀 있는 경우 소득기준·자산기준을 **+20%p 상향** 계산
  (공식 확인된 유형: LH_HAPPY_YOUTH, LH_HAPPY_NEWLYWED)

### getE() 함수 확장 필요
- ❌ 장기전세 지역별 자산기준 키 추가:
  ```javascript
  assetSeoul:   m(e.asset_limit_seoul),
  assetGyeonggi: m(e.asset_limit_gyeonggi),
  ```
- ❌ 통합공공임대 청년/신혼 우선·일반 소득기준 키 추가:
  ```javascript
  incYouthPri:   e.youth_priority_pct,
  incYouthGen:   e.youth_general_pct,
  incNwedPri:    e.newlywed_priority_pct,
  incNwedGen:    e.newlywed_general_pct,
  ```

---

## 공공분양·민간분양 투기과열지구 로직 (LH 공고 연동 시점에 구현)

### 배경
- 공공분양·민간분양 1순위 청약통장 조건이 공고 위치에 따라 다름
  - 투기과열지구(서울 전역·경기 과천·광명·하남·수원일부·성남일부·안양동안·용인수지·의왕): **2년이상+24회이상**
  - 일반 수도권: 1년이상+12회이상
  - 수도권 외: 6개월이상+6회이상
- SH 공고는 서울 = 무조건 투기과열지구 → 별도 로직 불필요, 24회 고정
- LH 공고는 전국 → 지역 파악 필요 (아직 미연동)

### 구현 시점
**LH 공고 연동 시점에 같이 구현** (선구현 불필요)

### 설계안
```
1. announcements.json에 region 필드 추가
   scraper가 공고 제목/내용에서 지역 파싱
   → { ..., region: "서울", is_overheated: true }

2. 투기과열지구 목록 하드코딩 (applyhome 기준, 수시 변경 가능성 있음)
   const OVERHEATED_REGIONS = ["서울", "과천", "광명", "하남", "수원팔달", "수원영통", "수원권선", "성남분당", "성남수정", "성남중원", "안양동안", "용인수지", "의왕"]

3. details.html 공고 매칭 시
   공고.is_overheated ? "청약 2년이상·24회이상 필요" : "청약 1년이상·12회이상 필요"
```

### 주의
- 투기과열지구 목록은 수시 변경됨 → applyhome.co.kr 규제지역 현황 주기적 확인 필요
- 임대주택은 이 로직 적용 불필요 (청약통장 조건 다름)

---

## evalProg 자산 체크 누락 (긴급)

### ❌ evalProg()에 자산 체크 없음
- 현재 `evalProg`는 나이·무주택·소득·지역·혼인상태만 체크
- `asset_real_limit`, `asset_limit`, `car_limit` 체크 완전 누락
- 공공분양 특별공급·금융지원 자격판단에 자산심사가 빠진 상태

**추가해야 할 로직 (evalProg 함수 내):**
```javascript
// 부동산 자산 (공공분양용) — realEstate 변수 사용
if (e.asset_real_limit && realEstate > e.asset_real_limit / 10000)
    r.push(`부동산 ${Math.round(e.asset_real_limit/10000).toLocaleString()}만원 이하 필요`);
// 총자산 (금융지원 등) — totalAssets 변수 사용
if (e.asset_limit && totalAssets > e.asset_limit / 10000)
    r.push(`총자산 ${Math.round(e.asset_limit/10000).toLocaleString()}만원 이하 필요`);
// 자동차 가액 — carVal 변수 사용
if (e.car_limit && carVal > e.car_limit / 10000)
    r.push(`자동차 ${Math.round(e.car_limit/10000).toLocaleString()}만원 이하 필요`);
```

**구분 원칙:**
- `asset_real_limit` = 부동산 가액만 (공공분양 특별공급 기준)
- `asset_limit` = 총자산/순자산 (금융지원·디딤돌·버팀목 등 기준)
- 두 필드는 절대 혼용하지 말 것

---

---

## 우선공급 대상 여부 결과 카드 표시

### 배경 (2026-03-29 사용자 지시)
- 신청 자격 판단과는 별개로, 자격이 되는 유형 내에서 **우선공급 대상인지 표시**해주면 유용
- 우선공급이 일반공급보다 유리하므로 사용자가 인지할 수 있어야 함

### 설계 방향
- 결과 카드에 "우선공급 대상" 배지 또는 문구 추가
- 판단 기준: 유형별로 schema notes나 별도 필드에서 우선공급 조건 파악
  - 예: 신생아 있음 → 신생아 우선공급
  - 예: 수급자·한부모·차상위 → 1순위 우선공급
  - 예: 해당 자치구 거주 → 1순위

### 구현 시점
- schema 검토 완료 후 details.html 일괄 수정 시 함께 반영
- 우선공급 조건은 유형마다 달라 유형별 로직 설계 필요

---

## 메모
- schema.sql 수정이 완료된 항목을 순서대로 details.html에 반영
- details.html 수정은 schema 검토가 어느 정도 마무리된 후 일괄 반영 예정
- DB(Supabase)에 schema.sql 적용 후 자동 반영되는 것과 코드 수정이 필요한 것을 구분해서 작업
