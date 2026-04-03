# details.html 수정 필요 항목 추적 (v2)

> 최초 작성: 2026-04-03
> 링크 검토 → schema.sql 수정 후 details.html에도 반영이 필요한 항목을 기록
> ✅ = 수정 완료 / ❌ = 수정 필요 / ⚠️ = 확인 필요

---

## 기본 원칙

### 1. schema vs details.html 역할 분리
- **schema.sql** = 단일 진실 공급원 (수치·조건 데이터)
- **details.html** = 판단 로직 + UI 표시
- schema가 바뀌면 → DB 연동 값은 자동 반영 / 하지만 아래 경우는 코드 수정 필요

### 2. details.html 수동 수정이 필요한 경우
| 상황 | 이유 |
|------|------|
| 새 자격 조건 추가 (나이·순위·우선공급 등) | 판단 로직에 분기 직접 추가 필요 |
| 새 getE() 키가 필요할 때 | getE() 함수에 매핑 추가 |
| 블록 이름 변경 | add() 호출 + typeDetailData + applyGuideData 키 동시 변경 |
| typeDetailData / applyGuideData 텍스트 | 수동 작성 |
| fallback 값 수정 | DB 미연결 시 안전망, schema와 일치시켜야 함 |

### 3. getE() 현재 매핑 전체 (2026-04-03 기준)
```javascript
function getE(code) {
    const e = sbPrograms.find(x => x.code === code)?.eligibility;
    return {
        // ── 자산 ──
        asset:         m(e.asset_limit),
        asset2:        m(e.asset_limit_rank2),    // alias: assetRank2
        asset3:        m(e.asset_limit_rank3),    // alias: assetRank3
        assetReal:     m(e.asset_real_limit),
        assetSeoul:    m(e.asset_limit_seoul),
        assetGyeonggi: m(e.asset_limit_gyeonggi),
        assetRank2:    m(e.asset_limit_rank2),
        assetRank3:    m(e.asset_limit_rank3),
        car:           m(e.car_limit),

        // ── 소득 ──
        inc:      e.income_pct,
        inc1p:    e.income_pct_1person,
        inc2p:    e.income_pct_2person,
        incM:     e.income_pct_married,
        incM2p:   e.income_pct_married_2person,
        incPri:   e.income_pct_priority,
        incGen:   e.income_pct_general,
        incRank1: e.income_pct_rank1,
        incRank2: e.income_pct_rank2,
        incRank3: e.income_pct_rank3,

        // ── 신생아 완화 ──
        newbornIncBonus:   e.newborn_income_bonus_pct,
        newbornAssetBonus: e.newborn_asset_bonus_pct,

        // ── 사회초년생 ──
        socialNewcomer:      e.social_newcomer_eligible,
        socialNewcomerYears: e.social_newcomer_years_max,

        // ── 청약저축 ──
        savingsRank1: e.savings_min_rank1,
        savingsRank2: e.savings_min_rank2,
        savingsAmt:   m(e.savings_amount_min),

        // ── 기타 ──
        childrenMin:  e.children_min,
        hhMemberReq:  e.is_household_member_required,
    };
}
```
→ **DB 업데이트하면 자동 반영**: 위 목록의 모든 키
→ **getE()에 없어서 직접 추가해야 하는 키**: 위 목록에 없는 신규 schema 필드

---

## 수정 항목 목록

<!-- 링크 검토 후 schema 수정 시 여기에 추가 -->
<!-- 형식: ### 유형명 (`CODE`) -->
<!-- - ❌ details.html 수정 내용 설명 -->
<!-- - ⚠️ 확인 필요 내용 -->

