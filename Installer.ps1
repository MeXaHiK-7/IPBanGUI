# ==============================================================================
# Installer.ps1
# Графічний майстер встановлення (Installer Wizard) для IPBan Manager & Control Center
# ==============================================================================

# Приховуємо вікно консолі (якщо скрипт запущено через powershell.exe)
try {
    if (-not ([System.Management.Automation.PSTypeName]'Win32Utils.Win32Console').Type) {
        Add-Type -Name Win32Console -Namespace Win32Utils -MemberDefinition '
        [DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        ' -ErrorAction SilentlyContinue
    }
    $consolePtr = [Win32Utils.Win32Console]::GetConsoleWindow()
    if ($consolePtr -and $consolePtr -ne [IntPtr]::Zero) {
        [Win32Utils.Win32Console]::ShowWindow($consolePtr, 0) | Out-Null # 0 = SW_HIDE
    }
} catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# Перевірка прав адміністратора
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit 0
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Для встановлення програми потрібні права адміністратора!", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }
}

$sourceDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

$script:InstallerVersion = "v2.2.2"

# ------------------------------------------------------------------------------
# Локалізація майстра інсталяції (Multi-Language: UA / EN)
# ------------------------------------------------------------------------------
$script:InstI18N = @{
    "UA" = @{
        "FormTitle" = "Встановлення — IPBan Manager & Control Center $script:InstallerVersion"
        "Brand" = "IPBan Control`nCenter"
        "BrandVer" = "$script:InstallerVersion"
        "Steps" = @("1. Вітання", "2. Папка програми", "3. Параметри", "4. Встановлення", "5. Завершення")
        "WelcomeTitle" = "Ласкаво просимо до майстра встановлення $script:InstallerVersion!"
        "WelcomeDesc" = "Ця програма встановить сучасний графічний інтерфейс керування захистом`nIPBan на ваш комп'ютер або сервер."
        "FeaturesHeader" = "IPBan Control Center забезпечує:"
        "Features" = @(
            "Автоматичне блокування спроб злому (RDP, SSH, SMB, SQL)",
            "Значок у системному треї з кольоровою індикацією та алертами",
            "Зручне керування білими/чорними списками із захистом своєї IP",
            "Моніторинг невдалих спроб входу Windows (Security Event 4625)",
            "Встановлення та оновлення служби IPBan безпосередньо з GitHub"
        )
        "WelcomeNotice" = "Натисніть кнопку «Далі», щоб продовжити встановлення."
        "FolderTitle" = "Вибір папки для встановлення програми"
        "FolderDesc" = "Програму буде встановлено у вказану нижче папку:`n(Працює на будь-якому диску, включаючи системний диск C:\)"
        "DestGroup" = "Папка призначення"
        "BrowseBtn" = "Огляд..."
        "SpaceInfo" = "Необхідно вільного місця на диску: ~15 МБ"
        "OptTitle" = "Налаштування параметрів встановлення"
        "OptDesc" = "Оберіть додаткові дії, які майстер має виконати під час інсталяції:"
        "ChkDesktop" = "Створити ярлик на Робочому столі"
        "ChkStartMenu" = "Створити ярлик у меню «Пуск»"
        "ChkAutostart" = "Додати в автозавантаження Windows (згортати у трей при вході)"
        "ChkAuditPol" = "Автоматично увімкнути аудит безпеки Windows (AuditPol)"
        "ChkCheckService" = "Перевірити наявність служби IPBan (та повідомити стан)"
        "InstallTitle" = "Встановлення програми..."
        "FinishTitle" = "Встановлення успішно завершено!"
        "FinishDesc" = "IPBan Manager & Control Center $script:InstallerVersion успішно встановлено на ваш комп'ютер.`n`nПрограма готова до роботи. Ви можете запускати її через ярлик на Робочому столі або з меню «Пуск»."
        "ChkLaunchNow" = "Запустити IPBan Control Center зараз"
        "BtnBack" = "< Назад"
        "BtnNext" = "Далі >"
        "BtnInstall" = "Встановити"
        "BtnFinish" = "Завершити"
        "BtnCancel" = "Скасувати"
        "CancelConfirm" = "Ви дійсно хочете перервати встановлення?"
        "CancelTitle" = "Скасування"
    }
    "EN" = @{
        "FormTitle" = "Setup — IPBan Manager & Control Center $script:InstallerVersion"
        "Brand" = "IPBan Control`nCenter"
        "BrandVer" = "$script:InstallerVersion"
        "Steps" = @("1. Welcome", "2. Destination", "3. Options", "4. Installation", "5. Finished")
        "WelcomeTitle" = "Welcome to the Setup Wizard ($script:InstallerVersion)!"
        "WelcomeDesc" = "This wizard will install the modern graphical interface for IPBan`nsecurity management on your computer or server."
        "FeaturesHeader" = "IPBan Control Center features:"
        "Features" = @(
            "Automatic brute-force attack blocking (RDP, SSH, SMB, SQL)",
            "System tray icon with real-time status and alert notifications",
            "Easy whitelist & blacklist management with self-IP protection",
            "Windows failed login audit & monitoring (Security Event 4625)",
            "1-click installation & update of IPBan service directly from GitHub"
        )
        "WelcomeNotice" = "Click 'Next' to continue setup."
        "FolderTitle" = "Select Installation Directory"
        "FolderDesc" = "The application will be installed in the destination folder below:`n(Works on any drive, including system drive C:\)"
        "DestGroup" = "Destination Folder"
        "BrowseBtn" = "Browse..."
        "SpaceInfo" = "Required free disk space: ~15 MB"
        "OptTitle" = "Additional Setup Options"
        "OptDesc" = "Select integration options for your operating system:"
        "ChkDesktop" = "Create a Desktop shortcut"
        "ChkStartMenu" = "Create a Start Menu shortcut"
        "ChkAutostart" = "Start in background on Windows logon (system tray)"
        "ChkAuditPol" = "Automatically enable Windows Security Audit (AuditPol)"
        "ChkCheckService" = "Check IPBan service presence (and notify status)"
        "InstallTitle" = "Installing application..."
        "FinishTitle" = "Installation Successfully Completed!"
        "FinishDesc" = "IPBan Manager & Control Center $script:InstallerVersion has been installed.`n`nThe software is ready to protect your system from unauthorized access."
        "ChkLaunchNow" = "Launch IPBan Control Center now"
        "BtnBack" = "< Back"
        "BtnNext" = "Next >"
        "BtnInstall" = "Install"
        "BtnFinish" = "Finish"
        "BtnCancel" = "Cancel"
        "CancelConfirm" = "Are you sure you want to exit the setup wizard?"
        "CancelTitle" = "Cancel Setup"
    }
}

$uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName.ToLower()
if ($uiCulture -in @("uk", "ru", "be")) {
    $script:CurrentLang = "UA"
} else {
    $script:CurrentLang = "EN"
}

function InstT([string]$key) {
    if ($script:InstI18N[$script:CurrentLang].ContainsKey($key)) {
        return $script:InstI18N[$script:CurrentLang][$key]
    }
    if ($script:InstI18N["EN"].ContainsKey($key)) {
        return $script:InstI18N["EN"][$key]
    }
    return $key
}

# Допоміжна функція згладжування кнопок
function Set-SmoothControl {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Control]$control,
        [int]$radius = 6
    )
    if ($control -is [System.Windows.Forms.ButtonBase]) {
        $control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $control.FlatAppearance.BorderSize = 0
        $control.Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    $rVal = if ($radius -gt 0) { $radius } else { 6 }
    $update = {
        param($s, $e)
        try {
            $curR = if ($rVal -gt 0) { $rVal } else { 6 }
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
    $control.Add_Resize($update)
    & $update $control $null
}

# ------------------------------------------------------------------------------
# Головне вікно інсталятора
# ------------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Встановлення — IPBan Manager & Control Center $script:InstallerVersion"
$form.Size = New-Object System.Drawing.Size(750, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.25)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

# Встановлюємо іконку інсталятора
$icoPath = Join-Path $sourceDir "app.ico"
if (Test-Path $icoPath) {
    try { $form.Icon = New-Object System.Drawing.Icon $icoPath } catch {}
}

# ------------------------------------------------------------------------------
# Ліва бічна панель (Sidebar)
# ------------------------------------------------------------------------------
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Dock = [System.Windows.Forms.DockStyle]::Left
$sidebar.Width = 210
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(24, 32, 47)
$sidebar.Padding = New-Object System.Windows.Forms.Padding(15, 25, 15, 20)
$form.Controls.Add($sidebar)

# Логотип/Щит у бічній панелі
$pbLogo = New-Object System.Windows.Forms.PictureBox
$pbLogo.Size = New-Object System.Drawing.Size(48, 48)
$pbLogo.Location = New-Object System.Drawing.Point(15, 20)
$pbLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
if (Test-Path $icoPath) {
    try { $pbLogo.Image = (New-Object System.Drawing.Icon $icoPath).ToBitmap() } catch {}
}
$sidebar.Controls.Add($pbLogo)

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "IPBan Control`nCenter"
$lblBrand.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblBrand.ForeColor = [System.Drawing.Color]::White
$lblBrand.Location = New-Object System.Drawing.Point(72, 16)
$lblBrand.Size = New-Object System.Drawing.Size(130, 38)
$sidebar.Controls.Add($lblBrand)

$lblBrandVer = New-Object System.Windows.Forms.Label
$lblBrandVer.Text = "$script:InstallerVersion"
$lblBrandVer.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$lblBrandVer.ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248)
$lblBrandVer.Location = New-Object System.Drawing.Point(72, 54)
$lblBrandVer.Size = New-Object System.Drawing.Size(130, 18)
$sidebar.Controls.Add($lblBrandVer)

# Кроки інсталяції в бічній панелі
$stepsList = @("1. Вітання", "2. Папка програми", "3. Параметри", "4. Встановлення", "5. Завершення")
$stepLabels = @()
$stepY = 100
for ($i = 0; $i -lt $stepsList.Count; $i++) {
    $lblStep = New-Object System.Windows.Forms.Label
    $lblStep.Text = $stepsList[$i]
    $lblStep.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $lblStep.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
    $lblStep.Location = New-Object System.Drawing.Point(20, $stepY)
    $lblStep.Size = New-Object System.Drawing.Size(175, 30)
    $sidebar.Controls.Add($lblStep)
    $stepLabels += $lblStep
    $stepY += 38
}

# Вибір мови в бічній панелі (Language Selector)
$lblLangPrompt = New-Object System.Windows.Forms.Label
$lblLangPrompt.Text = "Language / Мова:"
$lblLangPrompt.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblLangPrompt.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$lblLangPrompt.Location = New-Object System.Drawing.Point(20, 395)
$lblLangPrompt.Size = New-Object System.Drawing.Size(170, 18)
$sidebar.Controls.Add($lblLangPrompt)

$cbInstallerLang = New-Object System.Windows.Forms.ComboBox
$cbInstallerLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbInstallerLang.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$cbInstallerLang.Location = New-Object System.Drawing.Point(20, 418)
$cbInstallerLang.Size = New-Object System.Drawing.Size(165, 26)
$cbInstallerLang.Items.AddRange(@("Українська", "English"))
$cbInstallerLang.SelectedIndex = if ($script:CurrentLang -eq "EN") { 1 } else { 0 }
$sidebar.Controls.Add($cbInstallerLang)

$cbInstallerLang.Add_SelectedIndexChanged({
    $script:CurrentLang = if ($cbInstallerLang.SelectedIndex -eq 1) { "EN" } else { "UA" }
    Apply-InstallerLanguage
})

function Update-StepUI([int]$currentStep) {
    for ($i = 0; $i -lt $stepLabels.Count; $i++) {
        if ($i -eq $currentStep) {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248) # Голубий активний
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        } elseif ($i -lt $currentStep) {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(34, 197, 94) # Зелений пройдений
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
        } else {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
        }
    }
}

