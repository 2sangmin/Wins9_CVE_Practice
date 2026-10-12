# 가벼운 모의 백엔드 — 의존성 없음(파이썬 표준 라이브러리만), 런타임 다운로드 없음(규칙11)
# 규칙7: 태그 고정 (latest 금지)
FROM python:3.12-slim

WORKDIR /app
COPY app.py /app/app.py

ENV BACKEND_PORT=7101
# FLAG 는 compose 에서 런타임 주입 (하드코딩 금지 — 규칙3)
EXPOSE 7101
USER nobody
CMD ["python3", "app.py"]
