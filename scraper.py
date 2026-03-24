#!/usr/bin/env python3
"""
멀티소스 주택공고 크롤러
사용법:
  python scraper.py             # 일반 실행 (각 소스 1페이지)
  python scraper.py --initial   # 초기 DB 구축 (2026-03-01 이후 전체)
"""

import re, json, time, hashlib, argparse, os
import urllib.request, urllib.parse
from datetime import datetime, date, timedelta

# ── 설정 ────────────────────────────────────────────────────────────────
INITIAL_SINCE       = date(2026, 3, 1)   # 초기 크롤링 기준일
FUTURE_LIMIT_DAYS   = 31                 # 이 일수 이내 예정 공고만 포함
DETAIL_SLEEP        = 0.4                # 상세페이지 요청 간격(초)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept":          "text/html,application/xhtml+xml,*/*",
    "Accept-Language": "ko-KR,ko;q=0.9",
}

# ── 공통 유틸 ────────────────────────────────────────────────────────────
def fetch(url, data=None, extra_headers=None, timeout=20):
    headers = {**HEADERS, **(extra_headers or {})}
    if data:
        data = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            for enc in ["utf-8", "euc-kr"]:
                try:
                    return raw.decode(enc)
                except Exception:
                    continue
            return raw.decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  [fetch 오류] {url[:70]}: {e}")
        return ""

def fetch_json(url, extra_headers=None, timeout=20):
    html = fetch(url, extra_headers=extra_headers, timeout=timeout)
    if not html:
        return None
    try:
        return json.loads(html)
    except Exception:
        return None

def parse_ymd(y, m, d):
    try:
        return date(int(y), int(m), int(d))
    except Exception:
        return None

DATE_PAT  = r"(\d{4})\s*[.\-/]\s*(\d{1,2})\s*[.\-/]\s*(\d{1,2})"
RANGE_PAT = DATE_PAT + r"[^0-9]{0,30}?" + r"~" + r"[^0-9]{0,15}?" + DATE_PAT

def extract_range(text):
    m = re.search(RANGE_PAT, text)
    if m:
        s = parse_ymd(m.group(1), m.group(2), m.group(3))
        e = parse_ymd(m.group(4), m.group(5), m.group(6))
        if s and e and e >= s:
            return s, e
    return None, None

def extract_dates_from_html(html):
    """상세페이지 HTML에서 신청/청약/모집기간 추출"""
    # 태그 제거
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&nbsp;|&amp;|&lt;|&gt;", " ", text)
    text = re.sub(r"\s+", " ", text)

    keywords = ["신청기간", "접수기간", "청약기간", "모집기간",
                "공급기간", "신청일정", "청약일정", "접수일"]
    for kw in keywords:
        pos = text.find(kw)
        if pos < 0:
            continue
        seg = text[pos:pos + 400]
        s, e = extract_range(seg)
        if s and e:
            return s, e

    # fallback: 앞부분 3000자에서 첫 범위
    s, e = extract_range(text[:3000])
    if s and e and e.year >= date.today().year:
        return s, e
    return None, None

def normalize_title(title):
    return re.sub(r"\s+", "", title)[:20]

def make_id(source_key, uid):
    h = hashlib.md5(str(uid).encode("utf-8")).hexdigest()[:8]
    return f"{source_key}_{h}"

def compute_status(apply_start, apply_end, today=None):
    today = today or date.today()
    if not (apply_start and apply_end):
        return "needs_review"
    if apply_end < today:
        return "expired"
    if apply_start <= today:
        return "진행중"
    return "예정"

def should_keep(ann, today=None):
    """공고 포함 여부 판단 (만료·너무 먼 미래 제외)"""
    today = today or date.today()
    s = ann.get("apply_start")
    e = ann.get("apply_end")
    status = ann.get("status")

    if status in ("manual_ok", "needs_review"):
        return True     # 수동/미확인은 항상 유지
    if e:
        ed = date.fromisoformat(e)
        if ed < today:
            return False
    if s:
        sd = date.fromisoformat(s)
        if sd > today + timedelta(days=FUTURE_LIMIT_DAYS):
            return False
    return True

# ── 공고 유형 감지 ───────────────────────────────────────────────────────
SH_TYPES = [
    ("미리내집",                  ["미리내집", "장기전세주택2", "장기전세2"]),
    ("장기전세주택 (시프트)",      ["장기전세주택", "시프트"]),
    ("희망하우징",                ["희망하우징"]),
    ("청년안심주택",               ["청년안심주택"]),
    ("장기안심주택",               ["장기안심주택"]),
    ("전세임대형 든든주택",        ["든든주택"]),
    ("신혼·신생아 매입임대 Ⅱ형",  ["신혼신생아 매입", "신혼·신생아 매입", "신혼 신생아 매입"]),
    ("신혼·신생아 전세임대 Ⅱ형",  ["신혼신생아 전세", "신혼·신생아 전세"]),
    ("청년 매입임대주택",          ["청년형 매입", "청년 매입임대", "청년형 특화"]),
    ("장기미임대",                 ["장기미임대"]),
    ("기존주택 전세임대",          ["기존주택 전세임대", "전세임대주택"]),
    ("국민임대주택",               ["국민임대", "국민공공임대"]),
    ("일반 매입임대주택",          ["매입임대주택", "일반 매입임대"]),
    # 분양
    ("SH 공공분양 (일반공급)",    ["일반공급", "일반 공급"]),
    ("SH 나눔형 공공분양 (일반공급)", ["나눔형"]),
]

