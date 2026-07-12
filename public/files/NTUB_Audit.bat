@echo off
chcp 65001 > nul

if "%~1"=="-NoQuickEdit" (
    reg add "HKCU\Console" /v "QuickEdit" /t REG_DWORD /d %2 /f >nul
    goto :main
)

for /f "tokens=3" %%a in ('reg query "HKCU\Console" /v "QuickEdit" 2^>nul') do set "OrigQE=%%a"
if "%OrigQE%"=="" set "OrigQE=1"
reg add "HKCU\Console" /v "QuickEdit" /t REG_DWORD /d 0 /f >nul

start "" cmd /c ""%~f0" -NoQuickEdit %OrigQE%"
exit

:main
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 【錯誤】此指令必須使用最高權限！請按右鍵選擇「以系統管理員身分執行」。
    echo.
    pause
    exit /b
)

echo ===================================================
echo     NTUB 2026 通識資安稽核一條龍 （Nasir)
echo ===================================================
echo.

echo [1/5] 正在強制檢查作業系統版本合規性...
echo ---------------------------------------------------
powershell -ExecutionPolicy Bypass -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host \"OS 名稱: $($os.Caption)\"; Write-Host \"OS 版本: $($os.Version)\"; [int]$build = $os.BuildNumber; if ($os.Caption -like '*Windows 10*' -and $build -lt 19045) { Write-Host '【重大資安風險警告】這台電腦的 Windows 10 版本太舊（低於 22H2）！' -ForegroundColor Red; Write-Host '後續的 Adobe Reader、Chrome 等軟體可能會因為 OS 限制而無法更新到最新安全版本！' -ForegroundColor Yellow; Write-Host '建議：檢測完畢後，此台電腦必須強制排程升級 OS。' -ForegroundColor White; } else { Write-Host '【OS 檢查通過】此電腦之作業系統版本支援最新安全軟體部署。' -ForegroundColor Green; }"
echo ---------------------------------------------------
echo 正在強制處理 Windows Update 異常並清除快取...
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop cryptSvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1

if exist "C:\Windows\SoftwareDistribution.old" rmdir /s /q "C:\Windows\SoftwareDistribution.old"
if exist "C:\Windows\System32\catroot2.old" rmdir /s /q "C:\Windows\System32\catroot2.old"

ren "C:\Windows\SoftwareDistribution" "SoftwareDistribution.old" >nul 2>&1
ren "C:\Windows\System32\catroot2" "catroot2.old" >nul 2>&1

net start wuauserv >nul 2>&1
net start bits >nul 2>&1
net start cryptSvc >nul 2>&1
net start msiserver >nul 2>&1

wuauclt /resetauthorizations /detectnow
usoclient StartInteractiveScan
echo 【完成】更新服務已強制重置。
echo ---------------------------------------------------

echo [2/5] 正在清查並強制取消所有本機帳號的「密碼永久有效」...
powershell -ExecutionPolicy Bypass -Command "$accounts = Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True and PasswordExpires=False'; if ($accounts) { foreach ($a in $accounts) { $a | Set-CimInstance -Property @{PasswordExpires=$true}; Write-Host ('已成功處理帳號：' + $a.Name + '（已取消密碼永久有效）') -ForegroundColor Green } } else { Write-Host '檢查完畢：本機所有帳號皆已符合密碼定期更改規範。' -ForegroundColor Cyan }"
echo ---------------------------------------------------

echo [3/5] 正在清查內建高風險帳號停用狀態 (Administrator / Guest)...
powershell -ExecutionPolicy Bypass -Command "$admin = Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True' | Where-Object { $_.SID -like '*-500' }; if ($admin -and $admin.Disabled -eq $false) { $admin | Set-CimInstance -Property @{Disabled=$true}; Write-Host ('[警告] 偵測到內建管理員帳號 [' + $admin.Name + '] 為啟用狀態，已強制將其【停用】！') -ForegroundColor Yellow } elseif ($admin) { Write-Host ('[安全] 內建管理員帳號 [' + $admin.Name + '] 本來就已停用，無需動作。') -ForegroundColor Green }; $guest = Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True' | Where-Object { $_.SID -like '*-501' }; if ($guest -and $guest.Disabled -eq $false) { $guest | Set-CimInstance -Property @{Disabled=$true}; Write-Host ('[警告] 偵測到來賓帳號 [' + $guest.Name + '] 為啟用狀態，已強制將其【停用】！') -ForegroundColor Yellow } elseif ($guest) { Write-Host ('[安全] 來賓帳號 [' + $guest.Name + '] 本來就已停用，無需動作。') -ForegroundColor Green }"
echo ---------------------------------------------------

echo [4/5] 正在智慧盤點並更新高風險應用軟體...
echo.

set "hasChrome=0"
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" set "hasChrome=1"
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" set "hasChrome=1"
if "%hasChrome%"=="1" (
    echo [偵測到 Chrome] 正在強制背景更新...
    winget upgrade --id Google.Chrome --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
) else (
    echo [安全跳過] 本機未安裝 Google Chrome，無需處理。
)

if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    echo [偵測到 Edge] 正在強制背景更新...
    winget upgrade --id Microsoft.Edge --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
) else (
    echo [安全跳過] 本機未安裝 Microsoft Edge，無需處理。
)

set "hasAdobe=0"
if exist "C:\Program Files\Adobe" set "hasAdobe=1"
if exist "C:\Program Files (x86)\Adobe" set "hasAdobe=1"
if "%hasAdobe%"=="1" (
    echo [偵測到 Adobe Reader] 正在強制背景更新...
    winget upgrade --id Adobe.Acrobat.Reader.64bit --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
    winget upgrade --id Adobe.Acrobat.Reader.32bit --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
) else (
    echo [安全跳過] 本機未安裝 Adobe Acrobat Reader，無需處理。
)

winget list --name "Java" --accept-source-agreements >nul 2>&1
if %errorLevel% equ 0 (
    echo [警告：偵測到 Java] 正在強制將現有 Java 背景更新至安全版本...
    winget upgrade --id Oracle.JavaRuntimeEnvironment --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
) else (
    echo [安全過關] 本機沒有安裝 Java！
)

echo.
echo ===================================================
echo   所有資安強制防護與盤點任務已執行完畢！
echo ===================================================
pause