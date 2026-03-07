document.addEventListener('DOMContentLoaded', () => {

    // ===== Theme Toggle =====
    const themeToggle = document.getElementById('theme-toggle');
    const body = document.body;

    const savedTheme = localStorage.getItem('theme') || 'light';
    body.setAttribute('data-theme', savedTheme);
    if (themeToggle) {
        themeToggle.textContent = savedTheme === 'light' ? '다크 모드' : '라이트 모드';
    }

    if (themeToggle) {
        themeToggle.addEventListener('click', () => {
            const current = body.getAttribute('data-theme');
            const next = current === 'light' ? 'dark' : 'light';
            body.setAttribute('data-theme', next);
            localStorage.setItem('theme', next);
            themeToggle.textContent = next === 'light' ? '다크 모드' : '라이트 모드';
        });
    }

    // ===== Tab System (Housing Types) =====
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const target = btn.dataset.tab;

            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            btn.classList.add('active');
            const content = document.querySelector(`.tab-content[data-content="${target}"]`);
            if (content) content.classList.add('active');
        });
    });

    // ===== Eligibility Check =====
    const checkBtns = document.querySelectorAll('.check-btn');

    checkBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const group = btn.dataset.group;
            document.querySelectorAll(`.check-btn[data-group="${group}"]`)
                .forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            updateEligibilityResult();
        });
    });

    function getSelected(group) {
        const btn = document.querySelector(`.check-btn[data-group="${group}"].active`);
        return btn ? btn.dataset.value : null;
    }

    const eligibilityData = {
        youth: {
            low:  [
                { name: '청년 매입임대주택', badge: '1순위 가능 (시세 30%)', recommended: true },
                { name: '청년안심주택', badge: '1~2순위', recommended: true },
                { name: '행복주택 청년계층', badge: '청약저축 필요', recommended: false },
            ],
            mid:  [
                { name: '청년 매입임대주택', badge: '2·3순위 (시세 50%)', recommended: true },
                { name: '청년안심주택', badge: '2순위', recommended: true },
                { name: '행복주택 청년계층', badge: '청약저축 필요', recommended: false },
            ],
            high: [
                { name: '청년안심주택', badge: '2순위', recommended: true },
                { name: '장기전세주택 (시프트)', badge: '60㎡ 초과 소득무관', recommended: false },
            ],
            any: [
                { name: '장기전세주택 (시프트)', badge: '60㎡ 초과 소득무관', recommended: true },
            ],
        },
        student: {
            low:  [
                { name: '희망하우징', badge: '월 79,000~145,000원', recommended: true },
                { name: '청년 매입임대주택', badge: '대학생 보증금 100만원', recommended: true },
                { name: '행복주택 대학생계층', badge: '청약저축 필요', recommended: false },
            ],
            mid: [
                { name: '희망하우징', badge: '2순위', recommended: true },
                { name: '청년 매입임대주택', badge: '대학생 보증금 100만원', recommended: true },
            ],
            high: [
                { name: '청년 매입임대주택', badge: '3순위', recommended: true },
            ],
            any: [
                { name: '청년 매입임대주택', badge: '3순위', recommended: true },
            ],
        },
        newlywed: {
            low: [
                { name: '신혼·신생아 매입임대Ⅰ', badge: '시세 30~50%', recommended: true },
                { name: '신혼·신생아 전세임대Ⅰ', badge: '입주자 5%만 부담', recommended: true },
                { name: '행복주택 신혼부부', badge: '최장 14년', recommended: false },
            ],
            mid: [
                { name: '신혼·신생아 매입임대Ⅱ', badge: '시세 60~70%', recommended: true },
                { name: '장기안심주택', badge: '보증금 최대 6천만원 지원', recommended: true },
                { name: '행복주택 신혼부부', badge: '맞벌이 120%', recommended: false },
            ],
            high: [
                { name: '신혼·신생아 매입임대Ⅱ', badge: '맞벌이 200%', recommended: true },
                { name: '전세임대 신혼신생아Ⅱ', badge: '최대 6억 보증금', recommended: true },
                { name: '미리내집 (장기전세2)', badge: '10년 후 분양전환', recommended: false },
            ],
            any: [
                { name: '미리내집 (장기전세2)', badge: '10년 후 분양전환', recommended: true },
                { name: '장기전세주택 (시프트)', badge: '소득무관 60㎡ 초과', recommended: false },
            ],
        },
        newborn: {
            low: [
                { name: '신혼·신생아 매입임대Ⅰ', badge: '1순위', recommended: true },
                { name: '전세임대형 든든주택', badge: '소득·자산 무관', recommended: true },
                { name: '신혼·신생아 전세임대Ⅰ', badge: '1순위', recommended: false },
            ],
            mid: [
                { name: '신혼·신생아 매입임대Ⅱ', badge: '1순위', recommended: true },
                { name: '전세임대형 든든주택', badge: '소득·자산 무관', recommended: true },
            ],
            high: [
                { name: '전세임대형 든든주택', badge: '1순위 신생아가구', recommended: true },
                { name: '신혼·신생아 매입임대Ⅱ', badge: '맞벌이 200%', recommended: false },
            ],
            any: [
                { name: '전세임대형 든든주택', badge: '소득·자산 무관', recommended: true },
                { name: '미리내집 (장기전세2)', badge: '출산 인센티브', recommended: false },
            ],
        },
        general: {
            low: [
                { name: '국민임대주택', badge: '시세 60~80%, 제한없이 거주', recommended: true },
                { name: '기존주택 전세임대', badge: '최장 30년', recommended: true },
                { name: '일반 매입임대주택', badge: '총자산 2.37억 이하', recommended: false },
            ],
            mid: [
                { name: '국민임대주택', badge: '소득 70% 60㎡형', recommended: true },
                { name: '장기안심주택', badge: '보증금 최대 6천만원 지원', recommended: true },
            ],
            high: [
                { name: '장기안심주택', badge: '소득 100% 이하', recommended: true },
                { name: '장기전세주택 (시프트)', badge: '60㎡ 초과 소득무관', recommended: false },
            ],
            any: [
                { name: '장기전세주택 (시프트)', badge: '60㎡ 초과 소득무관', recommended: true },
                { name: '전세임대형 든든주택', badge: '소득·자산 무관', recommended: false },
            ],
        },
    };

    // Priority overrides
    const priorityBoosts = {
        recipient: '수급자 → 대부분 유형 1순위 자동 해당 (소득·자산 심사 없는 경우도 있음)',
        nearlow: '차상위계층 → 청년·희망하우징·전세임대 등 1순위 해당',
        disabled: '장애인 → 소득 70% 이하 시 일반매입임대·전세임대 1순위',
        none: null,
    };

    function updateEligibilityResult() {
        const type = getSelected('type') || 'youth';
        const income = getSelected('income') || 'mid';
        const priority = getSelected('priority') || 'none';

        const resultList = document.getElementById('result-list');
        if (!resultList) return;

        const data = eligibilityData[type]?.[income] || [];
        const priorityMsg = priorityBoosts[priority];

        let html = '';

        if (priorityMsg) {
            html += `<div class="result-item recommended" style="flex-direction:column;align-items:flex-start;gap:0.2rem;">
                <span style="font-size:0.78rem;opacity:0.8;">우대 대상 혜택</span>
                ${priorityMsg}
            </div>`;
        }

        data.forEach(item => {
            html += `<div class="result-item ${item.recommended ? 'recommended' : ''}">
                ${item.name}
                <span class="result-badge ${item.recommended ? '' : 'secondary'}">${item.badge}</span>
            </div>`;
        });

        if (!data.length && !priorityMsg) {
            html = '<div class="result-item">조건을 선택하면 추천 유형이 표시됩니다.</div>';
        }

        resultList.innerHTML = html;
    }

    updateEligibilityResult();

    // ===== FAQ Accordion =====
    const faqItems = document.querySelectorAll('.faq-item');
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');
        if (question) {
            question.addEventListener('click', () => {
                const isOpen = item.classList.contains('open');
                faqItems.forEach(i => i.classList.remove('open'));
                if (!isOpen) item.classList.add('open');
            });
        }
    });

    // ===== Subscribe Form =====
    const subscribeForm = document.getElementById('subscribe-form');
    if (subscribeForm) {
        subscribeForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const email = document.getElementById('input-email').value;
            const phone = document.getElementById('input-phone').value;
            if (email && phone) {
                alert('구독 완료! 맞춤 공고가 뜨면 바로 알려드릴게요.');
                subscribeForm.reset();
            } else {
                alert('이메일과 핸드폰 번호를 모두 입력해주세요.');
            }
        });
    }

    const experienceBtn = document.getElementById('btn-experience');
    if (experienceBtn) {
        experienceBtn.addEventListener('click', () => {
            window.location.href = 'details.html';
        });
    }

    // ===== Smooth scroll for nav links =====
    document.querySelectorAll('a[href^="#"]').forEach(link => {
        link.addEventListener('click', (e) => {
            const target = document.querySelector(link.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth' });
            }
        });
    });

});