# ------------------------------------------------------------------------------
# Нижня панель навігації (Bottom Navigation Bar)
# ------------------------------------------------------------------------------
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$bottomPanel.Height = 65
$bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$bottomPanel.Padding = New-Object System.Windows.Forms.Padding(15, 12, 20, 15)
$form.Controls.Add($bottomPanel)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Скасувати"
$btnCancel.Size = New-Object System.Drawing.Size(105, 34)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$btnCancel.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$bottomPanel.Controls.Add($btnCancel)
Set-SmoothControl $btnCancel 6

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Далі >"
$btnNext.Size = New-Object System.Drawing.Size(115, 34)
$btnNext.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnNext.ForeColor = [System.Drawing.Color]::White
$btnNext.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$bottomPanel.Controls.Add($btnNext)
Set-SmoothControl $btnNext 6

$btnBack = New-Object System.Windows.Forms.Button
$btnBack.Text = "< Назад"
$btnBack.Size = New-Object System.Drawing.Size(105, 34)
$btnBack.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$btnBack.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$btnBack.Enabled = $false
$bottomPanel.Controls.Add($btnBack)
Set-SmoothControl $btnBack 6

function Update-NavButtonsLayout {
    $w = $bottomPanel.ClientSize.Width
    $h = $bottomPanel.ClientSize.Height
    $topPos = [Math]::Max(14, [int](($h - 34) / 2))

    if ($script:CurrentStep -eq 4) {
        $btnBack.Visible = $false
        $btnCancel.Visible = $false
        $btnNext.Visible = $true
        $btnNext.Text = "Завершити"
        $btnNext.Width = 125
        $btnNext.Height = 34
        $btnNext.Left = $w - $btnNext.Width - 25
        $btnNext.Top = $topPos
        $btnNext.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    } else {
        $btnCancel.Visible = $true
        $btnCancel.Width = 105
        $btnCancel.Height = 34
        $btnCancel.Left = $w - $btnCancel.Width - 25
        $btnCancel.Top = $topPos

        $btnNext.Visible = $true
        $btnNext.Width = 115
        $btnNext.Height = 34
        $btnNext.Left = $btnCancel.Left - $btnNext.Width - 12
        $btnNext.Top = $topPos
        $btnNext.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)

        $btnBack.Visible = $true
        $btnBack.Width = 105
        $btnBack.Height = 34
        $btnBack.Left = $btnNext.Left - $btnBack.Width - 12
        $btnBack.Top = $topPos
    }
}
$bottomPanel.Add_Resize({ Update-NavButtonsLayout })

# ------------------------------------------------------------------------------
# Центральна робоча область сторінок
# ------------------------------------------------------------------------------
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$contentPanel.Padding = New-Object System.Windows.Forms.Padding(25, 20, 25, 10)
$form.Controls.Add($contentPanel)
$contentPanel.BringToFront()

# Створення панелей для кожного кроку (5 кроків)
$pages = @()
for ($p = 0; $p -lt 5; $p++) {
    $page = New-Object System.Windows.Forms.Panel
    $page.Dock = [System.Windows.Forms.DockStyle]::Fill
    $page.Visible = ($p -eq 0)
    $contentPanel.Controls.Add($page)
    $pages += $page
}

# ==============================================================================
# СТОРІНКА 0: Вітання
# ==============================================================================
$p0 = $pages[0]
$lblWelcomeTitle = New-Object System.Windows.Forms.Label
$lblWelcomeTitle.Text = "Ласкаво просимо до майстра встановлення!"
$lblWelcomeTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblWelcomeTitle.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$lblWelcomeTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblWelcomeTitle.Size = New-Object System.Drawing.Size(490, 32)
$p0.Controls.Add($lblWelcomeTitle)

$lblWelcomeDesc = New-Object System.Windows.Forms.Label
$lblWelcomeDesc.Text = "Ця програма встановить сучасний графічний інтерфейс керування захистом`nIPBan на ваш комп'ютер або сервер."
$lblWelcomeDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblWelcomeDesc.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblWelcomeDesc.Location = New-Object System.Drawing.Point(10, 48)
$lblWelcomeDesc.Size = New-Object System.Drawing.Size(510, 42)
$p0.Controls.Add($lblWelcomeDesc)

$lblFeaturesHeader = New-Object System.Windows.Forms.Label
$lblFeaturesHeader.Text = "IPBan Control Center забезпечує:"
$lblFeaturesHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$lblFeaturesHeader.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$lblFeaturesHeader.Location = New-Object System.Drawing.Point(10, 90)
$lblFeaturesHeader.Size = New-Object System.Drawing.Size(490, 24)
$p0.Controls.Add($lblFeaturesHeader)

$features = @(
    "Автоматичне блокування спроб злому (RDP, SSH, SMB, SQL)",
    "Значок у системному треї з кольоровою індикацією та алертами",
    "Зручне керування білими/чорними списками із захистом своєї IP",
    "Моніторинг невдалих спроб входу Windows (Security Event 4625)",
    "Встановлення та оновлення служби IPBan безпосередньо з GitHub"
)

$bulletY = 118
$featLabels = @()
foreach ($feat in $features) {
    $lblCheck = New-Object System.Windows.Forms.Label
    $lblCheck.Text = [char]0x2714
    $lblCheck.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblCheck.ForeColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    $lblCheck.Location = New-Object System.Drawing.Point(12, $bulletY)
    $lblCheck.Size = New-Object System.Drawing.Size(22, 22)
    $p0.Controls.Add($lblCheck)

    $textY = [int]($bulletY + 1)
    $lblFeatText = New-Object System.Windows.Forms.Label
    $lblFeatText.Text = $feat
    $lblFeatText.Font = New-Object System.Drawing.Font("Segoe UI", 9.25)
    $lblFeatText.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $lblFeatText.Location = New-Object System.Drawing.Point(38, $textY)
    $lblFeatText.Size = New-Object System.Drawing.Size(465, 22)
    $p0.Controls.Add($lblFeatText)
    $featLabels += $lblFeatText

    $bulletY += 28
}

