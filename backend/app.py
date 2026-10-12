#!/usr/bin/env python3
"""
CVE-2026-21962 CTF — 가벼운 모의 백엔드 (의존성 없음, 파이썬 표준 라이브러리만)
================================================================================
역할: OHS(프론트) 뒤에서 "보호된 리소스" /internal-admin/cont/.env 를 제공.
 - 플래그는 환경변수 FLAG 로 주입 (하드코딩/커밋 금지 — 규칙3)
 - 응답에 X-ORACLE-DMS-* 헤더를 실어 "진짜 백엔드"처럼 보이게 함
   (가진 exploit 이 이 헤더로 백엔드 도달을 검증하므로 필수)
 - 경로 정규화: 세그먼트의 ';' 파라미터 제거 후 '.'/'..' 수축
   → OHS 가 흘려보낸 /foo/../internal-admin/... 이 /internal-admin/... 으로 귀결

이 파일 자체에는 공격 코드가 없습니다. 평범한 백엔드 웹서버입니다.
"""
import os
import sys
import posixpath
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FLAG = os.environ.get("FLAG", "WINS{placeholder}")
BACKEND_PORT = int(os.environ.get("BACKEND_PORT", "7101"))
PROTECTED = "/internal-admin/cont/.env"

# 보호된 .env 내용 (가짜 크레덴셜 + 플래그)
ENV_BODY = (
    "# internal-admin service config (fabricated for CTF)\n"
    "APP_ENV=production\n"
    "DB_HOST=10.0.0.5\n"
    "DB_USER=svc_admin\n"
    f"DB_PASSWORD={FLAG}\n"
).encode()


def normalize(raw_path: str) -> str:
    """WebLogic 식 정규화: 세그먼트별 ';' 이후 제거 → '.'/'..' 수축."""
    path = urllib.parse.unquote(raw_path)
    segs = [seg.split(";", 1)[0] for seg in path.split("/")]
    return posixpath.normpath("/".join(segs) or "/")


class Handler(BaseHTTPRequestHandler):
    server_version = "WebLogicServer/12.2.1.4.0"

    def _dms_headers(self):
        self.send_header("X-ORACLE-DMS-ECID", "ctf-0000000000000001")
        self.send_header("X-ORACLE-DMS-RID", "0")

    def do_GET(self):
        raw = self.path.split("?", 1)[0]
        norm = normalize(raw)
        sys.stderr.write(f"[backend] {self.path}  ->  {norm}\n")

        if norm == PROTECTED:
            body, code = ENV_BODY, 200
        elif norm in ("/", "/foo", "/foo/"):
            body, code = b"backend ok\n", 200
        else:
            body, code = b"not found\n", 404

        self.send_response(code)
        self._dms_headers()
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass  # 접근 로그는 do_GET 에서 직접 출력


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", BACKEND_PORT), Handler)
    sys.stderr.write(f"[backend] listening on :{BACKEND_PORT}\n")
    srv.serve_forever()
