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
DATE_PAT_KO = r"(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일"
RANGE_PAT = DATE_PAT + r"[^0-9]{0,30}?" + r"~" + r"[^0-9]{0,15}?" + DATE_PAT
RANGE_PAT_KO = DATE_PAT_KO + r"[^0-9]{0,40}?" + r"~" + r"[^0-9]{0,20}?" + DATE_PAT_KO

def extract_range(text):
    # 숫자 구분자 방식 (YYYY.MM.DD ~ YYYY.MM.DD)
    m = re.search(RANGE_PAT, text)
    if m:
        s = parse_ymd(m.group(1), m.group(2), m.group(3))
        e = parse_ymd(m.group(4), m.group(5), m.group(6))
        if s and e and e >= s:
            return s, e
    # 한글 방식 (2026년 4월 3일 ~ 2026년 4월 10일)
    m = re.search(RANGE_PAT_KO, text)
    if m:
        s = parse_ymd(m.group(1), m.group(2), m.group(3))
        e = parse_ymd(m.group(4), m.group(5), m.group(6))
        if s and e and e >= s:
            return s, e
    # 한글 방식 — 연도 없이 월일만 쓰는 범위 (4월 3일 ~ 4월 10일), 올해 기준
    PAT_KO_SHORT = r"(\d{1,2})\s*월\s*(\d{1,2})\s*일[^0-9~]{0,20}?~[^0-9]{0,10}?(\d{1,2})\s*월\s*(\d{1,2})\s*일"
    m = re.search(PAT_KO_SHORT, text)
    if m:
        yr = date.today().year
        s = parse_ymd(yr, m.group(1), m.group(2))
        e = parse_ymd(yr, m.group(3), m.group(4))
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

_SEOUL_GUS = [
    '종로구','중구','용산구','성동구','광진구','동대문구','중랑구','성북구',
    '강북구','도봉구','노원구','은평구','서대문구','마포구','양천구','강서구',
    '구로구','금천구','영등포구','동작구','관악구','서초구','강남구','송파구','강동구'
]

def extract_gu_from_text(text):
    """제목·주소 등 텍스트에서 서울 구 이름 추출. 없으면 None."""
    if not text:
        return None
    for gu in _SEOUL_GUS:
        if gu in text:
            return gu
    return None

def make_id(inst, title, apply_end=None):
    """inst + title + apply_end 기반 안정적 해시 — 크롤러 source_key 무관하게 동일 공고는 동일 ID."""
    raw = f"{inst}|{title}|{apply_end or ''}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:12]

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
    ("미리내집 (장기전세2)",         ["미리내집", "장기전세주택2", "장기전세2"]),
    ("장기전세주택 (시프트)",        ["장기전세주택", "시프트"]),
    ("희망하우징",                   ["희망하우징"]),
    ("SH 청년안심주택 공공임대",     ["청년안심주택 공공임대", "[공공임대]"]),
    ("SH 청년안심주택 민간임대",     ["청년안심주택 민간임대", "[민간임대]"]),
    ("전세임대형 든든주택",          ["든든주택"]),
    ("신혼·신생아 매입임대 Ⅱ형",   ["신혼신생아 매입", "신혼·신생아 매입", "신혼 신생아 매입"]),
    ("신혼·신생아 전세임대 Ⅱ형",   ["신혼신생아 전세", "신혼·신생아 전세"]),
    ("청년 매입임대주택",            ["청년형 매입", "청년 매입임대", "청년형 특화"]),
    ("장기미임대",                   ["장기미임대"]),
    ("기존주택 전세임대",            ["기존주택 전세임대", "전세임대주택"]),
    ("국민임대주택",                 ["국민임대", "국민공공임대"]),
    ("일반 매입임대주택",            ["매입임대주택", "일반 매입임대"]),
    ("SH 공공·주거환경임대주택",     ["공공·주거환경", "주거환경임대", "공공주거환경"]),
    ("SH 재개발임대주택 (일반공급)", ["재개발임대"]),
    ("SH 도시형생활주택",            ["도시형생활주택"]),
    # 분양
    ("SH 공공분양",              ["일반공급", "일반 공급"]),
    ("SH 나눔형 공공분양",       ["나눔형"]),
    ("SH 토지임대부 분양주택",   ["토지임대부"]),
    ("SH 사회주택",              ["토지지원사회주택", "토지임대부사회주택", "리모델링형사회주택", "리모델링형 사회주택", "사회주택"]),
]