LH_TYPES = [
    ("LH 통합공공임대",            ["통합공공임대"]),
    ("LH 국민임대",                ["국민임대"]),
    ("LH 영구임대",                ["영구임대"]),
    ("LH 행복주택 (신혼부부)",     ["행복주택"]),   # 아래에서 세분화
    ("LH 행복주택 (청년)",         []),
    ("LH 행복주택 (대학생)",       []),
    ("LH 청년 매입임대",           ["청년 매입", "청년형 매입"]),
    ("LH 신혼·신생아 매입임대 Ⅰ형", ["신혼신생아 매입", "신혼·신생아 매입"]),
    ("LH 신혼·신생아 매입임대 Ⅱ형", []),
    ("LH 기존주택 전세임대",       ["전세임대"]),
    ("LH 든든전세주택",            ["든든전세"]),
    ("LH 기숙사형 청년주택",       ["기숙사형"]),
    ("LH 청년신혼부부 매입임대리츠", ["리츠", "매입임대리츠"]),
    ("LH 자립준비청년",            ["자립준비"]),
    # 분양
    ("LH 공공분양 (신혼부부 특별공급)", ["신혼부부 특별", "신혼 특별"]),
    ("LH 공공분양 (생애최초 특별공급)", ["생애최초"]),
    ("LH 공공분양 (다자녀 특별공급)",   ["다자녀 특별"]),
    ("LH 공공분양 (일반공급)",         ["일반공급", "공공분양"]),
    ("LH 신혼희망타운",               ["신혼희망타운"]),
]

IH_TYPES = [
    ("iH 인천 행복주택 (청년)",    ["행복주택"]),
    ("iH 인천 행복주택 (신혼)",    []),
    ("iH 인천 국민임대",           ["국민임대"]),
]

RECRUIT_INCLUDE = ["모집공고", "입주자모집", "모집 공고", "공급공고",
                   "청약공고", "추가모집", "추가 모집", "예비입주자 모집",
                   "예비자 모집", "선착순"]
RECRUIT_EXCLUDE = ["당첨자", "예비자 발표", "예비자 계약", "재계약", "결과발표",
                   "채용", "입찰", "입주안내", "동호추첨", "서류심사대상자",
                   "청약접수결과", "심사결과", "취소", "철회", "계약결과",
                   "입주대상자 발표", "연장공고"]

def is_recruitment(title):
    if any(e in title for e in RECRUIT_EXCLUDE):
        return False
    return any(i in title for i in RECRUIT_INCLUDE)

def detect_types_sh(title):
    tl = title.replace(" ", "").lower()
    if "행복주택" in title:
        if "신혼" in title: return ["행복주택 (신혼부부)"]
        if "청년" in title: return ["행복주택 (청년)"]
        if "대학" in title: return ["행복주택 (대학생)"]
        return ["행복주택 (청년)", "행복주택 (신혼부부)", "행복주택 (대학생)"]
    if any(k in title for k in ["신혼신생아", "신혼·신생아", "신혼 신생아"]):
        if "매입" in title:
            if any(x in title for x in ["Ⅱ", "2형", "II"]):
                return ["신혼·신생아 매입임대 Ⅱ형"]
            if any(x in title for x in ["Ⅰ", "1형"]):
                return ["신혼·신생아 매입임대 Ⅰ형"]
            return ["신혼·신생아 매입임대 Ⅰ형", "신혼·신생아 매입임대 Ⅱ형"]
        if "전세" in title:
            if any(x in title for x in ["Ⅱ", "2형"]):
                return ["신혼·신생아 전세임대 Ⅱ형"]
            return ["신혼·신생아 전세임대 Ⅰ형"]
    matched = []
    for name, kws in SH_TYPES:
        if not kws: continue
        if any(kw.replace(" ", "") in tl for kw in kws):
            if name not in matched:
                matched.append(name)
    return matched or ["기타"]

def detect_types_lh(title, type_col=""):
    """LH는 목록에 유형 컬럼이 있어서 type_col 우선 활용"""
    tl = title.replace(" ", "").lower()
    tc = type_col.replace(" ", "").lower()

    if "행복주택" in title or "행복주택" in type_col:
        if "신혼" in title or "신생아" in title: return ["LH 행복주택 (신혼부부)"]
        if "대학" in title: return ["LH 행복주택 (대학생)"]
        if "청년" in title: return ["LH 행복주택 (청년)"]
        return ["LH 행복주택 (청년)", "LH 행복주택 (신혼부부)"]
    if "통합공공" in tc or "통합공공" in tl:
        return ["LH 통합공공임대"]
    if "국민임대" in tc or "국민임대" in tl:
        return ["LH 국민임대"]
    if "영구임대" in tc or "영구임대" in tl:
        return ["LH 영구임대"]
    if any(k in tl for k in ["신혼신생아매입", "신혼·신생아매입"]):
        if any(x in title for x in ["Ⅱ", "2형", "II"]): return ["LH 신혼·신생아 매입임대 Ⅱ형"]
        return ["LH 신혼·신생아 매입임대 Ⅰ형"]
    if "청년매입" in tl or "청년형매입" in tl:
        return ["LH 청년 매입임대"]
    if "전세임대" in tl and "든든" in tl:
        return ["LH 든든전세주택"]
    if "전세임대" in tl:
        return ["LH 기존주택 전세임대"]
    if "기숙사형" in tl:
        return ["LH 기숙사형 청년주택"]
    if "리츠" in tl:
        return ["LH 청년신혼부부 매입임대리츠"]
    if "자립준비" in tl:
        return ["LH 자립준비청년"]
    if "신혼희망타운" in tl:
        return ["LH 신혼희망타운"]
    if "분양" in tc or "공공분양" in tl:
        if "신혼" in tl: return ["LH 공공분양 (신혼부부 특별공급)"]
        if "생애최초" in tl: return ["LH 공공분양 (생애최초 특별공급)"]
        return ["LH 공공분양 (일반공급)"]
    return ["기타(LH)"]

def detect_types_ih(title):
    tl = title.replace(" ", "").lower()
    if "행복주택" in title:
        if "신혼" in title: return ["iH 인천 행복주택 (신혼)"]
        return ["iH 인천 행복주택 (청년)"]
    if "국민임대" in tl: return ["iH 인천 국민임대"]
    return ["기타(iH)"]