$noticeY = [int]($bulletY + 12)
$lblNotice = New-Object System.Windows.Forms.Label
$lblNotice.Text = "Натисніть кнопку «Далі», щоб продовжити встановлення."
$lblNotice.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblNotice.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$lblNotice.Location = New-Object System.Drawing.Point(10, $noticeY)
$lblNotice.Size = New-Object System.Drawing.Size(490, 25)
$p0.Controls.Add($lblNotice)

# ==============================================================================
# СТОРІНКА 1: Вибір папки встановлення
# ==============================================================================
$p1 = $pages[1]
$lblFolderTitle = New-Object System.Windows.Forms.Label
$lblFolderTitle.Text = "Вибір папки для встановлення програми"
$lblFolderTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblFolderTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblFolderTitle.Size = New-Object System.Drawing.Size(490, 28)
$p1.Controls.Add($lblFolderTitle)

$lblFolderDesc = New-Object System.Windows.Forms.Label
$lblFolderDesc.Text = "Програму буде встановлено у вказану нижче папку:`n(Працює на будь-якому диску, включаючи системний диск C:\)"
$lblFolderDesc.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblFolderDesc.Location = New-Object System.Drawing.Point(10, 45)
$lblFolderDesc.Size = New-Object System.Drawing.Size(490, 40)
$p1.Controls.Add($lblFolderDesc)

$gbDest = New-Object System.Windows.Forms.GroupBox
$gbDest.Text = "Папка призначення"
$gbDest.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$gbDest.Location = New-Object System.Drawing.Point(10, 95)
$gbDest.Size = New-Object System.Drawing.Size(490, 85)
$p1.Controls.Add($gbDest)

$txtInstallDir = New-Object System.Windows.Forms.TextBox
$txtInstallDir.Text = "C:\Program Files\IPBan Manager"
$txtInstallDir.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$txtInstallDir.Location = New-Object System.Drawing.Point(15, 32)
$txtInstallDir.Size = New-Object System.Drawing.Size(370, 26)
$gbDest.Controls.Add($txtInstallDir)

$btnBrowseFolder = New-Object System.Windows.Forms.Button
$btnBrowseFolder.Text = "Огляд..."
$btnBrowseFolder.Location = New-Object System.Drawing.Point(395, 30)
$btnBrowseFolder.Size = New-Object System.Drawing.Size(85, 30)
$btnBrowseFolder.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$gbDest.Controls.Add($btnBrowseFolder)
Set-SmoothControl $btnBrowseFolder 6

$lblSpaceInfo = New-Object System.Windows.Forms.Label
$lblSpaceInfo.Text = "Необхідно вільного місця на диску: близько 15 МБ"
$lblSpaceInfo.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$lblSpaceInfo.Location = New-Object System.Drawing.Point(10, 195)
$lblSpaceInfo.Size = New-Object System.Drawing.Size(490, 25)
$p1.Controls.Add($lblSpaceInfo)

$btnBrowseFolder.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.SelectedPath = $txtInstallDir.Text
    $fbd.Description = "Виберіть папку для встановлення IPBan Manager"
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstallDir.Text = $fbd.SelectedPath
    }
})

# ==============================================================================
# СТОРІНКА 2: Параметри та опції
# ==============================================================================
$p2 = $pages[2]
$lblOptTitle = New-Object System.Windows.Forms.Label
$lblOptTitle.Text = "Налаштування параметрів встановлення"
$lblOptTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblOptTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblOptTitle.Size = New-Object System.Drawing.Size(490, 28)
$p2.Controls.Add($lblOptTitle)

$lblOptDesc = New-Object System.Windows.Forms.Label
$lblOptDesc.Text = "Оберіть додаткові дії, які майстер має виконати під час інсталяції:"
$lblOptDesc.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblOptDesc.Location = New-Object System.Drawing.Point(10, 45)
$lblOptDesc.Size = New-Object System.Drawing.Size(490, 30)
$p2.Controls.Add($lblOptDesc)

$chkDesktop = New-Object System.Windows.Forms.CheckBox
$chkDesktop.Text = "Створити ярлик на Робочому столі"
$chkDesktop.Checked = $true
$chkDesktop.Location = New-Object System.Drawing.Point(15, 82)
$chkDesktop.Size = New-Object System.Drawing.Size(480, 25)
$p2.Controls.Add($chkDesktop)

$chkStartMenu = New-Object System.Windows.Forms.CheckBox
$chkStartMenu.Text = "Створити ярлик у меню «Пуск»"
$chkStartMenu.Checked = $true
$chkStartMenu.Location = New-Object System.Drawing.Point(15, 112)
$chkStartMenu.Size = New-Object System.Drawing.Size(480, 25)
$p2.Controls.Add($chkStartMenu)

$chkAutostart = New-Object System.Windows.Forms.CheckBox
$chkAutostart.Text = "Додати в автозавантаження Windows (згортати у трей при вході)"
$chkAutostart.Checked = $true
$chkAutostart.Location = New-Object System.Drawing.Point(15, 142)
$chkAutostart.Size = New-Object System.Drawing.Size(480, 25)
$p2.Controls.Add($chkAutostart)

$chkAuditPol = New-Object System.Windows.Forms.CheckBox
$chkAuditPol.Text = "Автоматично увімкнути аудит безпеки Windows (AuditPol)"
$chkAuditPol.Checked = $true
$chkAuditPol.Location = New-Object System.Drawing.Point(15, 172)
$chkAuditPol.Size = New-Object System.Drawing.Size(480, 25)
$p2.Controls.Add($chkAuditPol)

$chkCheckService = New-Object System.Windows.Forms.CheckBox
$chkCheckService.Text = "Перевірити наявність служби IPBan (та повідомити стан)"
$chkCheckService.Checked = $true
$chkCheckService.Location = New-Object System.Drawing.Point(15, 202)
$chkCheckService.Size = New-Object System.Drawing.Size(480, 25)
$p2.Controls.Add($chkCheckService)

# ==============================================================================
# СТОРІНКА 3: Встановлення (Прогрес)
# ==============================================================================
$p3 = $pages[3]
$lblInstallTitle = New-Object System.Windows.Forms.Label
$lblInstallTitle.Text = "Встановлення програми..."
$lblInstallTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblInstallTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblInstallTitle.Size = New-Object System.Drawing.Size(490, 28)
$p3.Controls.Add($lblInstallTitle)