LH_TYPES = [
    ("LH 5·10·50년 공공임대",      ["5년공공임대", "10년공공임대", "50년공공임대", "분양전환공공임대"]),
    ("LH 통합공공임대",            ["통합공공임대"]),
    ("LH 국민임대",                ["국민임대"]),
    ("LH 영구임대",                ["영구임대"]),
    ("LH 행복주택",                 ["행복주택"]),
    ("LH 청년 매입임대",           ["청년 매입", "청년형 매입"]),
    ("LH 신혼·신생아 매입임대 Ⅰ형", ["신혼신생아 매입", "신혼·신생아 매입"]),
    ("LH 신혼·신생아 매입임대 Ⅱ형", []),
    ("LH 기존주택 전세임대",       ["전세임대"]),
    ("LH 든든전세주택",            ["든든전세"]),
    ("LH 기숙사형 매입임대",        ["기숙사형"]),
    # 분양
    ("LH 공공분양",    ["신혼부부 특별", "신혼 특별", "생애최초", "다자녀 특별", "일반공급", "공공분양"]),
    ("LH 신혼희망타운", ["신혼희망타운"]),
]


RECRUIT_INCLUDE = ["모집공고", "입주자모집", "모집 공고", "공급공고",
                   "청약공고", "추가모집", "추가 모집", "예비입주자 모집",
                   "예비자 모집", "선착순"]
RECRUIT_EXCLUDE = ["당첨자", "예비자 발표", "예비자 계약", "재계약", "결과발표",
                   "채용", "입찰", "입주안내", "동호추첨", "서류심사대상자",
                   "청약접수결과", "심사결과", "취소", "철회", "계약결과",
                   "입주대상자 발표", "연장공고",
                   "모집결과", "모집 결과",           # 예비자 모집결과 발표·계약 안내
                   "상가",                            # 단지 내 상가 입점자 모집
                   "업무시설",                        # 오피스·업무시설 임대
                   "운영자 모집",                     # 특화시설 운영자 모집
                   ]

def is_recruitment(title):
    if any(e in title for e in RECRUIT_EXCLUDE):
        return False
    return any(i in title for i in RECRUIT_INCLUDE)

def detect_types_sh(title):
    tl = title.replace(" ", "").lower()
    if "행복주택" in title:
        return ["SH 행복주택"]
    if "청년안심주택" in title:
        if "민간임대" in title or "[민간]" in title:
            return ["SH 청년안심주택 민간임대"]
        return ["SH 청년안심주택 공공임대"]
    if "재개발임대" in tl:
        return ["SH 재개발임대주택 (일반공급)"]
    if "주거환경임대" in tl or "공공주거환경" in tl or "공공·주거환경" in title:
        return ["SH 공공·주거환경임대주택"]
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
        return ["LH 행복주택"]
    if any(k in tl for k in ["5년공공임대", "10년공공임대", "50년공공임대", "분양전환공공임대"]):
        return ["LH 5·10·50년 공공임대"]
    if "통합공공" in tc or "통합공공" in tl:
        return ["LH 통합공공임대"]
    if "국민임대" in tc or "국민임대" in tl:
        return ["LH 국민임대"]
    if "영구임대" in tc or "영구임대" in tl:
        return ["LH 영구임대"]
    if any(k in tl for k in ["신혼신생아매입", "신혼·신생아매입"]):
        if any(x in title for x in ["Ⅱ", "2형", "II"]): return ["LH 신혼·신생아 매입임대 Ⅱ형"]
        return ["LH 신혼·신생아 매입임대 Ⅰ형"]
    if any(k in tl for k in ["신혼신생아전세", "신혼·신생아전세"]):
        if any(x in title for x in ["Ⅱ", "2형", "II"]): return ["LH 신혼·신생아 전세임대 Ⅱ형"]
        return ["LH 신혼·신생아 전세임대 Ⅰ형"]
    if "다자녀" in tl and "매입" in tl:
        return ["LH 다자녀 매입임대"]
    if "다자녀" in tl and "전세" in tl:
        return ["LH 다자녀 전세임대"]
    if "청년매입" in tl or "청년형매입" in tl:
        return ["LH 청년 매입임대"]
    if "청년전세" in tl:
        return ["LH 청년전세임대"]
    if "일반매입" in tl:
        return ["LH 일반 매입임대"]
    if "집주인" in tl:
        return ["LH 집주인 임대주택"]
    if "전세임대" in tl and "든든" in tl:
        return ["LH 든든전세주택"]
    if "장기전세" in tl:
        return ["LH 장기전세주택"]
    if "전세임대" in tl:
        return ["LH 기존주택 전세임대"]
    if "기숙사형" in tl:
        return ["LH 기숙사형 매입임대"]
    if "신혼희망타운" in tl:
        return ["LH 신혼희망타운"]
    if "분양" in tc or "공공분양" in tl:
        return ["LH 공공분양"]
    return ["기타(LH)"]


