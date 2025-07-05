@echo off
:: =============================================================================
:: Sistema de Monitoramento Anti-Travamento para Windows - Launcher
:: =============================================================================

setlocal enabledelayedexpansion

:: Configurações
set SCRIPT_NAME=Anti-FreezeMonitor.ps1
set SCRIPT_PATH=%~dp0%SCRIPT_NAME%

:: Cores para output
for /f %%A in ('"prompt $H &echo on &for %%B in (1) do rem"') do set BS=%%A

:: Função para mostrar mensagem colorida
echo.
echo [92m=== Sistema Anti-Travamento para Windows ===[0m
echo.

:: Verifica se o PowerShell está disponível
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo [91mERRO: PowerShell nao encontrado![0m
    echo Este script requer PowerShell para funcionar.
    pause
    exit /b 1
)

:: Verifica se o script PowerShell existe
if not exist "%SCRIPT_PATH%" (
    echo [91mERRO: Arquivo %SCRIPT_NAME% nao encontrado![0m
    echo Certifique-se de que ambos os arquivos estao na mesma pasta.
    pause
    exit /b 1
)

:: Verifica se está executando como administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [93mEste script precisa ser executado como Administrador![0m
    echo.
    echo [96mPor favor:[0m
    echo 1. Feche esta janela
    echo 2. Clique com o botao direito neste arquivo
    echo 3. Selecione "Executar como administrador"
    echo.
    pause
    exit /b 1
)

:: Menu principal
:MENU
cls
echo.
echo [92m=== Sistema Anti-Travamento para Windows ===[0m
echo.
echo [96mEscolha uma opcao:[0m
echo.
echo [93m1.[0m Executar monitoramento (com notificacoes)
echo [93m2.[0m Executar monitoramento (sem notificacoes)
echo [93m3.[0m Instalar como servico do Windows
echo [93m4.[0m Gerenciar servico
echo [93m5.[0m Ver logs
echo [93m6.[0m Ajuda
echo [93m7.[0m Sair
echo.
set /p choice=[96mOpcao (1-7): [0m

if "%choice%"=="1" goto RUN_NORMAL
if "%choice%"=="2" goto RUN_NO_NOTIFICATIONS
if "%choice%"=="3" goto INSTALL_SERVICE
if "%choice%"=="4" goto MANAGE_SERVICE
if "%choice%"=="5" goto VIEW_LOGS
if "%choice%"=="6" goto SHOW_HELP
if "%choice%"=="7" goto EXIT

echo [91mOpcao invalida![0m
timeout /t 2 >nul
goto MENU

:RUN_NORMAL
cls
echo [92mIniciando monitoramento com notificacoes...[0m
echo [93mPressione Ctrl+C para parar[0m
echo.
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
pause
goto MENU

:RUN_NO_NOTIFICATIONS
cls
echo [92mIniciando monitoramento sem notificacoes...[0m
echo [93mPressione Ctrl+C para parar[0m
echo.
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -NoNotifications
pause
goto MENU

:INSTALL_SERVICE
cls
echo [92mInstalando como servico do Windows...[0m
echo.
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -Install
echo.
echo [96mServico instalado! Use a opcao 4 para gerenciar.[0m
pause
goto MENU

:MANAGE_SERVICE
cls
echo [92m=== Gerenciamento do Servico ===[0m
echo.
echo [96mEscolha uma opcao:[0m
echo.
echo [93m1.[0m Iniciar servico
echo [93m2.[0m Parar servico
echo [93m3.[0m Status do servico
echo [93m4.[0m Desinstalar servico
echo [93m5.[0m Voltar ao menu principal
echo.
set /p service_choice=[96mOpcao (1-5): [0m

if "%service_choice%"=="1" (
    echo [92mIniciando servico...[0m
    powershell.exe -Command "Start-Service -Name AntiFreeze"
    echo [96mServico iniciado![0m
    pause
)
if "%service_choice%"=="2" (
    echo [92mParando servico...[0m
    powershell.exe -Command "Stop-Service -Name AntiFreeze -Force"
    echo [96mServico parado![0m
    pause
)
if "%service_choice%"=="3" (
    echo [92mStatus do servico:[0m
    powershell.exe -Command "Get-Service -Name AntiFreeze"
    pause
)
if "%service_choice%"=="4" (
    echo [92mDesinstalando servico...[0m
    powershell.exe -Command "Stop-Service -Name AntiFreeze -Force -ErrorAction SilentlyContinue; & sc.exe delete AntiFreeze"
    echo [96mServico desinstalado![0m
    pause
)
if "%service_choice%"=="5" goto MENU

goto MANAGE_SERVICE

:VIEW_LOGS
cls
echo [92m=== Visualizando Logs ===[0m
echo.
if exist "%TEMP%\anti-freeze.log" (
    type "%TEMP%\anti-freeze.log"
) else (
    echo [93mNenhum log encontrado ainda.[0m
    echo Execute o monitoramento primeiro para gerar logs.
)
echo.
pause
goto MENU

:SHOW_HELP
cls
echo [92m=== Sistema Anti-Travamento - Ajuda ===[0m
echo.
echo [96mO que faz:[0m
echo - Monitora o sistema em tempo real
echo - Detecta travamentos automaticamente
echo - Encerra processos problematicos
echo - Libera memoria cache quando necessario
echo - Mostra notificacoes sobre as acoes
echo.
echo [96mConfiguracao:[0m
echo - Threshold CPU: 80%%
echo - Threshold Memoria: 15%%
echo - Timeout travamento: 5 segundos
echo - Intervalo verificacao: 1 segundo
echo.
echo [96mProcessos Protegidos:[0m
echo - System, csrss, winlogon, services
echo - lsass, explorer, dwm, svchost
echo.
echo [96mLogs salvos em:[0m
echo %TEMP%\anti-freeze.log
echo.
pause
goto MENU

:EXIT
echo [92mObrigado por usar o Sistema Anti-Travamento![0m
exit /b 0
