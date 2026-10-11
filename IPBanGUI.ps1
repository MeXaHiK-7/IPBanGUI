# ==============================================================================
# IPBan Manager & Control Center (GUI)
# Повнофункціональний графічний інтерфейс для керування DigitalRuby IPBan Free
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------------------------------------------------------
# Глобальні змінні та стан
# ------------------------------------------------------------------------------
$script:DefaultInstallPath = "C:\Program Files\IPBan"
$script:CurrentInstallPath = $script:DefaultInstallPath
$script:ServiceName = "IPBan"
$script:LocalZipBackup = $null
$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$script:AutoRefreshTimer = $null
$script:LastBannedIPs = @()
$script:TrayIcon = $null
$script:TrayMenu = $null
$script:CurrentTrayState = ""
$script:PreviousBannedCount = -1
$script:AlertActive = $false
$script:AlertResetTimer = $null
$script:TrayMonitorTimer = $null
$script:IsExiting = $false
$script:ManualBanTimes = @{}
$script:CurrentBanTimeSetting = "01:00:00:00"

# Підтримка читання бази ipban.sqlite через вбудований у Windows winsqlite3.dll
$script:HasWinSqlite = (Test-Path "$env:windir\System32\winsqlite3.dll")
if ($script:HasWinSqlite -and -not ([System.Management.Automation.PSTypeName]'IPBanSqlite').Type) {
    try {
        $csSqlite = @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class IPBanSqlite {
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open16", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    private static extern int sqlite3_open16(string filename, out IntPtr db);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_prepare16_v2", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    private static extern int sqlite3_prepare16_v2(IntPtr db, string zSql, int nByte, out IntPtr ppStmt, IntPtr pzTail);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step", CallingConvention = CallingConvention.Cdecl)]
    private static extern int sqlite3_step(IntPtr pStmt);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_text16", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr sqlite3_column_text16(IntPtr pStmt, int iCol);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int64", CallingConvention = CallingConvention.Cdecl)]
    private static extern long sqlite3_column_int64(IntPtr pStmt, int iCol);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize", CallingConvention = CallingConvention.Cdecl)]
    private static extern int sqlite3_finalize(IntPtr pStmt);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close", CallingConvention = CallingConvention.Cdecl)]
    private static extern int sqlite3_close(IntPtr db);

    private const int SQLITE_ROW = 100;
    private const int SQLITE_OK = 0;

    public static Dictionary<string, long> ReadBanDates(string dbPath) {
        var dict = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrEmpty(dbPath) || !System.IO.File.Exists(dbPath)) return dict;
        IntPtr db = IntPtr.Zero;
        if (sqlite3_open16(dbPath, out db) != SQLITE_OK || db == IntPtr.Zero) return dict;
        try {
            IntPtr stmt = IntPtr.Zero;
            string sql = "SELECT IPAddress, BanDate FROM IPBan";
            if (sqlite3_prepare16_v2(db, sql, sql.Length * 2, out stmt, IntPtr.Zero) == SQLITE_OK && stmt != IntPtr.Zero) {
                try {
                    while (sqlite3_step(stmt) == SQLITE_ROW) {
                        IntPtr ptr = sqlite3_column_text16(stmt, 0);
                        string ip = Marshal.PtrToStringUni(ptr);
                        long banDate = sqlite3_column_int64(stmt, 1);
                        if (!string.IsNullOrEmpty(ip)) {
                            dict[ip] = banDate;
                        }
                    }
                } finally {
                    sqlite3_finalize(stmt);
                }
            }
        } catch {}
        finally {
            sqlite3_close(db);
        }
        return dict;
    }
}
'@
        Add-Type -TypeDefinition $csSqlite -ErrorAction SilentlyContinue
    } catch {}
}

# ------------------------------------------------------------------------------
# Локалізація (Multi-Language: UA / EN)
# ------------------------------------------------------------------------------
$script:I18N = @{
    "UA" = @{
        "AppTitle" = "IPBan Manager & Control Center"
        "HeaderTitle" = "IPBan Control Center"
        "HeaderSubtitle" = "Автоматичний захист від Brute-Force атак (RDP, SSH, SQL)"
        "StatusChecking" = "Перевірка..."
        "StatusRunning" = "ЗАПУЩЕНО"
        "StatusStopped" = "ЗУПИНЕНО"
        "StatusNotInstalled" = "НЕ ВСТАНОВЛЕНО"
        "BtnStart" = "Запустити"
        "BtnStop" = "Зупинити"
        "BtnRestart" = "Рестарт"
        "BtnRefresh" = "Оновити"
        "LangToggle" = "English"
        "PathLabel" = "Папка IPBan:"
        "BtnBrowse" = "Огляд..."
        "BtnOpenFolder" = "Відкрити папку"
        "BtnOpenConfig" = "Відкрити конфіг"
        "TabBanned" = "  Заблоковані IP  "
        "TabSettings" = "  Налаштування  "
        "TabLists" = "  Білий / Чорний списки  "
        "TabLogs" = "  Журнал та аудит  "
        "TabSetup" = "  Інсталяція та Сервіс  "
        "Search" = "Пошук:"
        "Filter" = "Фільтр:"
        "FilterBanned" = "⛔ Тільки заблоковані"
        "FilterWhitelist" = "⚪ Тільки білий список"
        "FilterAllRules" = "📋 Всі правила IPBan"
        "BtnUnbanSelected" = "Розблокувати обрані"
        "BtnManualBan" = "Заблокувати вручну..."
        "BtnUnbanAll" = "Очистити всі блокування"
        "BtnExport" = "Експорт..."
        "ColIndex" = "#"
        "ColIP" = "IP-адреса (Whois)"
        "ColBanTime" = "Час блокування"
        "ColUnbanTime" = "Час розблокування"
        "BanPermanent" = "— (Назавжди)"
        "BanActive" = "Активне"
        "BanPerConfig" = "За конфігом"
        "WhitelistNote" = "— (Білий список)"
        "StatusActive" = "🟢 Активно"
        "StatusDisabled" = "⚪ Вимкнено"
        "LblNoBans" = "🟢 Активних блокувань немає (0 IP-адрес) | У білому списку брандмауера: {0} IP-адрес"
        "LblBansCount" = "⛔ Заблоковано в брандмауері: {0} IP-адрес (Відображено: {1}) | У білому списку: {2} IP-адрес"
        "LblWhiteCount" = "⚪ У білому списку брандмауера: {0} IP-адрес (Відображено: {1}) | Заблоковано: {2} IP-адрес"
        "LblAllRulesCount" = "📋 Всього правил IPBan у брандмауері: {0} | Відображено: {1}"
        "GbGeneral" = "Правила виявлення та блокування"
        "LblFailedAttempts" = "Поріг невдалих спроб входу (FailedLoginAttemptsBeforeBan):"
        "LblBanTime" = "Час блокування (BanTime, формат Дні:Год:Хв:Сек):"
        "LblExpireTime" = "Час життя невдалих спроб до скидання (ExpireTime):"
        "LblCycleTime" = "Інтервал циклу перевірки та бану (CycleTime):"
        "GbBehavior" = "Додаткова поведінка та очищення"
        "ChkClearOnRestart" = "Очищати всі заблоковані IP при перезапуску служби (ClearBannedIPAddressesOnRestart)"
        "ChkClearOnSuccess" = "Скидати лічильник невдалих спроб при успішному вході (ClearFailedLoginsOnSuccessfulLogin)"
        "ChkProcessInternal" = "Обробляти та блокувати внутрішні локальні IP-адреси (ProcessInternalIPAddresses)"
        "ChkResetUnbanned" = "Скидати лічильник після розблокування IP (ResetFailedLoginCountForUnbannedIPAddresses)"
        "BtnSaveConfig" = "Зберегти налаштування у файл"
        "BtnReloadConfig" = "Скинути до значень файлу"
        "BtnRestoreBak" = "Відновити з бекапу (.bak)"
        "GbWhitelist" = "Білий список (Whitelist - ніколи не блокувати)"
        "LblWhiteDesc" = "Введіть IP-адреси або підмережі CIDR через кому або з нового рядка:"
        "BtnAddLocalIP" = "+ Додати мою локальну IP"
        "BtnAddPublicIP" = "+ Додати мою зовнішню WAN IP"
        "GbBlacklist" = "Чорний список (Blacklist - перманентно блокувати)"
        "LblBlackDesc" = "Введіть IP-адреси або підмережі CIDR для постійного блокування:"
        "BtnSaveLists" = "Зберегти Білий та Чорний списки у конфігурацію"
        "RbIPBanLog" = "Лог IPBan (logfile.txt)"
        "RbEventLog" = "Спроби входу Windows (Security 4625)"
        "BtnRefreshLog" = "Оновити журнал"
        "ChkAutoRefresh" = "Авто (кожні 5 сек)"
        "BtnClearLog" = "Очистити logfile.txt"
        "ColTime" = "Час"
        "ColUser" = "Користувач"
        "ColLogonType" = "Тип входу"
        "ColWorkstation" = "Робоча станція"
        "MiEventBan" = "Заблокувати цей IP"
        "MiEventWhite" = "Додати цей IP до Whitelist"
        "MiEventCopy" = "Копіювати IP-адресу"
        "GbSysStatus" = "Стан компонентів системи"
        "BtnBrowseZip" = "Обрати ZIP-архів..."
        "GbInstallActions" = "Керування встановленням та налаштуванням"
        "BtnSetupAudit" = "Увімкнути аудит безпеки Windows (AuditPol)"
        "LblAuditHint" = "(Обов'язково для виявлення невдалих спроб входу RDP/Windows)"
        "BtnInstallLocal" = "Встановити IPBan з локального архіву"
        "BtnInstallWeb" = "Завантажити та встановити найновішу з GitHub"
        "BtnUninstallService" = "Повністю видалити службу IPBan"
        "GbLinks" = "Корисні посилання та документація"
        "LlGithub" = "Офіційний репозиторій DigitalRuby/IPBan на GitHub"
        "LlWiki" = "Документація налаштувань та конфігурації (Wiki)"
        "StatusReady" = "Готово"
        "AdminYes" = "Адміністратор"
        "AdminNo" = "Без прав адміністратора"
        "TrayTitle" = "🛡 IPBan Control Center"
        "TrayStatusChecking" = "Статус: Перевірка..."
        "TrayBannedCount" = "Заблоковано IP: {0}"
        "TrayStart" = "▶ Запустити службу"
        "TrayStop" = "⏹ Зупинити службу"
        "TrayRestart" = "🔄 Перезапустити службу"
        "TrayRefresh" = "📋 Оновити дані"
        "TrayShow" = "🪟 Відкрити вікно програми"
        "TrayExit" = "❌ Вихід з програми"
        "SvcRunning" = "Служба Windows (IPBan): Працює (Running)"
        "SvcStopped" = "Служба Windows (IPBan): Зупинена (Stopped)"
        "SvcNotInstalled" = "Служба Windows (IPBan): Не знайдена в системі"
        "PromptInstallTitle" = "Майстер налаштувань IPBan"
        "PromptInstallText" = "Службу захисту IPBan ще не встановлено на цьому комп'ютері.`n`nВідкрито розділ «Інсталяція та Сервіс».`nДля захисту сервера від підбору паролів (RDP, SSH, SMB тощо) необхідно встановити службу IPBan.`n`nБажаєте завантажити та встановити найновішу версію IPBan прямо зараз з офіційного GitHub?"
    }
    "EN" = @{
        "AppTitle" = "IPBan Manager & Control Center"
        "HeaderTitle" = "IPBan Control Center"
        "HeaderSubtitle" = "Automated Brute-Force Attack Protection (RDP, SSH, SQL)"
        "StatusChecking" = "Checking..."
        "StatusRunning" = "RUNNING"
        "StatusStopped" = "STOPPED"
        "StatusNotInstalled" = "NOT INSTALLED"
        "BtnStart" = "Start"
        "BtnStop" = "Stop"
        "BtnRestart" = "Restart"
        "BtnRefresh" = "Refresh"
        "LangToggle" = "Українська"
        "PathLabel" = "IPBan Folder:"
        "BtnBrowse" = "Browse..."
        "BtnOpenFolder" = "Open Folder"
        "BtnOpenConfig" = "Open Config"
        "TabBanned" = "  Banned IPs  "
        "TabSettings" = "  Settings  "
        "TabLists" = "  White / Black Lists  "
        "TabLogs" = "  Logs & Audit  "
        "TabSetup" = "  Installation & Service  "
        "Search" = "Search:"
        "Filter" = "Filter:"
        "FilterBanned" = "⛔ Blocked Only"
        "FilterWhitelist" = "⚪ Whitelist Only"
        "FilterAllRules" = "📋 All IPBan Rules"
        "BtnUnbanSelected" = "Unban Selected"
        "BtnManualBan" = "Manual Ban..."
        "BtnUnbanAll" = "Clear All Bans"
        "BtnExport" = "Export..."
        "ColIndex" = "#"
        "ColIP" = "IP Address (Whois)"
        "ColBanTime" = "Ban Date & Time"
        "ColUnbanTime" = "Unban Date & Time"
        "BanPermanent" = "— (Permanent)"
        "BanActive" = "Active"
        "BanPerConfig" = "Per config"
        "WhitelistNote" = "— (Whitelist)"
        "StatusActive" = "🟢 Active"
        "StatusDisabled" = "⚪ Disabled"
        "LblNoBans" = "🟢 No active blocks (0 IP addresses) | Firewall whitelist: {0} IP addresses"
        "LblBansCount" = "⛔ Blocked in firewall: {0} IP addresses (Showing: {1}) | In whitelist: {2} IP addresses"
        "LblWhiteCount" = "⚪ Firewall whitelist: {0} IP addresses (Showing: {1}) | Blocked: {2} IP addresses"
        "LblAllRulesCount" = "📋 Total IPBan rules in firewall: {0} | Showing: {1}"
        "GbGeneral" = "Detection and Blocking Rules"
        "LblFailedAttempts" = "Failed login attempts threshold (FailedLoginAttemptsBeforeBan):"
        "LblBanTime" = "Ban duration (BanTime, format Days:Hours:Min:Sec):"
        "LblExpireTime" = "Failed attempt expiration window (ExpireTime):"
        "LblCycleTime" = "Cycle checking interval (CycleTime):"
        "GbBehavior" = "Additional Behavior and Cleanup"
        "ChkClearOnRestart" = "Clear all banned IPs on service restart (ClearBannedIPAddressesOnRestart)"
        "ChkClearOnSuccess" = "Reset failed attempts counter on successful login (ClearFailedLoginsOnSuccessfulLogin)"
        "ChkProcessInternal" = "Process and ban internal/local IP addresses (ProcessInternalIPAddresses)"
        "ChkResetUnbanned" = "Reset counter after unbanning an IP (ResetFailedLoginCountForUnbannedIPAddresses)"
        "BtnSaveConfig" = "Save Settings to File"
        "BtnReloadConfig" = "Reset to File Values"
        "BtnRestoreBak" = "Restore from Backup (.bak)"
        "GbWhitelist" = "Whitelist (Never ban these addresses)"
        "LblWhiteDesc" = "Enter IP addresses or CIDR subnets separated by comma or new lines:"
        "BtnAddLocalIP" = "+ Add My Local IP"
        "BtnAddPublicIP" = "+ Add My Public WAN IP"
        "GbBlacklist" = "Blacklist (Permanently block these addresses)"
        "LblBlackDesc" = "Enter IP addresses or CIDR subnets to permanently block:"
        "BtnSaveLists" = "Save Whitelist & Blacklist to Configuration"
        "RbIPBanLog" = "IPBan Log (logfile.txt)"
        "RbEventLog" = "Windows Logon Attempts (Security 4625)"
        "BtnRefreshLog" = "Refresh Log"
        "ChkAutoRefresh" = "Auto (every 5 sec)"
        "BtnClearLog" = "Clear logfile.txt"
        "ColTime" = "Time"
        "ColUser" = "User"
        "ColLogonType" = "Logon Type"
        "ColWorkstation" = "Workstation"
        "MiEventBan" = "Ban This IP"
        "MiEventWhite" = "Add This IP to Whitelist"
        "MiEventCopy" = "Copy IP Address"
        "GbSysStatus" = "System Components Status"
        "BtnBrowseZip" = "Choose ZIP Archive..."
        "GbInstallActions" = "Installation and Maintenance Controls"
        "BtnSetupAudit" = "Enable Windows Security Audit (AuditPol)"
        "LblAuditHint" = "(Required to detect failed RDP/Windows login attempts)"
        "BtnInstallLocal" = "Install IPBan from Local Archive"
        "BtnInstallWeb" = "Download and Install Latest from GitHub"
        "BtnUninstallService" = "Completely Remove IPBan Service"
        "GbLinks" = "Useful Links & Documentation"
        "LlGithub" = "Official DigitalRuby/IPBan Repository on GitHub"
        "LlWiki" = "Configuration and Settings Documentation (Wiki)"
        "StatusReady" = "Ready"
        "AdminYes" = "Administrator"
        "AdminNo" = "Standard User (Non-Admin)"
        "TrayTitle" = "🛡 IPBan Control Center"
        "TrayStatusChecking" = "Status: Checking..."
        "TrayBannedCount" = "Banned IPs: {0}"
        "TrayStart" = "▶ Start Service"
        "TrayStop" = "⏹ Stop Service"
        "TrayRestart" = "🔄 Restart Service"
        "TrayRefresh" = "📋 Refresh Data"
        "TrayShow" = "🪟 Open Control Center"
        "TrayExit" = "❌ Exit Application"
        "SvcRunning" = "Windows Service (IPBan): Running"
        "SvcStopped" = "Windows Service (IPBan): Stopped"
        "SvcNotInstalled" = "Windows Service (IPBan): Not found in system"
        "PromptInstallTitle" = "IPBan Setup Wizard"
        "PromptInstallText" = "The IPBan protection service is not yet installed on this computer.`n`nOpened the 'Installation & Service' section.`nTo protect this server from brute-force password attacks (RDP, SSH, SMB, etc.), the IPBan service must be installed.`n`nWould you like to download and install the latest IPBan release from GitHub right now?"
    }
}

