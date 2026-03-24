# 온통청년 Open API 학습 자료
> 기준일: 2026-03-24 | API 키: 별도 관리 (GitHub Secret 등록 권장)
> 운영: 한국고용정보원 | 감독: 고용노동부 청년정책 조정관실

---

## ■ API 개요

| 항목 | 내용 |
|------|------|
| 공식 사이트 | https://www.youthcenter.go.kr |
| API 문서 | https://www.youthcenter.go.kr/cmnFooter/openapiIntro/oaiDoc |
| 공공데이터포털 | https://www.data.go.kr/data/15143273/openapi.do |
| 총 정책 수 | 1,711개 (2026-03-24 기준) |
| 응답 형식 | JSON (`rtnType=json`) / XML (기본) |
| 인증 방식 | API 키 (`apiKeyNm` 파라미터) |

---

## ■ 주요 엔드포인트

| 메서드명 | URL | 설명 |
|---------|-----|------|
| `getPlcy` | `https://www.youthcenter.go.kr/go/ythip/getPlcy` | 청년정책 목록 조회 ★주력 |
| `getContent` | `https://www.youthcenter.go.kr/go/ythip/getContent` | 청년 콘텐츠 조회 |
| `getSpace` | `https://www.youthcenter.go.kr/go/ythip/getSpace` | 청년공간/센터 조회 |
| `getPolicyCode` | `https://www.youthcenter.go.kr/go/ythip/getPolicyCode` | 정책 코드 조회 (응답 null 확인됨) |

---

## ■ getPlcy 요청 파라미터

| 파라미터 | 필수 | 설명 | 예시 |
|---------|------|------|------|
| `apiKeyNm` | ✅ | 인증 API 키 | `95ea0919-...` |
| `rtnType` | 권장 | 응답 형식 | `json` |
| `pageIndex` | - | 페이지 번호 (기본 1) | `1` |
| `pageSize` | - | 페이지당 건수 (기본 10) | `100` |
| `keyword` | - | 검색 키워드 | `임대주택`, `주거` |
| `srchPolyBizSecd` | - | 정책 분류 코드 | `003` (필터링 효과 미미) |
| `lclsfNm` | - | 대분류명 필터 | `주거` ★효과적 |

### 주거 정책 조회 예시 (권장)
```
GET https://www.youthcenter.go.kr/go/ythip/getPlcy
  ?apiKeyNm={KEY}&pageIndex=1&pageSize=100&rtnType=json&keyword=주거&lclsfNm=주거
```
→ 156개 주거 정책 반환 (2026-03-24 기준)

---

## ■ getPlcy 응답 구조

```json
{
  "resultCode": 200,
  "resultMessage": "성공적으로 데이터를 가지고 왔습니다.",
  "result": {
    "pagging": {
      "totCount": 1711,
      "pageNum": 1,
      "pageSize": 10
    },
    "youthPolicyList": [ ... ]
  }
}
```

---

## ■ 정책 객체 필드 (youthPolicyList 각 원소)

| 필드명 | 타입 | 설명 | 예시 |
|--------|------|------|------|
| `plcyNo` | String | 정책 고유번호 | `"20260319005400112218"` |
| `plcyNm` | String | 정책명 | `"(국토부) 26년 청년월세 지원사업"` |
| `plcyExplnCn` | String | 정책 설명 | 상세 내용 |
| `plcySprtCn` | String | 지원 내용 | `"월 최대 20만원, 최대 24개월"` |
| `plcyAplyMthdCn` | String | 신청 방법 | |
| `lclsfNm` | String | 대분류 | `"주거"`, `"일자리"`, `"교육･직업훈련"` |
| `mclsfNm` | String | 중분류 | `"전월세 및 주거급여 지원"`, `"주택 및 거주지"`, `"기숙사"` |
| `plcyKywdNm` | String | 키워드 (쉼표 구분) | `"월세,청년,주거"` |
| `sprvsnInstCdNm` | String | 감독기관명 | `"국토교통부"` |
| `operInstCdNm` | String | 운영기관명 | `"국토교통부"` |
| `bizPrdBgngYmd` | String | 사업 시작일 (YYYYMMDD) | `"20260901"` |
| `bizPrdEndYmd` | String | 사업 종료일 (YYYYMMDD) | `"20281231"` |
| `aplyYmd` | String | 신청 기간 | `"20260330 ~ 20260529"` |
| `aplyPrdSeCd` | String | 신청 기간 구분 코드 | `"0057002"` |
| `aplyUrlAddr` | String | 신청 URL | `"https://bokjiro.go.kr"` |
| `refUrlAddr1` | String | 참고 URL 1 | |
| `refUrlAddr2` | String | 참고 URL 2 | |
| `sprtTrgtMinAge` | Number | 지원 최소 나이 | `19` (0=제한없음) |
| `sprtTrgtMaxAge` | Number | 지원 최대 나이 | `34` (0=제한없음) |
| `sprtSclCnt` | Number | 지원 인원 | `0` (무제한), 숫자 |
| `inqCnt` | Number | 조회수 | |
| `zipCd` | String | 지역 우편번호 (쉼표 구분) | `"11110,11140,..."` (수도권=광범위) |
| `frstRegDt` | String | 최초 등록일시 | `"2026-03-19 10:00:00"` |
| `lastMdfcnDt` | String | 최종 수정일시 | |