def detect_types_applyhome(title, house_type=""):
    """청약홈 공고 유형 감지 (APT분양 / 오피스텔 / 민간임대 등)"""
    tl = title.replace(" ", "").lower()
    ht = house_type.replace(" ", "").lower()
    if "오피스텔" in tl or "오피스텔" in ht:
        return ["오피스텔 청약"]
    if "생활숙박" in tl or "생활숙박" in ht:
        return ["생활숙박시설 청약"]
    if "공공지원" in ht or "공공지원" in tl:
        return ["공공지원민간임대 청약"]
    if "민간임대" in tl or "민간임대" in ht:
        return ["민간임대 청약"]
    if "도시형" in tl or "도시형" in ht:
        return ["도시형생활주택 청약"]
    if "국민" in ht:
        return ["공공분양 (아파트)"]
    return ["민간분양 (아파트) — 특별공급", "민간분양 (아파트) — 1순위", "민간분양 (아파트) — 2순위"]


# ════════════════════════════════════════════════════════════════════════
# ① SH 공사 크롤러 (임대 / 분양 공통 구조)
# ════════════════════════════════════════════════════════════════════════
class SHCrawler:
    def __init__(self, inst_key, base, list_path, view_path, multi_itm_seq,
                 param_name="multi_itm_seq", normal_max_pages=1, normal_since_days=2):
        self.inst_key          = inst_key
        self.base              = base
        self.list_url          = base + list_path
        self.view_url          = base + view_path
        self.multi_itm         = multi_itm_seq
        self.param_name        = param_name
        self.normal_max_pages  = normal_max_pages   # 일반 크롤링 시 최대 페이지 수
        self.normal_since_days = normal_since_days  # 일반 크롤링 시 며칠 전까지 볼지

    def crawl(self, initial=False):
        today  = date.today()
        since  = INITIAL_SINCE if initial else today - timedelta(days=self.normal_since_days)
        max_pages = 50 if initial else self.normal_max_pages
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
                    if posted < since:
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
            district = extract_gu_from_text(title)
            ann = {
                "id":          make_id("SH", title, apply_end.isoformat() if apply_end else None),
                "inst":        inst,
                "source_key":  self.inst_key,
                "title":       title,
                "types":       types,
                "location":    "서울특별시" + (" " + district if district else ""),
                "district":    district,
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
LH_BASE       = "https://apply.lh.or.kr"
LH_LIST_URL   = LH_BASE + "/lhapply/apply/wt/wrtanc/selectWrtancList.do"
LH_DETAIL_URL = LH_BASE + "/lhapply/apply/wt/wrtanc/selectWrtancInfo.do"

LH_STATUS_MAP = {
    "접수중":    "진행중",
    "공고중":    "예정",
    "정정공고중": "진행중",
    "접수마감":  "expired",
}

def crawl_lh(mi, source_key, initial=False):
    """
    LH청약플러스 서울 지역(cnpCd=11) 공고 크롤링.
    상세 페이지에서 실제 청약 접수 기간(sbscAcpStDt/sbscAcpClsgDt) 및 구 정보 파싱.
    """
    today    = date.today()
    results  = []
    list_url = LH_LIST_URL + f"?mi={mi}&cnpCd=11"

    print(f"  [LH {source_key}] 서울 목록 로딩...")
    html = fetch(list_url)
    if not html:
        return results

    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        print(f"  [LH {source_key}] tbody 없음")
        return results

    tbody = tbody_m.group(1)
    tr_blocks = re.split(r"<tr[^>]*>", tbody)[1:]

    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)

    for tr in tr_blocks:
        # data-id1~4 파싱 (상세 페이지 POST 파라미터)
        pan_m = re.search(r'data-id1="(\w+)"\s+data-id2="(\w+)"\s+data-id3="(\w+)"\s+data-id4="(\w+)"', tr)
        if not pan_m:
            continue
        pan_id, ccr_cd, upp_cd, ais_cd = pan_m.group(1), pan_m.group(2), pan_m.group(3), pan_m.group(4)

        # 제목
        title_m = re.search(r'class="wrtancInfoBtn"[^>]*>.*?<span>(.*?)</span>', tr, re.DOTALL)
        if not title_m:
            continue
        title = re.sub(r"<[^>]+>|\s+", " ", title_m.group(1)).strip()
        title = re.sub(r"\s+(NEW|\d+일전)\s*$", "", title).strip()
        if not is_recruitment(title):
            continue

        # 유형 컬럼 (cate col1)
        type_m = re.search(r'cate col1[^>]*>(.*?)</td>', tr, re.DOTALL)
        type_str = re.sub(r"\s+", " ", type_m.group(1)).strip() if type_m else ""

        # 공고일 (목록 첫 번째 날짜)
        dates = re.findall(r"<td>(\d{4}\.\d{2}\.\d{2})</td>", tr)
        posted = None
        if dates:
            pm = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", dates[0])
            posted = parse_ymd(pm.group(1), pm.group(2), pm.group(3)) if pm else today

        # 상태
        status_m = re.search(r'class="[^"]*stt[^"]*">([^<]+)</td>', tr)
        status_raw = status_m.group(1).strip() if status_m else ""
        lh_status = LH_STATUS_MAP.get(status_raw, "needs_review")

        if lh_status == "expired":
            continue

        # 상세 페이지 fetch → 실제 청약 접수 기간 + 구 파싱
        apply_start = None
        apply_end   = None
        district    = None

        time.sleep(DETAIL_SLEEP)
        detail_html = fetch(
            LH_DETAIL_URL,
            data={"panId": pan_id, "ccrCnntSysDsCd": ccr_cd,
                  "uppAisTpCd": upp_cd, "aisTpCd": ais_cd, "mi": mi},
            extra_headers={"Referer": list_url}
        )
        if detail_html:
            st_m = re.search(r"var sbscAcpStDt\s*=\s*'(\d{4}\.\d{2}\.\d{2})'", detail_html)
            cl_m = re.search(r"var sbscAcpClsgDt\s*=\s*'(\d{4}\.\d{2}\.\d{2})'", detail_html)
            if st_m:
                p = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", st_m.group(1))
                apply_start = parse_ymd(p.group(1), p.group(2), p.group(3)) if p else None
            if cl_m:
                p = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", cl_m.group(1))
                apply_end = parse_ymd(p.group(1), p.group(2), p.group(3)) if p else None
            # 구 파싱: sbdLgoNm JSON 필드에서 "서울XX구" 추출
            gu_m = re.search(r'"sbdLgoNm"\s*:\s*"[^"]*서울([^"]+구)', detail_html)
            if gu_m:
                district = gu_m.group(1).strip()
        # 파싱 실패 시 제목에서 fallback
        if not district:
            district = extract_gu_from_text(title)

        # apply_end 없으면 목록 두 번째 날짜로 fallback
        if not apply_end and len(dates) >= 2:
            em = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", dates[1])
            apply_end = parse_ymd(em.group(1), em.group(2), em.group(3)) if em else None

        if apply_end and apply_end < today:
            continue
        if apply_end and apply_end > future_limit:
            continue

        types    = detect_types_lh(title, type_str)
        location = "서울특별시" + (" " + district if district else "")

        ann = {
            "id":          make_id("LH", title, apply_end.isoformat() if apply_end else None),
            "inst":        "LH",
            "source_key":  source_key,
            "title":       title,
            "types":       types,
            "location":    location,
            "status":      lh_status,
            "url":         list_url,
            "posted_date": posted.isoformat() if posted else "",
            "crawled_at":  today.isoformat(),
        }
        if apply_end:
            ann["apply_end"]   = apply_end.isoformat()
            ann["apply_start"] = apply_start.isoformat() if apply_start else (posted.isoformat() if posted else "")
        else:
            ann["needs_pdf"] = True

        results.append(ann)
        print(f"    [{lh_status}] {title[:45]} (~{apply_end})")

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
    since   = INITIAL_SINCE if initial else today - timedelta(days=1)
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

            if posted < since:
                stop = True
                break

            status = compute_status(apply_start, apply_end, today)
            if status == "expired":
                continue

            url = f"{YOUTH_BASE}?menuNo=400008&boardId={board_id}"

            # 제목에서 공공임대/민간임대 구분
            if "민간임대" in title or "[민간]" in title:
                youth_type = "SH 청년안심주택 민간임대"
            else:
                youth_type = "SH 청년안심주택 공공임대"  # 공공임대 or 기본값

            # 민간임대만 상세 페이지에서 구 파싱 (공공임대는 상세에서 자치구 미표시)
            district = None
            if youth_type == "SH 청년안심주택 민간임대":
                detail_html = fetch(url, extra_headers={"Referer": YOUTH_REF})
                if detail_html:
                    m = re.search(r'주택위치\s*[:\：]\s*서울특별시\s*(\S+구)', detail_html)
                    if not m:
                        m = re.search(r'<option[^>]+selected[^>]*>([^<]+구)</option>', detail_html)
                    if m:
                        district = m.group(1).strip()

            ann = {
                "id":          make_id("SH", title, apply_end.isoformat() if apply_end else None),
                "inst":        "SH",
                "source_key":  "youth_housing",
                "title":       title,
                "types":       [youth_type],
                "location":    "서울",
                "status":      status,
                "url":         url,
                "posted_date": posted.isoformat(),
                "crawled_at":  today.isoformat(),
            }
            if district:
                ann["district"] = district
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
_NON_METRO = {
    # 경기도 (서울 집중 서비스)
    "경기",
    # 광역시·도 (약칭 + 행정명)
    "부산", "대구", "광주", "대전", "울산", "세종",
    "강원", "강원특별자치도",
    "충북", "충청북도",
    "충남", "충청남도",
    "전북", "전라북도", "전북특별자치도",
    "전남", "전라남도",
    "경북", "경상북도",
    "경남", "경상남도",
    "제주", "제주특별자치도",
    # 비수도권 주요 시·군 (LH 제목에 자주 등장)
    "논산", "서천", "보령", "증평", "청주", "충주", "제천",
    "양산", "경주", "밀양", "포항", "창원", "진주", "사천", "김해", "거제",
    "목포", "여수", "순천", "광양", "무안", "영암", "강진", "장흥", "완도", "진도", "장성", "담양",
    "전주", "군산", "익산", "정읍", "남원",
    "안동", "구미", "김천", "의성", "상주", "영주",
    "원주", "춘천", "강릉",
}