# Визначення поточної мови (реєстр або культура ОС)
$regKeyLang = "HKCU:\Software\IPBanControlCenter"
$savedLang = $null
try {
    if (Test-Path $regKeyLang) {
        $savedLang = (Get-ItemProperty -Path $regKeyLang -Name "Language" -ErrorAction SilentlyContinue).Language
    }
} catch {}

if ($savedLang -in @("UA", "EN")) {
    $script:CurrentLang = $savedLang
} else {
    $uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName.ToLower()
    if ($uiCulture -in @("uk", "ru", "be")) {
        $script:CurrentLang = "UA"
    } else {
        $script:CurrentLang = "EN"
    }
}

function T([string]$key) {
    if ($script:I18N[$script:CurrentLang].ContainsKey($key)) {
        return $script:I18N[$script:CurrentLang][$key]
    }
    if ($script:I18N["EN"].ContainsKey($key)) {
        return $script:I18N["EN"][$key]
    }
    return $key
}

# Підключення P/Invoke для коректного вивільнення дескрипторів іконок
if (-not ([System.Management.Automation.PSTypeName]'NativeMethods').Type) {
    $nativeCode = @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@
    Add-Type -TypeDefinition $nativeCode -ErrorAction SilentlyContinue
}

# Генератор динамічних іконок для системного трею (Працює, Не працює, Алерт)
function Get-AppTrayIcon([string]$state) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $rect = New-Object System.Drawing.Rectangle 1, 1, 29, 29

    switch ($state) {
        "Running" {
            # 🟢 Працює: Зелений щит/коло з білою галочкою
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 163, 74))
            $g.FillEllipse($brush, $rect)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White, 3.5)
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawLine($pen, 8, 16, 13, 21)
            $g.DrawLine($pen, 13, 21, 23, 10)
            $pen.Dispose()
        }
        "Alert" {
            # 🟠 Алерт: Помаранчевий/бурштиновий з білим знаком оклику (!)
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(234, 88, 12))
            $g.FillEllipse($brush, $rect)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White, 3.5)
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawLine($pen, 15, 7, 15, 17)
            $pen.Dispose()
            $brushWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
            $g.FillEllipse($brushWhite, 13, 21, 5, 5)
            $brushWhite.Dispose()
        }
        default {
            # 🔴 Не працює: Червоне коло з білим хрестиком (X)
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 38, 38))
            $g.FillEllipse($brush, $rect)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White, 3.5)
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawLine($pen, 9, 9, 21, 21)
            $g.DrawLine($pen, 21, 9, 9, 21)
            $pen.Dispose()
        }
    }

    $g.Dispose()
    $hIcon = $bmp.GetHicon()
    $ico = [System.Drawing.Icon]::FromHandle($hIcon)
    $clone = $ico.Clone()
    $ico.Dispose()
    [NativeMethods]::DestroyIcon($hIcon) | Out-Null
    $bmp.Dispose()
    return $clone
}

# Допоміжна функція створення згладжених кнопок та бейджів (Rounded Buttons)
function Set-SmoothButton {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Control]$control,
        [int]$radius = 7,
        [System.Drawing.Color]$borderColor = [System.Drawing.Color]::Empty
    )
    if ($control -is [System.Windows.Forms.ButtonBase]) {
        $control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $control.FlatAppearance.BorderSize = 0
        $control.Cursor = [System.Windows.Forms.Cursors]::Hand
    }

    $rVal = if ($radius -gt 0) { $radius } else { 7 }
    $bColorVal = $borderColor

    $updateRegion = {
        param($s, $e)
        try {
            $curR = if ($rVal -gt 0) { $rVal } else { 7 }
            $d = [int]($curR * 2)
            if ($s -and $s.Width -gt $d -and $s.Height -gt $d) {
                $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                $r = $s.ClientRectangle
                if ($r.Width -gt $d -and $r.Height -gt $d) {
                    $path.AddArc($r.X, $r.Y, $d, $d, 180, 90)
                    $path.AddArc(($r.Right - $d), $r.Y, $d, $d, 270, 90)
                    $path.AddArc(($r.Right - $d), ($r.Bottom - $d), $d, $d, 0, 90)
                    $path.AddArc($r.X, ($r.Bottom - $d), $d, $d, 90, 90)
                    $path.CloseFigure()
                    $s.Region = New-Object System.Drawing.Region($path)
                }
                $path.Dispose()
            }
        } catch {}
    }.GetNewClosure()
    $control.Add_Resize($updateRegion)
    & $updateRegion $control $null

    if (-not $bColorVal.IsEmpty) {
        $paintBorder = {
            param($s, $e)
            try {
                $curR = if ($rVal -gt 0) { $rVal } else { 7 }
                $d = [int]($curR * 2)
                if ($s -and $s.Width -gt $d -and $s.Height -gt $d) {
                    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $r = New-Object System.Drawing.Rectangle 0, 0, ($s.Width - 1), ($s.Height - 1)
                    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                    $path.AddArc($r.X, $r.Y, $d, $d, 180, 90)
                    $path.AddArc(($r.Right - $d), $r.Y, $d, $d, 270, 90)
                    $path.AddArc(($r.Right - $d), ($r.Bottom - $d), $d, $d, 0, 90)
                    $path.AddArc($r.X, ($r.Bottom - $d), $d, $d, 90, 90)
                    $path.CloseFigure()
                    $pen = New-Object System.Drawing.Pen($bColorVal, 1)
                    $e.Graphics.DrawPath($pen, $path)
                    $pen.Dispose()
                    $path.Dispose()
                }
            } catch {}
        }.GetNewClosure()
        $control.Add_Paint($paintBorder)
    }
}

function Find-LocalIPBanZip {
    if ($script:LocalZipBackup -and (Test-Path $script:LocalZipBackup)) {
        return $script:LocalZipBackup
    }

    $candidates = @(
        $PSScriptRoot,
        (Get-Location).Path,
        [System.IO.Path]::Combine($env:USERPROFILE, "Downloads"),
        "C:\Downloads",
        "C:\Temp",
        "C:\"
    )
    if (Test-Path "D:\") {
        $candidates += @("D:\Downloads", "D:\Temp", "D:\")
    }

    foreach ($dir in $candidates) {
        if ($dir -and (Test-Path $dir)) {
            $zip = Get-ChildItem -Path $dir -Filter "*IPBan*.zip" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($zip) {
                return $zip.FullName
            }
        }
    }
    return $null
}

function Get-IPBanPath {
    if ($txtInstallPath -and -not [string]::IsNullOrWhiteSpace($txtInstallPath.Text)) {
        $p = $txtInstallPath.Text.Trim()
        if (Test-Path "$p\DigitalRuby.IPBan.exe") {
            $script:CurrentInstallPath = $p
            return $p
        }
    }
    if (Test-Path "$script:CurrentInstallPath\DigitalRuby.IPBan.exe") {
        return $script:CurrentInstallPath
    }
    if (Test-Path "C:\Program Files\IPBan\DigitalRuby.IPBan.exe") {
        $script:CurrentInstallPath = "C:\Program Files\IPBan"
        return $script:CurrentInstallPath
    }
    if (Test-Path "C:\IPBan\DigitalRuby.IPBan.exe") {
        $script:CurrentInstallPath = "C:\IPBan"
        return $script:CurrentInstallPath
    }
    if ($txtInstallPath -and -not [string]::IsNullOrWhiteSpace($txtInstallPath.Text)) {
        return $txtInstallPath.Text.Trim()
    }
    return $script:CurrentInstallPath
}

function Get-IPBanConfigFile {
    $path = Get-IPBanPath
    if (Test-Path "$path\ipban.config") {
        return "$path\ipban.config"
    }
    if (Test-Path "$path\ipban.override.config") {
        return "$path\ipban.override.config"
    }
    return "$path\ipban.config"
}

function Get-IPBanServiceStatus {
    try {
        $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $svc) { return "NotInstalled" }
        return $svc.Status.ToString()
    } catch {
        return "NotInstalled"
    }
}

function Expand-ZipArchiveSafe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$zipPath,
        [Parameter(Mandatory=$true)]
        [string]$destDir
    )
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $archive.Entries) {
            $destFile = [System.IO.Path]::Combine($destDir, $entry.FullName)
            if ($entry.FullName.EndsWith("/") -or $entry.FullName.EndsWith("\")) {
                if (-not (Test-Path $destFile)) {
                    New-Item -ItemType Directory -Path $destFile -Force | Out-Null
                }
            } else {
                $parentDir = [System.IO.Path]::GetDirectoryName($destFile)
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
            }
        }
    } finally {
        $archive.Dispose()
    }
}

