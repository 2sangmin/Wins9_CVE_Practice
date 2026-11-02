# =============================================================================
# CVE-2026-21962 — 단일 이미지 (GZCTF 동적 컨테이너용)
# =============================================================================
# GZCTF 동적 컨테이너는 "문제 1개 = 컨테이너 1개" 라서, 2개 컨테이너(OHS+백엔드)를
# 한 이미지로 합친다. 이미 배포 중인 OHS 이미지(cve-2026-21962-ohs-front)를
# 베이스로 재활용하므로 Oracle 설치본(.bin/.tar.gz)이 없어도 빌드된다.
#
# 빌드 (저장소 루트에서, 컨텍스트=루트):
#   docker build -f single/Dockerfile -t cve-2026-21962-single .
#
# ⚠️ 베이스 이미지가 로컬에 있어야 함:
#   docker images | findstr cve-2026-21962-ohs-front
#   없으면 먼저:  docker load -i 경로\cve-2026-21962-images.tar
# -----------------------------------------------------------------------------
FROM cve-2026-21962-ohs-front

# yum / python3 설치를 위해 root 로
USER root

# 백엔드 실행용 python3 (백엔드는 파이썬 표준 라이브러리만 사용)
RUN yum install -y python3 && yum clean all && rm -rf /var/cache/yum

# 백엔드 앱 (기존 backend/app.py 그대로 재사용 — 수정 없음)
COPY backend/app.py /app/app.py

# 단일 컨테이너용 설정: WebLogicHost 가 backend(별도 컨테이너) → 127.0.0.1(같은 컨테이너)
COPY single/httpd.conf /u01/oracle/httpd.conf

# 프로세스 매니저: 한 컨테이너에서 백엔드 + OHS 를 동시에 기동/감시
COPY single/run.sh /u01/oracle/run.sh
RUN chmod +x /u01/oracle/run.sh

# 백엔드 기본 포트(내부 전용). 바깥엔 OHS(7777)만 노출.
ENV BACKEND_PORT=7101

EXPOSE 7777

# 기존 OHS 이미지의 ENTRYPOINT(entrypoint.sh) 를 무시하고 프로세스 매니저로 교체
ENTRYPOINT []
CMD ["/u01/oracle/run.sh"]