def _is_metro_or_national(region_text):
    """서울 또는 전국/불명확이면 True, 명확히 타 지역이면 False"""
    if not region_text:
        return True
    if "서울" in region_text:
        return True
    if any(n in region_text for n in _NON_METRO):
        return False
    return True  # 전국·전체·불명확 등 애매하면 통과

def _parse_applyhome_supply_types(detail_html, base_type):
    """청약홈 상세 페이지에서 공급유형별 세대수 파싱 → types 배열 반환
    컬럼 순서: 다자녀(0) 신혼부부(1) 생애최초(2) 청년(3) 노부모부양(4) 신생아(5) ...
    """
    types = [base_type]
    # trHshldco 이후 tbody 추출
    m = re.search(r'id="trHshldco".*?<tbody>(.*?)</tbody>', detail_html, re.DOTALL)
    if not m:
        return types
    col_sums = {}
    # tds[0]=주택형, tds[1~]=공급세대수 컬럼
    col_map = {1: "분양 다자녀", 2: "분양 신혼특공", 3: "분양 생애최초",
               4: "분양 청년특공", 5: "분양 노부모부양", 6: "분양 신생아특공"}
    for tr in re.split(r"<tr[^>]*>", m.group(1))[1:]:
        tds = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.DOTALL)
        for i, key in col_map.items():
            if i < len(tds):
                val = re.sub(r"<[^>]+>", "", tds[i]).strip()
                try:
                    col_sums[key] = col_sums.get(key, 0) + int(val)
                except ValueError:
                    pass
    for key, total in col_sums.items():
        if total > 0:
            types.append(key)
    return types