def detect_types_applyhome(title, house_type=""):
    """청약홈 공고 유형 감지 (APT분양 / 오피스텔 / 민간임대 등)"""
    tl = title.replace(" ", "").lower()
    ht = house_type.replace(" ", "").lower()
    if "오피스텔" in tl or "오피스텔" in ht:
        return ["오피스텔 청약"]
    if "생활숙박" in tl or "생활숙박" in ht:
        return ["생활숙박시설 청약"]
    if "민간임대" in tl or "민간임대" in ht or "공공지원" in ht:
        return ["민간임대 (공공지원)"]
    if "도시형" in tl or "도시형" in ht:
        return ["도시형생활주택 청약"]
    if "국민" in ht:
        return ["공공분양 (아파트)"]
    return ["민간분양 (아파트)"]


# ════════════════════════════════════════════════════════════════════════
# ① SH 공사 크롤러 (임대 / 분양 공통 구조)
# ════════════════════════════════════════════════════════════════════════
class SHCrawler:
    def __init__(self, inst_key, base, list_path, view_path, multi_itm_seq, param_name="multi_itm_seq"):
        self.inst_key     = inst_key        # 'sh_rental' or 'sh_sale'
        self.base         = base
        self.list_url     = base + list_path
        self.view_url     = base + view_path
        self.multi_itm    = multi_itm_seq
        self.param_name   = param_name

    def crawl(self, initial=False):
        today  = date.today()
        since  = INITIAL_SINCE if initial else today - timedelta(days=2)
        max_pages = 50 if initial else 1
        results = []
        candidates = []

        for page in range(1, max_pages + 1):
            print(f"  [SH {self.inst_key}] 목록 p{page}...")
            html = fetch(self.list_url,
                         data={self.param_name: self.multi_itm, "page": str(page)},
                         extra_headers={"Referer": self.base + "/main/index.do",
                                        "Content-Type": "application/x-www-form-urlencoded"})
            if not html:
                break

            rows = re.findall(
                r"onclick=\"javascript:getDetailView\('(\d+)'\)[^\"]*\">.*?</a>"
                r".*?<td[^>]*>\s*([^<]+)</td>"    # 담당부서
                r".*?<td[^>]*>\s*([\d-]+)\s*</td>", # 등록일
                html, re.DOTALL
            )
            if not rows:
                # 대안 패턴
                rows = re.findall(
                    r"getDetailView\('(\d+)'\)",
                    html)
                # seq만 추출된 경우 날짜 없이 처리
                for seq in rows:
                    candidates.append((seq, "", today.isoformat()))
                if not rows:
                    break
            else:
                stop = False
                for seq, dept, posted_str in rows:
                    posted_str = posted_str.strip()
                    try:
                        posted = date.fromisoformat(posted_str)
                    except Exception:
                        posted = today
                    if initial and posted < since:
                        stop = True
                        break
                    title_html = re.search(
                        rf"getDetailView\('{seq}'\)[^>]*>(.*?)</a>", html, re.DOTALL)
                    raw_title = title_html.group(1) if title_html else ""
                    title = re.sub(r"<[^>]+>|\s+", " ", raw_title).strip()
                    title = re.sub(r"^(NEW\s+|\d+일전\s+)+", "", title).strip()
                    candidates.append((seq, title, posted_str))
                if stop:
                    break
            time.sleep(0.3)

        print(f"  [SH {self.inst_key}] 상세 {len(candidates)}건 확인 중...")
        future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)

        for seq, title, posted_str in candidates:
            if title and not is_recruitment(title):
                continue

            try:
                html = fetch(self.view_url,
                             data={"seq": seq, self.param_name: self.multi_itm},
                             extra_headers={"Referer": self.list_url,
                                            "Content-Type": "application/x-www-form-urlencoded"})
                time.sleep(DETAIL_SLEEP)
            except Exception as e:
                print(f"    seq {seq} 오류: {e}")
                html = ""

            # 상세에서 제목 재추출 (목록 파싱 실패 시)
            if not title:
                tm = re.search(r"<title>(.*?)</title>", html, re.DOTALL)
                title = re.sub(r"\s+", " ", tm.group(1)).strip() if tm else f"seq={seq}"
                if not is_recruitment(title):
                    continue

            apply_start, apply_end = extract_dates_from_html(html) if html else (None, None)
            status = compute_status(apply_start, apply_end, today)

            if status == "expired":
                continue
            if apply_start and apply_start > future_limit:
                continue
            if status == "needs_review":
                # 게시일 30일 이내만 포함
                try:
                    posted = date.fromisoformat(posted_str)
                    if (today - posted).days > 30:
                        continue
                except Exception:
                    pass

            inst = "SH"
            types = detect_types_sh(title)
            url = f"{self.view_url}?seq={seq}&multi_itm_seq={self.multi_itm}"
            ann = {
                "id":          make_id(self.inst_key, seq),
                "inst":        inst,
                "source_key":  self.inst_key,
                "title":       title,
                "types":       types,
                "location":    "서울",
                "status":      status,
                "url":         url,
                "posted_date": posted_str,
                "crawled_at":  today.isoformat(),
            }
            if apply_start:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            else:
                ann["needs_pdf"] = True

            results.append(ann)
            flag = f"{apply_start}~{apply_end}" if apply_start else "날짜미파싱"
            print(f"    [{status}] {title[:45]} ({flag})")

        return results


# ════════════════════════════════════════════════════════════════════════
# ② LH청약플러스 크롤러
# ════════════════════════════════════════════════════════════════════════
LH_BASE     = "https://apply.lh.or.kr"
LH_LIST_URL = LH_BASE + "/lhapply/apply/wt/wrtanc/selectWrtancList.do"

LH_STATUS_MAP = {
    "접수중":    "진행중",
    "공고중":    "예정",
    "정정공고중": "진행중",
    "접수마감":  "expired",
}