### 대분류(lclsfNm) 값 목록
`주거` / `일자리` / `교육･직업훈련` / `생활･문화` / `참여･기반` / `복지·건강` / `금융`

### 주거 중분류(mclsfNm) 값 목록
`전월세 및 주거급여 지원` / `주택 및 거주지` / `기숙사`

---

## ■ 우리 플랫폼 활용 전략

### 1. 주거 정책 실시간 조회
```python
def fetch_ontong_housing():
    url = "https://www.youthcenter.go.kr/go/ythip/getPlcy"
    params = {
        "apiKeyNm": ONTONG_API_KEY,
        "pageIndex": 1,
        "pageSize": 200,
        "rtnType": "json",
        "keyword": "주거",
        "lclsfNm": "주거"
    }
    # → 156개 주거 정책 (전국 지자체 포함)
```

### 2. programs 테이블 연계
- `ontong_plcy_no` 컬럼으로 매핑 (예: `GOV_YOUTH_MONTHLY_RENT` ↔ `20260319005400112218`)
- 신청기간(aplyYmd), 사업기간(bizPrdBgngYmd~bizPrdEndYmd) 실시간 업데이트 가능

### 3. 수도권 지자체 정책 자동 수집
- zipCd 필드로 서울(110xx)/경기(410xx)/인천(210xx) 필터링 가능
- 지자체 고유 월세지원·이자지원 정책 자동 탐지

---

## ■ 주거 분야 주요 정책 (2026-03-24 기준, 총 156개)

### 중앙 정부 정책
| plcyNo | 정책명 | 신청기간 | 나이 |
|--------|--------|---------|------|
| 20260319005400112218 | (국토부) 26년 청년월세 지원사업 | 2026.03.30~05.29 | 19~34세 |
| 20260123005400112079 | 대학생 연합생활관(은행권,고양) | 수시 | 제한없음 |

### 수도권 지자체 정책 (일부)
| plcyNo | 정책명 | 지역 | 신청기간 |
|--------|--------|------|---------|
| 20260318005400212197 | 군포시 신혼부부·청년 전월세 보증금 대출이자 지원 | 경기(군포) | 2026.03.09~04.30 |
| 20260318005400212193 | 청년 1인가구 전월세 안심계약 지원 | 경기(군포) | 2026.03.10~12.31 |
| 20260313005400212147 | 용인청년 부동산 중개 보수 감면 | 경기(용인) | 수시 |

---

## ■ 주의사항

1. **API 키 보안**: `apiKeyNm`은 온통청년 계정 기반 발급, GitHub Secret 등에 별도 저장 권장
2. **데이터 신선도**: `lastMdfcnDt` 기준으로 최근 업데이트 정책 우선 표시 권장
3. **신청기간 파싱**: `aplyYmd` 형식이 `"YYYYMMDD ~ YYYYMMDD"` 또는 빈문자열(`""`) 혼재
4. **나이 0**: `sprtTrgtMinAge=0 && sprtTrgtMaxAge=0` → 나이 제한 없음을 의미
5. **지역 필터**: `zipCd`로 지역 필터링 가능하나 수도권 정책은 빈 값이거나 광범위 코드

---

## ■ API 키 관리
- 현재 발급된 키: GitHub Secret `ONTONG_API_KEY`에 저장 권장
- 발급처: https://www.youthcenter.go.kr (마이페이지 → 오픈API)
- 콜센터: 1670-1839 / 이메일: ycmaster@keis.or.kr
