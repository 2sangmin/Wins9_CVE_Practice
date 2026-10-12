#!/bin/sh
# =============================================================================
# OHS 프론트 기동 — httpd 직접 포그라운드 실행 (도메인/NodeManager 불필요)
# =============================================================================
set -eu

export ORACLE_HOME=/u01/oracle/ohs
# OHS 모듈(.so)이 의존하는 Oracle 라이브러리 경로
export LD_LIBRARY_PATH="/u01/oracle/ohs/ohs/lib:/u01/oracle/ohs/lib:/u01/oracle/ohs/oracle_common/lib:/u01/oracle/ohs/wlserver/server/native/linux/x86_64:/u01/oracle/ohs/webgate/ohs/lib:${LD_LIBRARY_PATH:-}"

HTTPD=/u01/oracle/ohs/ohs/bin/httpd
CONF=/u01/oracle/httpd.conf
DOCROOT=/u01/oracle/htdocs

# 랜딩 페이지 생성 (healthcheck 통과 + 솔버 안내)
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

echo "[ohs] starting httpd on :7777 (foreground)"
exec "$HTTPD" -f "$CONF" -DFOREGROUND
