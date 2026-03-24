#!/usr/bin/env python3
"""
온통청년 Open API → Supabase programs 테이블 동기화
실행: python3 ontong_sync.py
환경변수: ONTONG_API_KEY, SUPABASE_URL, SUPABASE_KEY
"""

import os, json, re, urllib.request, urllib.parse
from datetime import datetime, date

ONTONG_BASE = "https://www.youthcenter.go.kr/go/ythip/getPlcy"
SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
ONTONG_API_KEY = os.environ["ONTONG_API_KEY"]

# 제외할 타 지역 키워드 (수도권·전국 외)
OTHER_REGIONS = [
    '부산', '대구', '대전', '광주', '울산', '세종',
    '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
]
# 수도권·전국 기관 키워드
METRO_KEYWORDS = ['서울', '경기', '인천']
NATIONAL_KEYWORDS = ['국토교통부', '국토부', '주택도시기금', '한국토지주택공사',
                     'LH', '보건복지부', '고용노동부', '중소벤처기업부']


# ── 지역 판별 ──────────────────────────────────────────────────

def detect_region(inst: str, policy: dict) -> str:
    for kw, region in [('서울', '서울'), ('경기', '경기'), ('인천', '인천')]:
        if kw in inst:
            return region
    # zipCd로 2차 판별
    zip_cd = policy.get('zipCd', '') or ''
    for z in zip_cd.split(','):
        z = z.strip()[:3]
        if z.startswith('11'):
            return '서울'
        if z.startswith('41'):
            return '경기'
        if z.startswith('21'):
            return '인천'
    return '전국'


def is_metro_or_national(policy: dict) -> bool:
    """수도권 또는 전국 정책만 통과"""
    texts = [
        policy.get('operInstCdNm', '') or '',
        policy.get('sprvsnInstCdNm', '') or '',
        policy.get('plcyNm', '') or '',
    ]
    full = ' '.join(texts)

    # 타 지역 명시 → 제외
    if any(r in full for r in OTHER_REGIONS):
        return False

    # 전국 기관 또는 수도권 → 포함
    if any(k in full for k in NATIONAL_KEYWORDS + METRO_KEYWORDS):
        return True

    # zipCd로 판단
    zip_cd = policy.get('zipCd', '') or ''
    if not zip_cd:
        return True  # 지역 미지정 → 전국으로 간주
    for z in zip_cd.split(','):
        z = z.strip()[:3]
        if z.startswith(('11', '41', '21')):
            return True

    return False


def is_active(policy: dict) -> bool:
    """사업 종료일이 오늘 이전이면 제외"""
    end_ymd = policy.get('bizPrdEndYmd', '') or ''
    if len(end_ymd) == 8:
        try:
            end = date(int(end_ymd[:4]), int(end_ymd[4:6]), int(end_ymd[6:8]))
            return end >= date.today()
        except ValueError:
            pass
    return True


# ── 스키마 변환 헬퍼 ──────────────────────────────────────────

def detect_institution(policy: dict) -> str:
    name = policy.get('operInstCdNm', '') or policy.get('sprvsnInstCdNm', '') or ''
    name = re.sub(r'^\([^)]+\)\s*', '', name).strip()  # "(국토부) " prefix 제거
    return name or '기타'


def detect_category(policy: dict) -> tuple:
    mclsf = policy.get('mclsfNm', '') or ''
    text = (policy.get('plcyNm', '') or '') + (policy.get('plcySprtCn', '') or '')

    if mclsf in ('주택 및 거주지', '기숙사'):
        return '임대주택', mclsf
    if any(k in text for k in ['전세자금', '구입자금', '대출', '보금자리론', '디딤돌', '버팀목']):
        return '금융지원', mclsf
    if any(k in text for k in ['이자지원', '이자 지원']):
        return '이자지원', mclsf
    if any(k in text for k in ['보증료', '보증보험']):
        return '보증료지원', mclsf
    return '주거비지원', mclsf


def parse_support_content(policy: dict, category: str) -> dict:
    sprt = policy.get('plcySprtCn', '') or ''
    result = {'description': sprt}

    if category == '주거비지원':
        m = re.search(r'월\s*(?:최대\s*)?(\d+)만원', sprt)
        if m:
            result['monthly_support'] = int(m.group(1)) * 10000
        m = re.search(r'(\d+)개월', sprt)
        if m:
            result['max_months'] = int(m.group(1))
        m = re.search(r'(?:총|최대)\s*(\d+)만원', sprt)
        if m:
            result['total_max'] = int(m.group(1)) * 10000

    elif category == '이자지원':
        m = re.search(r'연\s*(?:최대\s*)?(\d+)만원', sprt)
        if m:
            result['annual_max'] = int(m.group(1)) * 10000
        m = re.search(r'(\d+)년', sprt)
        if m:
            result['period_years'] = int(m.group(1))

    elif category == '금융지원':
        m = re.search(r'(?:최대\s*)?(\d+)억', sprt)
        if m:
            result['loan_limit'] = int(m.group(1)) * 100_000_000
        m = re.search(r'(\d+(?:\.\d+)?)\s*~\s*(\d+(?:\.\d+)?)%', sprt)
        if m:
            result['interest_min'] = float(m.group(1))
            result['interest_max'] = float(m.group(2))

    return result


