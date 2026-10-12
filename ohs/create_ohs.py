# =============================================================================
# OHS 12.2.1.4 스탠드얼론 인스턴스 생성 (WLST) — 환경에서 검증/보완 필요
# =============================================================================
# 솔직히 안내: OHS 스탠드얼론 인스턴스 생성 API 는 설치 구성에 따라 조금씩 달라서,
# "무조건 되는" 코드를 장담하기 어렵습니다. 가장 확실한 두 가지 길:
#
#   (A) [권장] 저번에 받은 Oracle 공식 컨테이너 스크립트 재사용
#       C:\SecuritySpace\docker-images-main\OracleHTTPServer\  안의
#       container-scripts / createDomain 스크립트가 Oracle이 테스트한 방식입니다.
#       그걸 Dockerfile 에서 호출하도록 바꾸는 게 제일 안전합니다.
#
#   (B) config 툴로 직접 생성 후, 결과 도메인을 그대로 사용
#       $ORACLE_HOME/oracle_common/common/bin/config.sh (GUI) 로 한 번 만들어 보고,
#       거기서 쓰인 설정을 이 스크립트/Dockerfile 에 반영.
#
# 아래는 WLST 표준 흐름의 뼈대입니다. 실행해보고 에러 나는 줄을 저한테 주시면
# 환경에 맞게 같이 고쳐드릴게요.
# -----------------------------------------------------------------------------
import os

ORACLE_HOME = os.environ['ORACLE_HOME']
DOMAIN_HOME = os.environ['DOMAIN_HOME']
INSTANCE    = os.environ.get('OHS_INSTANCE', 'ohs1')
OHS_PORT    = int(os.environ.get('OHS_PORT', '7777'))

# 스탠드얼론 OHS 템플릿 선택 → 도메인 생성 → OHS 인스턴스 추가 → 저장
#   (버전에 따라 createOHSInstance() 시그니처가 다를 수 있음 — 검증 포인트)
selectTemplate('Oracle HTTP Server (Standalone)')
loadTemplates()

# 노드매니저 자격증명(스탠드얼론 필수) — CTF 용 간단 값
cd('/')
# TODO(검증): 아래 한 줄은 환경에 따라 createOHSInstance 또는 SystemComponent 생성으로.
# createOHSInstance(name=INSTANCE, listenAddress='', listenPort=OHS_PORT)

setOption('NodeManagerType', 'PerDomainNodeManager')
# setOption 등 자격/포트 설정 ...

writeDomain(DOMAIN_HOME)
closeTemplate()
print(">> domain written to %s (인스턴스/포트 설정은 검증하세요)" % DOMAIN_HOME)
exit()
