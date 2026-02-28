document.addEventListener('DOMContentLoaded', () => {
    // --- 기존 번역 및 테마 로직 ... ---
    // (이 부분은 이전과 동일하게 유지됩니다)

    // --- 신규 기능 로직 시작 ---

    // 1. 부드러운 스크롤
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            document.querySelector(this.getAttribute('href')).scrollIntoView({
                behavior: 'smooth'
            });
        });
    });

    // 2. 메인 버튼 -> 분석 폼으로 이동
    const heroCtaBtn = document.getElementById('hero-cta-btn');
    if(heroCtaBtn) {
        heroCtaBtn.addEventListener('click', () => {
            document.getElementById('analysis').scrollIntoView({ behavior: 'smooth' });
        });
    }

    // 3. 자격 분석 폼 처리
    const analysisForm = document.getElementById('analysis-form');
    const resultDiv = document.getElementById('analysis-result');
    const resultText = document.getElementById('result-text');

    if(analysisForm) {
        analysisForm.addEventListener('submit', (e) => {
            e.preventDefault();

            // 입력 값 가져오기
            const age = parseInt(document.getElementById('age').value, 10);
            const isHomeless = document.getElementById('is-homeless').value === 'yes';
            const income = parseInt(document.getElementById('income').value, 10) * 10000;
            const assets = parseInt(document.getElementById('assets').value, 10) * 10000;
            const carValue = parseInt(document.getElementById('car-value').value, 10) * 10000;
            const hasSavings = document.getElementById('has-savings').value === 'yes';

            if (isNaN(age) || isNaN(income) || isNaN(assets)) {
                resultText.innerHTML = '<span class="error">나이, 소득, 자산 정보를 정확히 입력해주세요.</span>';
                resultDiv.classList.remove('hidden');
                return;
            }

            const eligible = [];

            // --- 분석 로직 ---
            if (isHomeless) {
                // 행복주택
                if (age >= 19 && age <= 39 && assets <= 340000000 && carValue <= 38000000) {
                    eligible.push('행복주택');
                }
                // 청년주택
                if (age >= 19 && age <= 39 && assets <= 360000000) {
                    eligible.push('청년주택(역세권 등)');
                }
                // 장기전세주택
                if (assets <= 360000000 && !hasSavings) {
                    eligible.push('장기전세주택');
                }
                // 공공분양
                if (hasSavings && assets <= 360000000) {
                    eligible.push('공공분양');
                }
            }

            // --- 결과 표시 ---
            if (eligible.length > 0) {
                resultText.innerHTML = `축하합니다! 현재 조건으로 <strong class="highlight">${eligible.join(', ')}</strong>에 지원 가능성이 높습니다. <br>아래 유형 비교표에서 상세 자격 요건을 다시 한번 확인해보세요.`
            } else {
                if (!isHomeless) {
                    resultText.innerHTML = '아쉽지만, 공공주택은 무주택 세대 구성원만 신청 가능합니다. 조건을 다시 확인해주세요.';
                } else {
                    resultText.innerHTML = '아쉽지만 현재 조건에 맞는 주택 유형을 찾지 못했습니다. 소득, 자산 기준 등을 다시 확인해보세요.';
                }
            }
            resultDiv.classList.remove('hidden');
            resultDiv.scrollIntoView({ behavior: 'smooth' });
        });
    }
});
