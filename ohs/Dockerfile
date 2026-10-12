# =============================================================================
# OHS 프론트엔드 (진짜 취약 버전) — Oracle HTTP Server 12.2.1.4.0
# =============================================================================
# 저번 프로젝트의 동작하는 설치 Dockerfile
#   (C:\SecuritySpace\docker-images-main\OracleHTTPServer\dockerfiles\12.2.1.4.0\Dockerfile)
# 을 기반으로, CTF 용 "인스턴스 생성 + 취약 프록시 설정 + 포그라운드 기동" 을 덧붙인 버전.
#
# ⚠️ 빌드 전 준비: 아래 두 설치본을 이 ohs/ 폴더에 복사해 두세요 (.gitignore 로 커밋 차단됨)
#     - fmw_12.2.1.4.0_ohs_linux64.bin
#     - jdk-8u202-linux-x64.tar.gz
# -----------------------------------------------------------------------------
# 규칙7: 태그 고정 (latest 금지)
FROM oraclelinux:7-slim

RUN yum install -y tar gzip hostname shadow-utils curl libaio && yum clean all && \
    groupadd -g 1000 oinstall && \
    useradd -u 1000 -g oinstall -m -s /bin/bash oracle

ENV ORACLE_HOME=/u01/oracle/ohs \
    JAVA_HOME=/u01/oracle/jdk \
    PATH=/u01/oracle/jdk/bin:$PATH \
    DOMAIN_HOME=/u01/oracle/domain \
    OHS_INSTANCE=ohs1 \
    OHS_PORT=7777

RUN mkdir -p /u01/oracle && chown -R oracle:oinstall /u01/oracle
WORKDIR /u01/oracle

COPY jdk-8u202-linux-x64.tar.gz /tmp/
COPY fmw_12.2.1.4.0_ohs_linux64.bin /tmp/
RUN chown oracle:oinstall /tmp/jdk-8u202-linux-x64.tar.gz /tmp/fmw_12.2.1.4.0_ohs_linux64.bin && \
    chmod +x /tmp/fmw_12.2.1.4.0_ohs_linux64.bin

USER oracle

# ---- JDK + OHS 사일런트 설치 (저번 Dockerfile 과 동일) -------------------------
RUN tar -xzf /tmp/jdk-8u202-linux-x64.tar.gz -C /u01/oracle && \
    mv /u01/oracle/jdk1.8.0_202 /u01/oracle/jdk && \
    rm /tmp/jdk-8u202-linux-x64.tar.gz

RUN echo "[ENGINE]"                                                             >  /tmp/ohs.rsp && \
    echo "Response File Version=1.0.0.0.0"                                      >> /tmp/ohs.rsp && \
    echo ""                                                                     >> /tmp/ohs.rsp && \
    echo "[GENERIC]"                                                            >> /tmp/ohs.rsp && \
    echo "ORACLE_HOME=/u01/oracle/ohs"                                          >> /tmp/ohs.rsp && \
    echo "INSTALL_TYPE=Standalone HTTP Server (Managed independently of WebLogic server)" >> /tmp/ohs.rsp && \
    echo "DECLINE_AUTO_UPDATES=true"                                            >> /tmp/ohs.rsp && \
    echo "inventory_loc=/u01/oracle/oraInventory"                              >  /tmp/oraInst.loc && \
    echo "inst_group=oinstall"                                                  >> /tmp/oraInst.loc && \
    /tmp/fmw_12.2.1.4.0_ohs_linux64.bin -silent -responseFile /tmp/ohs.rsp -invPtrLoc /tmp/oraInst.loc -jreLoc "$JAVA_HOME" -ignoreSysPrereqs ; \
    echo "===== OHS install log tail =====" ; cat /tmp/OraInstall*/install*.log 2>/dev/null | tail -30 ; \
    test -d /u01/oracle/ohs && rm /tmp/fmw_12.2.1.4.0_ohs_linux64.bin

# ---- CTF 구동 설정: OHS Apache(httpd) 직접 기동 (도메인/NodeManager 불필요) ----
# 취약 설정(mod_wl_ohs 프록시 + /internal-admin 차단)은 httpd.conf 안에 포함.
COPY --chown=oracle:oinstall httpd.conf    /u01/oracle/httpd.conf
COPY --chown=oracle:oinstall entrypoint.sh /u01/oracle/entrypoint.sh
RUN chmod +x /u01/oracle/entrypoint.sh

EXPOSE 7777
ENTRYPOINT ["/u01/oracle/entrypoint.sh"]
