#!/bin/sh
# =============================================================================
# CVE-2026-21962 — 단일 컨테이너 프로세스 매니저
# =============================================================================
# 한 컨테이너 안에서 두 프로세스를 함께 실행/감시한다 (운영진 요구: "프로세스 매니저"):
#   1) 백엔드(python)  : 127.0.0.1:7101  — 죽으면 자동 재시작
#   2) OHS httpd       : 0.0.0.0:7777    — 컨테이너 메인 프로세스(포그라운드)
# OHS 가 죽으면 컨테이너가 종료되고, GZCTF 가 인스턴스를 새로 띄운다.
# =============================================================================
set -u

export ORACLE_HOME=/u01/oracle/ohs
# OHS 모듈(.so)이 의존하는 Oracle 라이브러리 경로 (기존 entrypoint.sh 와 동일)
export LD_LIBRARY_PATH="/u01/oracle/ohs/ohs/lib:/u01/oracle/ohs/lib:/u01/oracle/ohs/oracle_common/lib:/u01/oracle/ohs/wlserver/server/native/linux/x86_64:/u01/oracle/ohs/webgate/ohs/lib:${LD_LIBRARY_PATH:-}"

HTTPD=/u01/oracle/ohs/ohs/bin/httpd
CONF=/u01/oracle/httpd.conf
DOCROOT=/u01/oracle/htdocs

# ---- 랜딩 페이지 생성 (healthcheck 통과 + 솔버 안내) ----
mkdir -p "$DOCROOT"
cat > "$DOCROOT/index.html" <<'HTML'
<!doctype html><html lang="ko"><meta charset="utf-8">
<title>CVE-2026-21962 Challenge</title>
<body style="font-family:sans-serif;max-width:640px;margin:60px auto;padding:0 16px">
<h1>CVE-2026-21962 — OHS Access-Control Bypass</h1>
<p>Oracle HTTP Server 12.2.1.4.0 (mod_wl_ohs) 접근제어 우회 챌린지.</p>
<p>보호된 백엔드 리소스에 도달해 플래그 <code>WINS{...}</code> 를 획득하세요.</p>
</body></html>
HTML

# ---- 1) 백엔드: 백그라운드 + 죽으면 재시작 ----
#   GZCTF_FLAG / FLAG 환경변수는 컨테이너 → run.sh → python 으로 그대로 상속됨.
(
  while true; do
    echo "[pm] starting backend (:7101)"
    python3 /app/app.py
    echo "[pm] backend exited (code $?). restart in 2s"
    sleep 2
  done
) &

# 백엔드가 포트를 열 때까지 잠깐 대기 (OHS 첫 프록시 연결 안정화)
sleep 1

# ---- 2) OHS httpd: 포그라운드 = 컨테이너 메인 프로세스 ----
echo "[pm] starting OHS httpd (:7777, foreground)"
exec "$HTTPD" -f "$CONF" -DFOREGROUND