def _parse_applyhome_district(detail_html):
    """청약홈 상세페이지 공급위치에서 구/군 추출 → '강남구' 형태"""
    if not detail_html:
        return ""
    m = re.search(r'공급위치\s*(?:<[^>]+>\s*){0,5}([가-힣\s\d\-\.]+(?:구|군))', detail_html, re.DOTALL)
    if m:
        addr = m.group(1).strip()
        # 구/군 단위만 추출
        gu = re.search(r'(\S+(?:구|군))', addr)
        return gu.group(1) if gu else ""
    return ""

def _parse_applyhome_period(text):
    """'2026-04-03 ~ 2026-04-06' 또는 '2026.04.03 ~ 2026.04.06' 형식 파싱"""
    m = re.search(r"(\d{4})[-.](\d{2})[-.](\d{2})\s*~\s*(\d{4})[-.](\d{2})[-.](\d{2})", text)
    if m:
        s = parse_ymd(m.group(1), m.group(2), m.group(3))
        e = parse_ymd(m.group(4), m.group(5), m.group(6))
        return s, e
    return None, None

def crawl_applyhome_apt(initial=False):
    """청약홈 아파트 청약일정 — 서울 필터, 첫 페이지만"""
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    print("  [청약홈 APT] 서울 목록 로딩...")

    html = fetch(
        APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do",
        data={"pageIndex": "1", "orderbySecd": "", "orderbyMth": "01",
              "rentSecd": "", "schTxt": "", "suplyAreaCode": "서울"},
        extra_headers={"Referer": APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do",
                       "Content-Type": "application/x-www-form-urlencoded"}
    )
    if not html:
        return results

    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        return results

    tr_blocks = re.findall(
        r'<tr\s+data-pbno="(\d+)"\s+data-hmno="(\d+)"[^>]*>(.*?)</tr>',
        tbody_m.group(1), re.DOTALL
    )
    for pbno, hmno, tr_inner in tr_blocks:
        tds = re.findall(r"<td[^>]*>(.*?)</td>", tr_inner, re.DOTALL)
        if len(tds) < 5:
            continue
        house_type = re.sub(r"<[^>]+>|\s+", " ", tds[1]).strip()
        link_m = re.search(r"<a[^>]*>(.*?)</a>", tds[3], re.DOTALL)
        name_raw = re.sub(r"<[^>]+>|\s+", " ", link_m.group(1)).strip() if link_m \
                   else re.sub(r"<[^>]+>|\s+", " ", tds[3]).strip()
        if not name_raw:
            continue

        period_raw = ""
        for col_i in range(4, len(tds)):
            c = re.sub(r"<[^>]+>|\s+", " ", tds[col_i]).strip()
            if "~" in c and re.search(r"\d{4}[-./]\d{2}[-./]\d{2}", c):
                period_raw = c
                break

        apply_start, apply_end = _parse_applyhome_period(period_raw)
        if apply_end and apply_end < today:
            continue
        if apply_end and apply_end > future_limit:
            continue

        status = compute_status(apply_start, apply_end, today)

        # 상세 페이지 크롤링 → 공급유형 파악
        detail_url = (f"{APPLYHOME_BASE}/ai/aia/selectAPTLttotPblancDetail.do"
                      f"?pblancNo={pbno}&houseManageNo={hmno}")
        detail_html = fetch(detail_url, extra_headers={
            "Referer": APPLYHOME_BASE + "/ai/aia/selectAPTLttotPblancListView.do"
        })
        time.sleep(DETAIL_SLEEP)
        base_types = detect_types_applyhome(name_raw, house_type)
        if base_types[0].startswith("민간분양"):
            types = base_types
        else:
            types = _parse_applyhome_supply_types(detail_html, base_types[0]) if detail_html else base_types
        district = _parse_applyhome_district(detail_html) or extract_gu_from_text(name_raw)

        ann = {
            "id":          make_id("청약홈", name_raw, apply_end.isoformat() if apply_end else None),
            "inst":        "청약홈",
            "source_key":  "applyhome_apt",
            "title":       name_raw,
            "types":       types,
            "location":    "서울특별시" + (" " + district if district else ""),
            "district":    district,
            "status":      status,
            "url":         detail_url,
            "posted_date": today.isoformat(),
            "crawled_at":  today.isoformat(),
        }
        if apply_start and apply_end:
            ann["apply_start"] = apply_start.isoformat()
            ann["apply_end"]   = apply_end.isoformat()
        results.append(ann)
        supply_info = ", ".join(types[1:]) if len(types) > 1 else "일반공급만"
        print(f"    [{status}] {name_raw[:35]} → {supply_info}")

    print(f"  [청약홈 APT] 서울 {len(results)}건")
    return results




