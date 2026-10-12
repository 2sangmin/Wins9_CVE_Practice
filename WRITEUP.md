# WRITEUP — CVE-2026-21962

## 1. 취약점 개요
- **CVE:** CVE-2026-21962
- **대상:** Oracle HTTP Server / WebLogic Server Proxy Plug-in (`mod_wl_ohs`) 12.2.1.4.0
- **유형:** 부적절한 접근 제어 (Improper Access Control, CWE-284)
- **심각도:** CVSS 3.1 **10.0 (Critical)** — 네트워크 경유, 인증·사용자 개입 불필요
- **영향:** 프론트엔드(OHS)에서 차단되어야 할 보호 리소스에 비인가 접근(정보 유출)

## 2. 근본 원인 — URI 정규화 불일치
프론트엔드(OHS + `mod_wl_ohs`)와 백엔드(WebLogic)가 경로 세그먼트 **`..;` 를 서로 다르게 처리**한다.

- **OHS(프론트):** `..;` 를 그대로 둔다 → 요청 경로가 여전히 `/foo/...` 로 보여
  `<Location /foo>` 프록시 규칙에 매칭되고, `<Location /internal-admin>` 차단은 **적용되지 않는다.**
- **WebLogic(백엔드):** `;` 를 서블릿 경로 파라미터로 보고 제거 → `..` 로 정규화 →
  `/internal-admin/...` 으로 해석해 **보호 리소스를 응답한다.**

즉, 프론트엔드에만 걸려 있던 접근제어가 이 정규화 차이로 무력화된다.

## 3. 챌린지 환경
```
[솔버] → :10008 → [ohs-front: OHS 12.2.1.4.0 + mod_wl_ohs]
                        │  /foo → 프록시
                        ▼ :7101
                  [backend: 모의 WebLogic]
                   └ 보호 리소스 /internal-admin/cont/.env (FLAG + X-ORACLE-DMS 헤더)
```
- 플래그는 환경변수 `FLAG` 로 런타임 주입되어 보호 리소스에 기록된다(소스 하드코딩 없음).
- 백엔드는 응답에 `X-ORACLE-DMS-*` 헤더를 실어, "실제 백엔드 도달" 검증이 가능하게 한다.

## 4. 재현 (Vulnerable vs. 정상)
| 요청 | HTTP | 결과 |
|------|------|------|
| `GET /internal-admin/cont/.env` (직접) | **404** | 프론트 차단 ("OHS: Disallowed location") |
| `GET /foo/..;/internal-admin/cont/.env` (우회) | **200** | 보호 `.env` 유출 (FLAG 포함), `X-ORACLE-DMS-*` 헤더 확인 |

- 직접 경로가 404로 막히는 것이 접근제어가 살아있다는 증거이고, 우회 경로가 200으로 유출되는 것이 취약점 성립의 증거다.
- 같은 메커니즘의 변형들(예: `..%3b`, `..;jsessionid=...`, `%2e%2e;`)도 동일하게 성립한다.
- 참고: 1·2차 검증 자료(`analysis/`, `evidence/`)에 패치 환경과의 A/B 비교가 있다.

## 5. 풀이
```bash
python3 exploit/CVE-2026-21962.py -t http://127.0.0.1:10008 --auto-proxy --check ALL
```
- `--auto-proxy`: 프록시 접두사(`/foo`) 자동 탐지
- 우회로 보호된 `.env` 를 읽어 **FLAG = `WINS{...}`** 추출
- 백엔드 도달 여부는 응답의 `X-ORACLE-DMS-*` 헤더로 검증

## 6. 대응 방안
- **패치:** 2026년 1월 Oracle Critical Patch Update 적용
- **정규화 일관성:** 프론트/백엔드가 `..;`·인코딩 변형을 동일하게 처리하도록 정렬, 비정상 경로 거부
- **다중 방어:** 보호 경로를 프론트 규칙에만 의존하지 말고 백엔드에서도 인증·인가 수행

## 7. 참고
- NVD: https://nvd.nist.gov/vuln/detail/CVE-2026-21962
- Oracle CPU (Jan 2026): https://www.oracle.com/security-alerts/cpujan2026.html
