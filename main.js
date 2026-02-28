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
            hero_h1: '서울/경기 2030 청년을 위한<br>내집마련 필승 전략',
            hero_p: 'LH, SH, GH, 청약홈... 매일 확인하기 힘드시죠?<br>AI가 모든 공고를 실시간으로 모니터링하여 나에게 딱 맞는 정보만 배달합니다.',
            hero_btn: '지금 바로 시작하기',
            
            why_h2: '왜 내집구독인가요?',
            why_p: '흩어져 있는 공공주택 정보를 한눈에 확인하고, 내 자격에 맞는 공고만 받아보세요.',
            why_item1_h3: 'LH·SH·GH·청약홈 통합',
            why_item1_p: '각 공사 사이트를 일일이 방문할 필요가 없습니다. 모든 공공분양 및 임대 정보를 한곳으로 모았습니다.',
            why_item2_h3: '나에게만 최적화된 매칭',
            why_item2_p: '수백 개의 공고 중 내가 신청 가능한 것만 골라냅니다. 복잡한 자격 요건 분석은 AI에게 맡기세요.',
            why_item3_h3: '놓치지 않는 실시간 알림',
            why_item3_p: '공고가 올라오는 즉시 이메일과 문자로 알려드립니다. 바쁜 일상 속에서도 청약 기회를 놓치지 마세요.',

            table_h2: '기존 방식 vs 내집구독',
            table_manual: '기존의 정보 찾기',
            table_auto: '내집구독 서비스',
            table_check_sites: '각 공사 사이트 개별 확인 (LH, SH, GH, 청약홈)',
            table_check_auto: 'AI가 실시간으로 모든 사이트 통합 수집',
            table_qual_check: '공고문마다 복잡한 자격 요건 직접 계산',
            table_qual_auto: '내 정보를 기반으로 AI가 즉시 자격 판정',
            table_alert: '매번 직접 들어가서 확인 (기회 놓침 빈번)',
            table_alert_auto: '맞춤 공고 발생 시 즉시 Push 알림',

            about_h2: "'내집구독'은 어떤 서비스인가요?",
            about_p: '서울/경기 지역의 내 집 마련, 정보가 없어서 포기하지 마세요.<br>장기전세주택, 매입임대, 행복주택, 역세권 청년주택 등 모든 정부 지원 주택 정보를 실시간으로 분류해 드립니다.',
            
            feature1_h3: 'AI 기반 맞춤 정보',
            feature1_p: '내 정보를 입력하면 AI가 자격 요건을 분석하여 신청 가능한 주택 정보를 이메일과 문자로 실시간 알려드려요.',
            feature2_h3: '간편한 신청 준비',
            feature2_p: "복잡한 서류와 절차는 이제 그만! '내집구독'이 알려주는 대로 간편하게 신청만 하세요.",
            feature3_h3: '놓치지 않는 알림',
            feature3_p: '새로운 공고가 올라오면 놓치지 않도록 바로 알려드려요. 이제 청약홈만 바라보지 않아도 괜찮아요.',
            
            subscribe_h2: '지금 바로 구독하고 내집마련의 꿈을 현실로!',
            subscribe_p: '이메일과 핸드폰 번호를 입력해주시면, 맞춤형 주택 정보를 보내드립니다.',
            reviews_h2: '사용자 후기',
            reviews_p: "'내집구독'을 통해 내 집 마련의 꿈을 이룬 분들의 생생한 후기를 확인해보세요.",
            form_email: '이메일 주소',
            form_phone: '핸드폰 번호',
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
            form_success: '구독이 완료되었습니다!\n입력하신 정보로 맞춤형 주택 공고를 보내드릴게요.',
            form_error: '이메일과 핸드폰 번호를 정확히 입력해주세요.'
        },
        en: {
            logo: 'My Home Finder',
            nav_about: 'About',
            nav_subscribe: 'Subscribe',
            nav_faq: 'FAQ',
            nav_reviews: 'Reviews',
            nav_login: 'Login',
            hero_h1: 'Strategic Housing Solution for<br>Seoul/Gyeonggi 2030 Youth',
            hero_p: 'LH, SH, GH, Subscription Home... Tired of checking them every day?<br>AI monitors all announcements and delivers only the ones perfect for you.',
            hero_btn: 'Get Started Now',
            
            why_h2: 'Why My Home Finder?',
            why_p: 'Centralized housing information and automated eligibility checks.',
            why_item1_h3: 'LH·SH·GH Integrated',
            why_item1_p: 'No need to visit individual sites. We gather all public housing info in one place.',
            why_item2_h3: 'Optimized Matching',
            why_item2_p: 'We filter out only what you can apply for. Let AI handle complex criteria.',
            why_item3_h3: 'Real-time Alerts',
            why_item3_p: 'Instant notifications via email and SMS as soon as an announcement is posted.',

            table_h2: 'Manual Search vs My Home Finder',
            table_manual: 'Traditional Search',
            table_auto: 'My Home Finder',
            table_check_sites: 'Visit individual sites (LH, SH, GH, etc.)',
            table_check_auto: 'AI centralizes data from all platforms',
            table_qual_check: 'Manually calculate eligibility for each post',
            table_qual_auto: 'AI instantly determines eligibility for you',
            table_alert: 'Manual check required (missing deadlines common)',
            table_alert_auto: 'Instant push alerts for matching posts',

            about_h2: 'What is My Home Finder?',
            about_p: 'Housing in Seoul/Gyeonggi area - Don’t give up due to lack of information.<br>We categorize all government housing info including happiness and youth housing.',
            
            feature1_h3: 'AI-Based Custom Info',
            feature1_p: 'Enter your info, and AI analyzes eligibility to notify you via email and SMS.',
            feature2_h3: 'Easy Application Prep',
            feature2_p: 'Simple instructions for complex procedures and documents.',
            feature3_h3: 'Instant Alerts',
            feature3_p: "Immediate notification for new announcements. No more manual searching.",
            
            subscribe_h2: 'Subscribe Now and Make Your Dream a Reality!',
            subscribe_p: 'Enter your email and phone number for customized housing info.',
            reviews_h2: 'User Reviews',
            reviews_p: 'Real stories from those who found homes with My Home Finder.',
            form_email: 'Email Address',
            form_phone: 'Phone Number',
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
            form_success: 'Subscription complete!\nWe will send you customized housing announcements.',
            form_error: 'Please enter a valid email and phone number.'
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
            const subscribeSection = document.getElementById('subscribe');
            if (subscribeSection) {
                subscribeSection.scrollIntoView({ behavior: 'smooth' });
            }
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
            const email = document.getElementById('input-email').value;
            const phone = document.getElementById('input-phone').value;

            if (email && phone) {
                alert(translations[currentLang].form_success);
            } else {
                alert(translations[currentLang].form_error);
            }
        });
    }
});