def crawl_applyhome_remndr(initial=False):
    """청약홈 아파트 잔여세대 — 서울 필터, 첫 페이지만.
    유형 고정: 민간분양(아파트) 잔여세대 (추첨제, 서울 무주택세대주 자격)
    """
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    list_url = APPLYHOME_BASE + "/ai/aia/selectAPTRemndrLttotPblancListView.do"
    print("  [청약홈 잔여] 서울 목록 로딩...")

    html = fetch(
        list_url,
        data={"pageIndex": "1", "orderbySecd": "", "orderbyMth": "01", "suplyAreaCode": "서울"},
        extra_headers={"Referer": list_url, "Content-Type": "application/x-www-form-urlencoded"}
    )
    if not html:
        return results

    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        return results

    for tr_block in re.findall(
        r'<tr\s+data-pbno="(\d+)"\s+data-hmno="(\d+)"\s+data-hsecd="(\w+)"\s+data-honm="([^"]+)"[^>]*>(.*?)</tr>',
        tbody_m.group(1), re.DOTALL
    ):
        pbno, hmno, hsecd, honm, tr_inner = tr_block
        name_raw = honm
        if not name_raw:
            continue

        tds = re.findall(r"<td[^>]*>(.*?)</td>", tr_inner, re.DOTALL)
        period_raw = ""
        for col_i in range(3, len(tds)):
            c = re.sub(r"<[^>]+>|\s+", " ", tds[col_i]).strip()
            if "~" in c and re.search(r"\d{4}[-./]\d{2}[-./]\d{2}", c):
                period_raw = c
                break

        apply_start, apply_end = _parse_applyhome_period(period_raw)
        if apply_end and apply_end < today:
            continue
        if apply_end and apply_end > future_limit:
            continue

        status = compute_status(apply_start, apply_end, today)

        # 상세 페이지 POST → 공급위치(구) 파싱
        time.sleep(DETAIL_SLEEP)
        detail_html = fetch(
            APPLYHOME_BASE + "/ai/aia/selectAPTRemndrLttotPblancDetailView.do",
            data={"pblancNo": pbno, "houseManageNo": hmno, "houseSecd": hsecd},
            extra_headers={"Referer": list_url}
        )
        district = _parse_applyhome_district(detail_html) or extract_gu_from_text(name_raw)

        ann = {
            "id":          make_id("청약홈", name_raw + " (잔여세대)", apply_end.isoformat() if apply_end else None),
            "inst":        "청약홈",
            "source_key":  "applyhome_remndr",
            "title":       name_raw + " (잔여세대)",
            "types":       ["민간분양(아파트) 잔여세대"],
            "location":    "서울특별시" + (" " + district if district else ""),
            "district":    district,
            "status":      status,
            "url":         list_url,
            "posted_date": today.isoformat(),
            "crawled_at":  today.isoformat(),
        }
        if apply_start and apply_end:
            ann["apply_start"] = apply_start.isoformat()
            ann["apply_end"]   = apply_end.isoformat()
        results.append(ann)
        print(f"    [{status}] {name_raw[:40]} [{district}] (~{apply_end})")

    print(f"  [청약홈 잔여] 서울 {len(results)}건")
    return results