def crawl_lh(mi, source_key, initial=False):
    """
    LH청약플러스 목록 페이지에서 현재 활성 공고 전체를 파싱.
    활성 공고는 단일 페이지에 모두 표시되므로 pagination 불필요.
    상세 페이지는 세션이 없으면 차단되어 목록 데이터만 활용.
    """
    today  = date.today()
    since  = INITIAL_SINCE if initial else today - timedelta(days=7)
    results = []

    print(f"  [LH {source_key}] 목록 로딩...")
    html = fetch(LH_LIST_URL + f"?mi={mi}")
    if not html:
        return results

    # <tbody> 내 <tr> 블록 분리
    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        print(f"  [LH {source_key}] tbody 없음")
        return results

    tbody = tbody_m.group(1)
    tr_blocks = re.split(r"<tr[^>]*>", tbody)[1:]  # 첫 빈 항목 제거

    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)

    for tr in tr_blocks:
        # data-id1 이 있는 행만 처리 (공고 행)
        pan_m = re.search(r'data-id1="(\w+)"', tr)
        if not pan_m:
            continue
        pan_id = pan_m.group(1)

        # 제목
        title_m = re.search(r'class="wrtancInfoBtn"[^>]*>.*?<span>(.*?)</span>', tr, re.DOTALL)
        if not title_m:
            continue
        title = re.sub(r"<[^>]+>|\s+", " ", title_m.group(1)).strip()
        # 목록 뱃지 텍스트 제거: "NEW", "N일전" 등
        title = re.sub(r"\s+(NEW|\d+일전)\s*$", "", title).strip()
        if not is_recruitment(title):
            continue

        # 유형 (cate col1)
        type_m = re.search(r'cate col1[^>]*>(.*?)</td>', tr, re.DOTALL)
        type_str = re.sub(r"\s+", " ", type_m.group(1)).strip() if type_m else ""

        # 지역 (cate col2)
        region_m = re.search(r'cate col2[^>]*>(.*?)</td>', tr, re.DOTALL)
        region = re.sub(r"<[^>]+>|\s+", " ", region_m.group(1)).strip() if region_m else "전국"

        # 날짜: <td>YYYY.MM.DD</td> 형식 2개 (게시일, 마감일)
        dates = re.findall(r"<td>(\d{4}\.\d{2}\.\d{2})</td>", tr)
        posted = None
        apply_end = None
        if len(dates) >= 2:
            pm = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", dates[0])
            em = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", dates[1])
            posted    = parse_ymd(pm.group(1), pm.group(2), pm.group(3)) if pm else today
            apply_end = parse_ymd(em.group(1), em.group(2), em.group(3)) if em else None
        elif len(dates) == 1:
            pm = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", dates[0])
            posted = parse_ymd(pm.group(1), pm.group(2), pm.group(3)) if pm else today

        # 상태
        status_m = re.search(r'class="[^"]*stt[^"]*">([^<]+)</td>', tr)
        status_raw = status_m.group(1).strip() if status_m else ""
        lh_status = LH_STATUS_MAP.get(status_raw, "needs_review")

        if lh_status == "expired":
            continue
        if apply_end and apply_end < today:
            continue
        if apply_end and apply_end > future_limit:
            continue
        if posted and initial and posted < since:
            continue

        types = detect_types_lh(title, type_str)
        list_url = LH_LIST_URL + f"?mi={mi}"

        ann = {
            "id":          make_id(source_key, pan_id),
            "inst":        "LH",
            "source_key":  source_key,
            "title":       title,
            "types":       types,
            "location":    region,
            "status":      lh_status,
            "url":         list_url,
            "posted_date": posted.isoformat() if posted else "",
            "crawled_at":  today.isoformat(),
        }
        if apply_end:
            ann["apply_end"]   = apply_end.isoformat()
            ann["apply_start"] = posted.isoformat() if posted else ""
        else:
            ann["needs_pdf"] = True

        results.append(ann)
        print(f"    [{lh_status}] {title[:45]} (~{apply_end})")

    return results


# ════════════════════════════════════════════════════════════════════════
# ③ iH (인천도시공사) 크롤러
# ════════════════════════════════════════════════════════════════════════
IH_SOURCES = {
    "ih_sale":   "https://www.ih.co.kr/main/sale_lease/board/house_notice.jsp",
    "ih_rental": "https://www.ih.co.kr/main/sale_lease/notice.jsp",
}
IH_BASE = "https://www.ih.co.kr"

