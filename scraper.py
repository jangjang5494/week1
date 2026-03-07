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

def scrape_list(pages=5):
    results = []
    for page in range(1, pages + 1):
        print(f"Fetching page {page}...")
        html = fetch(LIST_URL, {"multi_itm_seq": "2", "page": str(page)})
        rows = re.findall(
            r'onclick="javascript:getDetailView\(\'(\d+)\'\)[^"]*">(.*?)</a>.*?<td class="num">\s*([\d-]+)\s*</td>',
            html, re.DOTALL
        )
        if not rows:
            break
        for seq, title_raw, posted_date in rows:
            title = re.sub(r"<[^>]+>|\s+", " ", title_raw).strip()
            if not title:
                continue
            if not is_recruitment(title):
                continue
            types = detect_types(title)
            url = f"{BASE}/main/lay2/program/S1T294C296/www/brd/m_244/view.do?seq={seq}&multi_itm_seq=2"
            results.append({
                "seq": seq,
                "title": title,
                "date": posted_date.strip(),
                "types": types,
                "url": url,
            })
        # Stop if nothing found this page
        if not rows:
            break
    return results

def main():
    print("SH공사 공고 크롤링 시작...")
    announcements = scrape_list(pages=5)
    print(f"모집공고 {len(announcements)}건 수집")

    today = date.today().isoformat()
    cutoff = (date.today() - timedelta(days=60)).isoformat()

    # 60일 이내 공고만 유지
    recent = [a for a in announcements if a["date"] >= cutoff]
    print(f"최근 60일 이내: {len(recent)}건")

    output = {
        "updated": today,
        "count": len(recent),
        "announcements": recent
    }

    with open("announcements.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("announcements.json 저장 완료")
    for a in recent:
        print(f"  [{a['date']}] {a['title'][:50]} → {a['types']}")

if __name__ == "__main__":
    main()