def parse_application_info(policy: dict) -> dict:
    aply_ymd = policy.get('aplyYmd', '') or ''
    url = policy.get('aplyUrlAddr', '') or policy.get('refUrlAddr1', '') or ''

    period_type = '수시'
    period_note = ''

    raw = aply_ymd.replace(' ', '')
    if '~' in raw:
        parts = raw.split('~')
        s, e = parts[0].strip(), parts[1].strip()
        if len(s) == 8 and len(e) == 8:
            period_note = f"{s[:4]}.{s[4:6]}.{s[6:]} ~ {e[:4]}.{e[4:6]}.{e[6:]}"
            period_type = '공고별'
        else:
            period_note = aply_ymd
    elif raw:
        period_note = aply_ymd

    result = {'period_type': period_type, 'url': url}
    if period_note:
        result['period_note'] = period_note
    return result


def parse_eligibility(policy: dict) -> dict:
    age_min = policy.get('sprtTrgtMinAge') or 0
    age_max = policy.get('sprtTrgtMaxAge') or 0
    result = {'homeless_required': False}
    if age_min > 0:
        result['age_min'] = age_min
    if age_max > 0:
        result['age_max'] = age_max
    return result


def build_record(p: dict) -> dict:
    cat, subcat = detect_category(p)
    inst = detect_institution(p)
    region = detect_region(inst, p)

    age_min = p.get('sprtTrgtMinAge') or 0
    age_max = p.get('sprtTrgtMaxAge') or 0
    if age_min > 0 and age_max > 0:
        target = f"만 {age_min}~{age_max}세"
    elif age_min > 0:
        target = f"만 {age_min}세 이상"
    else:
        target = ''

    return {
        'code': f"ONTONG_{p['plcyNo']}",
        'ontong_plcy_no': p['plcyNo'],
        'name': (p.get('plcyNm', '') or '').strip(),
        'category': cat,
        'subcategory': subcat,
        'institution': inst,
        'region': region,
        'description': p.get('plcyExplnCn', '') or '',
        'target_summary': target,
        'eligibility': parse_eligibility(p),
        'support_content': parse_support_content(p, cat),
        'application_info': parse_application_info(p),
        'source_url': (p.get('aplyUrlAddr', '') or p.get('refUrlAddr1', '') or ''),
        'is_active': True,
        'is_central': region == '전국',
        'data_year': 2026,
    }


# ── API 호출 ──────────────────────────────────────────────────

def fetch_all() -> list:
    all_policies = []
    page = 1
    page_size = 200

    while True:
        params = urllib.parse.urlencode({
            'apiKeyNm': ONTONG_API_KEY,
            'pageIndex': page,
            'pageSize': page_size,
            'rtnType': 'json',
            'lclsfNm': '주거',
        })
        req = urllib.request.Request(f"{ONTONG_BASE}?{params}")
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode('utf-8'))

        result = data.get('result', {})
        policies = result.get('youthPolicyList', []) or []
        all_policies.extend(policies)

        tot = result.get('pagging', {}).get('totCount', 0)
        print(f"  페이지 {page}: {len(policies)}개 (누적 {len(all_policies)}/{tot})")

        if len(all_policies) >= tot or not policies:
            break
        page += 1

    return all_policies


# ── Supabase upsert ────────────────────────────────────────────

def upsert_batch(records: list) -> None:
    url = f"{SUPABASE_URL}/rest/v1/programs"
    body = json.dumps(records).encode('utf-8')
    req = urllib.request.Request(url, data=body, method='POST')
    req.add_header('apikey', SUPABASE_KEY)
    req.add_header('Authorization', f'Bearer {SUPABASE_KEY}')
    req.add_header('Content-Type', 'application/json')
    req.add_header('Prefer', 'resolution=merge-duplicates,return=minimal')

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            status = resp.status
    except urllib.error.HTTPError as e:
        body_err = e.read().decode('utf-8', errors='replace')[:300]
        print(f"  ⚠️  HTTP {e.code}: {body_err}")
        return

    if status not in (200, 201):
        print(f"  ⚠️  예상치 못한 상태코드: {status}")


def upsert_all(records: list, batch_size: int = 50) -> int:
    total = 0
    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        upsert_batch(batch)
        total += len(batch)
        print(f"  ✅ {i + 1}~{i + len(batch)} upsert 완료")
    return total


# ── 메인 ──────────────────────────────────────────────────────

def main():
    print("=== 온통청년 → Supabase 동기화 시작 ===")
    print(f"실행 시각: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    print("\n[1] 온통청년 주거 정책 조회 중...")
    all_policies = fetch_all()
    print(f"  총 {len(all_policies)}개 주거 정책 조회 완료")

    print("\n[2] 수도권·전국 필터 + 만료 제외...")
    filtered = [p for p in all_policies if is_metro_or_national(p) and is_active(p)]
    excluded = len(all_policies) - len(filtered)
    print(f"  대상 {len(filtered)}개 (제외 {excluded}개)")

    print("\n[3] programs 스키마 변환 중...")
    records = [build_record(p) for p in filtered]
    print(f"  {len(records)}개 레코드 준비 완료")

    print("\n[4] Supabase upsert 중...")
    upserted = upsert_all(records)

    print(f"\n=== 완료: {upserted}개 upsert ===")


if __name__ == '__main__':
    main()