def crawl_ih(source_key, initial=False):
    list_url = IH_SOURCES[source_key]
    today    = date.today()
    since    = INITIAL_SINCE if initial else today - timedelta(days=2)
    results  = []
    max_pages = 10 if initial else 1

    for page in range(1, max_pages + 1):
        print(f"  [iH {source_key}] 목록 p{page}...")
        url = list_url + (f"?page={page}" if page > 1 else "")
        html = fetch(url)
        if not html:
            break

        # iH 목록: <a href="detail?..."> 또는 bbsMsgDetail.do?msg_seq=XXX
        rows = re.findall(
            r"msg_seq=(\d+)[^\"]*\"[^>]*>(.*?)</a>"
            r".*?(\d{4}\.\d{2}\.\d{2})",
            html, re.DOTALL
        )
        if not rows:
            rows_alt = re.findall(
                r"href=\"([^\"]*detail[^\"]*)\">([^<]+)</a>"
                r".*?(\d{4}\.\d{1,2}\.\d{1,2})",
                html, re.DOTALL
            )
            if not rows_alt:
                break
            rows = [(r[0], r[1], r[2]) for r in rows_alt]

        stop = False
        for seq_or_href, title_raw, posted_raw in rows:
            title = re.sub(r"\s+", " ", title_raw).strip()
            if not title or not is_recruitment(title):
                continue

            pm = re.match(r"(\d{4})\.(\d{1,2})\.(\d{1,2})", posted_raw)
            posted = parse_ymd(pm.group(1), pm.group(2), pm.group(3)) if pm else today

            if initial and posted < since:
                stop = True
                break

            # 상세 페이지에서 날짜 추출
            if seq_or_href.isdigit():
                detail_url = f"{IH_BASE}/main/bbs/bbsMsgDetail.do?msg_seq={seq_or_href}"
            else:
                detail_url = seq_or_href if seq_or_href.startswith("http") else IH_BASE + seq_or_href

            detail_html = fetch(detail_url)
            time.sleep(DETAIL_SLEEP)
            apply_start, apply_end = extract_dates_from_html(detail_html) if detail_html else (None, None)
            status = compute_status(apply_start, apply_end, today)

            if status == "expired":
                continue
            if apply_start and apply_start > today + timedelta(days=FUTURE_LIMIT_DAYS):
                continue
            if status == "needs_review":
                if (today - posted).days > 30:
                    continue

            types = detect_types_ih(title)
            ann = {
                "id":          make_id(source_key, seq_or_href),
                "inst":        "iH",
                "source_key":  source_key,
                "title":       title,
                "types":       types,
                "location":    "인천",
                "status":      status,
                "url":         detail_url,
                "posted_date": posted.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if apply_start:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            else:
                ann["needs_pdf"] = True
            results.append(ann)
            flag = f"{apply_start}~{apply_end}" if apply_start else "날짜미파싱"
            print(f"    [{status}] {title[:45]} ({flag})")

        if stop:
            break
        time.sleep(0.3)

    return results


# ════════════════════════════════════════════════════════════════════════
# ④ ihwc.or.kr (인천주거복지센터 — LH + iH 공공임대 통합)
# ════════════════════════════════════════════════════════════════════════
IHWC_BASE = "https://www.ihwc.or.kr"
IHWC_LIST = IHWC_BASE + "/rent/recruit.jsp"

def crawl_ihwc(initial=False):
    today    = date.today()
    since    = INITIAL_SINCE if initial else today - timedelta(days=2)
    results  = []
    max_pages = 9 if initial else 1  # 총 9페이지

    for page in range(1, max_pages + 1):
        print(f"  [ihwc] 목록 p{page}...")
        url = IHWC_LIST + (f"?pgno={page}" if page > 1 else "")
        html = fetch(url)
        if not html:
            break

        # 실제 HTML 구조:
        # <a href="https://..."><p class="tag">
        #   <span class="tag_ih">IH도시공사</span>
        #   <span class="tag_ing"></span>
        # </p><dl><dt>공고명</dt></dl></a>
        entries = re.findall(
            r'href="(https?://[^"]+)"[^>]*>\s*'
            r'<p class="tag">\s*'
            r'<span class="(tag_lh|tag_ih)[^"]*">[^<]+</span>\s*'
            r'<span class="(tag_\w+)"></span>\s*'
            r'</p>\s*<dl>\s*<dt>(.*?)</dt>',
            html, re.DOTALL
        )

        if not entries:
            break

        IHWC_STATUS = {"tag_ing": "진행중", "tag_end": "expired"}

        for href, op_cls, st_cls, title_raw in entries:
            title = re.sub(r"\s+", " ", title_raw).strip()
            if not title or not is_recruitment(title):
                continue

            ihwc_status = IHWC_STATUS.get(st_cls, "needs_review")
            lh_status = ihwc_status
            if lh_status == "expired":
                continue

            inst = "iH" if "tag_ih" in op_cls else "LH"
            href_full = href if href.startswith("http") else IHWC_BASE + href
            detail_html = fetch(href_full)
            time.sleep(DETAIL_SLEEP)
            apply_start, apply_end = extract_dates_from_html(detail_html) if detail_html else (None, None)
            status = compute_status(apply_start, apply_end, today)

            if status == "expired":
                continue

            types = detect_types_lh(title) if inst == "LH" else detect_types_ih(title)
            ann = {
                "id":          make_id("ihwc", href),
                "inst":        inst,
                "source_key":  "ihwc",
                "title":       title,
                "types":       types,
                "location":    "인천",
                "status":      status,
                "url":         href_full,
                "posted_date": today.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if apply_start:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            else:
                ann["needs_pdf"] = True
            results.append(ann)
            flag = f"{apply_start}~{apply_end}" if apply_start else "날짜미파싱"
            print(f"    [{status}] {title[:45]} ({flag})")

    return results


# ════════════════════════════════════════════════════════════════════════
# ⑤ 청년안심주택 (soco.seoul.go.kr) — JSON API (POST)
# ════════════════════════════════════════════════════════════════════════
YOUTH_API   = "https://soco.seoul.go.kr/youth/pgm/home/yohome/bbsListJson.json"
YOUTH_BBS   = "BMSR00015"
YOUTH_BASE  = "https://soco.seoul.go.kr/youth/bbs/BMSR00015/view.do"
YOUTH_REF   = "https://soco.seoul.go.kr/youth/bbs/BMSR00015/list.do?menuNo=400008"

def crawl_youth_housing(initial=False):
    """
    청년안심주택(역세권청년주택) 공고 크롤링.
    API는 POST + bbsId 파라미터 필요.
    날짜 필드: optn1=신청시작일, optn4=신청마감일.
    """
    today   = date.today()
    since   = INITIAL_SINCE if initial else today - timedelta(days=7)
    results = []
    max_pages = 5 if initial else 1

    for page in range(1, max_pages + 1):
        print(f"  [청년안심주택] API p{page}...")
        raw = fetch(YOUTH_API,
                    data={"bbsId": YOUTH_BBS, "pageIndex": str(page),
                          "searchAdresGu": "", "searchCondition": "",
                          "searchKeyword": "", "optn2": "", "optn5": ""},
                    extra_headers={"X-Requested-With": "XMLHttpRequest",
                                   "Referer": YOUTH_REF})
        if not raw:
            break
        try:
            data = json.loads(raw)
        except Exception:
            break

        items = data.get("resultList", [])
        if not items:
            break

        stop = False
        for item in items:
            title    = (item.get("nttSj") or "").strip()
            board_id = item.get("boardId", "")

            if not title or not is_recruitment(title):
                continue

            # 날짜: optn1 = 시작일, optn4 = 마감일 (YYYY-MM-DD)
            apply_start_raw = item.get("optn1") or ""
            apply_end_raw   = item.get("optn4") or ""

            apply_start = None
            apply_end   = None
            for raw_d, setter in [(apply_start_raw, "s"), (apply_end_raw, "e")]:
                if raw_d:
                    m = re.match(r"(\d{4})[-.](\d{1,2})[-.](\d{1,2})", raw_d)
                    if m:
                        d = parse_ymd(m.group(1), m.group(2), m.group(3))
                        if setter == "s": apply_start = d
                        else:             apply_end   = d

            # 등록일: regDate는 ms 타임스탬프
            reg_ts = item.get("regDate")
            try:
                posted = date.fromtimestamp(reg_ts / 1000) if reg_ts else today
            except Exception:
                posted = today

            if initial and posted < since:
                stop = True
                break

            status = compute_status(apply_start, apply_end, today)
            if status == "expired":
                continue

            url = f"{YOUTH_BASE}?menuNo=400008&boardId={board_id}"
            ann = {
                "id":          make_id("youth", board_id),
                "inst":        "SH",
                "source_key":  "youth_housing",
                "title":       title,
                "types":       ["청년안심주택"],
                "location":    "서울",
                "status":      status,
                "url":         url,
                "posted_date": posted.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if apply_start and apply_end:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            else:
                ann["needs_pdf"] = True
            results.append(ann)
            flag = f"{apply_start}~{apply_end}" if apply_start else "날짜미파싱"
            print(f"    [{status}] {title[:45]} ({flag})")

        if stop:
            break

    return results


# ════════════════════════════════════════════════════════════════════════
# ⑥ 청약홈 아파트 청약일정 (applyhome.co.kr)
# ════════════════════════════════════════════════════════════════════════
APPLYHOME_BASE = "https://www.applyhome.co.kr"
METRO_REGIONS  = {"서울", "경기", "인천"}

def _is_metro_region(region_text):
    """수도권 지역 여부 (서울/경기/인천 포함)"""
    return any(r in region_text for r in METRO_REGIONS)

def _parse_applyhome_period(text):
    """'2026-04-03 ~ 2026-04-06' 또는 '2026.04.03 ~ 2026.04.06' 형식 파싱"""
    m = re.search(r"(\d{4})[-.](\d{2})[-.](\d{2})\s*~\s*(\d{4})[-.](\d{2})[-.](\d{2})", text)
    if m:
        s = parse_ymd(m.group(1), m.group(2), m.group(3))
        e = parse_ymd(m.group(4), m.group(5), m.group(6))
        return s, e
    return None, None

def crawl_applyhome_apt(initial=False):
    """청약홈 아파트 청약일정 — 수도권 필터"""
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    print("  [청약홈 APT] 목록 로딩...")

    for page in range(1, 20):
        html = fetch(
            APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do",
            data={"pageIndex": str(page), "orderbySecd": "", "orderbyMth": "01",
                  "rentSecd": "", "schTxt": ""},
            extra_headers={"Referer": APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do",
                           "Content-Type": "application/x-www-form-urlencoded"}
        )
        if not html:
            break

        tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
        if not tbody_m:
            break

        rows = re.split(r"<tr[^>]*>", tbody_m.group(1))[1:]
        if not rows:
            break

        found_any = False
        for tr in rows:
            tds = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.DOTALL)
            if len(tds) < 4:
                continue
            # 컬럼: 지역, 주택구분, 주택명(+링크), 청약기간, 당첨자발표, 분양/임대
            region    = re.sub(r"<[^>]+>|\s+", " ", tds[0]).strip()
            house_type = re.sub(r"<[^>]+>|\s+", " ", tds[1]).strip()
            name_raw  = re.sub(r"<[^>]+>|\s+", " ", tds[2]).strip()
            period_raw = re.sub(r"<[^>]+>|\s+", " ", tds[3]).strip() if len(tds) > 3 else ""

            if not name_raw or not _is_metro_region(region):
                continue

            apply_start, apply_end = _parse_applyhome_period(period_raw)
            status = compute_status(apply_start, apply_end, today)
            if status == "expired":
                continue
            if apply_end and apply_end > future_limit:
                continue

            # 링크 추출
            link_m = re.search(r'href="([^"]+)"', tds[2])
            url = (APPLYHOME_BASE + link_m.group(1)) if link_m else \
                  APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do"

            uid = name_raw + (apply_end.isoformat() if apply_end else "")
            ann = {
                "id":          make_id("applyhome_apt", uid),
                "inst":        "청약홈",
                "source_key":  "applyhome_apt",
                "title":       name_raw,
                "types":       detect_types_applyhome(name_raw, house_type),
                "location":    region,
                "status":      status,
                "url":         url,
                "posted_date": today.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if apply_start and apply_end:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            results.append(ann)
            found_any = True
            print(f"    [{status}] {name_raw[:40]} [{region}]")

        if not found_any and page > 1:
            break
        time.sleep(0.5)

    print(f"  [청약홈 APT] 수도권 {len(results)}건")
    return results


def crawl_applyhome_remndr(initial=False):
    """청약홈 아파트 잔여세대 청약일정"""
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    print("  [청약홈 잔여] 목록 로딩...")

    html = fetch(
        APPLYHOME_BASE + "/ai/aia/selectAPTRemndrLttotPblancListView.do",
        data={"pageIndex": "1", "orderbySecd": "", "orderbyMth": "01"},
        extra_headers={"Referer": APPLYHOME_BASE + "/ai/aia/selectAPTRemndrLttotPblancListView.do",
                       "Content-Type": "application/x-www-form-urlencoded"}
    )
    if not html:
        return results

    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        return results

    for tr in re.split(r"<tr[^>]*>", tbody_m.group(1))[1:]:
        tds = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.DOTALL)
        if len(tds) < 3:
            continue
        region    = re.sub(r"<[^>]+>|\s+", " ", tds[0]).strip()
        house_type = re.sub(r"<[^>]+>|\s+", " ", tds[1]).strip()
        name_raw  = re.sub(r"<[^>]+>|\s+", " ", tds[2]).strip()
        period_raw = re.sub(r"<[^>]+>|\s+", " ", tds[3]).strip() if len(tds) > 3 else ""

        if not name_raw or not _is_metro_region(region):
            continue

        apply_start, apply_end = _parse_applyhome_period(period_raw)
        status = compute_status(apply_start, apply_end, today)
        if status == "expired":
            continue

        link_m = re.search(r'href="([^"]+)"', tds[2])
        url = (APPLYHOME_BASE + link_m.group(1)) if link_m else \
              APPLYHOME_BASE + "/ai/aia/selectAPTRemndrLttotPblancListView.do"

        uid = name_raw + "remndr" + (apply_end.isoformat() if apply_end else "")
        ann = {
            "id":          make_id("applyhome_remndr", uid),
            "inst":        "청약홈",
            "source_key":  "applyhome_remndr",
            "title":       name_raw + " (잔여세대)",
            "types":       detect_types_applyhome(name_raw, house_type),
            "location":    region,
            "status":      status,
            "url":         url,
            "posted_date": today.isoformat(),
            "crawled_at":  today.isoformat(),
        }
        if apply_start and apply_end:
            ann["apply_start"] = apply_start.isoformat()
            ann["apply_end"]   = apply_end.isoformat()
        results.append(ann)

    print(f"  [청약홈 잔여] 수도권 {len(results)}건")
    return results


def crawl_applyhome_other(initial=False):
    """청약홈 오피스텔/생활숙박/도시형/민간임대 청약일정"""
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    print("  [청약홈 기타] 목록 로딩...")

    for page in range(1, 10):
        html = fetch(
            APPLYHOME_BASE + "/ai/aia/selectOtherLttotPblancListView.do",
            data={"pageIndex": str(page), "orderbySecd": "", "orderbyMth": "01",
                  "houseNm": "", "start_year": "", "end_year": ""},
            extra_headers={"Referer": APPLYHOME_BASE + "/ai/aia/selectOtherLttotPblancListView.do",
                           "Content-Type": "application/x-www-form-urlencoded"}
        )
        if not html:
            break

        tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
        if not tbody_m:
            break

        rows = re.split(r"<tr[^>]*>", tbody_m.group(1))[1:]
        if not rows:
            break

        found_any = False
        for tr in rows:
            tds = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.DOTALL)
            if len(tds) < 3:
                continue
            region    = re.sub(r"<[^>]+>|\s+", " ", tds[0]).strip()
            house_type = re.sub(r"<[^>]+>|\s+", " ", tds[1]).strip()
            name_raw  = re.sub(r"<[^>]+>|\s+", " ", tds[2]).strip()
            period_raw = re.sub(r"<[^>]+>|\s+", " ", tds[3]).strip() if len(tds) > 3 else ""

            if not name_raw or not _is_metro_region(region):
                continue

            apply_start, apply_end = _parse_applyhome_period(period_raw)
            status = compute_status(apply_start, apply_end, today)
            if status == "expired":
                continue
            if apply_end and apply_end > future_limit:
                continue

            link_m = re.search(r'href="([^"]+)"', tds[2])
            url = (APPLYHOME_BASE + link_m.group(1)) if link_m else \
                  APPLYHOME_BASE + "/ai/aia/selectOtherLttotPblancListView.do"

            uid = name_raw + (apply_end.isoformat() if apply_end else "")
            ann = {
                "id":          make_id("applyhome_other", uid),
                "inst":        "청약홈",
                "source_key":  "applyhome_other",
                "title":       name_raw,
                "types":       detect_types_applyhome(name_raw, house_type),
                "location":    region,
                "status":      status,
                "url":         url,
                "posted_date": today.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if apply_start and apply_end:
                ann["apply_start"] = apply_start.isoformat()
                ann["apply_end"]   = apply_end.isoformat()
            results.append(ann)
            found_any = True

        if not found_any and page > 1:
            break
        time.sleep(0.5)

    print(f"  [청약홈 기타] 수도권 {len(results)}건")
    return results


# ════════════════════════════════════════════════════════════════════════
# ⑦ 오케스트레이터
# ════════════════════════════════════════════════════════════════════════
def dedup(announcements):
    """
    1차: 같은 기관 내 중복 제거 (inst + norm_title + apply_end)
    2차: 기관 간 중복 제거 (norm_title + apply_end) — apply_end 있는 경우만
          우선순위: lh/sh/ih/youth > applyhome
    """
    PRIORITY = {
        # LH 최우선 (기관 간 동일 공고 시 LH 버전 유지)
        "lh_rental": 1, "lh_sale": 1,
        # SH / iH / 청년안심주택
        "sh_rental": 2, "sh_sale": 2, "sh_notice": 2,
        "ih_sale": 2, "ih_rental": 2, "ihwc": 2,
        "youth_housing": 2,
        # 청약홈은 집계 사이트이므로 기관 직접 공고보다 후순위
        "applyhome_apt": 3, "applyhome_remndr": 3, "applyhome_other": 3,
    }

    # 1차: 같은 기관 내 dedup
    seen = {}
    for ann in sorted(announcements, key=lambda a: PRIORITY.get(a["source_key"], 9)):
        key = (ann["inst"], normalize_title(ann["title"]), ann.get("apply_end", ""))
        if key not in seen:
            seen[key] = ann
    deduped = list(seen.values())

    # 2차: 기관 간 cross-dedup (apply_end 있는 경우만)
    cross_seen = {}
    result = []
    for ann in sorted(deduped, key=lambda a: PRIORITY.get(a["source_key"], 9)):
        end = ann.get("apply_end", "")
        if end:
            cross_key = (normalize_title(ann["title"]), end)
            if cross_key not in cross_seen:
                cross_seen[cross_key] = True
                result.append(ann)
        else:
            result.append(ann)
    return result

def load_manual_overrides(path="manual_overrides.json"):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def apply_overrides(announcements, overrides):
    ann_map = {a["id"]: a for a in announcements}
    # 오버라이드 적용 (_comment, _format 등 메타 키 제외)
    for ann_id, patch in overrides.items():
        if ann_id.startswith("_"):
            continue
        if not isinstance(patch, dict):
            continue
        if ann_id in ann_map:
            ann_map[ann_id].update(patch)
        else:
            # 수동 전용 공고 (크롤러에 없음 — GH 등)
            ann_map[ann_id] = patch
    result = list(ann_map.values())
    # 수동 공고 만료 여부는 manual_overrides에서 직접 관리
    return result


# ════════════════════════════════════════════════════════════════════════
# Supabase 저장
# ════════════════════════════════════════════════════════════════════════
def save_to_supabase(announcements):
    sb_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    sb_key = os.environ.get("SUPABASE_KEY", "")
    if not sb_url or not sb_key:
        print("  [Supabase] 환경변수 없음 — 건너뜀")
        return

    STATUS_MAP = {"needs_review": "확인필요", "진행중": "진행중",
                  "예정": "예정", "마감": "마감", "manual_ok": "manual_ok"}

    rows = []
    for a in announcements:
        rows.append({
            "institution": a.get("inst", ""),
            "seq":         a.get("seq") or a.get("id", ""),
            "title":       a.get("title", ""),
            "date":        a.get("date") or None,
            "types":       a.get("types") or [],
            "url":         a.get("url") or None,
            "status":      STATUS_MAP.get(a.get("status", ""), a.get("status", "")),
            "apply_start": a.get("apply_start") or None,
            "apply_end":   a.get("apply_end") or None,
            "raw_data":    {"source_key": a.get("source_key", "")},
        })

    # 배치 upsert (100개씩)
    endpoint = f"{sb_url}/rest/v1/announcements"
    headers = {
        "apikey":          sb_key,
        "Authorization":   f"Bearer {sb_key}",
        "Content-Type":    "application/json",
        "Prefer":          "resolution=merge-duplicates,return=minimal",
    }
    inserted = 0
    for i in range(0, len(rows), 100):
        batch = rows[i:i+100]
        body = json.dumps(batch).encode("utf-8")
        req = urllib.request.Request(endpoint, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                inserted += len(batch)
        except Exception as e:
            print(f"  [Supabase] 배치 오류 (i={i}): {e}")

    print(f"  [Supabase] {inserted}건 upsert 완료")


# ════════════════════════════════════════════════════════════════════════
# main
# ════════════════════════════════════════════════════════════════════════
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--initial", action="store_true",
                        help=f"초기 DB 구축 ({INITIAL_SINCE} 이후 전체 공고)")
    args = parser.parse_args()
    initial = args.initial
    today   = date.today()

    print(f"{'[초기 DB 구축]' if initial else '[일반 크롤링]'} 시작: {today}")
    print("=" * 60)

    all_announcements = []

    # ── SH ──────────────────────────────────────────────────────────────
    sh_base = "https://www.i-sh.co.kr"
    sh_rental = SHCrawler(
        inst_key="sh_rental", base=sh_base,
        list_path="/app/lay2/program/S48T561C563/www/brd/m_247/list.do",
        view_path="/app/lay2/program/S48T561C563/www/brd/m_247/view.do",
        multi_itm_seq="2"
    )
    sh_sale = SHCrawler(
        inst_key="sh_sale", base=sh_base,
        list_path="/main/lay2/program/S1T294C296/www/brd/m_244/list.do",
        view_path="/main/lay2/program/S1T294C296/www/brd/m_244/view.do",
        multi_itm_seq="1"
    )
    sh_notice = SHCrawler(
        inst_key="sh_notice", base=sh_base,
        list_path="/main/lay2/program/S1T294C295/www/brd/m_241/list.do",
        view_path="/main/lay2/program/S1T294C295/www/brd/m_241/view.do",
        multi_itm_seq="1,2,4,8,16,32,64,128,256,512",
        param_name="multi_itm_seqs"
    )
    all_announcements += sh_rental.crawl(initial)
    all_announcements += sh_sale.crawl(initial)
    all_announcements += sh_notice.crawl(initial)

    # ── LH ──────────────────────────────────────────────────────────────
    all_announcements += crawl_lh(mi="1026", source_key="lh_rental", initial=initial)
    all_announcements += crawl_lh(mi="1027", source_key="lh_sale",   initial=initial)

    # ── iH ──────────────────────────────────────────────────────────────
    all_announcements += crawl_ih("ih_sale",   initial)
    all_announcements += crawl_ih("ih_rental", initial)

    # ── ihwc ────────────────────────────────────────────────────────────
    all_announcements += crawl_ihwc(initial)

    # ── 청년안심주택 ────────────────────────────────────────────────────
    all_announcements += crawl_youth_housing(initial)

    # ── 청약홈 ──────────────────────────────────────────────────────────────
    all_announcements += crawl_applyhome_apt(initial)
    all_announcements += crawl_applyhome_remndr(initial)
    all_announcements += crawl_applyhome_other(initial)

    # ── GH는 manual_overrides.json 에서만 관리 ──────────────────────────

    # ── 중복 제거 ────────────────────────────────────────────────────────
    print("\n중복 제거 중...")
    all_announcements = dedup(all_announcements)

    # ── 만료 공고 제거 ────────────────────────────────────────────────────
    all_announcements = [a for a in all_announcements if should_keep(a, today)]

    # ── 수동 오버라이드 병합 ──────────────────────────────────────────────
    overrides = load_manual_overrides()
    if overrides:
        all_announcements = apply_overrides(all_announcements, overrides)

    # ── 저장 ─────────────────────────────────────────────────────────────
    needs_review = [a for a in all_announcements if a.get("status") == "needs_review"]
    output = {
        "updated":       today.isoformat(),
        "count":         len(all_announcements),
        "needs_review_count": len(needs_review),
        "announcements": all_announcements,
    }
    with open("announcements.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    # ── Supabase 저장 ────────────────────────────────────────────────
    save_to_supabase(all_announcements)

    print(f"\n완료: 총 {len(all_announcements)}건 저장")
    print(f"  ├ 진행중:  {sum(1 for a in all_announcements if a.get('status')=='진행중')}건")
    print(f"  ├ 예정:    {sum(1 for a in all_announcements if a.get('status')=='예정')}건")
    print(f"  └ 검토필요: {len(needs_review)}건")

if __name__ == "__main__":
    main()
