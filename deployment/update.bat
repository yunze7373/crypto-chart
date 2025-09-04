@echo off
:: CryptoChart Pro Windows 更新脚本
:: 适用于 Windows 环境的更新部署

setlocal enabledelayedexpansion

:: 配置变量
set APP_DIR=%~dp0..
set PYTHON_EXE=python
set SERVICE_NAME=CryptoChart

:: 颜色设置 (Windows 10+)
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"
set "NC=%ESC%[0m"

:: 日志函数
:log
echo %BLUE%[%date% %time%]%NC% %~1
goto :eof

:success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:error
echo %RED%[ERROR]%NC% %~1
exit /b 1

:: 检查管理员权限
:check_admin
net session >nul 2>&1
if %errorLevel% == 0 (
    call :log "检测到管理员权限"
) else (
    call :warning "建议以管理员身份运行以获得完整功能"
)
goto :eof

:: 检查Python环境
:check_python
call :log "检查Python环境..."
%PYTHON_EXE% --version >nul 2>&1
if %errorLevel% neq 0 (
    call :error "Python 未安装或不在PATH中"
)
call :success "Python 环境正常"
goto :eof

:: 创建备份
:create_backup
call :log "创建备份..."

set BACKUP_DIR=%APP_DIR%\backups\%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set BACKUP_DIR=%BACKUP_DIR: =0%

mkdir "%BACKUP_DIR%" 2>nul

:: 备份数据库
if exist "%APP_DIR%\instance\crypto_alerts.db" (
    copy "%APP_DIR%\instance\crypto_alerts.db" "%BACKUP_DIR%\crypto_alerts.db.backup" >nul
    call :success "数据库备份完成"
)

:: 备份配置文件
if exist "%APP_DIR%\.env" (
    copy "%APP_DIR%\.env" "%BACKUP_DIR%\.env.backup" >nul
)

call :success "备份创建完成: %BACKUP_DIR%"
goto :eof

:: 停止服务
:stop_service
call :log "停止现有服务..."

:: 尝试停止Windows服务（如果存在）
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorLevel% == 0 (
    call :log "停止Windows服务: %SERVICE_NAME%"
    sc stop "%SERVICE_NAME%" >nul 2>&1
    timeout /t 5 /nobreak >nul
)

:: 强制终止Python进程
tasklist | findstr "python" >nul 2>&1
if %errorLevel% == 0 (
    call :log "终止Python进程..."
    taskkill /f /im python.exe >nul 2>&1
)

call :success "服务停止完成"
goto :eof

:: 更新代码
:update_code
call :log "更新应用代码..."

cd /d "%APP_DIR%"

:: 检查Git仓库
if exist ".git" (
    call :log "从Git仓库更新..."
    git stash >nul 2>&1
    git pull origin main
    if %errorLevel% neq 0 (
        call :error "Git更新失败"
    )
    call :success "代码更新完成"
) else (
    call :warning "未检测到Git仓库，请手动更新代码"
)
goto :eof

:: 更新依赖
:update_dependencies
call :log "更新Python依赖..."

cd /d "%APP_DIR%"

:: 升级pip
%PYTHON_EXE% -m pip install --upgrade pip

:: 安装依赖
%PYTHON_EXE% -m pip install -r requirements.txt --upgrade
if %errorLevel% neq 0 (
    call :error "依赖安装失败"
)

call :success "依赖更新完成"
goto :eof

:: 数据库检查
:check_database
call :log "检查数据库..."

if exist "%APP_DIR%\instance\crypto_alerts.db" (
    call :success "数据库文件存在，无需迁移"
) else (
    call :log "将创建新数据库"
)
goto :eof

:: 测试应用
:test_application
call :log "测试应用启动..."

cd /d "%APP_DIR%\src"

:: 启动应用进行测试
start /b "" %PYTHON_EXE% app.py

:: 等待启动
timeout /t 10 /nobreak >nul

:: 测试健康检查
curl -f http://localhost:5008/health >nul 2>&1
if %errorLevel% == 0 (
    call :success "应用测试成功"
    :: 停止测试进程
    taskkill /f /im python.exe >nul 2>&1
) else (
    call :error "应用测试失败，请检查日志"
)
goto :eof

:: 启动服务
:start_service
call :log "启动服务..."

cd /d "%APP_DIR%\src"

:: 检查是否有Windows服务配置
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorLevel% == 0 (
    call :log "启动Windows服务: %SERVICE_NAME%"
    sc start "%SERVICE_NAME%"
) else (
    call :log "以进程方式启动应用"
    start /b "" %PYTHON_EXE% app.py
)

timeout /t 5 /nobreak >nul
call :success "服务启动完成"
goto :eof

:: 验证更新
:verify_update
call :log "验证更新结果..."

:: 多次尝试健康检查
for /l %%i in (1,1,10) do (
    curl -f http://localhost:5008/health >nul 2>&1
    if !errorLevel! == 0 (
        call :success "健康检查通过"
        goto :verify_api
    )
    call :log "等待服务启动... (%%i/10)"
    timeout /t 2 /nobreak >nul
)

call :error "健康检查失败"

:verify_api
:: 测试API功能
curl -f http://localhost:5008/api/monitor/status >nul 2>&1
if %errorLevel% == 0 (
    call :success "API功能正常"
) else (
    call :warning "API功能可能异常"
)

call :log "应用地址: http://localhost:5008"
goto :eof

:: 清理旧备份
:cleanup
call :log "清理旧备份文件..."

:: 删除7天前的备份
forfiles /p "%APP_DIR%\backups" /s /m *.* /d -7 /c "cmd /c del @path" >nul 2>&1

call :success "清理完成"
goto :eof

:: 主函数
:main
echo.
echo ========================================
echo   CryptoChart Pro v2.0 Windows 更新
echo ========================================
echo.

call :check_admin
call :check_python
call :create_backup
call :stop_service
call :update_code
call :update_dependencies
call :check_database
call :test_application
call :start_service
call :verify_update
call :cleanup

echo.
call :success "🎉 CryptoChart Pro 更新到 v2.0 完成！"
echo.
echo 应用地址: http://localhost:5008
echo 健康检查: http://localhost:5008/health
echo.

pause
goto :eof

:: 显示帮助
:show_help
echo CryptoChart Pro Windows 更新脚本
echo.
echo 用法: update.bat [选项]
echo.
echo 选项:
echo   /help      显示此帮助信息
echo   /test      仅测试，不实际更新
echo.
echo 示例:
echo   update.bat           执行完整更新
echo   update.bat /test     测试模式
echo.
goto :eof

:: 测试模式
:test_mode
echo.
echo ========================================
echo      测试模式 - 预览更新步骤
echo ========================================
echo.
echo 将执行以下步骤:
echo 1. 检查环境
echo 2. 创建备份
echo 3. 停止服务
echo 4. 更新代码
echo 5. 更新依赖
echo 6. 检查数据库
echo 7. 测试应用
echo 8. 启动服务
echo 9. 验证更新
echo 10. 清理
echo.
echo 注意: 测试模式不会实际执行更新操作
echo.
pause
goto :eof

:: 参数处理
if "%1"=="/help" goto :show_help
if "%1"=="--help" goto :show_help
if "%1"=="/?" goto :show_help
if "%1"=="/test" goto :test_mode
if "%1"=="--test" goto :test_mode

:: 执行主函数
call :main
