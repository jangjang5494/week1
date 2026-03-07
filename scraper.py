#!/usr/bin/env python3
"""SH공사 임대주택 공고 크롤러 - GitHub Actions에서 매일 실행"""

import re
import json
import urllib.request
import urllib.parse
from datetime import datetime, date, timedelta

BASE = "https://www.i-sh.co.kr"
LIST_URL = BASE + "/main/lay2/program/S1T294C296/www/brd/m_244/list.do"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": BASE + "/main/index.do",
    "Content-Type": "application/x-www-form-urlencoded",
}

# 공고 제목 → 유형 매핑 (순서 중요: 더 구체적인 것 먼저)
TYPE_KEYWORDS = [
    ("미리내집",          ["미리내집", "장기전세주택2", "장기전세2", "장기전세 2차"]),
    ("장기전세주택 (시프트)", ["장기전세주택", "장기전세 주택", "시프트"]),
    ("희망하우징",         ["희망하우징"]),
    ("청년안심주택",        ["청년안심주택"]),
    ("장기안심주택",        ["장기안심주택"]),
    ("행복주택 (신혼부부)",  ["행복주택"]),   # 행복주택은 공고에서 세분화 어려워 통합
    ("행복주택 (청년)",     []),              # 위에서 통합 처리
    ("행복주택 (대학생)",   []),
    ("신혼·신생아 매입임대 Ⅱ형", ["신혼신생아 매입", "신혼·신생아 매입", "신혼 신생아 매입"]),
    ("신혼·신생아 매입임대 Ⅰ형", []),
    ("신혼·신생아 전세임대 Ⅱ형", ["신혼신생아 전세", "신혼·신생아 전세", "신혼 신생아 전세"]),
    ("신혼·신생아 전세임대 Ⅰ형", []),
    ("청년 매입임대주택",   ["청년형 매입", "청년 매입임대", "청년형 특화형 매입", "청년형] 특화형 매입", "청년형] 특화"]),
    ("장기미임대",         ["장기미임대"]),
    ("전세임대형 든든주택",  ["든든주택"]),
    ("기존주택 전세임대",   ["기존주택 전세임대", "전세임대주택"]),
    ("국민임대주택",        ["국민임대", "국민공공임대"]),
    ("일반 매입임대주택",   ["매입임대주택", "일반 매입임대"]),
]

# 공고 제목에서 유형 추출
def detect_types(title):
    title_lower = title.replace(" ", "").lower()
    matched = []

    # 행복주택 세분화 시도
    if "행복주택" in title:
        if "신혼" in title:
            matched.append("행복주택 (신혼부부)")
        elif "청년" in title:
            matched.append("행복주택 (청년)")
        elif "대학" in title:
            matched.append("행복주택 (대학생)")
        else:
            matched += ["행복주택 (대학생)", "행복주택 (청년)", "행복주택 (신혼부부)"]
        return matched

    # 신혼·신생아 세분화
    if any(k in title for k in ["신혼신생아", "신혼·신생아", "신혼 신생아"]):
        if "매입" in title:
            if "Ⅱ" in title or "2형" in title or "II" in title:
                matched.append("신혼·신생아 매입임대 Ⅱ형")
            elif "Ⅰ" in title or "1형" in title or "I형" in title:
                matched.append("신혼·신생아 매입임대 Ⅰ형")
            else:
                matched += ["신혼·신생아 매입임대 Ⅰ형", "신혼·신생아 매입임대 Ⅱ형"]
        elif "전세" in title:
            if "Ⅱ" in title or "2형" in title:
                matched.append("신혼·신생아 전세임대 Ⅱ형")
            elif "Ⅰ" in title or "1형" in title:
                matched.append("신혼·신생아 전세임대 Ⅰ형")
            else:
                matched += ["신혼·신생아 전세임대 Ⅰ형", "신혼·신생아 전세임대 Ⅱ형"]
        return matched

    for type_name, keywords in TYPE_KEYWORDS:
        if not keywords:
            continue
        if any(kw.replace(" ", "") in title_lower for kw in keywords):
            if type_name not in matched:
                matched.append(type_name)

    return matched if matched else ["기타"]

# 공고가 모집공고인지 판단 (당첨자발표, 재계약 등 제외)
def is_recruitment(title):
    exclude = ["당첨자", "예비자", "예비입주", "재계약", "결과발표", "계약결과",
               "채용", "입찰", "입주안내", "입주대상자", "동호추첨",
               "서류심사대상자 발표", "청약접수결과", "심사결과", "분양원가",
               "연장공고", "취소", "철회", "위임장", "변경 안내"]
    include = ["모집공고", "입주자모집", "모집 공고", "공급공고", "청약공고", "추가모집", "추가 모집"]
    title_has_exclude = any(e in title for e in exclude)
    title_has_include = any(i in title for i in include)
    return title_has_include and not title_has_exclude

import time

DETAIL_URL = BASE + "/main/lay2/program/S1T294C296/www/brd/m_244/view.do"

def fetch(url, data=None):
    if data:
        data = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=data, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as r:
        raw = r.read()
        try:
            return raw.decode("utf-8")
        except:
            return raw.decode("euc-kr", errors="replace")

def parse_date(y, m, d):
    try:
        return date(int(y), int(m), int(d))
    except:
        return None