def crawl_applyhome_other(initial=False):
    """청약홈 오피스텔/도시형/민간임대 — 서울 필터, 첫 페이지만"""
    today = date.today()
    future_limit = today + timedelta(days=FUTURE_LIMIT_DAYS)
    results = []
    list_url = APPLYHOME_BASE + "/ai/aia/selectOtherLttotPblancListView.do"
    print("  [청약홈 기타] 서울 목록 로딩...")

    html = fetch(
        list_url,
        data={"pageIndex": "1", "orderbySecd": "", "orderbyMth": "01",
              "houseNm": "", "start_year": "", "end_year": "", "suplyAreaCode": "서울"},
        extra_headers={"Referer": list_url, "Content-Type": "application/x-www-form-urlencoded"}
    )
    if not html:
        return results

    tbody_m = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_m:
        return results

    tr_blocks = re.findall(
        r'<tr\s+data-pbno="(\d+)"\s+data-hmno="(\d+)"\s+data-hsecd="(\w+)"\s+data-honm="([^"]+)"[^>]*>(.*?)</tr>',
        tbody_m.group(1), re.DOTALL
    )
    for pbno, hmno, hsecd, honm, tr_inner in tr_blocks:
        tds = re.findall(r"<td[^>]*>(.*?)</td>", tr_inner, re.DOTALL)
        if len(tds) < 4:
            continue
        house_type = re.sub(r"<[^>]+>|\s+", " ", tds[1]).strip()
        name_raw   = honm
        if not name_raw:
            continue

        period_raw = ""
        for col_i in range(3, len(tds)):
            c = re.sub(r"<[^>]+>|\s+", " ", tds[col_i]).strip()
            if "~" in c and re.search(r"\d{4}[-./]\d{2}[-./]\d{2}", c):
                period_raw = c
                break

        apply_start, apply_end = _parse_applyhome_period(period_raw)
        if apply_end and apply_end < today:
            continue
        if apply_end and apply_end > future_limit:
            continue

        status = compute_status(apply_start, apply_end, today)

        # 상세 페이지 POST → 공급위치(구) 파싱
        time.sleep(DETAIL_SLEEP)
        detail_html = fetch(
            APPLYHOME_BASE + "/ai/aia/selectPRMOLttotPblancDetailView.do",
            data={"pblancNo": pbno, "houseManageNo": hmno, "houseSecd": hsecd},
            extra_headers={"Referer": list_url}
        )
        district = _parse_applyhome_district(detail_html) or extract_gu_from_text(name_raw)

        ann = {
            "id":          make_id("청약홈", name_raw, apply_end.isoformat() if apply_end else None),
            "inst":        "청약홈",
            "source_key":  "applyhome_other",
            "title":       name_raw,
            "types":       detect_types_applyhome(name_raw, house_type),
            "location":    "서울특별시" + (" " + district if district else ""),
            "district":    district,
            "status":      status,
            "url":         list_url,
            "posted_date": today.isoformat(),
            "crawled_at":  today.isoformat(),
        }
        if apply_start and apply_end:
            ann["apply_start"] = apply_start.isoformat()
            ann["apply_end"]   = apply_end.isoformat()
        results.append(ann)
        print(f"    [{status}] {name_raw[:35]} [{district}] (~{apply_end})")

    print(f"  [청약홈 기타] 서울 {len(results)}건")
    return results


