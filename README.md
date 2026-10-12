# CVE-2026-21962 — OHS Access-Control Bypass CTF Challenge

> 윈스테크넷 9기 CTF 3차 — 도커 환경 구축 / 배정 포트 **10008**
> 대상: Oracle HTTP Server **12.2.1.4.0** (+ mod_wl_ohs 프록시 플러그인)

## 취약점 한 줄 요약
OHS(프론트)와 백엔드가 `..;` 를 다르게 정규화해서, `<Location /internal-admin>`
차단을 우회(`/foo/..;/internal-admin/cont/.env`)해 보호 리소스에 접근하는
**접근제어 우회(CWE-284, CVSS 10.0)**.

## 구조 (컨테이너 2개)
```
[솔버] → :10008 → [ohs-front : 진짜 취약 OHS 12.2.1.4.0]
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
├── .gitignore
├── ohs/                      # 프론트 OHS (진짜 취약 버전)
│   ├── Dockerfile            # 저번 설치 Dockerfile 기반 + 인스턴스/설정/기동
│   ├── entrypoint.sh
│   ├── create_ohs.py         # 인스턴스 생성 (환경에서 검증 필요)
│   ├── conf/mod_wl_ohs.conf  # 취약 프록시 설정 (트리거)
│   └── (설치본 2개 여기 복사: fmw_...ohs...bin, jdk-8u202...tar.gz)  ← gitignore
├── backend/                 # 가벼운 모의 백엔드 (완성, 테스트됨)
│   ├── Dockerfile
│   └── app.py
└── exploit/
    └── README.md            # 검증된 PoC(CVE-2026-21962.py) 여기 복사
```

## 빌드 & 실행
```bash
# 1) ohs/ 에 설치본 2개 복사 (fmw_12.2.1.4.0_ohs_linux64.bin, jdk-8u202-linux-x64.tar.gz)
# 2) exploit/ 에 CVE-2026-21962.py 복사
# 3) 실제 플래그는 커밋하지 말고 실행 시점에만 주입
FLAG='WINS{여기_실제_플래그}' docker compose up -d --build

docker compose ps
docker compose logs -f
```

## 풀이 검증 (규칙8)
```bash
python3 exploit/CVE-2026-21962.py -t http://127.0.0.1:10008 --auto-proxy --check ALL
# => 보호된 .env 의 WINS{...} 가 유출되면 완료
```

## 지금 완성 / 남은 작업
| 부분 | 상태 |
|------|------|
| 백엔드(app.py, Dockerfile) | ✅ 완성 + 테스트됨 (우회 변형 5종 통과) |
| 취약 프록시 설정(mod_wl_ohs.conf) | ✅ README 트리거 그대로 |
| compose / 포트 / 메모리 / 플래그 주입 | ✅ 완성 |
| exploit | ✅ 저번 PoC 복사만 하면 됨 |
| **OHS 인스턴스 생성 + 포그라운드 기동** | ⚠️ 본인 환경에서 마무리/검증 (ohs/Dockerfile, create_ohs.py, entrypoint.sh 의 TODO) |

→ 마지막 OHS 기동 부분에서 에러가 나면 **그 메시지를 그대로** 주세요. 같이 고쳐드립니다.

## 제출 전 체크리스트
- [ ] 바깥 포트 10008, 백엔드 내부 전용
- [ ] 플래그 `WINS{...}`, 환경변수 주입, 실제 플래그/설치본 커밋 안 함
- [ ] `privileged`/`docker.sock`/`/:/host` 미사용
- [ ] 이미지 태그 고정, 런타임 외부 다운로드 없음
- [ ] `docker compose up -d --build` 한 번에 기동
- [ ] exploit 으로 플래그 획득 확인
- [ ] (컨테이너 2개 구성을 반장님께 한 번 확인 — 보통 OK)
- [ ] 깃허브 레포 URL 시트 작성 + [도커 제작 완료] 체크