function Install-IPBanFromArchive {
    param(
        [Parameter(Mandatory=$true)]
        [string]$zipPath,
        [Parameter(Mandatory=$true)]
        [string]$destPath,
        [System.Windows.Forms.Label]$progressLabel = $null,
        [System.Windows.Forms.Label]$detailsLabel = $null
    )

    # 1. Резервне копіювання конфігурації
    $tempBackup = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ipban_cfg_backup")
    if (Test-Path $destPath) {
        if (-not (Test-Path $tempBackup)) { New-Item -ItemType Directory -Path $tempBackup -Force | Out-Null }
        foreach ($cfg in @("ipban.config", "ipban.override.config", "ipban.sqlite", "nlog.config")) {
            $srcFile = Join-Path $destPath $cfg
            if (Test-Path $srcFile) {
                Copy-Item -Path $srcFile -Destination $tempBackup -Force
            }
        }
    }

    # 2. Зупинка та видалення старої служби
    if (Get-Service $script:ServiceName -ErrorAction SilentlyContinue) {
        if ($detailsLabel) { $detailsLabel.Text = "Зупинка попередньої служби IPBan..."; [System.Windows.Forms.Application]::DoEvents() }
        try { Stop-Service $script:ServiceName -Force } catch {}
        & sc.exe delete $script:ServiceName
        Start-Sleep -Seconds 1
    }

    # 3. Розпакування файлів
    if ($detailsLabel) { $detailsLabel.Text = "Розпакування файлів у $destPath..."; [System.Windows.Forms.Application]::DoEvents() }
    Expand-ZipArchiveSafe -zipPath $zipPath -destDir $destPath

    # 4. Відновлення конфігурації
    if (Test-Path $tempBackup) {
        foreach ($cfg in @("ipban.config", "ipban.override.config", "ipban.sqlite", "nlog.config")) {
            $bakFile = Join-Path $tempBackup $cfg
            if (Test-Path $bakFile) {
                Copy-Item -Path $bakFile -Destination $destPath -Force
            }
        }
        Remove-Item $tempBackup -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 5. Налаштування аудиту безпеки
    if ($detailsLabel) { $detailsLabel.Text = "Налаштування аудиту входу Windows (AuditPol)..."; [System.Windows.Forms.Application]::DoEvents() }
    & auditpol.exe /set /category:"{69979849-797A-11D9-BED3-505054503030}" /success:enable /failure:enable
    & auditpol.exe /set /category:"{69979850-797A-11D9-BED3-505054503030}" /success:enable /failure:enable

    # 6. Створення та запуск служби Windows
    if ($detailsLabel) { $detailsLabel.Text = "Створення та запуск служби Windows..."; [System.Windows.Forms.Application]::DoEvents() }
    $exePath = Join-Path $destPath "DigitalRuby.IPBan.exe"
    if (-not (Test-Path $exePath)) {
        throw "Не знайдено файл DigitalRuby.IPBan.exe у $destPath після розпакування!"
    }
    & sc.exe create $script:ServiceName binPath= "`"$exePath`"" start= delayed-auto
    Start-Sleep -Seconds 1
    Start-Service $script:ServiceName
}

function Get-FirewallBannedIPs {
    $results = @()
    try {
        $fw = New-Object -ComObject HNetCfg.FwPolicy2
        foreach ($rule in $fw.Rules) {
            if ($rule.Name -like "IPBan*") {
                $ips = $rule.RemoteAddresses -split ","
                foreach ($ip in $ips) {
                    $trim = $ip.Trim()
                    if ($trim -and $trim -ne "*" -and $trim -ne "255.255.255.255") {
                        $cleanIp = $trim.Replace("/255.255.255.255", "").Replace("/32", "")
                        $isBlock = ($rule.Action -eq 0) -and ($rule.Name -notlike "*Whitelist*")
                        $results += [PSCustomObject]@{
                            IPAddress   = $cleanIp
                            RuleName    = $rule.Name
                            ActionType  = if ($isBlock) { "Block" } else { "Allow" }
                            ActionLabel = if ($isBlock) { "⛔ Блокування" } else { "⚪ Дозволено (Whitelist)" }
                            Enabled     = $rule.Enabled
                        }
                    }
                }
            }
        }
    } catch {
        try {
            $rules = Get-NetFirewallRule -Name "IPBan*" -ErrorAction SilentlyContinue
            foreach ($r in $rules) {
                $filters = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
                foreach ($f in $filters) {
                    foreach ($ip in $f.RemoteAddress) {
                        $trim = $ip.Trim()
                        if ($trim -and $trim -ne "*" -and $trim -ne "255.255.255.255") {
                            $cleanIp = $trim.Replace("/255.255.255.255", "").Replace("/32", "")
                            $isBlock = ($r.Action -eq "Block") -and ($r.Name -notlike "*Whitelist*")
                            $results += [PSCustomObject]@{
                                IPAddress   = $cleanIp
                                RuleName    = $r.Name
                                ActionType  = if ($isBlock) { "Block" } else { "Allow" }
                                ActionLabel = if ($isBlock) { "⛔ Блокування" } else { "⚪ Дозволено (Whitelist)" }
                                Enabled     = $r.Enabled
                            }
                        }
                    }
                }
            }
        } catch {}
    }
    return ,$results
}

function Get-IPBanTimesMap {
    $map = @{}
    $path = Get-IPBanPath

    # 1. Читання бази ipban.sqlite якщо winsqlite3 доступний
    if ($script:HasWinSqlite -and ([System.Management.Automation.PSTypeName]'IPBanSqlite').Type) {
        $dbPath = Join-Path $path "ipban.sqlite"
        if (Test-Path $dbPath) {
            try {
                $sqliteBans = [IPBanSqlite]::ReadBanDates($dbPath)
                foreach ($entry in $sqliteBans.GetEnumerator()) {
                    $epochMs = $entry.Value
                    if ($epochMs -gt 0) {
                        $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($epochMs).ToLocalTime().DateTime
                        $map[$entry.Key] = @{
                            BanDate = $dt
                            Duration = $null
                        }
                    }
                }
            } catch {}
        }
    }

    # 2. Читання logfile.txt (останні 3000 рядків)
    $logFile = Join-Path $path "logfile.txt"
    if (Test-Path $logFile) {
        try {
            $lines = Get-Content -Path $logFile -Tail 3000 -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}).*?Banning ip address:\s*([^,\s]+)') {
                    $rawTime = $matches[1]
                    $ip = $matches[2].Trim()
                    $dur = $null
                    if ($line -match 'duration:\s*([0-9\.:]+)') {
                        $dur = $matches[1].Trim()
                    }
                    try {
                        $dt = [DateTime]::ParseExact($rawTime, "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                        $map[$ip] = @{
                            BanDate = $dt
                            Duration = $dur
                        }
                    } catch {}
                }
            }
        } catch {}
    }

    # 3. Ручні блокування поточної сесії
    if ($script:ManualBanTimes) {
        foreach ($k in $script:ManualBanTimes.Keys) {
            if (-not $map.ContainsKey($k)) {
                $map[$k] = @{
                    BanDate = $script:ManualBanTimes[$k]
                    Duration = $script:CurrentBanTimeSetting
                }
            }
        }
    }

    return $map
}

function Unban-IPAddress {
    param([string]$ip)
    if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
    $cleanIp = $ip.Trim().Replace("/255.255.255.255", "").Replace("/32", "")
    $path = Get-IPBanPath
    $success = $false

    # 1. Запис у unban.txt (офіційний механізм IPBan)
    try {
        if (Test-Path $path) {
            $unbanFile = Join-Path $path "unban.txt"
            Add-Content -Path $unbanFile -Value $cleanIp -Encoding UTF8
            $success = $true
        }
    } catch {}

    # 2. Негайне видалення з брандмауера Windows (тільки правила блокування!)
    try {
        $fw = New-Object -ComObject HNetCfg.FwPolicy2
        foreach ($rule in $fw.Rules) {
            if ($rule.Name -like "IPBan*" -and $rule.Name -notlike "*Whitelist*" -and $rule.Action -eq 0) {
                $addresses = ($rule.RemoteAddresses -split ",") | ForEach-Object { $_.Trim().Replace("/255.255.255.255", "").Replace("/32", "") }
                if ($addresses -contains $cleanIp) {
                    $remaining = $addresses | Where-Object { $_ -ne $cleanIp -and $_ -ne "255.255.255.255" }
                    if ($remaining.Count -eq 0) {
                        $rule.RemoteAddresses = "255.255.255.255"
                        $rule.Enabled = $false
                    } else {
                        $rule.RemoteAddresses = ($remaining -join ",")
                    }
                    $success = $true
                }
            }
        }
    } catch {}

    return $success
}

function Ban-IPAddressManual {
    param([string]$ip)
    if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
    $cleanIp = $ip.Trim().Replace("/255.255.255.255", "").Replace("/32", "")
    if (-not $script:ManualBanTimes) { $script:ManualBanTimes = @{} }
    $script:ManualBanTimes[$cleanIp] = (Get-Date)

    try {
        $fw = New-Object -ComObject HNetCfg.FwPolicy2
        $manualRule = $null
        foreach ($rule in $fw.Rules) {
            if ($rule.Name -eq "IPBan_Manual_Block") {
                $manualRule = $rule
                break
            }
        }

        if ($null -eq $manualRule) {
            $ruleType = [Type]::GetTypeFromProgID("HNetCfg.FWRule")
            $newRule = [Activator]::CreateInstance($ruleType)
            $newRule.Name = "IPBan_Manual_Block"
            $newRule.Description = "Ручне блокування IP-адреси через IPBan GUI Manager"
            $newRule.Action = 0 # NET_FW_ACTION_BLOCK
            $newRule.Direction = 1 # NET_FW_RULE_DIR_IN
            $newRule.Enabled = $true
            $newRule.Protocol = 256 # Any
            $newRule.RemoteAddresses = $cleanIp
            $fw.Rules.Add($newRule)
        } else {
            $addresses = ($manualRule.RemoteAddresses -split ",") | ForEach-Object { $_.Trim() }
            if ($addresses -notcontains $cleanIp) {
                $addresses += $cleanIp
                $manualRule.RemoteAddresses = ($addresses -join ",")
                $manualRule.Enabled = $true
            }
        }
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка додавання блокування у Firewall: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Get-WindowsFailedLogins {
    param([int]$maxEvents = 30)
    $events = @()
    try {
        $rawEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents $maxEvents -ErrorAction Stop
        foreach ($ev in $rawEvents) {
            $xml = [xml]$ev.ToXml()
            $eventData = @{}
            foreach ($data in $xml.Event.EventData.Data) {
                $eventData[$data.Name] = $data.'#text'
            }

            $user = $eventData['TargetUserName']
            $domain = $eventData['TargetDomainName']
            if ($domain -and $domain -ne "-") { $user = "$domain\$user" }
            $ip = $eventData['IpAddress']
            if ([string]::IsNullOrWhiteSpace($ip) -or $ip -eq "-") { $ip = "Локальний процес" }
            $workstation = $eventData['WorkstationName']
            $logonType = $eventData['LogonType']
            $logonTypeDesc = switch ($logonType) {
                "2"  { "Interactive (Локально)" }
                "3"  { "Network (Мережа/SMB)" }
                "10" { "RemoteDesktop (RDP)" }
                default { "Тип $logonType" }
            }

            $events += [PSCustomObject]@{
                TimeCreated   = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                TargetUser    = $user
                IPAddress     = $ip
                LogonType     = $logonTypeDesc
                Workstation   = $workstation
                Status        = $eventData['Status']
            }
        }
    } catch {
        # Подій немає або немає доступу
    }
    return $events
}

# ------------------------------------------------------------------------------
# Створення Головного Вікна
# ------------------------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "IPBan Manager & Control Center"
$form.Size = New-Object System.Drawing.Size(1080, 780)
$form.MinimumSize = New-Object System.Drawing.Size(950, 680)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.25)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

# Головна вертикальна розмітка
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 4
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 85)))  # Header
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 45)))  # Path Bar
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Tabs
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))  # StatusStrip
$form.Controls.Add($mainLayout)

# ------------------------------------------------------------------------------
# 1. Шапка форми (Header / Service Control)
# ------------------------------------------------------------------------------
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 32, 47)
$headerPanel.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 10)
$mainLayout.Controls.Add($headerPanel, 0, 0)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "IPBan Control Center"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Location = New-Object System.Drawing.Point(15, 12)
$lblTitle.AutoSize = $true
$headerPanel.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Автоматичний захист від Brute-Force атак (RDP, SSH, SQL)"
$lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$lblSubtitle.Location = New-Object System.Drawing.Point(18, 42)
$lblSubtitle.AutoSize = $true
$headerPanel.Controls.Add($lblSubtitle)

# Статус бейдж
$lblStatusBadge = New-Object System.Windows.Forms.Label
$lblStatusBadge.Text = "Перевірка..."
$lblStatusBadge.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblStatusBadge.ForeColor = [System.Drawing.Color]::White
$lblStatusBadge.BackColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$lblStatusBadge.Size = New-Object System.Drawing.Size(150, 36)
$lblStatusBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$headerPanel.Controls.Add($lblStatusBadge)

# Кнопки керування службою
$btnStartService = New-Object System.Windows.Forms.Button
$btnStartService.Text = T "BtnStart"
$btnStartService.Size = New-Object System.Drawing.Size(95, 36)
$btnStartService.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnStartService.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
$btnStartService.ForeColor = [System.Drawing.Color]::White
$btnStartService.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStartService.FlatAppearance.BorderSize = 0
$btnStartService.Cursor = [System.Windows.Forms.Cursors]::Hand
$headerPanel.Controls.Add($btnStartService)

$btnStopService = New-Object System.Windows.Forms.Button
$btnStopService.Text = T "BtnStop"
$btnStopService.Size = New-Object System.Drawing.Size(92, 36)
$btnStopService.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnStopService.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
$btnStopService.ForeColor = [System.Drawing.Color]::White
$btnStopService.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStopService.FlatAppearance.BorderSize = 0
$btnStopService.Cursor = [System.Windows.Forms.Cursors]::Hand
$headerPanel.Controls.Add($btnStopService)

$btnRestartService = New-Object System.Windows.Forms.Button
$btnRestartService.Text = T "BtnRestart"
$btnRestartService.Size = New-Object System.Drawing.Size(85, 36)
$btnRestartService.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnRestartService.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnRestartService.ForeColor = [System.Drawing.Color]::White
$btnRestartService.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRestartService.FlatAppearance.BorderSize = 0
$btnRestartService.Cursor = [System.Windows.Forms.Cursors]::Hand
$headerPanel.Controls.Add($btnRestartService)

$btnRefreshAll = New-Object System.Windows.Forms.Button
$btnRefreshAll.Text = T "BtnRefresh"
$btnRefreshAll.Size = New-Object System.Drawing.Size(88, 36)
$btnRefreshAll.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnRefreshAll.BackColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$btnRefreshAll.ForeColor = [System.Drawing.Color]::White
$btnRefreshAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefreshAll.FlatAppearance.BorderSize = 0
$btnRefreshAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$headerPanel.Controls.Add($btnRefreshAll)

# Кнопка перемикання мови інтерфейсу (UA / EN)
$btnLang = New-Object System.Windows.Forms.Button
$btnLang.Text = T "LangToggle"
$btnLang.Size = New-Object System.Drawing.Size(95, 36)
$btnLang.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnLang.BackColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$btnLang.ForeColor = [System.Drawing.Color]::White
$btnLang.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLang.FlatAppearance.BorderSize = 0
$btnLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$headerPanel.Controls.Add($btnLang)

Set-SmoothButton $lblStatusBadge 8
Set-SmoothButton $btnStartService 8
Set-SmoothButton $btnStopService 8
Set-SmoothButton $btnRestartService 8
Set-SmoothButton $btnRefreshAll 8
Set-SmoothButton $btnLang 8

function Update-HeaderLayout {
    $w = $headerPanel.ClientSize.Width
    $right = $w - 15

    $btnLang.Location = New-Object System.Drawing.Point(($right - 95), 20)
    $right -= (95 + 8)

    $btnRefreshAll.Location = New-Object System.Drawing.Point(($right - 88), 20)
    $right -= (88 + 8)

    $btnRestartService.Location = New-Object System.Drawing.Point(($right - 85), 20)
    $right -= (85 + 8)

    $btnStopService.Location = New-Object System.Drawing.Point(($right - 92), 20)
    $right -= (92 + 8)

    $btnStartService.Location = New-Object System.Drawing.Point(($right - 95), 20)
    $right -= (95 + 12)

    $lblStatusBadge.Location = New-Object System.Drawing.Point(($right - 150), 20)
}
$headerPanel.Add_Resize({ Update-HeaderLayout })
Update-HeaderLayout

$btnLang.Add_Click({
    if ($script:CurrentLang -eq "UA") {
        Apply-Language "EN"
    } else {
        Apply-Language "UA"
    }
})

# ------------------------------------------------------------------------------
# 2. Рядок шляху до IPBan (Path Bar)
# ------------------------------------------------------------------------------
$pathPanel = New-Object System.Windows.Forms.Panel
$pathPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$pathPanel.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$pathPanel.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$mainLayout.Controls.Add($pathPanel, 0, 1)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Папка IPBan:"
$lblPath.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblPath.Location = New-Object System.Drawing.Point(10, 11)
$lblPath.AutoSize = $true
$pathPanel.Controls.Add($lblPath)

$txtInstallPath = New-Object System.Windows.Forms.TextBox
$txtInstallPath.Text = Get-IPBanPath
$txtInstallPath.Location = New-Object System.Drawing.Point(105, 8)
$txtInstallPath.Size = New-Object System.Drawing.Size(530, 25)
$pathPanel.Controls.Add($txtInstallPath)

$btnBrowsePath = New-Object System.Windows.Forms.Button
$btnBrowsePath.Text = "Огляд..."
$btnBrowsePath.Location = New-Object System.Drawing.Point(645, 7)
$btnBrowsePath.Size = New-Object System.Drawing.Size(80, 27)
$pathPanel.Controls.Add($btnBrowsePath)

$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = "Відкрити папку"
$btnOpenFolder.Location = New-Object System.Drawing.Point(735, 7)
$btnOpenFolder.Size = New-Object System.Drawing.Size(140, 27)
$pathPanel.Controls.Add($btnOpenFolder)

$btnOpenConfigFile = New-Object System.Windows.Forms.Button
$btnOpenConfigFile.Text = "Відкрити конфіг"
$btnOpenConfigFile.Location = New-Object System.Drawing.Point(885, 7)
$btnOpenConfigFile.Size = New-Object System.Drawing.Size(145, 27)
$pathPanel.Controls.Add($btnOpenConfigFile)

Set-SmoothButton $btnBrowsePath 6 ([System.Drawing.Color]::FromArgb(203, 213, 225))
Set-SmoothButton $btnOpenFolder 6 ([System.Drawing.Color]::FromArgb(203, 213, 225))
Set-SmoothButton $btnOpenConfigFile 6 ([System.Drawing.Color]::FromArgb(203, 213, 225))

# ------------------------------------------------------------------------------
# 3. Вкладки інтерфейсу (TabControl)
# ------------------------------------------------------------------------------
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$mainLayout.Controls.Add($tabControl, 0, 2)

# ==============================================================================
# ВКЛАДКА 1: Заблоковані IP (Banned IPs & Firewall)
# ==============================================================================
$tabBanned = New-Object System.Windows.Forms.TabPage
$tabBanned.Text = "  Заблоковані IP  "
$tabBanned.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabBanned)

$layoutBanned = New-Object System.Windows.Forms.TableLayoutPanel
$layoutBanned.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutBanned.RowCount = 3
$layoutBanned.ColumnCount = 1
$layoutBanned.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
$layoutBanned.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$layoutBanned.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
$tabBanned.Controls.Add($layoutBanned)

# Панель дій над заблокованими IP
$panelBannedActions = New-Object System.Windows.Forms.Panel
$panelBannedActions.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelBannedActions.Padding = New-Object System.Windows.Forms.Padding(5)
$layoutBanned.Controls.Add($panelBannedActions, 0, 0)

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "Пошук:"
$lblSearch.Location = New-Object System.Drawing.Point(10, 15)
$lblSearch.AutoSize = $true
$panelBannedActions.Controls.Add($lblSearch)

$txtSearchBanned = New-Object System.Windows.Forms.TextBox
$txtSearchBanned.Location = New-Object System.Drawing.Point(60, 12)
$txtSearchBanned.Size = New-Object System.Drawing.Size(120, 25)
$panelBannedActions.Controls.Add($txtSearchBanned)

$lblFilterType = New-Object System.Windows.Forms.Label
$lblFilterType.Text = "Фільтр:"
$lblFilterType.Location = New-Object System.Drawing.Point(190, 15)
$lblFilterType.AutoSize = $true
$panelBannedActions.Controls.Add($lblFilterType)

$cbRuleFilter = New-Object System.Windows.Forms.ComboBox
$cbRuleFilter.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbRuleFilter.Location = New-Object System.Drawing.Point(245, 12)
$cbRuleFilter.Size = New-Object System.Drawing.Size(175, 25)
$cbRuleFilter.Items.AddRange(@(
    "⛔ Тільки заблоковані",
    "⚪ Тільки білий список",
    "📋 Всі правила IPBan"
))
$cbRuleFilter.SelectedIndex = 0
$panelBannedActions.Controls.Add($cbRuleFilter)

$btnUnbanSelected = New-Object System.Windows.Forms.Button
$btnUnbanSelected.Text = "Розблокувати обрані"
$btnUnbanSelected.Location = New-Object System.Drawing.Point(430, 10)
$btnUnbanSelected.Size = New-Object System.Drawing.Size(160, 29)
$btnUnbanSelected.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnUnbanSelected.BackColor = [System.Drawing.Color]::FromArgb(239, 246, 255)
$btnUnbanSelected.ForeColor = [System.Drawing.Color]::FromArgb(29, 78, 216)
$panelBannedActions.Controls.Add($btnUnbanSelected)

$btnManualBan = New-Object System.Windows.Forms.Button
$btnManualBan.Text = "Заблокувати вручну..."
$btnManualBan.Location = New-Object System.Drawing.Point(600, 10)
$btnManualBan.Size = New-Object System.Drawing.Size(165, 29)
$btnManualBan.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
$btnManualBan.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
$panelBannedActions.Controls.Add($btnManualBan)

$btnUnbanAll = New-Object System.Windows.Forms.Button
$btnUnbanAll.Text = "Очистити всі блокування"
$btnUnbanAll.Location = New-Object System.Drawing.Point(775, 10)
$btnUnbanAll.Size = New-Object System.Drawing.Size(175, 29)
$panelBannedActions.Controls.Add($btnUnbanAll)

$btnExportBanned = New-Object System.Windows.Forms.Button
$btnExportBanned.Text = "Експорт..."
$btnExportBanned.Location = New-Object System.Drawing.Point(960, 10)
$btnExportBanned.Size = New-Object System.Drawing.Size(90, 29)
$panelBannedActions.Controls.Add($btnExportBanned)

Set-SmoothButton $btnUnbanSelected 6
Set-SmoothButton $btnManualBan 6
Set-SmoothButton $btnUnbanAll 6
Set-SmoothButton $btnExportBanned 6

# Таблиця заблокованих IP
$dgvBanned = New-Object System.Windows.Forms.DataGridView
$dgvBanned.Dock = [System.Windows.Forms.DockStyle]::Fill
$dgvBanned.ReadOnly = $true
$dgvBanned.AllowUserToAddRows = $false
$dgvBanned.AllowUserToDeleteRows = $false
$dgvBanned.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$dgvBanned.MultiSelect = $true
$dgvBanned.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$dgvBanned.BackgroundColor = [System.Drawing.Color]::White
$dgvBanned.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$dgvBanned.RowHeadersVisible = $false

[void]$dgvBanned.Columns.Add("Index", "#")

$colIPLink = New-Object System.Windows.Forms.DataGridViewLinkColumn
$colIPLink.Name = "IPAddress"
$colIPLink.HeaderText = (T "ColIP")
$colIPLink.LinkColor = [System.Drawing.Color]::FromArgb(29, 78, 216)
$colIPLink.ActiveLinkColor = [System.Drawing.Color]::FromArgb(30, 58, 138)
$colIPLink.VisitedLinkColor = [System.Drawing.Color]::FromArgb(29, 78, 216)
$colIPLink.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
[void]$dgvBanned.Columns.Add($colIPLink)

[void]$dgvBanned.Columns.Add("BanDate", (T "ColBanTime"))
[void]$dgvBanned.Columns.Add("UnbanDate", (T "ColUnbanTime"))

$dgvBanned.Columns["Index"].FillWeight = 8
$dgvBanned.Columns["IPAddress"].FillWeight = 32
$dgvBanned.Columns["BanDate"].FillWeight = 30
$dgvBanned.Columns["UnbanDate"].FillWeight = 30

# Перевірка Whois при кліку на IP-адресу
$dgvBanned.Add_CellContentClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0 -and $e.ColumnIndex -eq $dgvBanned.Columns["IPAddress"].Index) {
        $cellVal = $dgvBanned.Rows[$e.RowIndex].Cells["IPAddress"].Value
        if ($cellVal) {
            $ipStr = $cellVal.ToString().Trim().Replace("/255.255.255.255", "").Replace("/32", "")
            if ($ipStr) {
                try {
                    [System.Diagnostics.Process]::Start("https://ipinfo.io/$ipStr") | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Не вдалося відкрити браузер: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
            }
        }
    }
})

$layoutBanned.Controls.Add($dgvBanned, 0, 1)

# Підвал таблиці
$panelBannedFooter = New-Object System.Windows.Forms.Panel
$panelBannedFooter.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelBannedFooter.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 5)
$layoutBanned.Controls.Add($panelBannedFooter, 0, 2)

$lblBannedCount = New-Object System.Windows.Forms.Label
$lblBannedCount.Text = "Загалом заблоковано: 0 IP-адрес"
$lblBannedCount.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblBannedCount.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblBannedCount.Location = New-Object System.Drawing.Point(10, 10)
$lblBannedCount.AutoSize = $true
$panelBannedFooter.Controls.Add($lblBannedCount)

# Контекстне меню для таблиці заблокованих IP (без Whois, оскільки IP тепер клікабельний лінк)
$ctxBanned = New-Object System.Windows.Forms.ContextMenuStrip
$miCopyIP = $ctxBanned.Items.Add("Копіювати IP")
$miUnban = $ctxBanned.Items.Add("Розблокувати")
$miWhitelist = $ctxBanned.Items.Add("Додати до Білого списку (Whitelist)")
$dgvBanned.ContextMenuStrip = $ctxBanned

# ==============================================================================
# ВКЛАДКА 2: Налаштування блокування (Конфігурація)
# ==============================================================================
$tabSettings = New-Object System.Windows.Forms.TabPage
$tabSettings.Text = "  Налаштування  "
$tabSettings.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabSettings)

$scrollSettings = New-Object System.Windows.Forms.Panel
$scrollSettings.Dock = [System.Windows.Forms.DockStyle]::Fill
$scrollSettings.AutoScroll = $true
$scrollSettings.Padding = New-Object System.Windows.Forms.Padding(20)
$tabSettings.Controls.Add($scrollSettings)

# Група: Основні правила
$gbGeneral = New-Object System.Windows.Forms.GroupBox
$gbGeneral.Text = "Правила виявлення та блокування"
$gbGeneral.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbGeneral.Location = New-Object System.Drawing.Point(20, 15)
$gbGeneral.Size = New-Object System.Drawing.Size(990, 215)
$scrollSettings.Controls.Add($gbGeneral)

$lblFailedAttempts = New-Object System.Windows.Forms.Label
$lblFailedAttempts.Text = "Поріг невдалих спроб входу (FailedLoginAttemptsBeforeBan):"
$lblFailedAttempts.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblFailedAttempts.Location = New-Object System.Drawing.Point(20, 32)
$lblFailedAttempts.AutoSize = $true
$gbGeneral.Controls.Add($lblFailedAttempts)

$numFailedAttempts = New-Object System.Windows.Forms.NumericUpDown
$numFailedAttempts.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$numFailedAttempts.Location = New-Object System.Drawing.Point(450, 30)
$numFailedAttempts.Size = New-Object System.Drawing.Size(120, 25)
$numFailedAttempts.Minimum = 1
$numFailedAttempts.Maximum = 1000
$numFailedAttempts.Value = 5
$gbGeneral.Controls.Add($numFailedAttempts)

$lblBanTime = New-Object System.Windows.Forms.Label
$lblBanTime.Text = "Час блокування (BanTime, формат Дні:Год:Хв:Сек):"
$lblBanTime.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblBanTime.Location = New-Object System.Drawing.Point(20, 72)
$lblBanTime.AutoSize = $true
$gbGeneral.Controls.Add($lblBanTime)

$cbBanTimePreset = New-Object System.Windows.Forms.ComboBox
$cbBanTimePreset.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$cbBanTimePreset.Location = New-Object System.Drawing.Point(450, 70)
$cbBanTimePreset.Size = New-Object System.Drawing.Size(200, 25)
$cbBanTimePreset.Items.AddRange(@(
    "01:00:00:00 (1 доба)",
    "03:00:00:00 (3 доби)",
    "07:00:00:00 (1 тиждень)",
    "30:00:00:00 (30 днів)",
    "00:01:00:00 (1 година)",
    "00:00:00:00 (Назавжди)"
))
$cbBanTimePreset.SelectedIndex = 0
$gbGeneral.Controls.Add($cbBanTimePreset)

$txtBanTimeCustom = New-Object System.Windows.Forms.TextBox
$txtBanTimeCustom.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtBanTimeCustom.Location = New-Object System.Drawing.Point(660, 70)
$txtBanTimeCustom.Size = New-Object System.Drawing.Size(120, 25)
$txtBanTimeCustom.Text = "01:00:00:00"
$gbGeneral.Controls.Add($txtBanTimeCustom)

$lblExpireTime = New-Object System.Windows.Forms.Label
$lblExpireTime.Text = "Час життя невдалих спроб до скидання (ExpireTime):"
$lblExpireTime.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblExpireTime.Location = New-Object System.Drawing.Point(20, 115)
$lblExpireTime.AutoSize = $true
$gbGeneral.Controls.Add($lblExpireTime)

$txtExpireTime = New-Object System.Windows.Forms.TextBox
$txtExpireTime.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtExpireTime.Location = New-Object System.Drawing.Point(450, 112)
$txtExpireTime.Size = New-Object System.Drawing.Size(160, 25)
$txtExpireTime.Text = "01:00:00:00"
$gbGeneral.Controls.Add($txtExpireTime)

$lblCycleTime = New-Object System.Windows.Forms.Label
$lblCycleTime.Text = "Інтервал циклу перевірки та бану (CycleTime):"
$lblCycleTime.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblCycleTime.Location = New-Object System.Drawing.Point(20, 158)
$lblCycleTime.AutoSize = $true
$gbGeneral.Controls.Add($lblCycleTime)

$txtCycleTime = New-Object System.Windows.Forms.TextBox
$txtCycleTime.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtCycleTime.Location = New-Object System.Drawing.Point(450, 155)
$txtCycleTime.Size = New-Object System.Drawing.Size(160, 25)
$txtCycleTime.Text = "00:00:00:15"
$gbGeneral.Controls.Add($txtCycleTime)

# Група: Додаткові опції поведінки
$gbBehavior = New-Object System.Windows.Forms.GroupBox
$gbBehavior.Text = "Додаткова поведінка та очищення"
$gbBehavior.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbBehavior.Location = New-Object System.Drawing.Point(20, 245)
$gbBehavior.Size = New-Object System.Drawing.Size(990, 160)
$scrollSettings.Controls.Add($gbBehavior)

$chkClearOnRestart = New-Object System.Windows.Forms.CheckBox
$chkClearOnRestart.Text = "Очищати всі заблоковані IP при перезапуску служби (ClearBannedIPAddressesOnRestart)"
$chkClearOnRestart.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkClearOnRestart.Location = New-Object System.Drawing.Point(20, 30)
$chkClearOnRestart.AutoSize = $true
$gbBehavior.Controls.Add($chkClearOnRestart)

$chkClearOnSuccess = New-Object System.Windows.Forms.CheckBox
$chkClearOnSuccess.Text = "Скидати лічильник невдалих спроб при успішному вході (ClearFailedLoginsOnSuccessfulLogin)"
$chkClearOnSuccess.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkClearOnSuccess.Location = New-Object System.Drawing.Point(20, 60)
$chkClearOnSuccess.AutoSize = $true
$gbBehavior.Controls.Add($chkClearOnSuccess)

$chkProcessInternal = New-Object System.Windows.Forms.CheckBox
$chkProcessInternal.Text = "Обробляти та блокувати внутрішні локальні IP-адреси (ProcessInternalIPAddresses)"
$chkProcessInternal.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkProcessInternal.Location = New-Object System.Drawing.Point(20, 90)
$chkProcessInternal.AutoSize = $true
$gbBehavior.Controls.Add($chkProcessInternal)

$chkResetUnbanned = New-Object System.Windows.Forms.CheckBox
$chkResetUnbanned.Text = "Скидати лічильник після розблокування IP (ResetFailedLoginCountForUnbannedIPAddresses)"
$chkResetUnbanned.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkResetUnbanned.Location = New-Object System.Drawing.Point(20, 120)
$chkResetUnbanned.AutoSize = $true
$gbBehavior.Controls.Add($chkResetUnbanned)

# Панель кнопок збереження налаштувань
$btnSaveConfig = New-Object System.Windows.Forms.Button
$btnSaveConfig.Text = "Зберегти налаштування у файл"
$btnSaveConfig.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSaveConfig.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
$btnSaveConfig.ForeColor = [System.Drawing.Color]::White
$btnSaveConfig.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveConfig.FlatAppearance.BorderSize = 0
$btnSaveConfig.Location = New-Object System.Drawing.Point(20, 420)
$btnSaveConfig.Size = New-Object System.Drawing.Size(260, 38)
$scrollSettings.Controls.Add($btnSaveConfig)

$btnReloadConfig = New-Object System.Windows.Forms.Button
$btnReloadConfig.Text = "Скинути до значень файлу"
$btnReloadConfig.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnReloadConfig.Location = New-Object System.Drawing.Point(290, 420)
$btnReloadConfig.Size = New-Object System.Drawing.Size(210, 38)
$scrollSettings.Controls.Add($btnReloadConfig)

$btnRestoreBak = New-Object System.Windows.Forms.Button
$btnRestoreBak.Text = "Відновити з бекапу (.bak)"
$btnRestoreBak.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnRestoreBak.Location = New-Object System.Drawing.Point(510, 420)
$btnRestoreBak.Size = New-Object System.Drawing.Size(210, 38)
$scrollSettings.Controls.Add($btnRestoreBak)

Set-SmoothButton $btnSaveConfig 8
Set-SmoothButton $btnReloadConfig 8
Set-SmoothButton $btnRestoreBak 8

# ==============================================================================
# ВКЛАДКА 3: Білий та Чорний списки (Whitelist / Blacklist)
# ==============================================================================
$tabLists = New-Object System.Windows.Forms.TabPage
$tabLists.Text = "  Білий / Чорний списки  "
$tabLists.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabLists)

$layoutLists = New-Object System.Windows.Forms.TableLayoutPanel
$layoutLists.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutLists.ColumnCount = 2
$layoutLists.RowCount = 2
$layoutLists.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$layoutLists.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$layoutLists.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$layoutLists.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
$tabLists.Controls.Add($layoutLists)

# Ліва колонка: Whitelist
$gbWhitelist = New-Object System.Windows.Forms.GroupBox
$gbWhitelist.Text = "Білий список (Whitelist - ніколи не блокувати)"
$gbWhitelist.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbWhitelist.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
$gbWhitelist.Dock = [System.Windows.Forms.DockStyle]::Fill
$gbWhitelist.Padding = New-Object System.Windows.Forms.Padding(10)
$layoutLists.Controls.Add($gbWhitelist, 0, 0)

$layoutWhiteInner = New-Object System.Windows.Forms.TableLayoutPanel
$layoutWhiteInner.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutWhiteInner.RowCount = 3
$layoutWhiteInner.ColumnCount = 1
$layoutWhiteInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
$layoutWhiteInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$layoutWhiteInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 45)))
$gbWhitelist.Controls.Add($layoutWhiteInner)

$lblWhiteDesc = New-Object System.Windows.Forms.Label
$lblWhiteDesc.Text = "Введіть IP-адреси або підмережі CIDR через кому або з нового рядка:"
$lblWhiteDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblWhiteDesc.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$lblWhiteDesc.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutWhiteInner.Controls.Add($lblWhiteDesc, 0, 0)

$txtWhitelist = New-Object System.Windows.Forms.TextBox
$txtWhitelist.Multiline = $true
$txtWhitelist.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtWhitelist.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtWhitelist.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtWhitelist.BackColor = [System.Drawing.Color]::FromArgb(240, 253, 244)
$txtWhitelist.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
$layoutWhiteInner.Controls.Add($txtWhitelist, 0, 1)

$panelWhiteButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$panelWhiteButtons.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelWhiteButtons.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)
$layoutWhiteInner.Controls.Add($panelWhiteButtons, 0, 2)

$btnAddLocalIP = New-Object System.Windows.Forms.Button
$btnAddLocalIP.Text = "+ Додати мою локальну IP"
$btnAddLocalIP.Size = New-Object System.Drawing.Size(180, 30)
$btnAddLocalIP.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$panelWhiteButtons.Controls.Add($btnAddLocalIP)

$btnAddPublicIP = New-Object System.Windows.Forms.Button
$btnAddPublicIP.Text = "+ Додати мою зовнішню WAN IP"
$btnAddPublicIP.Size = New-Object System.Drawing.Size(205, 30)
$btnAddPublicIP.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$panelWhiteButtons.Controls.Add($btnAddPublicIP)

Set-SmoothButton $btnAddLocalIP 6
Set-SmoothButton $btnAddPublicIP 6

# Права колонка: Blacklist
$gbBlacklist = New-Object System.Windows.Forms.GroupBox
$gbBlacklist.Text = "Чорний список (Blacklist - перманентно блокувати)"
$gbBlacklist.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbBlacklist.ForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27)
$gbBlacklist.Dock = [System.Windows.Forms.DockStyle]::Fill
$gbBlacklist.Padding = New-Object System.Windows.Forms.Padding(10)
$layoutLists.Controls.Add($gbBlacklist, 1, 0)

$layoutBlackInner = New-Object System.Windows.Forms.TableLayoutPanel
$layoutBlackInner.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutBlackInner.RowCount = 2
$layoutBlackInner.ColumnCount = 1
$layoutBlackInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
$layoutBlackInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$gbBlacklist.Controls.Add($layoutBlackInner)

$lblBlackDesc = New-Object System.Windows.Forms.Label
$lblBlackDesc.Text = "Введіть IP-адреси або підмережі CIDR для постійного блокування:"
$lblBlackDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblBlackDesc.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$lblBlackDesc.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutBlackInner.Controls.Add($lblBlackDesc, 0, 0)

$txtBlacklist = New-Object System.Windows.Forms.TextBox
$txtBlacklist.Multiline = $true
$txtBlacklist.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtBlacklist.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtBlacklist.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtBlacklist.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
$txtBlacklist.ForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27)
$layoutBlackInner.Controls.Add($txtBlacklist, 0, 1)

# Нижня панель збереження списків
$panelListsFooter = New-Object System.Windows.Forms.Panel
$panelListsFooter.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutLists.SetColumnSpan($panelListsFooter, 2)
$layoutLists.Controls.Add($panelListsFooter, 0, 1)

$btnSaveLists = New-Object System.Windows.Forms.Button
$btnSaveLists.Text = "Зберегти Білий та Чорний списки у конфігурацію"
$btnSaveLists.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSaveLists.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnSaveLists.ForeColor = [System.Drawing.Color]::White
$btnSaveLists.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaveLists.FlatAppearance.BorderSize = 0
$btnSaveLists.Location = New-Object System.Drawing.Point(10, 8)
$btnSaveLists.Size = New-Object System.Drawing.Size(390, 34)
$panelListsFooter.Controls.Add($btnSaveLists)

Set-SmoothButton $btnSaveLists 8

# ==============================================================================
# ВКЛАДКА 4: Журнал подій та логи (Logs & Events)
# ==============================================================================
$tabLogs = New-Object System.Windows.Forms.TabPage
$tabLogs.Text = "  Журнал та аудит  "
$tabLogs.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabLogs)

$layoutLogs = New-Object System.Windows.Forms.TableLayoutPanel
$layoutLogs.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutLogs.RowCount = 2
$layoutLogs.ColumnCount = 1
$layoutLogs.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 45)))
$layoutLogs.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$tabLogs.Controls.Add($layoutLogs)

# Панель перемикання та кнопок логів
$panelLogsHeader = New-Object System.Windows.Forms.Panel
$panelLogsHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelLogsHeader.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 5)
$layoutLogs.Controls.Add($panelLogsHeader, 0, 0)

$rbIPBanLog = New-Object System.Windows.Forms.RadioButton
$rbIPBanLog.Text = "Лог IPBan (logfile.txt)"
$rbIPBanLog.Checked = $true
$rbIPBanLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rbIPBanLog.Location = New-Object System.Drawing.Point(10, 10)
$rbIPBanLog.AutoSize = $true
$panelLogsHeader.Controls.Add($rbIPBanLog)

$rbEventLog = New-Object System.Windows.Forms.RadioButton
$rbEventLog.Text = "Спроби входу Windows (Security 4625)"
$rbEventLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rbEventLog.Location = New-Object System.Drawing.Point(200, 10)
$rbEventLog.AutoSize = $true
$panelLogsHeader.Controls.Add($rbEventLog)

$btnRefreshLog = New-Object System.Windows.Forms.Button
$btnRefreshLog.Text = "Оновити журнал"
$btnRefreshLog.Location = New-Object System.Drawing.Point(470, 8)
$btnRefreshLog.Size = New-Object System.Drawing.Size(140, 28)
$panelLogsHeader.Controls.Add($btnRefreshLog)

$chkAutoRefreshLog = New-Object System.Windows.Forms.CheckBox
$chkAutoRefreshLog.Text = "Авто (кожні 5 сек)"
$chkAutoRefreshLog.Location = New-Object System.Drawing.Point(620, 12)
$chkAutoRefreshLog.AutoSize = $true
$panelLogsHeader.Controls.Add($chkAutoRefreshLog)

$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = "Очистити logfile.txt"
$btnClearLog.Location = New-Object System.Drawing.Point(780, 8)
$btnClearLog.Size = New-Object System.Drawing.Size(160, 28)
$panelLogsHeader.Controls.Add($btnClearLog)

Set-SmoothButton $btnRefreshLog 6
Set-SmoothButton $btnClearLog 6

# Контейнер для вмісту логів: або текстове поле, або таблиця Windows Event
$panelLogContainer = New-Object System.Windows.Forms.Panel
$panelLogContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
$layoutLogs.Controls.Add($panelLogContainer, 0, 1)

$txtIPBanLog = New-Object System.Windows.Forms.RichTextBox
$txtIPBanLog.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtIPBanLog.ReadOnly = $true
$txtIPBanLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$txtIPBanLog.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$txtIPBanLog.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$txtIPBanLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$panelLogContainer.Controls.Add($txtIPBanLog)

$dgvEventLog = New-Object System.Windows.Forms.DataGridView
$dgvEventLog.Dock = [System.Windows.Forms.DockStyle]::Fill
$dgvEventLog.ReadOnly = $true
$dgvEventLog.AllowUserToAddRows = $false
$dgvEventLog.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$dgvEventLog.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$dgvEventLog.BackgroundColor = [System.Drawing.Color]::White
$dgvEventLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$dgvEventLog.Visible = $false
[void]$dgvEventLog.Columns.Add("Time", "Час")
[void]$dgvEventLog.Columns.Add("User", "Користувач")
[void]$dgvEventLog.Columns.Add("IPAddress", "IP-адреса")
[void]$dgvEventLog.Columns.Add("LogonType", "Тип входу")
[void]$dgvEventLog.Columns.Add("Workstation", "Робоча станція")
[void]$dgvEventLog.Columns.Add("Status", "Статус")
$panelLogContainer.Controls.Add($dgvEventLog)

# Контекстне меню для Windows Events
$ctxEvents = New-Object System.Windows.Forms.ContextMenuStrip
$miEventBan = $ctxEvents.Items.Add("Заблокувати цей IP")
$miEventWhite = $ctxEvents.Items.Add("Додати цей IP до Whitelist")
$miEventCopy = $ctxEvents.Items.Add("Копіювати IP-адресу")
$dgvEventLog.ContextMenuStrip = $ctxEvents

# ==============================================================================
# ВКЛАДКА 5: Інсталяція та Сервіс (Setup & Maintenance)
# ==============================================================================
$tabSetup = New-Object System.Windows.Forms.TabPage
$tabSetup.Text = "  Інсталяція та Сервіс  "
$tabSetup.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabSetup)

$scrollSetup = New-Object System.Windows.Forms.Panel
$scrollSetup.Dock = [System.Windows.Forms.DockStyle]::Fill
$scrollSetup.AutoScroll = $true
$scrollSetup.Padding = New-Object System.Windows.Forms.Padding(20)
$tabSetup.Controls.Add($scrollSetup)

# Група: Стан компонентів системи
$gbSysStatus = New-Object System.Windows.Forms.GroupBox
$gbSysStatus.Text = "Стан компонентів системи"
$gbSysStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbSysStatus.Location = New-Object System.Drawing.Point(20, 15)
$gbSysStatus.Size = New-Object System.Drawing.Size(990, 140)
$scrollSetup.Controls.Add($gbSysStatus)

$lblSvcStatusText = New-Object System.Windows.Forms.Label
$lblSvcStatusText.Text = "Служба Windows (IPBan): Невідомо"
$lblSvcStatusText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSvcStatusText.Location = New-Object System.Drawing.Point(20, 30)
$lblSvcStatusText.AutoSize = $true
$gbSysStatus.Controls.Add($lblSvcStatusText)

$lblAuditStatusText = New-Object System.Windows.Forms.Label
$lblAuditStatusText.Text = "Аудит невдалих спроб входу (AuditPol): Перевірка..."
$lblAuditStatusText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblAuditStatusText.Location = New-Object System.Drawing.Point(20, 60)
$lblAuditStatusText.AutoSize = $true
$gbSysStatus.Controls.Add($lblAuditStatusText)

$lblZipStatusText = New-Object System.Windows.Forms.Label
$lblZipStatusText.Text = "Локальний архів IPBan: Перевірка..."
$lblZipStatusText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblZipStatusText.Location = New-Object System.Drawing.Point(20, 93)
$lblZipStatusText.AutoSize = $true
$gbSysStatus.Controls.Add($lblZipStatusText)

$btnBrowseZip = New-Object System.Windows.Forms.Button
$btnBrowseZip.Text = "Обрати ZIP-архів..."
$btnBrowseZip.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnBrowseZip.Location = New-Object System.Drawing.Point(800, 88)
$btnBrowseZip.Size = New-Object System.Drawing.Size(160, 28)
$gbSysStatus.Controls.Add($btnBrowseZip)

$btnBrowseZip.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "IPBan Zip Архів (*.zip)|*.zip|Всі файли (*.*)|*.*"
    $ofd.Title = "Оберіть архів інсталятора IPBan"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:LocalZipBackup = $ofd.FileName
        Update-ServiceUI
    }
})

# Група: Дії інсталяції та обслуговування
$gbInstallActions = New-Object System.Windows.Forms.GroupBox
$gbInstallActions.Text = "Керування встановленням та налаштуванням"
$gbInstallActions.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbInstallActions.Location = New-Object System.Drawing.Point(20, 170)
$gbInstallActions.Size = New-Object System.Drawing.Size(990, 200)
$scrollSetup.Controls.Add($gbInstallActions)

$btnSetupAudit = New-Object System.Windows.Forms.Button
$btnSetupAudit.Text = "Увімкнути аудит безпеки Windows (AuditPol)"
$btnSetupAudit.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSetupAudit.Location = New-Object System.Drawing.Point(20, 35)
$btnSetupAudit.Size = New-Object System.Drawing.Size(340, 35)
$btnSetupAudit.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$gbInstallActions.Controls.Add($btnSetupAudit)

$lblAuditHint = New-Object System.Windows.Forms.Label
$lblAuditHint.Text = "(Обов'язково для виявлення невдалих спроб входу RDP/Windows)"
$lblAuditHint.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblAuditHint.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$lblAuditHint.Location = New-Object System.Drawing.Point(370, 43)
$lblAuditHint.AutoSize = $true
$gbInstallActions.Controls.Add($lblAuditHint)

$btnInstallLocal = New-Object System.Windows.Forms.Button
$btnInstallLocal.Text = "Встановити IPBan з локального архіву"
$btnInstallLocal.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnInstallLocal.Location = New-Object System.Drawing.Point(20, 85)
$btnInstallLocal.Size = New-Object System.Drawing.Size(340, 35)
$btnInstallLocal.BackColor = [System.Drawing.Color]::FromArgb(220, 252, 231)
$btnInstallLocal.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
$gbInstallActions.Controls.Add($btnInstallLocal)

$btnInstallWeb = New-Object System.Windows.Forms.Button
$btnInstallWeb.Text = "Завантажити та встановити найновішу з GitHub"
$btnInstallWeb.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnInstallWeb.Location = New-Object System.Drawing.Point(375, 85)
$btnInstallWeb.Size = New-Object System.Drawing.Size(340, 35)
$btnInstallWeb.BackColor = [System.Drawing.Color]::FromArgb(219, 234, 254)
$btnInstallWeb.ForeColor = [System.Drawing.Color]::FromArgb(29, 78, 216)
$gbInstallActions.Controls.Add($btnInstallWeb)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Повністю видалити службу IPBan"
$btnUninstall.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnUninstall.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
$btnUninstall.Location = New-Object System.Drawing.Point(20, 135)
$btnUninstall.Size = New-Object System.Drawing.Size(340, 35)
$gbInstallActions.Controls.Add($btnUninstall)

Set-SmoothButton $btnBrowseZip 6
Set-SmoothButton $btnSetupAudit 7
Set-SmoothButton $btnInstallLocal 7
Set-SmoothButton $btnInstallWeb 7
Set-SmoothButton $btnUninstall 7

# Група: Документація та посилання
$gbLinks = New-Object System.Windows.Forms.GroupBox
$gbLinks.Text = "Корисні посилання та документація"
$gbLinks.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$gbLinks.Location = New-Object System.Drawing.Point(20, 385)
$gbLinks.Size = New-Object System.Drawing.Size(990, 100)
$scrollSetup.Controls.Add($gbLinks)

$llGithub = New-Object System.Windows.Forms.LinkLabel
$llGithub.Text = "Офіційний репозиторій DigitalRuby/IPBan на GitHub"
$llGithub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$llGithub.Location = New-Object System.Drawing.Point(20, 30)
$llGithub.AutoSize = $true
$gbLinks.Controls.Add($llGithub)

$llWiki = New-Object System.Windows.Forms.LinkLabel
$llWiki.Text = "Документація налаштувань та конфігурації (Wiki)"
$llWiki.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$llWiki.Location = New-Object System.Drawing.Point(20, 60)
$llWiki.AutoSize = $true
$gbLinks.Controls.Add($llWiki)

# ------------------------------------------------------------------------------
# 4. Нижня смуга стану (StatusStrip)
# ------------------------------------------------------------------------------
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainLayout.Controls.Add($statusStrip, 0, 3)

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Готово"
$statusLabel.Spring = $true
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
[void]$statusStrip.Items.Add($statusLabel)

$statusAdmin = New-Object System.Windows.Forms.ToolStripStatusLabel
if ($script:IsAdmin) {
    $statusAdmin.Text = "Адміністратор"
    $statusAdmin.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
} else {
    $statusAdmin.Text = "Без прав адміністратора"
    $statusAdmin.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
}
[void]$statusStrip.Items.Add($statusAdmin)

# ------------------------------------------------------------------------------
# Реалізація Логіки та Обробників Подій
# ------------------------------------------------------------------------------

function Update-UILanguage {
    $form.Text = T "AppTitle"
    $lblTitle.Text = T "HeaderTitle"
    $lblSubtitle.Text = T "HeaderSubtitle"
    $btnStartService.Text = T "BtnStart"
    $btnStopService.Text = T "BtnStop"
    $btnRestartService.Text = T "BtnRestart"
    $btnRefreshAll.Text = T "BtnRefresh"
    $btnLang.Text = T "LangToggle"

    $lblPath.Text = T "PathLabel"
    $btnBrowsePath.Text = T "BtnBrowse"
    $btnOpenFolder.Text = T "BtnOpenFolder"
    $btnOpenConfigFile.Text = T "BtnOpenConfig"

    $tabBanned.Text = T "TabBanned"
    $tabSettings.Text = T "TabSettings"
    $tabLists.Text = T "TabLists"
    $tabLogs.Text = T "TabLogs"
    $tabSetup.Text = T "TabSetup"

    $lblSearch.Text = T "Search"
    $lblFilterType.Text = T "Filter"
    if ($cbRuleFilter -and $cbRuleFilter.Items.Count -ge 3) {
        $curIdx = $cbRuleFilter.SelectedIndex
        $cbRuleFilter.Items[0] = T "FilterBanned"
        $cbRuleFilter.Items[1] = T "FilterWhitelist"
        $cbRuleFilter.Items[2] = T "FilterAllRules"
        if ($curIdx -ge 0) { $cbRuleFilter.SelectedIndex = $curIdx }
    }
    $btnUnbanSelected.Text = T "BtnUnbanSelected"
    $btnManualBan.Text = T "BtnManualBan"
    $btnUnbanAll.Text = T "BtnUnbanAll"
    $btnExportBanned.Text = T "BtnExport"

    if ($dgvBanned.Columns["IPAddress"]) { $dgvBanned.Columns["IPAddress"].HeaderText = T "ColIP" }
    if ($dgvBanned.Columns["BanDate"]) { $dgvBanned.Columns["BanDate"].HeaderText = T "ColBanTime" }
    if ($dgvBanned.Columns["UnbanDate"]) { $dgvBanned.Columns["UnbanDate"].HeaderText = T "ColUnbanTime" }

    $gbGeneral.Text = T "GbGeneral"
    $lblFailedAttempts.Text = T "LblFailedAttempts"
    $lblBanTime.Text = T "LblBanTime"
    $lblExpireTime.Text = T "LblExpireTime"
    $lblCycleTime.Text = T "LblCycleTime"
    $gbBehavior.Text = T "GbBehavior"
    $chkClearOnRestart.Text = T "ChkClearOnRestart"
    $chkClearOnSuccess.Text = T "ChkClearOnSuccess"
    $chkProcessInternal.Text = T "ChkProcessInternal"
    $chkResetUnbanned.Text = T "ChkResetUnbanned"
    $btnSaveConfig.Text = T "BtnSaveConfig"
    $btnReloadConfig.Text = T "BtnReloadConfig"
    $btnRestoreBak.Text = T "BtnRestoreBak"

    $gbWhitelist.Text = T "GbWhitelist"
    $lblWhiteDesc.Text = T "LblWhiteDesc"
    $btnAddLocalIP.Text = T "BtnAddLocalIP"
    $btnAddPublicIP.Text = T "BtnAddPublicIP"
    $gbBlacklist.Text = T "GbBlacklist"
    $lblBlackDesc.Text = T "LblBlackDesc"
    $btnSaveLists.Text = T "BtnSaveLists"

    $rbIPBanLog.Text = T "RbIPBanLog"
    $rbEventLog.Text = T "RbEventLog"
    $btnRefreshLog.Text = T "BtnRefreshLog"
    $chkAutoRefreshLog.Text = T "ChkAutoRefresh"
    $btnClearLog.Text = T "BtnClearLog"

    if ($dgvEventLog.Columns["Time"]) { $dgvEventLog.Columns["Time"].HeaderText = T "ColTime" }
    if ($dgvEventLog.Columns["User"]) { $dgvEventLog.Columns["User"].HeaderText = T "ColUser" }
    if ($dgvEventLog.Columns["IPAddress"]) { $dgvEventLog.Columns["IPAddress"].HeaderText = T "ColIP" }
    if ($dgvEventLog.Columns["LogonType"]) { $dgvEventLog.Columns["LogonType"].HeaderText = T "ColLogonType" }
    if ($dgvEventLog.Columns["Workstation"]) { $dgvEventLog.Columns["Workstation"].HeaderText = T "ColWorkstation" }
    if ($dgvEventLog.Columns["Status"]) { $dgvEventLog.Columns["Status"].HeaderText = T "ColStatus" }

    $miEventBan.Text = T "MiEventBan"
    $miEventWhite.Text = T "MiEventWhite"
    $miEventCopy.Text = T "MiEventCopy"

    $gbSysStatus.Text = T "GbSysStatus"
    $btnBrowseZip.Text = T "BtnBrowseZip"
    $gbInstallActions.Text = T "GbInstallActions"
    $btnSetupAudit.Text = T "BtnSetupAudit"
    $lblAuditHint.Text = T "LblAuditHint"
    $btnInstallLocal.Text = T "BtnInstallLocal"
    $btnInstallWeb.Text = T "BtnInstallWeb"
    $btnUninstall.Text = T "BtnUninstallService"
    $gbLinks.Text = T "GbLinks"
    $llGithub.Text = T "LlGithub"
    $llWiki.Text = T "LlWiki"

    $statusLabel.Text = T "StatusReady"
    $statusAdmin.Text = if ($script:IsAdmin) { T "AdminYes" } else { T "AdminNo" }

    if ($script:tmiStart) { $script:tmiStart.Text = T "TrayStart" }
    if ($script:tmiStop) { $script:tmiStop.Text = T "TrayStop" }
    if ($script:tmiRestart) { $script:tmiRestart.Text = T "TrayRestart" }
    if ($script:tmiRefresh) { $script:tmiRefresh.Text = T "TrayRefresh" }
    if ($script:tmiShow) { $script:tmiShow.Text = T "TrayShow" }
    if ($script:tmiExit) { $script:tmiExit.Text = T "TrayExit" }
}

function Apply-Language([string]$lang) {
    $script:CurrentLang = $lang
    try {
        $regKey = "HKCU:\Software\IPBanControlCenter"
        if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
        Set-ItemProperty -Path $regKey -Name "Language" -Value $lang
    } catch {}

    Update-UILanguage
    Update-HeaderLayout
    Update-ServiceUI
    Filter-BannedGrid
    Refresh-LogsView
}

function Init-Tray {
    if ($script:TrayIcon) { return }

    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:TrayMenu.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $tmiTitle = $script:TrayMenu.Items.Add((T "TrayTitle"))
    $tmiTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $tmiTitle.Enabled = $false

    [void]$script:TrayMenu.Items.Add("-")

    $script:tmiStatus = $script:TrayMenu.Items.Add((T "TrayStatusChecking"))
    $script:tmiStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:tmiStatus.Enabled = $false

    $script:tmiBannedCount = $script:TrayMenu.Items.Add([string]::Format((T "TrayBannedCount"), 0))
    $script:tmiBannedCount.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:tmiBannedCount.Enabled = $false

    [void]$script:TrayMenu.Items.Add("-")

    $script:tmiStart = $script:TrayMenu.Items.Add((T "TrayStart"))
    $script:tmiStart.Add_Click({
        try {
            Start-Service -Name $script:ServiceName -ErrorAction Stop
            Start-Sleep -Seconds 1
            Update-ServiceUI
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Не вдалося запустити службу: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    $script:tmiStop = $script:TrayMenu.Items.Add((T "TrayStop"))
    $script:tmiStop.Add_Click({
        try {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
            Start-Sleep -Seconds 1
            Update-ServiceUI
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Не вдалося зупинити службу: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    $script:tmiRestart = $script:TrayMenu.Items.Add((T "TrayRestart"))
    $script:tmiRestart.Add_Click({
        Restart-ServiceAction
    })

    $script:tmiRefresh = $script:TrayMenu.Items.Add((T "TrayRefresh"))
    $script:tmiRefresh.Add_Click({
        Update-ServiceUI
        Refresh-BannedIPs
        Refresh-LogsView
    })

    [void]$script:TrayMenu.Items.Add("-")

    $script:tmiShow = $script:TrayMenu.Items.Add((T "TrayShow"))
    $script:tmiShow.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:tmiShow.Add_Click({
        $form.Show()
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.Activate()
    })

    $script:tmiExit = $script:TrayMenu.Items.Add((T "TrayExit"))
    $script:tmiExit.Add_Click({
        $script:IsExiting = $true
        $form.Close()
    })

    $script:TrayIcon.ContextMenuStrip = $script:TrayMenu
    $script:TrayIcon.Visible = $true

    # Клік лівою кнопкою відкриває вікно
    $script:TrayIcon.Add_Click({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if (-not $form.Visible -or $form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
                $form.Show()
                $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
                $form.Activate()
            }
        }
    })

    # Подвійний клік перемикає згортання/розгортання
    $script:TrayIcon.Add_DoubleClick({
        if ($form.Visible -and $form.WindowState -ne [System.Windows.Forms.FormWindowState]::Minimized) {
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            $form.Hide()
        } else {
            $form.Show()
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
            $form.Activate()
        }
    })

    # Фоновий таймер моніторингу статусу та нових блокувань (кожні 10 сек)
    $script:TrayMonitorTimer = New-Object System.Windows.Forms.Timer
    $script:TrayMonitorTimer.Interval = 10000
    $script:TrayMonitorTimer.Add_Tick({
        try {
            $ips = Get-FirewallBannedIPs
            $script:LastBannedIPs = $ips
            $blockCount = @($ips | Where-Object { $_.ActionType -eq "Block" }).Count
            if ($script:PreviousBannedCount -ge 0 -and $blockCount -gt $script:PreviousBannedCount) {
                $diff = $blockCount - $script:PreviousBannedCount
                $script:AlertActive = $true
                Update-TrayIndicator -forceState "Alert" -alertMessage "УВАГА: Заблоковано нових IP-адрес: +$diff! (Загалом: $blockCount)"
                if ($script:AlertResetTimer) { $script:AlertResetTimer.Stop(); $script:AlertResetTimer.Dispose() }
                $script:AlertResetTimer = New-Object System.Windows.Forms.Timer
                $script:AlertResetTimer.Interval = 15000
                $script:AlertResetTimer.Add_Tick({
                    $script:AlertActive = $false
                    $script:AlertResetTimer.Stop()
                    Update-TrayIndicator
                })
                $script:AlertResetTimer.Start()
            } else {
                Update-TrayIndicator
            }
            $script:PreviousBannedCount = $blockCount
        } catch {}
    })
    $script:TrayMonitorTimer.Start()

    Update-TrayIndicator
}

function Update-TrayIndicator {
    param([string]$forceState = $null, [string]$alertMessage = $null)

    if (-not $script:TrayIcon) { return }

    $svcStatus = Get-IPBanServiceStatus
    $blockCount = @($script:LastBannedIPs | Where-Object { $_.ActionType -eq "Block" }).Count

    $targetState = if ($forceState) {
        $forceState
    } elseif ($script:AlertActive) {
        "Alert"
    } elseif ($svcStatus -eq "Running") {
        "Running"
    } else {
        "Stopped"
    }

    if ($targetState -ne $script:CurrentTrayState) {
        $newIco = Get-AppTrayIcon $targetState
        $oldIco = $script:TrayIcon.Icon
        $script:TrayIcon.Icon = $newIco
        $form.Icon = $newIco
        if ($oldIco) { $oldIco.Dispose() }
        $script:CurrentTrayState = $targetState
    }

    $tipText = if ($targetState -eq "Alert") {
        "IPBan: ⚠ УВАГА! Нове блокування / загроза!"
    } elseif ($svcStatus -eq "Running") {
        "IPBan: Захист активний | Заблоковано: $blockCount IP"
    } elseif ($svcStatus -eq "Stopped") {
        "IPBan: Службу зупинено!"
    } else {
        "IPBan: Служба не встановлена"
    }
    if ($tipText.Length -gt 63) { $tipText = $tipText.Substring(0, 60) + "..." }
    $script:TrayIcon.Text = $tipText

    if ($script:tmiStatus) {
        if ($svcStatus -eq "Running") {
            $script:tmiStatus.Text = "Статус: 🟢 Працює (Running)"
            $script:tmiStart.Enabled = $false
            $script:tmiStop.Enabled = $true
            $script:tmiRestart.Enabled = $true
        } elseif ($svcStatus -eq "Stopped") {
            $script:tmiStatus.Text = "Статус: 🔴 Зупинено (Stopped)"
            $script:tmiStart.Enabled = $true
            $script:tmiStop.Enabled = $false
            $script:tmiRestart.Enabled = $false
        } else {
            $script:tmiStatus.Text = "Статус: ⚪ Не встановлено"
            $script:tmiStart.Enabled = $false
            $script:tmiStop.Enabled = $false
            $script:tmiRestart.Enabled = $false
        }
    }

    if ($script:tmiBannedCount) {
        $script:tmiBannedCount.Text = "Заблоковано в брандмауері: $blockCount IP"
    }

    if ($alertMessage) {
        $script:TrayIcon.ShowBalloonTip(4000, "IPBan Control Center", $alertMessage, [System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

function Update-ServiceUI {
    $status = Get-IPBanServiceStatus
    switch ($status) {
        "Running" {
            $lblStatusBadge.Text = T "StatusRunning"
            $lblStatusBadge.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
            $btnStartService.Enabled = $false
            $btnStopService.Enabled = $true
            $btnRestartService.Enabled = $true
            $lblSvcStatusText.Text = T "SvcRunning"
            $lblSvcStatusText.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
        }
        "Stopped" {
            $lblStatusBadge.Text = T "StatusStopped"
            $lblStatusBadge.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
            $btnStartService.Enabled = $true
            $btnStopService.Enabled = $false
            $btnRestartService.Enabled = $false
            $lblSvcStatusText.Text = T "SvcStopped"
            $lblSvcStatusText.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
        }
        default {
            $lblStatusBadge.Text = T "StatusNotInstalled"
            $lblStatusBadge.BackColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
            $btnStartService.Enabled = $false
            $btnStopService.Enabled = $false
            $btnRestartService.Enabled = $false
            $lblSvcStatusText.Text = T "SvcNotInstalled"
            $lblSvcStatusText.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
        }
    }

    $foundZip = Find-LocalIPBanZip
    if ($foundZip) {
        $script:LocalZipBackup = $foundZip
        $foundMsg = if ($script:CurrentLang -eq "EN") { "Local IPBan Archive: Found ($foundZip)" } else { "Локальний архів IPBan: Знайдено ($foundZip)" }
        $lblZipStatusText.Text = $foundMsg
        $lblZipStatusText.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
        $btnInstallLocal.Enabled = $true
        $btnInstallLocal.Text = T "BtnInstallLocal"
    } else {
        $notFoundMsg = if ($script:CurrentLang -eq "EN") { "Local IPBan Archive: Not found (select file or download from GitHub)" } else { "Локальний архів IPBan: Не знайдено (оберіть файл або завантажте з GitHub)" }
        $lblZipStatusText.Text = $notFoundMsg
        $lblZipStatusText.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
        $btnInstallLocal.Enabled = $true
        $btnInstallLocal.Text = if ($script:CurrentLang -eq "EN") { "Choose ZIP Archive & Install..." } else { "Обрати ZIP-архів та встановити..." }
    }

    try {
        $auditCheck = & auditpol.exe /get /category:"Logon/Logoff" 2>$null
        if ($auditCheck -match "Success and Failure|Успех и отказ|Успіх та відмова") {
            $auditOk = if ($script:CurrentLang -eq "EN") { "Windows Security Audit (AuditPol): Enabled (Success and Failure)" } else { "Аудит невдалих спроб входу (AuditPol): Увімкнено (Success and Failure)" }
            $lblAuditStatusText.Text = $auditOk
            $lblAuditStatusText.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
        } else {
            $auditWarn = if ($script:CurrentLang -eq "EN") { "Windows Security Audit (AuditPol): May not be fully enabled" } else { "Аудит невдалих спроб входу (AuditPol): Можливо не налаштовано повністю" }
            $lblAuditStatusText.Text = $auditWarn
            $lblAuditStatusText.ForeColor = [System.Drawing.Color]::FromArgb(194, 65, 12)
        }
    } catch {
        $auditErr = if ($script:CurrentLang -eq "EN") { "Windows Security Audit (AuditPol): Permission denied to check" } else { "Аудит невдалих спроб входу (AuditPol): Немає доступу для перевірки" }
        $lblAuditStatusText.Text = $auditErr
    }

    Update-TrayIndicator
}

function Refresh-BannedIPs {
    $statusLabel.Text = if ($script:CurrentLang -eq "EN") { "Loading IPBan firewall rules..." } else { "Завантаження правил брандмауера IPBan..." }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        $script:LastBannedIPs = Get-FirewallBannedIPs
        Filter-BannedGrid
        $blockCount = @($script:LastBannedIPs | Where-Object { $_.ActionType -eq "Block" }).Count
        $allowCount = @($script:LastBannedIPs | Where-Object { $_.ActionType -eq "Allow" }).Count
        $statusLabel.Text = if ($script:CurrentLang -eq "EN") { "Rules refreshed. Blocked: $blockCount | Whitelisted: $allowCount" } else { "Правила оновлено. Заблоковано: $blockCount | У білому списку: $allowCount" }

        # Перевірка на новий бан для тривоги (Alert)
        if ($script:PreviousBannedCount -ge 0 -and $blockCount -gt $script:PreviousBannedCount) {
            $diff = $blockCount - $script:PreviousBannedCount
            $script:AlertActive = $true
            $alertMsg = if ($script:CurrentLang -eq "EN") { "IPBan banned new IP addresses: +$diff! (Total: $blockCount)" } else { "IPBan заблокував нових адрес: +$diff! (Всього: $blockCount)" }
            Update-TrayIndicator -forceState "Alert" -alertMessage $alertMsg
            if ($script:AlertResetTimer) { $script:AlertResetTimer.Stop(); $script:AlertResetTimer.Dispose() }
            $script:AlertResetTimer = New-Object System.Windows.Forms.Timer
            $script:AlertResetTimer.Interval = 15000
            $script:AlertResetTimer.Add_Tick({
                $script:AlertActive = $false
                $script:AlertResetTimer.Stop()
                Update-TrayIndicator
            })
            $script:AlertResetTimer.Start()
        } else {
            Update-TrayIndicator
        }
        $script:PreviousBannedCount = $blockCount
    } catch {
        $errMsg = if ($script:CurrentLang -eq "EN") { "Error loading rules: $_" } else { "Помилка завантаження правил: $_" }
        $statusLabel.Text = $errMsg
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

function Filter-BannedGrid {
    $dgvBanned.Rows.Clear()
    $filter = $txtSearchBanned.Text.Trim()
    $filterMode = if ($cbRuleFilter -and $cbRuleFilter.SelectedIndex -ge 0) { $cbRuleFilter.SelectedIndex } else { 0 }

    $allList = @($script:LastBannedIPs)
    $blockCount = @($allList | Where-Object { $_.ActionType -eq "Block" }).Count
    $allowCount = @($allList | Where-Object { $_.ActionType -eq "Allow" }).Count

    # Отримуємо карту часу блокувань із БД / логів
    $timesMap = Get-IPBanTimesMap

    $idx = 1
    foreach ($item in $allList) {
        if ($filterMode -eq 0 -and $item.ActionType -ne "Block") { continue }
        if ($filterMode -eq 1 -and $item.ActionType -ne "Allow") { continue }

        if ([string]::IsNullOrEmpty($filter) -or $item.IPAddress.Contains($filter) -or $item.RuleName.Contains($filter)) {
            $isBlock = ($item.ActionType -eq "Block")

            $banDateStr = "—"
            $unbanDateStr = "—"

            if ($isBlock) {
                $info = $timesMap[$item.IPAddress]
                if ($info -and $info.BanDate) {
                    $banDateStr = $info.BanDate.ToString("dd.MM.yyyy HH:mm:ss")
                    $durStr = if ($info.Duration) { $info.Duration } else { $script:CurrentBanTimeSetting }
                    if ($durStr -eq "00:00:00:00" -or $durStr -eq "0.00:00:00") {
                        $unbanDateStr = (T "BanPermanent")
                    } else {
                        try {
                            $ts = [TimeSpan]::Parse($durStr)
                            $unbanDateStr = $info.BanDate.Add($ts).ToString("dd.MM.yyyy HH:mm:ss")
                        } catch {
                            $unbanDateStr = (T "BanPerConfig")
                        }
                    }
                } else {
                    $banDateStr = (T "BanActive")
                    $durStr = $script:CurrentBanTimeSetting
                    if ($durStr -eq "00:00:00:00" -or $durStr -eq "0.00:00:00") {
                        $unbanDateStr = (T "BanPermanent")
                    } else {
                        $unbanDateStr = (T "BanPerConfig")
                    }
                }
            } else {
                $banDateStr = (T "WhitelistNote")
                $unbanDateStr = "—"
            }

            $rowIdx = $dgvBanned.Rows.Add(
                $idx,
                $item.IPAddress,
                $banDateStr,
                $unbanDateStr
            )
            $row = $dgvBanned.Rows[$rowIdx]
            $row.Tag = $item.ActionType

            # Розділення кольором: блідо-червоний для заблокованих, блідо-зелений для білого списку
            if ($isBlock) {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27)
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(254, 202, 202)
                $row.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27)
            } else {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 253, 244)
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(187, 247, 208)
                $row.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
            }

            $idx++
        }
    }

    if ($filterMode -eq 0) {
        if ($blockCount -eq 0) {
            $lblBannedCount.Text = [string]::Format((T "LblNoBans"), $allowCount)
            $lblBannedCount.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
        } else {
            $lblBannedCount.Text = [string]::Format((T "LblBansCount"), $blockCount, $dgvBanned.Rows.Count, $allowCount)
            $lblBannedCount.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
        }
    } elseif ($filterMode -eq 1) {
        $lblBannedCount.Text = [string]::Format((T "LblWhiteCount"), $allowCount, $dgvBanned.Rows.Count, $blockCount)
        $lblBannedCount.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    } else {
        $lblBannedCount.Text = [string]::Format((T "LblAllRulesCount"), $allList.Count, $dgvBanned.Rows.Count)
        $lblBannedCount.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    }
}

function Load-ConfigData {
    $configFile = Get-IPBanConfigFile
    if (-not (Test-Path $configFile)) {
        $statusLabel.Text = "Файл конфігурації не знайдено: $configFile"
        return
    }

    try {
        [xml]$xml = Get-Content -Path $configFile -Encoding UTF8 -Raw

        function Get-XmlKey([string]$key) {
            $node = $xml.SelectSingleNode("//appSettings/add[@key='$key']")
            if ($null -ne $node -and $node.HasAttribute("value")) {
                return $node.GetAttribute("value")
            }
            return $null
        }

        $valAttempts = Get-XmlKey "FailedLoginAttemptsBeforeBan"
        if ($valAttempts) { $numFailedAttempts.Value = [int]$valAttempts }

        $valBanTime = Get-XmlKey "BanTime"
        if ($valBanTime) {
            $script:CurrentBanTimeSetting = $valBanTime
            $txtBanTimeCustom.Text = $valBanTime
            $foundIndex = -1
            for ($i = 0; $i -lt $cbBanTimePreset.Items.Count; $i++) {
                if ($cbBanTimePreset.Items[$i].ToString().StartsWith($valBanTime)) {
                    $foundIndex = $i
                    break
                }
            }
            if ($foundIndex -ge 0) { $cbBanTimePreset.SelectedIndex = $foundIndex }
        }

        $valExpire = Get-XmlKey "ExpireTime"
        if ($valExpire) { $txtExpireTime.Text = $valExpire }

        $valCycle = Get-XmlKey "CycleTime"
        if ($valCycle) { $txtCycleTime.Text = $valCycle }

        $valClearRestart = Get-XmlKey "ClearBannedIPAddressesOnRestart"
        $chkClearOnRestart.Checked = ($valClearRestart -eq "true")

        $valClearSuccess = Get-XmlKey "ClearFailedLoginsOnSuccessfulLogin"
        $chkClearOnSuccess.Checked = ($valClearSuccess -eq "true")

        $valProcessInternal = Get-XmlKey "ProcessInternalIPAddresses"
        $chkProcessInternal.Checked = ($valProcessInternal -eq "true")

        $valResetUnbanned = Get-XmlKey "ResetFailedLoginCountForUnbannedIPAddresses"
        $chkResetUnbanned.Checked = ($valResetUnbanned -eq "true")

        # Whitelist & Blacklist
        $valWhite = Get-XmlKey "Whitelist"
        if ($valWhite) {
            $whiteItems = ($valWhite -split ",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $txtWhitelist.Text = ($whiteItems -join "`r`n")
        } else {
            $txtWhitelist.Text = ""
        }

        $valBlack = Get-XmlKey "Blacklist"
        if ($valBlack) {
            $blackItems = ($valBlack -split ",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $txtBlacklist.Text = ($blackItems -join "`r`n")
        } else {
            $txtBlacklist.Text = ""
        }

        $statusLabel.Text = "Налаштування завантажено з $([System.IO.Path]::GetFileName($configFile))"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка читання конфігурації: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Save-ConfigData {
    $configFile = Get-IPBanConfigFile
    $configDir = [System.IO.Path]::GetDirectoryName($configFile)

    if (-not (Test-Path $configDir)) {
        try {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Не вдалося створити папку: $configDir`n$_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    }

    try {
        [xml]$xml = $null
        if (Test-Path $configFile) {
            $bakFile = "$configFile.bak"
            Copy-Item -Path $configFile -Destination $bakFile -Force
            [xml]$xml = Get-Content -Path $configFile -Encoding UTF8 -Raw
        } else {
            [xml]$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
  </appSettings>
</configuration>
"@
        }

        $appSettingsNode = $xml.SelectSingleNode("//appSettings")
        if ($null -eq $appSettingsNode) {
            $configNode = $xml.SelectSingleNode("//configuration")
            if ($null -eq $configNode) {
                $configNode = $xml.AppendChild($xml.CreateElement("configuration"))
            }
            $appSettingsNode = $configNode.AppendChild($xml.CreateElement("appSettings"))
        }

        function Set-XmlKey([string]$key, [string]$val) {
            $node = $xml.SelectSingleNode("//appSettings/add[@key='$key']")
            if ($null -ne $node) {
                $node.SetAttribute("value", $val)
            } else {
                $newNode = $xml.CreateElement("add")
                $newNode.SetAttribute("key", $key)
                $newNode.SetAttribute("value", $val)
                $appSettingsNode.AppendChild($newNode) | Out-Null
            }
        }

        Set-XmlKey "FailedLoginAttemptsBeforeBan" $numFailedAttempts.Value.ToString()
        Set-XmlKey "BanTime" $txtBanTimeCustom.Text.Trim()
        Set-XmlKey "ExpireTime" $txtExpireTime.Text.Trim()
        Set-XmlKey "CycleTime" $txtCycleTime.Text.Trim()
        Set-XmlKey "ClearBannedIPAddressesOnRestart" ($chkClearOnRestart.Checked.ToString().ToLower())
        Set-XmlKey "ClearFailedLoginsOnSuccessfulLogin" ($chkClearOnSuccess.Checked.ToString().ToLower())
        Set-XmlKey "ProcessInternalIPAddresses" ($chkProcessInternal.Checked.ToString().ToLower())
        Set-XmlKey "ResetFailedLoginCountForUnbannedIPAddresses" ($chkResetUnbanned.Checked.ToString().ToLower())

        $whiteListFormatted = ($txtWhitelist.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ","
        Set-XmlKey "Whitelist" $whiteListFormatted

        $blackListFormatted = ($txtBlacklist.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ","
        Set-XmlKey "Blacklist" $blackListFormatted

        $xml.Save($configFile)
        $statusLabel.Text = "Налаштування успішно збережено у $configFile"

        $resp = [System.Windows.Forms.MessageBox]::Show("Налаштування збережено у файл:`n$configFile`n`nБажаєте перезапустити службу IPBan зараз, щоб застосувати зміни?", "Збережено", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($resp -eq [System.Windows.Forms.DialogResult]::Yes) {
            Restart-ServiceAction
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка збереження файлу конфігурації: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Refresh-LogsView {
    if ($rbIPBanLog.Checked) {
        $dgvEventLog.Visible = $false
        $txtIPBanLog.Visible = $true
        $path = Get-IPBanPath
        $logFile = Join-Path $path "logfile.txt"
        if (Test-Path $logFile) {
            try {
                $lines = Get-Content -Path $logFile -Tail 250 -Encoding UTF8 -ErrorAction Stop
                $txtIPBanLog.Text = ($lines -join "`r`n")
                $txtIPBanLog.SelectionStart = $txtIPBanLog.Text.Length
                $txtIPBanLog.ScrollToCaret()
                $statusLabel.Text = "Лог IPBan оновлено ($($lines.Count) останніх рядків)"
            } catch {
                $txtIPBanLog.Text = "Не вдалося прочитати лог-файл: $_"
            }
        } else {
            $txtIPBanLog.Text = "Файл логу не знайдено за шляхом: $logFile`n`nЛоги з'являться після запуску служби IPBan."
        }
    } else {
        $txtIPBanLog.Visible = $false
        $dgvEventLog.Visible = $true
        $statusLabel.Text = "Опитування журналу безпеки Windows (Event 4625)..."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $events = Get-WindowsFailedLogins -maxEvents 50
            $dgvEventLog.Rows.Clear()
            foreach ($e in $events) {
                [void]$dgvEventLog.Rows.Add(
                    $e.TimeCreated,
                    $e.TargetUser,
                    $e.IPAddress,
                    $e.LogonType,
                    $e.Workstation,
                    $e.Status
                )
            }
            $statusLabel.Text = "Отримано невдалих спроб входу: $($events.Count)"
        } catch {
            $statusLabel.Text = "Помилка читання журналу подій: $_"
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }
}

function Restart-ServiceAction {
    $statusLabel.Text = "Перезапуск служби IPBan..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        Restart-Service -Name $script:ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 1
        Update-ServiceUI
        $statusLabel.Text = "Службу IPBan успішно перезапущено!"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка перезапуску служби: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $statusLabel.Text = "Помилка перезапуску служби"
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# ------------------------------------------------------------------------------
# Прив'язка подій елементів керування
# ------------------------------------------------------------------------------

# Кнопки Header
$btnStartService.Add_Click({
    try {
        $statusLabel.Text = "Запуск служби IPBan..."
        Start-Service -Name $script:ServiceName -ErrorAction Stop
        Start-Sleep -Seconds 1
        Update-ServiceUI
        $statusLabel.Text = "Службу IPBan запущено!"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Не вдалося запустити службу: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnStopService.Add_Click({
    try {
        $statusLabel.Text = "Зупинка служби IPBan..."
        Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 1
        Update-ServiceUI
        $statusLabel.Text = "Службу IPBan зупинено!"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Не вдалося зупинити службу: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnRestartService.Add_Click({ Restart-ServiceAction })

$btnRefreshAll.Add_Click({
    Update-ServiceUI
    Refresh-BannedIPs
    Refresh-LogsView
    Load-ConfigData
})

# Path Bar
$btnBrowsePath.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.SelectedPath = $txtInstallPath.Text
    $fbd.Description = "Виберіть папку встановлення IPBan"
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstallPath.Text = $fbd.SelectedPath
        $script:CurrentInstallPath = $fbd.SelectedPath
        Update-ServiceUI
        Load-ConfigData
    }
})

$btnOpenFolder.Add_Click({
    $path = Get-IPBanPath
    if (Test-Path $path) {
        [System.Diagnostics.Process]::Start("explorer.exe", $path)
    } else {
        [System.Windows.Forms.MessageBox]::Show("Папка не існує: $path", "Увага", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

$btnOpenConfigFile.Add_Click({
    $cfg = Get-IPBanConfigFile
    if (Test-Path $cfg) {
        [System.Diagnostics.Process]::Start("notepad.exe", $cfg)
    } else {
        [System.Windows.Forms.MessageBox]::Show("Файл конфігурації не існує: $cfg", "Увага", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Tab 1: Banned IPs
$txtSearchBanned.Add_TextChanged({ Filter-BannedGrid })
$cbRuleFilter.Add_SelectedIndexChanged({ Filter-BannedGrid })

$btnUnbanSelected.Add_Click({
    if ($dgvBanned.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Оберіть один або декілька рядків з IP для розблокування.", "Увага", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $ipsToUnban = @()
    $whitelistIps = @()
    foreach ($row in $dgvBanned.SelectedRows) {
        $ip = $row.Cells["IPAddress"].Value.ToString()
        if ($row.Tag -eq "Allow") {
            $whitelistIps += $ip
        } else {
            $ipsToUnban += $ip
        }
    }

    if ($whitelistIps.Count -gt 0 -and $ipsToUnban.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Обрані IP ($($whitelistIps -join ', ') ) знаходяться у Білому списку (дозволено), а не в блокуванні!`n`nЩоб прибрати адресу з білого списку, перейдіть на вкладку 'Білий / Чорний списки'.", "Інформація", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    if ($ipsToUnban.Count -gt 0) {
        $msg = "Ви впевнені, що хочете розблокувати наступні IP ($($ipsToUnban.Count)):`n`n" + ($ipsToUnban -join ", ")
        $ans = [System.Windows.Forms.MessageBox]::Show($msg, "Підтвердження розблокування", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            foreach ($ip in $ipsToUnban) {
                Unban-IPAddress -ip $ip
            }
            [System.Windows.Forms.MessageBox]::Show("Запит на розблокування відправлено до IPBan та брандмауера!", "Успіх", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            Start-Sleep -Milliseconds 500
            Refresh-BannedIPs
        }
    }
})

$btnManualBan.Add_Click({
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Ручне блокування IP-адреси"
    $inputForm.Size = New-Object System.Drawing.Size(420, 200)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false

    $lblInput = New-Object System.Windows.Forms.Label
    $lblInput.Text = "Введіть IP-адресу для негайного блокування:"
    $lblInput.Location = New-Object System.Drawing.Point(20, 20)
    $lblInput.AutoSize = $true
    $inputForm.Controls.Add($lblInput)

    $txtInputIP = New-Object System.Windows.Forms.TextBox
    $txtInputIP.Location = New-Object System.Drawing.Point(20, 50)
    $txtInputIP.Size = New-Object System.Drawing.Size(360, 25)
    $inputForm.Controls.Add($txtInputIP)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "Заблокувати"
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnOk.Location = New-Object System.Drawing.Point(180, 100)
    $btnOk.Size = New-Object System.Drawing.Size(100, 30)
    $inputForm.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Скасувати"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnCancel.Location = New-Object System.Drawing.Point(290, 100)
    $btnCancel.Size = New-Object System.Drawing.Size(90, 30)
    $inputForm.Controls.Add($btnCancel)
    $inputForm.AcceptButton = $btnOk

    if ($inputForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $ipToBlock = $txtInputIP.Text.Trim()
        if ($ipToBlock) {
            Ban-IPAddressManual -ip $ipToBlock
            Refresh-BannedIPs
        }
    }
})

$btnUnbanAll.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("УВАГА! Ви дійсно хочете розблокувати ВСІ поточні IP-адреси у правилах блокування IPBan?`n`nПравила Білого списку (Whitelist) НЕ будуть видалені.", "Очищення всіх блокувань", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            $fw = New-Object -ComObject HNetCfg.FwPolicy2
            foreach ($rule in $fw.Rules) {
                if ($rule.Name -like "IPBan*" -and $rule.Name -notlike "*Whitelist*" -and $rule.Action -eq 0) {
                    $rule.RemoteAddresses = "255.255.255.255"
                    $rule.Enabled = $false
                }
            }
            $path = Get-IPBanPath
            if (Test-Path $path) {
                $unbanFile = Join-Path $path "unban.txt"
                $allBannedIps = @($script:LastBannedIPs | Where-Object { $_.ActionType -eq "Block" } | ForEach-Object { $_.IPAddress })
                if ($allBannedIps.Count -gt 0) {
                    $allBannedIps | Set-Content -Path $unbanFile -Encoding UTF8
                }
            }
            [System.Windows.Forms.MessageBox]::Show("Всі правила блокування успішно очищено!", "Успіх", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            Refresh-BannedIPs
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Помилка очищення: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

$btnExportBanned.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv"
    $sfd.FileName = "IPBan_IPs_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $isCsv = $sfd.FileName.EndsWith(".csv", [System.StringComparison]::OrdinalIgnoreCase)
            $exportList = @()
            if ($isCsv) {
                $exportList += "Index,IPAddress,BanDate,UnbanDate,Type"
                for ($r = 0; $r -lt $dgvBanned.Rows.Count; $r++) {
                    $row = $dgvBanned.Rows[$r]
                    $exportList += "$($row.Cells['Index'].Value),`"$($row.Cells['IPAddress'].Value)`",`"$($row.Cells['BanDate'].Value)`",`"$($row.Cells['UnbanDate'].Value)`",`"$($row.Tag)`""
                }
            } else {
                for ($r = 0; $r -lt $dgvBanned.Rows.Count; $r++) {
                    $row = $dgvBanned.Rows[$r]
                    $exportList += "$($row.Cells['IPAddress'].Value)`t$($row.Cells['BanDate'].Value)`t$($row.Cells['UnbanDate'].Value)"
                }
            }
            $exportList | Set-Content -Path $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Список успішно збережено у файл!`n$($sfd.FileName)", "Експорт завершено", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Помилка експорту: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Контекстне меню таблиці блокувань
$miCopyIP.Add_Click({
    if ($dgvBanned.SelectedRows.Count -gt 0) {
        $ip = $dgvBanned.SelectedRows[0].Cells["IPAddress"].Value.ToString()
        [System.Windows.Forms.Clipboard]::SetText($ip)
    }
})

$miUnban.Add_Click({
    $btnUnbanSelected.PerformClick()
})

$miWhitelist.Add_Click({
    if ($dgvBanned.SelectedRows.Count -gt 0) {
        $ip = $dgvBanned.SelectedRows[0].Cells["IPAddress"].Value.ToString()
        $current = $txtWhitelist.Text.Trim()
        if ($current -notmatch [regex]::Escape($ip)) {
            if ($current) { $txtWhitelist.Text += "`r`n$ip" } else { $txtWhitelist.Text = $ip }
            [System.Windows.Forms.MessageBox]::Show("IP-адресу $ip додано до вкладки 'Білий список'. Не забудьте натиснути 'Зберегти' на вкладці списків!", "Додано", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $tabControl.SelectedTab = $tabLists
        } else {
            [System.Windows.Forms.MessageBox]::Show("IP $ip вже присутня у білому списку.", "Інформація", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
})

# Tab 2: Settings
$cbBanTimePreset.Add_SelectedIndexChanged({
    $sel = $cbBanTimePreset.SelectedItem.ToString()
    $match = [regex]::Match($sel, "^\d{2}:\d{2}:\d{2}:\d{2}")
    if ($match.Success) {
        $txtBanTimeCustom.Text = $match.Value
    }
})

$btnSaveConfig.Add_Click({ Save-ConfigData })
$btnReloadConfig.Add_Click({ Load-ConfigData })

$btnRestoreBak.Add_Click({
    $cfg = Get-IPBanConfigFile
    $bak = "$cfg.bak"
    if (Test-Path $bak) {
        $ans = [System.Windows.Forms.MessageBox]::Show("Відновити конфігурацію з $bak ?", "Підтвердження", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            Copy-Item -Path $bak -Destination $cfg -Force
            Load-ConfigData
            [System.Windows.Forms.MessageBox]::Show("Конфігурацію відновлено з бекапу!", "Успіх", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Резервної копії не знайдено: $bak", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Tab 3: Lists (Whitelist / Blacklist)
$btnAddLocalIP.Add_Click({
    try {
        $localIPs = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }).IPAddress
        if ($localIPs) {
            foreach ($ip in $localIPs) {
                if ($txtWhitelist.Text -notmatch [regex]::Escape($ip)) {
                    if ($txtWhitelist.Text.Trim()) { $txtWhitelist.Text += "`r`n$ip" } else { $txtWhitelist.Text = $ip }
                }
            }
            [System.Windows.Forms.MessageBox]::Show("Локальну IP ($($localIPs -join ', ')) додано до списку!", "Додано", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка отримання IP: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnAddPublicIP.Add_Click({
    $btnAddPublicIP.Enabled = $false
    $statusLabel.Text = "Отримання зовнішньої публічної IP-адреси..."
    try {
        $wanIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 3).Trim()
        if ($wanIP -and $wanIP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            if ($txtWhitelist.Text -notmatch [regex]::Escape($wanIP)) {
                if ($txtWhitelist.Text.Trim()) { $txtWhitelist.Text += "`r`n$wanIP" } else { $txtWhitelist.Text = $wanIP }
                [System.Windows.Forms.MessageBox]::Show("Зовнішню публічну IP ($wanIP) додано до Whitelist!", "Успіх", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("Зовнішня IP ($wanIP) вже присутня у списку.", "Інформація", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Не вдалося автоматично визначити зовнішню IP: $_", "Увага", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    } finally {
        $btnAddPublicIP.Enabled = $true
        $statusLabel.Text = "Готово"
    }
})

$btnSaveLists.Add_Click({
    Save-ConfigData
})

# Tab 4: Logs
$rbIPBanLog.Add_CheckedChanged({ Refresh-LogsView })
$rbEventLog.Add_CheckedChanged({ Refresh-LogsView })
$btnRefreshLog.Add_Click({ Refresh-LogsView })

$btnClearLog.Add_Click({
    $path = Get-IPBanPath
    $logFile = Join-Path $path "logfile.txt"
    if (Test-Path $logFile) {
        $ans = [System.Windows.Forms.MessageBox]::Show("Ви дійсно хочете очистити logfile.txt?", "Очищення логу", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                Clear-Content -Path $logFile -Force
                $txtIPBanLog.Text = ""
                $statusLabel.Text = "Лог-файл успішно очищено"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Не вдалося очистити лог: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    }
})

# Контекстне меню Event Log
$miEventBan.Add_Click({
    if ($dgvEventLog.SelectedRows.Count -gt 0) {
        $ip = $dgvEventLog.SelectedRows[0].Cells["IPAddress"].Value.ToString()
        if ($ip -and $ip -notlike "*Локальн*") {
            Ban-IPAddressManual -ip $ip
            Refresh-BannedIPs
        }
    }
})

$miEventWhite.Add_Click({
    if ($dgvEventLog.SelectedRows.Count -gt 0) {
        $ip = $dgvEventLog.SelectedRows[0].Cells["IPAddress"].Value.ToString()
        if ($ip -and $ip -notlike "*Локальн*") {
            if ($txtWhitelist.Text.Trim()) { $txtWhitelist.Text += "`r`n$ip" } else { $txtWhitelist.Text = $ip }
            $tabControl.SelectedTab = $tabLists
        }
    }
})

$miEventCopy.Add_Click({
    if ($dgvEventLog.SelectedRows.Count -gt 0) {
        $ip = $dgvEventLog.SelectedRows[0].Cells["IPAddress"].Value.ToString()
        [System.Windows.Forms.Clipboard]::SetText($ip)
    }
})

# Таймер автооновлення логів
$script:AutoRefreshTimer = New-Object System.Windows.Forms.Timer
$script:AutoRefreshTimer.Interval = 5000
$script:AutoRefreshTimer.Add_Tick({
    if ($chkAutoRefreshLog.Checked) {
        Refresh-LogsView
    }
})

$chkAutoRefreshLog.Add_CheckedChanged({
    if ($chkAutoRefreshLog.Checked) {
        $script:AutoRefreshTimer.Start()
    } else {
        $script:AutoRefreshTimer.Stop()
    }
})

# Tab 5: Setup & Maintenance
$btnSetupAudit.Add_Click({
    $statusLabel.Text = "Налаштування Windows Audit Policy..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        & auditpol.exe /set /category:"{69979849-797A-11D9-BED3-505054503030}" /success:enable /failure:enable
        & auditpol.exe /set /category:"{69979850-797A-11D9-BED3-505054503030}" /success:enable /failure:enable
        Update-ServiceUI
        [System.Windows.Forms.MessageBox]::Show("Аудит успішних та невдалих спроб входу успішно увімкнено!", "Успіх", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка налаштування аудиту: $_`nПереконайтеся, що програму запущено з правами адміністратора.", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $statusLabel.Text = "Готово"
    }
})

$btnInstallLocal.Add_Click({
    $zipPath = $script:LocalZipBackup
    if (-not $zipPath -or -not (Test-Path $zipPath)) {
        $zipPath = Find-LocalIPBanZip
    }

    if (-not $zipPath -or -not (Test-Path $zipPath)) {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = "IPBan Zip Архів (*.zip)|*.zip|Всі файли (*.*)|*.*"
        $ofd.Title = "Оберіть архів інсталятора IPBan для встановлення"
        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $zipPath = $ofd.FileName
            $script:LocalZipBackup = $zipPath
            Update-ServiceUI
        } else {
            return
        }
    }

    $destPath = $txtInstallPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($destPath)) {
        $destPath = "C:\Program Files\IPBan"
        $txtInstallPath.Text = $destPath
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show("Встановити IPBan з архіву:`n`"$zipPath`"`nу папку:`n`"$destPath`"?`n`nБуде налаштовано службу IPBan та аудит Windows.", "Підтвердження інсталяції", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $statusLabel.Text = "Встановлення IPBan з локального архіву..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        Install-IPBanFromArchive -zipPath $zipPath -destPath $destPath

        Update-ServiceUI
        Load-ConfigData
        Refresh-BannedIPs

        [System.Windows.Forms.MessageBox]::Show("IPBan успішно встановлено та запущено як службу Windows!", "Інсталяція завершена", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка під час встановлення: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $statusLabel.Text = "Готово"
    }
})

$btnInstallWeb.Add_Click({
    $destPath = $txtInstallPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($destPath)) {
        $destPath = "C:\Program Files\IPBan"
        $txtInstallPath.Text = $destPath
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Завантажити найновішу версію IPBan з офіційного GitHub та встановити у папку:`n`"$destPath`"?`n`nБуде завантажено інсталяційний архів, налаштовано службу Windows та активовано аудит невдалих спроб входу.",
        "Встановлення IPBan з GitHub",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Встановлення IPBan з GitHub"
    $dlg.Size = New-Object System.Drawing.Size(520, 185)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ControlBox = $false
    $dlg.TopMost = $true

    $lblProgress = New-Object System.Windows.Forms.Label
    $lblProgress.Text = "Отримання інформації про реліз з GitHub..."
    $lblProgress.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $lblProgress.Location = New-Object System.Drawing.Point(20, 18)
    $lblProgress.Size = New-Object System.Drawing.Size(465, 24)
    $dlg.Controls.Add($lblProgress)

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point(20, 48)
    $pb.Size = New-Object System.Drawing.Size(465, 24)
    $pb.Minimum = 0
    $pb.Maximum = 100
    $pb.Value = 0
    $dlg.Controls.Add($pb)

    $lblDetails = New-Object System.Windows.Forms.Label
    $lblDetails.Text = "З'єднання з сервером GitHub..."
    $lblDetails.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $lblDetails.Location = New-Object System.Drawing.Point(20, 80)
    $lblDetails.Size = New-Object System.Drawing.Size(465, 20)
    $lblDetails.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    $dlg.Controls.Add($lblDetails)

    $dlg.Show($form)
    [System.Windows.Forms.Application]::DoEvents()

    $statusLabel.Text = "Завантаження та встановлення IPBan з GitHub..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $downloadUrl = $null
        $versionTag = "latest"

        # 1. Пошук файлу через GitHub Releases API
        try {
            $headers = @{ "User-Agent" = "IPBan-GUI-Installer" }
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/DigitalRuby/IPBan/releases/latest" -Headers $headers -TimeoutSec 15
            $versionTag = $rel.tag_name
            $asset = $rel.assets | Where-Object { $_.name -like "*Windows-$arch*.zip" } | Select-Object -First 1
            if ($asset) {
                $downloadUrl = $asset.browser_download_url
            }
        } catch {}

        # Fallback 1: парсинг офіційної сторінки релізів
        if (-not $downloadUrl) {
            try {
                $wcWeb = New-Object System.Net.WebClient
                $wcWeb.Headers.Add("User-Agent", "IPBan-GUI-Installer")
                $html = $wcWeb.DownloadString("https://github.com/DigitalRuby/IPBan/releases/latest")
                if ($html -match 'href="([^"]+IPBan-Windows-' + $arch + '[^"]+\.zip)"') {
                    $downloadUrl = "https://github.com" + $matches[1]
                }
            } catch {}
        }

        # Fallback 2: пряме стабільне посилання
        if (-not $downloadUrl) {
            $downloadUrl = "https://github.com/DigitalRuby/IPBan/releases/download/4.1.0/IPBan-Windows-${arch}_4_1_0.zip"
            $versionTag = "4.1.0"
        }

        # Шлях для збереження ZIP архіву
        $saveDir = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
        if (-not (Test-Path $saveDir)) {
            $saveDir = [System.IO.Path]::GetTempPath()
        }
        $zipFileName = [System.IO.Path]::GetFileName($downloadUrl)
        if ([string]::IsNullOrWhiteSpace($zipFileName) -or -not $zipFileName.EndsWith(".zip")) {
            $zipFileName = "IPBan-Windows-$arch-$versionTag.zip"
        }
        $targetZip = Join-Path $saveDir $zipFileName

        $lblProgress.Text = "Завантаження IPBan v$versionTag..."
        $lblDetails.Text = "Підготовка до завантаження $zipFileName..."
        [System.Windows.Forms.Application]::DoEvents()

        # 2. Завантаження через WebClient з відображенням прогресу
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "IPBan-GUI-Installer")
        $script:dlComplete = $false
        $script:dlError = $null

        $wc.add_DownloadProgressChanged({
            param($s, $e)
            $pb.Value = [Math]::Min(100, [Math]::Max(0, $e.ProgressPercentage))
            $recMB = [Math]::Round($e.BytesReceived / 1MB, 1)
            $totMB = [Math]::Round($e.TotalBytesToReceive / 1MB, 1)
            $lblDetails.Text = "Завантажено: $recMB MB з $totMB MB ($($e.ProgressPercentage)%)"
            [System.Windows.Forms.Application]::DoEvents()
        })

        $wc.add_DownloadFileCompleted({
            param($s, $e)
            if ($e.Error) { $script:dlError = $e.Error }
            $script:dlComplete = $true
        })

        $wc.DownloadFileAsync((New-Object System.Uri($downloadUrl)), $targetZip)

        while (-not $script:dlComplete) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }

        if ($script:dlError) {
            throw $script:dlError
        }

        $script:LocalZipBackup = $targetZip

        # 3. Інсталяція
        $lblProgress.Text = "Встановлення та реєстрація служби IPBan..."
        $pb.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        [System.Windows.Forms.Application]::DoEvents()

        Install-IPBanFromArchive -zipPath $targetZip -destPath $destPath -progressLabel $lblProgress -detailsLabel $lblDetails

        $dlg.Close()

        Update-ServiceUI
        Load-ConfigData
        Refresh-BannedIPs

        [System.Windows.Forms.MessageBox]::Show(
            "IPBan v$versionTag успішно завантажено та встановлено у:`n$destPath`n`nСлужбу запущено, аудит безпеки активовано!",
            "Інсталяція завершена",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        if ($dlg) { $dlg.Close() }
        [System.Windows.Forms.MessageBox]::Show(
            "Помилка під час завантаження або встановлення IPBan:`n$_`n`nПеревірте інтернет-з'єднання та запуск програми від імені адміністратора.",
            "Помилка встановлення",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } finally {
        if ($dlg) { $dlg.Dispose() }
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $statusLabel.Text = "Готово"
    }
})

$btnUninstall.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("УВАГА! Ви дійсно бажаєте зупинити та видалити службу IPBan?", "Видалення IPBan", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            if (Get-Service $script:ServiceName -ErrorAction SilentlyContinue) {
                try { Stop-Service $script:ServiceName -Force } catch {}
                & sc.exe delete $script:ServiceName
            }
            Update-ServiceUI
            [System.Windows.Forms.MessageBox]::Show("Службу IPBan видалено із системи.", "Видалено", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Помилка видалення служби: $_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

$llGithub.Add_LinkClicked({
    [System.Diagnostics.Process]::Start("https://github.com/DigitalRuby/IPBan")
})

$llWiki.Add_LinkClicked({
    [System.Diagnostics.Process]::Start("https://github.com/DigitalRuby/IPBan/wiki/Configuration")
})

# Завантаження при відкритті форми
$form.Add_Shown({
    Update-UILanguage
    Update-HeaderLayout
    Init-Tray
    Update-ServiceUI
    Refresh-BannedIPs
    Load-ConfigData
    Refresh-LogsView

    # Якщо служба IPBan не встановлена - відкриваємо майстер налаштувань
    $svcStatus = Get-IPBanServiceStatus
    if ($svcStatus -eq "NotInstalled") {
        $tabControl.SelectedTab = $tabSetup
        $msg = T "PromptInstallText"
        $title = T "PromptInstallTitle"
        $ans = [System.Windows.Forms.MessageBox]::Show(
            $form,
            $msg,
            $title,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            $btnInstallWeb.PerformClick()
        }
    }
})

# Закриття або згортання форми у системний трей
$form.Add_FormClosing({
    param($s, $e)
    if (-not $script:IsExiting) {
        $e.Cancel = $true
        $form.Hide()
        if ($script:TrayIcon) {
            $script:TrayIcon.ShowBalloonTip(2000, "IPBan Control Center", "Програму згорнуто у системний трей. Клікніть двічі для відновлення.", [System.Windows.Forms.ToolTipIcon]::Info)
        }
    } else {
        if ($script:AutoRefreshTimer) {
            $script:AutoRefreshTimer.Stop()
            $script:AutoRefreshTimer.Dispose()
        }
        if ($script:AlertResetTimer) {
            $script:AlertResetTimer.Stop()
            $script:AlertResetTimer.Dispose()
        }
        if ($script:TrayMonitorTimer) {
            $script:TrayMonitorTimer.Stop()
            $script:TrayMonitorTimer.Dispose()
        }
        if ($script:TrayIcon) {
            $script:TrayIcon.Visible = $false
            $script:TrayIcon.Dispose()
        }
    }
})

# ------------------------------------------------------------------------------
# Запуск
# ------------------------------------------------------------------------------
[System.Windows.Forms.Application]::Run($form)