# ════════════════════════════════════════════════════════════════════════
# ⑦ 오케스트레이터
# ════════════════════════════════════════════════════════════════════════
def dedup(announcements):
    """
    1차: 같은 기관 내 중복 제거 (inst + norm_title + apply_end)
    2차: 기관 간 중복 제거 (norm_title + apply_end) — apply_end 있는 경우만
          우선순위: lh/sh/youth > applyhome
    """
    PRIORITY = {
        # LH 최우선 (기관 간 동일 공고 시 LH 버전 유지)
        "lh_rental": 1, "lh_sale": 1,
        # SH / 청년안심주택
        "sh_rental": 2, "sh_sale": 2, "sh_notice": 2,

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
            # 수동 전용 공고 (크롤러가 수집 못하는 공고)
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
            "district":    a.get("district") or None,
            "raw_data":    {"source_key": a.get("source_key", "")},
        })

    # 만료 공고 삭제 (apply_end 지난 것)
    today_str = date.today().isoformat()
    cleanup_url = f"{sb_url}/rest/v1/announcements?apply_end=lt.{today_str}&apply_end=not.is.null"
    cleanup_headers = {
        "apikey":        sb_key,
        "Authorization": f"Bearer {sb_key}",
        "Content-Type":  "application/json",
    }
    try:
        req = urllib.request.Request(cleanup_url, headers=cleanup_headers, method="DELETE")
        urllib.request.urlopen(req, timeout=30)
        print(f"  [Supabase] 만료 공고 삭제 완료 (apply_end < {today_str})")
    except Exception as e:
        print(f"  [Supabase] 만료 공고 삭제 오류: {e}")

    # 배치 upsert (100개씩) — on_conflict 명시 필요
    endpoint = f"{sb_url}/rest/v1/announcements?on_conflict=institution,seq"
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
        param_name="multi_itm_seqs",
        normal_max_pages=2,    # 오늘+전날 공고는 2페이지면 충분
        normal_since_days=1    # 오늘 + 전날까지만
    )
    all_announcements += sh_rental.crawl(initial)
    all_announcements += sh_sale.crawl(initial)
    all_announcements += sh_notice.crawl(initial)

    # ── LH ──────────────────────────────────────────────────────────────
    all_announcements += crawl_lh(mi="1026", source_key="lh_rental", initial=initial)
    all_announcements += crawl_lh(mi="1027", source_key="lh_sale",   initial=initial)

    # ── 청년안심주택 ────────────────────────────────────────────────────
    all_announcements += crawl_youth_housing(initial)

    # ── 청약홈 ──────────────────────────────────────────────────────────────
    all_announcements += crawl_applyhome_apt(initial)
    all_announcements += crawl_applyhome_remndr(initial)
    all_announcements += crawl_applyhome_other(initial)

    # ── 중복 제거 ────────────────────────────────────────────────────────
    print("\n중복 제거 중...")
    all_announcements = dedup(all_announcements)

    # ── 만료 공고 제거 ────────────────────────────────────────────────────
    all_announcements = [a for a in all_announcements if should_keep(a, today)]

    # ── 인천·경기 공고 제거 (서울 집중 서비스) ──────────────────────────────
    INCHEON_KEYWORDS = ["인천"]
    def is_incheon(ann):
        title = ann.get("title", "")
        district = ann.get("district", "") or ""
        return any(kw in title or kw in district for kw in INCHEON_KEYWORDS)
    before = len(all_announcements)
    all_announcements = [a for a in all_announcements if not is_incheon(a)]
    removed = before - len(all_announcements)
    if removed:
        print(f"  [인천 필터] {removed}건 제거")

    # ── 수동 오버라이드 병합 ──────────────────────────────────────────────
    overrides = load_manual_overrides()
    if overrides:
        all_announcements = apply_overrides(all_announcements, overrides)

    # ── 저장 ─────────────────────────────────────────────────────────────
    needs_review = [a for a in all_announcements if a.get("status") == "needs_review"]

    # ── Supabase 저장 ────────────────────────────────────────────────
    save_to_supabase(all_announcements)

    print(f"\n완료: 총 {len(all_announcements)}건 저장")
    print(f"  ├ 진행중:  {sum(1 for a in all_announcements if a.get('status')=='진행중')}건")
    print(f"  ├ 예정:    {sum(1 for a in all_announcements if a.get('status')=='예정')}건")
    print(f"  └ 검토필요: {len(needs_review)}건")

if __name__ == "__main__":
    main()
