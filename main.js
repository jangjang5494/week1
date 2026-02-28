document.addEventListener('DOMContentLoaded', () => {
    // Translation Data
    const translations = {
        ko: {
            logo: '내집구독',
            nav_about: '서비스 소개',
            nav_subscribe: '구독 신청',
            nav_faq: '자주 묻는 질문',
            nav_reviews: '사용자 후기',
            nav_login: '로그인',
            hero_h1: '서울 2030 청년들을 위한<br>내집마련 정보 구독 서비스',
            hero_p: '더 이상 복잡한 공고 찾기는 그만! AI가 나에게 맞는 주택 정보를 찾아 알려드려요.',
            hero_btn: '지금 바로 시작하기',
            about_h2: "'내집구독'은 어떤 서비스인가요?",
            about_p: '서울에서 내 집 마련의 꿈, 복잡한 공고와 자격 조건 때문에 포기하셨나요?<br>SH공사, LH공사에서 제공하는 <b>장기전세주택, 매입임대, 행복주택, 역세권 청년주택</b> 등 다양한 정부 지원 주택 정보를 놓치지 마세요. "내집구독"은 2030 청년들을 위해 나에게 딱 맞는 청약 공고만 골라 실시간으로 배달해 드립니다.',
            feature1_h3: 'AI 기반 맞춤 정보',
            feature1_p: '내 직업, 연봉, 자산을 입력하면 AI가 자격 요건을 분석하여 신청 가능한 주택 정보를 실시간으로 알려드려요.',
            feature2_h3: '간편한 신청 준비',
            feature2_p: '복잡한 서류와 절차는 이제 그만! \'내집구독\'이 알려주는 대로 간편하게 신청만 하세요.',
            feature3_h3: '놓치지 않는 알림',
            feature3_p: '새로운 공고가 올라오면 놓치지 않도록 바로 알려드려요. 이제 청약홈만 바라보지 않아도 괜찮아요.',
            faq_h2: '자주 묻는 질문',
            faq_q1: '행복주택과 청년주택의 차이가 무엇인가요?',
            faq_a1: '행복주택은 정부와 공기업(LH, SH)에서 공급하는 저렴한 임대주택이며, 역세권 청년주택은 역세권 근처에 청년과 신혼부부를 위해 특별히 공급되는 주택입니다. 내집구독은 이 모든 공고를 실시간으로 분류해 드립니다.',
            faq_q2: '신청 자격이 어떻게 되나요?',
            faq_a2: '나이, 소득, 자산 등 조건에 따라 달라집니다. 내집구독 서비스를 이용하시면 본인의 데이터를 바탕으로 신청 가능한 공고만 자동으로 매칭해 드립니다.',
            subscribe_h2: '지금 바로 구독하고 내집마련의 꿈을 현실로!',
            subscribe_p: '아래 정보를 입력해주시면, AI가 분석하여 맞춤형 정보를 제공해드립니다.',
            reviews_h2: '사용자 후기',
            reviews_p: "'내집구독'을 통해 내 집 마련의 꿈을 이룬 분들의 생생한 후기를 확인해보세요.",
            form_job: '직업',
            form_salary: '연봉 (만원)',
            form_assets: '자산 (만원)',
            form_btn: '맞춤 정보 받기',
            form_exp_btn: '체험하기',
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
            nav_faq: 'FAQ',
            nav_reviews: 'Reviews',
            nav_login: 'Login',
            hero_h1: 'Housing Subscription for<br>Seoul 2030 Youth',
            hero_p: 'No more complex announcements! AI finds the right housing information for you.',
            hero_btn: 'Get Started Now',
            about_h2: 'What is My Home Finder?',
            about_p: 'Are you giving up on your dream of owning a home in Seoul because of complex announcements and eligibility? Don’t miss out on government housing like <b>long-term rentals, public housing, happiness housing, and youth housing</b> provided by SH and LH. "My Home Finder" delivers only the best subscription announcements for youth in their 20s and 30s in real-time.',
            feature1_h3: 'AI-Based Custom Info',
            feature1_p: 'Enter your job, salary, and assets, and AI will analyze eligibility to notify you of available housing in real-time.',
            feature2_h3: 'Easy Application Prep',
            feature2_p: 'No more complex documents and procedures! Just follow the instructions from My Home Finder.',
            feature3_h3: 'Instant Alerts',
            feature3_p: "We'll notify you immediately when a new announcement is posted. You don't have to keep checking yourself.",
            faq_h2: 'Frequently Asked Questions',
            faq_q1: 'What is the difference between happiness housing and youth housing?',
            faq_a1: 'Happiness housing is affordable rental housing provided by the government and corporations (LH, SH), while youth housing near subways is specifically for youth and newlyweds. My Home Finder categorizes all these announcements in real-time.',
            faq_q2: 'What are the application requirements?',
            faq_a2: 'Requirements vary based on age, income, and assets. By using My Home Finder, we automatically match you with announcements you are eligible for based on your data.',
            subscribe_h2: 'Subscribe Now and Make Your Dream a Reality!',
            subscribe_p: 'Enter your information below, and AI will provide customized results.',
            reviews_h2: 'User Reviews',
            reviews_p: 'Check out the real stories of those who achieved their homeownership dreams through My Home Finder.',
            form_job: 'Job',
            form_salary: 'Annual Salary (10k KRW)',
            form_assets: 'Assets (10k KRW)',
            form_btn: 'Get My Info',
            form_exp_btn: 'Try Experience',
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

    const experienceBtn = document.getElementById('btn-experience');
    if (experienceBtn) {
        experienceBtn.addEventListener('click', () => {
            window.location.href = 'details.html';
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