$lblStatusText = New-Object System.Windows.Forms.Label
$lblStatusText.Text = "Підготовка файлів до копіювання..."
$lblStatusText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatusText.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblStatusText.Location = New-Object System.Drawing.Point(10, 50)
$lblStatusText.Size = New-Object System.Drawing.Size(490, 25)
$p3.Controls.Add($lblStatusText)

$pbInstall = New-Object System.Windows.Forms.ProgressBar
$pbInstall.Location = New-Object System.Drawing.Point(10, 80)
$pbInstall.Size = New-Object System.Drawing.Size(490, 26)
$pbInstall.Minimum = 0
$pbInstall.Maximum = 100
$pbInstall.Value = 0
$p3.Controls.Add($pbInstall)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.Location = New-Object System.Drawing.Point(10, 115)
$txtLog.Size = New-Object System.Drawing.Size(490, 220)
$txtLog.BackColor = [System.Drawing.Color]::White
$p3.Controls.Add($txtLog)

function Log-Step([string]$msg) {
    $lblStatusText.Text = $msg
    $txtLog.AppendText("$msg`r`n")
    $txtLog.SelectionStart = $txtLog.Text.Length
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ==============================================================================
# СТОРІНКА 4: Завершення
# ==============================================================================
$p4 = $pages[4]
$lblFinishTitle = New-Object System.Windows.Forms.Label
$lblFinishTitle.Text = "Встановлення успішно завершено!"
$lblFinishTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblFinishTitle.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
$lblFinishTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblFinishTitle.Size = New-Object System.Drawing.Size(490, 30)
$p4.Controls.Add($lblFinishTitle)

$lblFinishDesc = New-Object System.Windows.Forms.Label
$lblFinishDesc.Text = "IPBan Manager & Control Center успішно встановлено на ваш комп'ютер.`n`nПрограма готова до роботи. Ви можете запускати її через ярлик на Робочому столі або з меню «Пуск»."
$lblFinishDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblFinishDesc.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$lblFinishDesc.Location = New-Object System.Drawing.Point(10, 52)
$lblFinishDesc.Size = New-Object System.Drawing.Size(490, 80)
$p4.Controls.Add($lblFinishDesc)

$chkLaunchNow = New-Object System.Windows.Forms.CheckBox
$chkLaunchNow.Text = "Запустити IPBan Control Center зараз"
$chkLaunchNow.Checked = $true
$chkLaunchNow.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$chkLaunchNow.ForeColor = [System.Drawing.Color]::FromArgb(30, 58, 138)
$chkLaunchNow.Location = New-Object System.Drawing.Point(10, 145)
$chkLaunchNow.Size = New-Object System.Drawing.Size(490, 30)
$p4.Controls.Add($chkLaunchNow)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Логіка навігації між сторінками та локалізація
# ------------------------------------------------------------------------------
$script:CurrentStep = 0

function Apply-InstallerLanguage {
    $form.Text = InstT "FormTitle"
    $lblBrand.Text = InstT "Brand"
    $lblBrandVer.Text = InstT "BrandVer"

    $stepTexts = InstT "Steps"
    for ($i = 0; $i -lt $stepLabels.Count; $i++) {
        if ($i -lt $stepTexts.Count) {
            $stepLabels[$i].Text = $stepTexts[$i]
        }
    }

    $lblWelcomeTitle.Text = InstT "WelcomeTitle"
    $lblWelcomeDesc.Text = InstT "WelcomeDesc"
    $lblFeaturesHeader.Text = InstT "FeaturesHeader"
    $featTexts = InstT "Features"
    for ($i = 0; $i -lt $featLabels.Count; $i++) {
        if ($i -lt $featTexts.Count) {
            $featLabels[$i].Text = $featTexts[$i]
        }
    }
    $lblNotice.Text = InstT "WelcomeNotice"

    $lblFolderTitle.Text = InstT "FolderTitle"
    $lblFolderDesc.Text = InstT "FolderDesc"
    $gbDest.Text = InstT "DestGroup"
    $btnBrowseFolder.Text = InstT "BrowseBtn"
    $lblSpaceInfo.Text = InstT "SpaceInfo"

    $lblOptTitle.Text = InstT "OptTitle"
    $lblOptDesc.Text = InstT "OptDesc"
    $chkDesktop.Text = InstT "ChkDesktop"
    $chkStartMenu.Text = InstT "ChkStartMenu"
    $chkAutostart.Text = InstT "ChkAutostart"
    $chkAuditPol.Text = InstT "ChkAuditPol"
    $chkCheckService.Text = InstT "ChkCheckService"

    $lblInstallTitle.Text = InstT "InstallTitle"

    $lblFinishTitle.Text = InstT "FinishTitle"
    $lblFinishDesc.Text = InstT "FinishDesc"
    $chkLaunchNow.Text = InstT "ChkLaunchNow"

    $btnBack.Text = InstT "BtnBack"
    $btnCancel.Text = InstT "BtnCancel"
    if ($script:CurrentStep -eq 2) {
        $btnNext.Text = InstT "BtnInstall"
    } elseif ($script:CurrentStep -eq 4) {
        $btnNext.Text = InstT "BtnFinish"
    } else {
        $btnNext.Text = InstT "BtnNext"
    }
    Update-NavButtonsLayout
}

function Set-Page([int]$stepIndex) {
    $script:CurrentStep = $stepIndex
    for ($i = 0; $i -lt $pages.Count; $i++) {
        $pages[$i].Visible = ($i -eq $stepIndex)
    }
    Update-StepUI $stepIndex

    # Налаштування кнопок
    $btnBack.Text = InstT "BtnBack"
    $btnCancel.Text = InstT "BtnCancel"
    if ($stepIndex -eq 0) {
        $btnBack.Enabled = $false
        $btnNext.Text = InstT "BtnNext"
    } elseif ($stepIndex -eq 1) {
        $btnBack.Enabled = $true
        $btnNext.Text = InstT "BtnNext"
    } elseif ($stepIndex -eq 2) {
        $btnBack.Enabled = $true
        $btnNext.Text = InstT "BtnInstall"
    } elseif ($stepIndex -eq 3) {
        $btnBack.Enabled = $false
        $btnNext.Enabled = $false
        $btnCancel.Enabled = $false
        Update-NavButtonsLayout
        # Запускаємо процес інсталяції
        Start-InstallationProcess
        return
    } elseif ($stepIndex -eq 4) {
        $btnNext.Enabled = $true
        $btnNext.Text = InstT "BtnFinish"
    }
    Update-NavButtonsLayout
}

$btnNext.Add_Click({
    if ($script:CurrentStep -lt 2) {
        Set-Page ($script:CurrentStep + 1)
    } elseif ($script:CurrentStep -eq 2) {
        Set-Page 3
    } elseif ($script:CurrentStep -eq 4) {
        # Завершення
        if ($chkLaunchNow.Checked) {
            $targetDir = $txtInstallDir.Text.Trim()
            $exePath = Join-Path $targetDir "IPBanControlCenter.exe"
            if (Test-Path $exePath) {
                try {
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = $exePath
                    $psi.Verb = "runas"
                    [System.Diagnostics.Process]::Start($psi) | Out-Null
                } catch {}
            }
        }
        $form.Close()
    }
})

$btnBack.Add_Click({
    if ($script:CurrentStep -gt 0 -and $script:CurrentStep -lt 3) {
        Set-Page ($script:CurrentStep - 1)
    }
})

$btnCancel.Add_Click({
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (InstT "CancelConfirm"),
        (InstT "CancelTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
        $form.Close()
    }
})

# ------------------------------------------------------------------------------
# Процес встановлення (Крок 3)
# ------------------------------------------------------------------------------
function Start-InstallationProcess {
    $targetDir = $txtInstallDir.Text.Trim()
    $pbInstall.Value = 5
    Log-Step "Створення папки призначення: $targetDir"

    try {
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # 0. Перевірка та закриття попередніх запущених копій (запобігає дублюванню процесів та блокуванню файлів)
        $pbInstall.Value = 10
        Log-Step "Перевірка та закриття попередніх запущених копій..."
        try {
            Get-Process -Name "IPBanControlCenter" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $_.CloseMainWindow() | Out-Null
                    Start-Sleep -Milliseconds 250
                    if (-not $_.HasExited) { $_.Kill() }
                } catch {}
            }
            Get-WmiObject Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.CommandLine -like "*IPBanGUI.ps1*") {
                    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                }
            }
        } catch {}

        # 1. Копіювання файлів програми
        $pbInstall.Value = 20
        Log-Step "Копіювання файлів IPBan Control Center..."

        $filesToCopy = @("IPBanGUI.ps1", "Run_IPBan_GUI.bat", "app.ico", "IPBanControlCenter.exe", "README_IPBan_GUI.md")
        foreach ($f in $filesToCopy) {
            $src = Join-Path $sourceDir $f
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination (Join-Path $targetDir $f) -Force
                Log-Step "  -> Скопійовано: $f"
            }
        }

        # Якщо лаунчер exe ще не згенеровано, компілюємо на місці
        $targetExe = Join-Path $targetDir "IPBanControlCenter.exe"
        if (-not (Test-Path $targetExe)) {
            Log-Step "Компіляція нативного лаунчера IPBanControlCenter.exe..."
            $csharp = @'
using System;
using System.Diagnostics;
using System.IO;
namespace IPBanControlCenter {
    class Program {
        [STAThread]
        static void Main(string[] args) {
            string dir = AppDomain.CurrentDomain.BaseDirectory;
            string ps1 = Path.Combine(dir, "IPBanGUI.ps1");
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"";
            psi.Verb = "runas";
            psi.UseShellExecute = true;
            psi.WorkingDirectory = dir;
            try { Process.Start(psi); } catch {}
        }
    }
}
'@
            $opt = New-Object System.CodeDom.Compiler.CompilerParameters
            $opt.ReferencedAssemblies.Add("System.dll") | Out-Null
            $opt.ReferencedAssemblies.Add("System.Windows.Forms.dll") | Out-Null
            $opt.GenerateExecutable = $true
            $opt.OutputAssembly = $targetExe
            $icoTarget = Join-Path $targetDir "app.ico"
            if (Test-Path $icoTarget) { $opt.CompilerOptions = "/target:winexe /win32icon:`"$icoTarget`"" } else { $opt.CompilerOptions = "/target:winexe" }
            $cp = New-Object Microsoft.CSharp.CSharpCodeProvider
            $cr = $cp.CompileAssemblyFromSource($opt, $csharp)
        }

        # 2. Створення деінсталятора (Uninstall.ps1 та Uninstall.bat)
        $pbInstall.Value = 40
        Log-Step "Створення модуля деінсталяції..."
        $uninstallerPs1 = Join-Path $targetDir "Uninstall.ps1"
        $uninstallerBat = Join-Path $targetDir "Uninstall.bat"

        $uninstallPs1Content = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit 0
    } catch {
        exit 1
    }
}

$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $installDir) { $installDir = "C:\Program Files\IPBan Manager" }

$uninstLang = "UA"
try {
    $regU = "HKCU:\SOFTWARE\IPBanControlCenter"
    if (Test-Path $regU) {
        $savedL = (Get-ItemProperty -Path $regU -Name "Language" -ErrorAction SilentlyContinue).Language
        if ($savedL -in @("UA", "EN")) { $uninstLang = $savedL }
    }
} catch {}

$qMsg = if ($uninstLang -eq "EN") { "Are you sure you want to completely remove IPBan Manager & Control Center from your computer?" } else { "Ви дійсно бажаєте повністю видалити IPBan Manager & Control Center із комп'ютера?" }
$qTitle = if ($uninstLang -eq "EN") { "Uninstall Application" } else { "Видалення програми" }
$ans = [System.Windows.Forms.MessageBox]::Show(
    $qMsg,
    $qTitle,
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)
if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) {
    exit 0
}

# 1. Зупинка процесів програми та прибирання з системного трею
try {
    Get-Process -Name "IPBanControlCenter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%IPBanGUI.ps1%'" -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
} catch {}

# Очищення фантомних значків із системного трею (Windows Notification Area)
try {
    $trayCode = 'using System; using System.Runtime.InteropServices; public class TrayCleaner { [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t); [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t); [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l); [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; } public static void Clean() { IntPtr tb = FindWindow("Shell_TrayWnd", null); if (tb != IntPtr.Zero) { IntPtr tn = FindWindowEx(tb, IntPtr.Zero, "TrayNotifyWnd", null); if (tn != IntPtr.Zero) { IntPtr sp = FindWindowEx(tn, IntPtr.Zero, "SysPager", null); IntPtr wnd = sp != IntPtr.Zero ? FindWindowEx(sp, IntPtr.Zero, "ToolbarWindow32", null) : FindWindowEx(tn, IntPtr.Zero, "ToolbarWindow32", null); if (wnd != IntPtr.Zero) Sweep(wnd); } } IntPtr ov = FindWindow("NotifyIconOverflowWindow", null); if (ov != IntPtr.Zero) { IntPtr wnd = FindWindowEx(ov, IntPtr.Zero, "ToolbarWindow32", null); if (wnd != IntPtr.Zero) Sweep(wnd); } } private static void Sweep(IntPtr hWnd) { RECT r; if (GetClientRect(hWnd, out r)) { for (int x = 0; x < r.Right; x += 8) { for (int y = 0; y < r.Bottom; y += 8) { SendMessage(hWnd, 0x0200, IntPtr.Zero, (IntPtr)((y << 16) | (x & 0xFFFF))); } } } } };'
    if (-not ([System.Management.Automation.PSTypeName]'TrayCleaner').Type) {
        Add-Type -TypeDefinition $trayCode -ErrorAction SilentlyContinue
    }
    [TrayCleaner]::Clean()
} catch {}

# 2. Зупинка служби захисту IPBan
try {
    $svc = Get-Service -Name "IPBan" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Stop-Service -Name "IPBan" -Force -ErrorAction SilentlyContinue
    }
} catch {}

# 3. Видалення ярликів на Робочому столі
try {
    $cDesktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDesktopDirectory)
    $uDesktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    foreach ($d in @($cDesktop, $uDesktop)) {
        if ($d) {
            $lnk = Join-Path $d "IPBan Control Center.lnk"
            if (Test-Path $lnk) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
        }
    }
} catch {}

# 4. Видалення ярликів у меню «Пуск»
try {
    $cStart = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonPrograms)
    $uStart = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
    foreach ($s in @($cStart, $uStart)) {
        if ($s) {
            $lnk = Join-Path $s "IPBan Control Center.lnk"
            if (Test-Path $lnk) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
        }
    }
} catch {}

# 5. Видалення запису автозавантаження
try {
    $runHklm = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $runHklm) {
        Remove-ItemProperty -Path $runHklm -Name "IPBanControlCenter" -ErrorAction SilentlyContinue
    }
    $runHkcu = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $runHkcu) {
        Remove-ItemProperty -Path $runHkcu -Name "IPBanControlCenter" -ErrorAction SilentlyContinue
    }
} catch {}

# 6. Видалення запису з «Встановлених програм Windows»
try {
    $uninstReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IPBanControlCenter"
    if (Test-Path $uninstReg) {
        Remove-Item -Path $uninstReg -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {}

# 6b. Очищення прив'язок та налаштувань у реєстрі HKLM та HKCU
try {
    $regM = "HKLM:\SOFTWARE\IPBanControlCenter"
    if (Test-Path $regM) {
        Remove-Item -Path $regM -Recurse -Force -ErrorAction SilentlyContinue
    }
    $regU = "HKCU:\SOFTWARE\IPBanControlCenter"
    if (Test-Path $regU) {
        Remove-Item -Path $regU -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {}

# 7. Відкладене видалення папки програми у фоні
try {
    $cleanCmd = "timeout /t 1 /nobreak >nul & rmdir /s /q `"$installDir`""
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c " + $cleanCmd
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
} catch {}

$doneMsg = if ($uninstLang -eq "EN") { "IPBan Manager & Control Center has been successfully uninstalled from your system!" } else { "IPBan Manager & Control Center успішно видалено із системи!" }
$doneTitle = if ($uninstLang -eq "EN") { "Uninstall Complete" } else { "Видалення завершено" }
[System.Windows.Forms.MessageBox]::Show(
    $doneMsg,
    $doneTitle,
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
'@
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($uninstallerPs1, $uninstallPs1Content, $utf8WithBom)

        # Чистий ASCII лаунчер Uninstall.bat без кирилиці
        $uninstallBatContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"%~dp0Uninstall.ps1`"`r`n"
        [System.IO.File]::WriteAllText($uninstallerBat, $uninstallBatContent, [System.Text.Encoding]::ASCII)

        # 3. Реєстрація у списку встановлених програм Windows (Add/Remove Programs)
        $pbInstall.Value = 55
        Log-Step "Реєстрація у встановлених програмах Windows..."
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\IPBanControlCenter"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "IPBan Manager & Control Center"
        Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value "$targetExe,0"
        Set-ItemProperty -Path $regPath -Name "DisplayVersion" -Value "2.2.1"
        Set-ItemProperty -Path $regPath -Name "Publisher" -Value "IPBan Community & Tooling"
        Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $targetDir
        Set-ItemProperty -Path $regPath -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uninstallerPs1`""
        Set-ItemProperty -Path $regPath -Name "NoModify" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "NoRepair" -Value 1 -Type DWord

        # Запис системної інформації про встановлення
        $appReg = "HKLM:\SOFTWARE\IPBanControlCenter"
        if (-not (Test-Path $appReg)) { New-Item -Path $appReg -Force | Out-Null }
        Set-ItemProperty -Path $appReg -Name "InstallPath" -Value $targetDir -Force
        Set-ItemProperty -Path $appReg -Name "InstallDate" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force

        # 4. Створення ярликів (тільки для поточного користувача)
        $pbInstall.Value = 70
        $wsh = New-Object -ComObject WScript.Shell

        if ($chkDesktop.Checked) {
            Log-Step "Створення ярлика на Робочому столі..."
            # Видаляємо спільний ярлик із Public Desktop, щоб він не з'являвся в усіх RDP сесіях
            $commonDesktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDesktopDirectory)
            if ($commonDesktop) {
                $oldPublicLnk = Join-Path $commonDesktop "IPBan Control Center.lnk"
                if (Test-Path $oldPublicLnk) { Remove-Item $oldPublicLnk -Force -ErrorAction SilentlyContinue }
            }

            # Створюємо ТІЛЬКИ на робочому столі користувача, що встановлює
            $desktopDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
            $shortcutPath = Join-Path $desktopDir "IPBan Control Center.lnk"
            $sc = $wsh.CreateShortcut($shortcutPath)
            $sc.TargetPath = $targetExe
            $sc.WorkingDirectory = $targetDir
            $sc.IconLocation = "$targetExe,0"
            $sc.Description = "Центр керування та моніторингу DigitalRuby IPBan"
            $sc.Save()
            Log-Step "  -> Ярлик створено для користувача: $shortcutPath"
        }

        if ($chkStartMenu.Checked) {
            Log-Step "Створення ярлика в меню «Пуск»..."
            # Видаляємо спільний ярлик із CommonPrograms
            $commonPrograms = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonPrograms)
            if ($commonPrograms) {
                $oldPublicStart = Join-Path $commonPrograms "IPBan Control Center.lnk"
                if (Test-Path $oldPublicStart) { Remove-Item $oldPublicStart -Force -ErrorAction SilentlyContinue }
            }

            # Створюємо ТІЛЬКИ в меню поточного користувача
            $startMenuDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
            $shortcutStart = Join-Path $startMenuDir "IPBan Control Center.lnk"
            $sc2 = $wsh.CreateShortcut($shortcutStart)
            $sc2.TargetPath = $targetExe
            $sc2.WorkingDirectory = $targetDir
            $sc2.IconLocation = "$targetExe,0"
            $sc2.Description = "Центр керування та моніторингу DigitalRuby IPBan"
            $sc2.Save()
            Log-Step "  -> Ярлик створено для користувача: $shortcutStart"
        }

        # 5. Автозавантаження (тільки для поточного користувача в HKCU)
        # Обов'язково очищаємо HKLM Run, щоб програма НЕ стартувала в сторонніх RDP-юзерів!
        $runHklm = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        if (Test-Path $runHklm) {
            Remove-ItemProperty -Path $runHklm -Name "IPBanControlCenter" -ErrorAction SilentlyContinue
        }

        if ($chkAutostart.Checked) {
            $pbInstall.Value = 85
            Log-Step "Налаштування автозавантаження Windows (тільки для поточного користувача)..."
            $runHkcu = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            if (-not (Test-Path $runHkcu)) { New-Item -Path $runHkcu -Force | Out-Null }
            Set-ItemProperty -Path $runHkcu -Name "IPBanControlCenter" -Value "`"$targetExe`" -tray" -Force
            Log-Step "  -> Додано в HKCU Run (режим трею): $targetExe -tray"
        }

        # 6. Служба IPBan
        if ($chkCheckService.Checked) {
            $pbInstall.Value = 90
            Log-Step "Перевірка наявності служби IPBan..."
            $ipbanSvc = Get-Service -Name "IPBan" -ErrorAction SilentlyContinue
            if ($ipbanSvc) {
                Log-Step "  -> Службу IPBan знайдено. Налаштування автоматичного запуску (Automatic)..."
                try {
                    Set-Service -Name "IPBan" -StartupType Automatic -ErrorAction SilentlyContinue
                    & sc.exe config "IPBan" start= auto | Out-Null
                    & sc.exe failure "IPBan" reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
                    Start-Service -Name "IPBan" -ErrorAction SilentlyContinue
                    Log-Step "  -> Службу IPBan успішно налаштовано та запущено в режимі Automatic"
                } catch {
                    Log-Step "  -> Попередження: $($_.Exception.Message)"
                }
            } else {
                Log-Step "  -> Службу IPBan не виявлено (її можна встановити з програми у вкладці «Служба IPBan»)"
            }
        }

        # 7. Аудит безпеки Windows
        if ($chkAuditPol.Checked) {
            $pbInstall.Value = 95
            Log-Step "Увімкнення політики аудиту безпеки Windows (AuditPol)..."
            & auditpol.exe /set /category:"{69979849-797A-11D9-BED3-505054503030}" /success:enable /failure:enable 2>$null
            & auditpol.exe /set /category:"{69979850-797A-11D9-BED3-505054503030}" /success:enable /failure:enable 2>$null
            Log-Step "  -> Аудит Logon/Logoff успішно активовано"
        }

        # 8. Збереження налаштувань у реєстр HKCU
        try {
            $regUser = "HKCU:\SOFTWARE\IPBanControlCenter"
            if (-not (Test-Path $regUser)) { New-Item -Path $regUser -Force | Out-Null }
            Set-ItemProperty -Path $regUser -Name "Language" -Value $script:CurrentLang -Force
            Set-ItemProperty -Path $regUser -Name "StartInTray" -Value 1 -Force
            Log-Step "  -> Налаштування мови ($($script:CurrentLang)) та трею збережено в реєстр"
        } catch {}

        $pbInstall.Value = 100
        Log-Step "✅ Інсталяцію завершено успішно!"
        Start-Sleep -Milliseconds 600

        Set-Page 4
    } catch {
        Log-Step "❌ ПОМИЛКА: $_"
        [System.Windows.Forms.MessageBox]::Show("Під час встановлення сталася помилка:`n$_", "Помилка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $btnBack.Enabled = $true
        $btnCancel.Enabled = $true
    }
}

# Початкове відображення
Apply-InstallerLanguage
Set-Page 0

[System.Windows.Forms.Application]::Run($form)
