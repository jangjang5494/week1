
document.addEventListener('DOMContentLoaded', () => {
    const startButton = document.querySelector('.hero-content button');
    if (startButton) {
        startButton.addEventListener('click', () => {
            alert('내집마련 서비스에 오신 것을 환영합니다!\n곧 서비스가 출시될 예정입니다.');
        });
    }

    const subscribeForm = document.querySelector('.subscribe form');
    if (subscribeForm) {
        subscribeForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const job = document.querySelector('input[placeholder="직업"]').value;
            const salary = document.querySelector('input[placeholder="연봉 (만원)"]').value;
            const assets = document.querySelector('input[placeholder="자산 (만원)"]').value;

            if (job && salary && assets) {
                alert(`입력하신 정보:\n- 직업: ${job}\n- 연봉: ${salary}만원\n- 자산: ${assets}만원\n\n내집마련 서비스가 당신에게 맞는 집을 찾아드리겠습니다!`);
            } else {
                alert('모든 정보를 입력해주세요.');
            }
        });
    }
});