def extract_apply_dates(html):
    """상세 페이지에서 신청 시작일·마감일 추출"""
    idx = html.find('class="cont"')
    if idx < 0:
        return None, None
    content = html[idx:idx+8000]
    content = re.sub(r"<[^>]+>", " ", content)
    content = re.sub(r"&nbsp;", " ", content)
    content = re.sub(r"&[a-z]+;", "", content)
    content = re.sub(r"\s+", " ", content)

    # SH공사 날짜 형식 다양:
    #   2026.03.18  /  2026. 3.18  /  2026. 3. 18.  /  2026-03-18
    # 공백 허용 패턴
    DATE_PAT = r"(\d{4})\s*[.\-]\s*(\d{1,2})\s*[.\-]\s*(\d{1,2})"
    RANGE_PAT = DATE_PAT + r"[^0-9]{0,30}?~[^0-9]{0,15}?" + DATE_PAT

    keywords = ["신청기간", "접수기간", "접수일", "신청일", "모집기간", "청약기간", "공고기간", "청약 기간", "신청 기간"]
    for kw in keywords:
        pos = content.find(kw)
        if pos < 0:
            continue
        segment = content[pos:pos+400]
        m = re.search(RANGE_PAT, segment)
        if m:
            start = parse_date(m.group(1), m.group(2), m.group(3))
            end   = parse_date(m.group(4), m.group(5), m.group(6))
            if start and end and end >= start:
                return start, end
        # 범위가 아닌 경우: 키워드 뒤 첫 날짜만 있으면 start만 추출 (fallback)
        sm = re.search(DATE_PAT, segment)
        if sm:
            start = parse_date(sm.group(1), sm.group(2), sm.group(3))
            if start:
                return start, start + timedelta(days=14)  # 14일 예상 마감

    # 키워드 없이 전체에서 첫 날짜 범위 추출 (fallback)
    m = re.search(RANGE_PAT, content)
    if m:
        start = parse_date(m.group(1), m.group(2), m.group(3))
        end   = parse_date(m.group(4), m.group(5), m.group(6))
        if start and end and end >= start and end.year >= date.today().year:
            return start, end

    return None, None

def scrape_list(pages=5):
    candidates = []
    for page in range(1, pages + 1):
        print(f"목록 페이지 {page} 수집 중...")
        html = fetch(LIST_URL, {"multi_itm_seq": "2", "page": str(page)})
        rows = re.findall(
            r'onclick="javascript:getDetailView\(\'(\d+)\'\)[^"]*">(.*?)</a>.*?<td class="num">\s*([\d-]+)\s*</td>',
            html, re.DOTALL
        )
        if not rows:
            break
        for seq, title_raw, posted_date in rows:
            title = re.sub(r"<[^>]+>|\s+", " ", title_raw).strip()
            if not title or not is_recruitment(title):
                continue
            candidates.append((seq, title, posted_date.strip()))

    today = date.today()
    future_limit = today + timedelta(days=31)
    results = []

    print(f"\n상세 페이지 파싱 중 ({len(candidates)}건)...")
    for seq, title, posted_date in candidates:
        try:
            html = fetch(DETAIL_URL, {"seq": seq, "multi_itm_seq": "2"})
            apply_start, apply_end = extract_apply_dates(html)
            time.sleep(0.4)  # 서버 부하 방지
        except Exception as e:
            print(f"  seq {seq} 오류: {e}")
            apply_start, apply_end = None, None

        # 날짜 파싱 성공한 경우: 마감일 >= 오늘 AND 시작일 <= 오늘+31일
        if apply_start and apply_end:
            if apply_end >= today and apply_start <= future_limit:
                status = "진행중" if apply_start <= today <= apply_end else "예정"
            else:
                print(f"  [{posted_date}] 마감/미래초과 제외: {title[:40]} ({apply_start}~{apply_end})")
                continue
        else:
            # 날짜 파싱 실패: 게시일 기준 30일 이내만 포함 (보수적 처리)
            posted = date.fromisoformat(posted_date) if posted_date else today
            if (today - posted).days > 30:
                print(f"  [{posted_date}] 게시 30일 초과 제외(날짜미파싱): {title[:40]}")
                continue
            apply_start, apply_end = None, None
            status = "확인필요"

        types = detect_types(title)
        url = f"{BASE}/main/lay2/program/S1T294C296/www/brd/m_244/view.do?seq={seq}&multi_itm_seq=2"
        item = {
            "seq": seq,
            "title": title,
            "date": posted_date,
            "types": types,
            "url": url,
            "status": status,
        }
        if apply_start:
            item["apply_start"] = apply_start.isoformat()
            item["apply_end"]   = apply_end.isoformat()

        results.append(item)
        flag = f"{apply_start}~{apply_end}" if apply_start else "날짜미파싱"
        print(f"  [{status}] {title[:45]} ({flag})")

    return results

def main():
    print("SH공사 공고 크롤링 시작...")
    announcements = scrape_list(pages=5)

    today = date.today().isoformat()
    output = {
        "updated": today,
        "count": len(announcements),
        "announcements": announcements
    }

    with open("announcements.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n완료: {len(announcements)}건 저장 → announcements.json")

if __name__ == "__main__":
    main()
