document.addEventListener('DOMContentLoaded', () => {
    // Translation Data
    const translations = {
        ko: {
            logo: '내집구독',
            nav_about: '서비스 소개',
            nav_subscribe: '구독 신청',
            nav_reviews: '사용자 후기',
            nav_login: '로그인',
            hero_h1: '서울 2030 청년들을 위한<br>내집마련 정보 구독 서비스',
            hero_p: '더 이상 복잡한 공고 찾기는 그만! AI가 나에게 맞는 주택 정보를 찾아 알려드려요.',
            hero_btn: '지금 바로 시작하기',
            about_h2: "'내집구독'은 어떤 서비스인가요?",
            about_p: '서울에서 내 집 마련의 꿈, 너무 멀게만 느껴지시나요?<br>장기전세주택, 임대주택, 행복주택 등 정부 지원 혜택, 정보가 부족해 놓치고 계셨다면 \'내집구독\'이 도와드릴게요.',
            feature1_h3: 'AI 기반 맞춤 정보',
            feature1_p: '내 직업, 연봉, 자산을 입력하면 AI가 자격 요건을 분석하여 신청 가능한 주택 정보를 실시간으로 알려드려요.',
            feature2_h3: '간편한 신청 준비',
            feature2_p: '복잡한 서류와 절차는 이제 그만! \'내집구독\'이 알려주는 대로 간편하게 신청만 하세요.',
            feature3_h3: '놓치지 않는 알림',
            feature3_p: '새로운 공고가 올라오면 놓치지 않도록 바로 알려드려요. 이제 청약홈만 바라보지 않아도 괜찮아요.',
            subscribe_h2: '지금 바로 구독하고 내집마련의 꿈을 현실로!',
            subscribe_p: '아래 정보를 입력해주시면, AI가 분석하여 맞춤형 정보를 제공해드립니다.',
            reviews_h2: '사용자 후기',
            reviews_p: "'내집구독'을 통해 내 집 마련의 꿈을 이룬 분들의 생생한 후기를 확인해보세요.",
            form_job: '직업',
            form_salary: '연봉 (만원)',
            form_assets: '자산 (만원)',
            form_btn: '맞춤 정보 받기',
            footer_rights: 'All rights reserved.',
            contact_h2: '제휴 및 서비스 문의',
            contact_p: '내집구독과 함께하고 싶은 파트너분들의 연락을 기다립니다.',
            contact_name: '성함/업체명',
            contact_email: '이메일 주소',
            contact_message: '문의 내용',
            contact_btn: '문의 보내기',
            theme_light: '라이트 모드',
            theme_dark: '다크 모드',
            welcome_msg: '내집마련 서비스에 오신 것을 환영합니다!\n곧 서비스가 출시될 예정입니다.',
            form_success: '입력하신 정보:\n- 직업: {job}\n- 연봉: {salary}만원\n- 자산: {assets}만원\n\n내집마련 서비스가 당신에게 맞는 집을 찾아드리겠습니다!',
            form_error: '모든 정보를 입력해주세요.'
        },
        en: {
            logo: 'My Home Finder',
            nav_about: 'About',
            nav_subscribe: 'Subscribe',
            nav_reviews: 'Reviews',
            nav_login: 'Login',
            hero_h1: 'Housing Subscription for<br>Seoul 2030 Youth',
            hero_p: 'No more complex announcements! AI finds the right housing information for you.',
            hero_btn: 'Get Started Now',
            about_h2: 'What is My Home Finder?',
            about_p: 'Feeling far from your dream of owning a home in Seoul? If you missed out on benefits like long-term rental, public rental, or happiness housing due to lack of info, My Home Finder is here to help.',
            feature1_h3: 'AI-Based Custom Info',
            feature1_p: 'Enter your job, salary, and assets, and AI will analyze eligibility to notify you of available housing in real-time.',
            feature2_h3: 'Easy Application Prep',
            feature2_p: 'No more complex documents and procedures! Just follow the instructions from My Home Finder.',
            feature3_h3: 'Instant Alerts',
            feature3_p: "We'll notify you immediately when a new announcement is posted. You don't have to keep checking yourself.",
            subscribe_h2: 'Subscribe Now and Make Your Dream a Reality!',
            subscribe_p: 'Enter your information below, and AI will provide customized results.',
            reviews_h2: 'User Reviews',
            reviews_p: 'Check out the real stories of those who achieved their homeownership dreams through My Home Finder.',
            form_job: 'Job',
            form_salary: 'Annual Salary (10k KRW)',
            form_assets: 'Assets (10k KRW)',
            form_btn: 'Get My Info',
            footer_rights: 'All rights reserved.',
            contact_h2: 'Partnership Inquiry',
            contact_p: 'We are looking for partners to grow with My Home Finder.',
            contact_name: 'Name / Company',
            contact_email: 'Email Address',
            contact_message: 'Message',
            contact_btn: 'Send Inquiry',
            theme_light: 'Light Mode',
            theme_dark: 'Dark Mode',
            welcome_msg: 'Welcome to My Home Finder!\nThe service will be launched soon.',
            form_success: 'Information Entered:\n- Job: {job}\n- Salary: {salary}\n- Assets: {assets}\n\nMy Home Finder will find the perfect home for you!',
            form_error: 'Please enter all information.'
        }
    };

    // Language Logic
    const langToggle = document.getElementById('lang-toggle');
    let currentLang = localStorage.getItem('lang') || 'ko';

    function setLanguage(lang) {
        currentLang = lang;
        localStorage.setItem('lang', lang);
        
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            if (translations[lang][key]) {
                el.innerHTML = translations[lang][key];
            }
        });

        document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
            const key = el.getAttribute('data-i18n-placeholder');
            if (translations[lang][key]) {
                el.placeholder = translations[lang][key];
            }
        });

        langToggle.textContent = lang === 'ko' ? 'English' : '한국어';
        updateToggleButton(localStorage.getItem('theme') || 'light');
    }

    langToggle.addEventListener('click', () => {
        setLanguage(currentLang === 'ko' ? 'en' : 'ko');
    });

    // Theme Toggle Logic
    const themeToggle = document.getElementById('theme-toggle');
    const body = document.body;
    
    const savedTheme = localStorage.getItem('theme') || 'light';
    body.setAttribute('data-theme', savedTheme);
    
    themeToggle.addEventListener('click', () => {
        const currentTheme = body.getAttribute('data-theme');
        const newTheme = currentTheme === 'light' ? 'dark' : 'light';
        
        body.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        updateToggleButton(newTheme);
    });

    function updateToggleButton(theme) {
        const key = theme === 'light' ? 'theme_dark' : 'theme_light';
        themeToggle.textContent = translations[currentLang][key];
    }

    // Initial load
    setLanguage(currentLang);

    // Button interactions
    const startButton = document.querySelector('.hero-content button');
    if (startButton) {
        startButton.addEventListener('click', () => {
            alert(translations[currentLang].welcome_msg);
        });
    }

    const subscribeForm = document.getElementById('subscribe-form');
    if (subscribeForm) {
        subscribeForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const job = document.getElementById('input-job').value;
            const salary = document.getElementById('input-salary').value;
            const assets = document.getElementById('input-assets').value;

            if (job && salary && assets) {
                let msg = translations[currentLang].form_success
                    .replace('{job}', job)
                    .replace('{salary}', salary)
                    .replace('{assets}', assets);
                alert(msg);
            } else {
                alert(translations[currentLang].form_error);
            }
        });
    }
});
