# ==============================================================================
# Build_Binaries.ps1
# Компілює повністю автономні (Standalone) виконавчі файли .exe
# з вбудованими ресурсами (GZip Base64) та генерує іконку .ico
# ==============================================================================

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$appVersion = "2.2.2.0"
$appDisplayVersion = "2.2.2"

# Допоміжна функція створення GZip Base64 архіву файлів
function New-GZipPackage([string[]]$fileNames, [string]$baseFolder) {
    $ms = New-Object System.IO.MemoryStream
    $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
    $bw = New-Object System.IO.BinaryWriter($gz)

    $items = @()
    foreach ($fn in $fileNames) {
        $fullPath = Join-Path $baseFolder $fn
        if (Test-Path $fullPath) {
            $items += @{ Name = $fn; Path = $fullPath }
        }
    }

    $bw.Write([int]$items.Count)
    foreach ($item in $items) {
        $bytes = [System.IO.File]::ReadAllBytes($item.Path)
        $bw.Write([string]$item.Name)
        $bw.Write([int]$bytes.Length)
        $bw.Write($bytes)
    }
    $bw.Flush()
    $gz.Close()
    $payload = $ms.ToArray()
    return [Convert]::ToBase64String($payload)
}

# ------------------------------------------------------------------------------
# 1. Генерація app.ico (іконка щита захисту)
# ------------------------------------------------------------------------------
$icoPath = Join-Path $scriptDir "app.ico"
$bmp = New-Object System.Drawing.Bitmap 48, 48
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$points = @(
    (New-Object System.Drawing.Point 24, 2),
    (New-Object System.Drawing.Point 44, 9),
    (New-Object System.Drawing.Point 44, 28),
    (New-Object System.Drawing.Point 24, 45),
    (New-Object System.Drawing.Point 4, 28),
    (New-Object System.Drawing.Point 4, 9)
)
$p1 = New-Object System.Drawing.Point 0, 0
$p2 = New-Object System.Drawing.Point 48, 48
$c1 = [System.Drawing.Color]::FromArgb(30, 58, 138)
$c2 = [System.Drawing.Color]::FromArgb(16, 185, 129)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $p1, $p2, $c1, $c2
$g.FillPolygon($brush, $points)
$brush.Dispose()

$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White, 2)
$g.DrawPolygon($pen, $points)
$pen.Dispose()

# Галочка всередині щита
$penCheck = New-Object System.Drawing.Pen ([System.Drawing.Color]::White, 3.5)
$penCheck.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$penCheck.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($penCheck, 14, 23, 22, 31)
$g.DrawLine($penCheck, 22, 31, 34, 15)
$penCheck.Dispose()
$g.Dispose()

$hIcon = $bmp.GetHicon()
$ico = [System.Drawing.Icon]::FromHandle($hIcon)
if (Test-Path $icoPath) { Remove-Item $icoPath -Force }
$fs = [System.IO.File]::OpenWrite($icoPath)
$ico.Save($fs)
$fs.Close()
$ico.Dispose()
$bmp.Dispose()
Write-Host "✅ Створено іконку: $icoPath" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 2. Компіляція автономного IPBanControlCenter.exe
#    (Містить вбудований скрипт IPBanGUI.ps1 та іконку app.ico)
# ------------------------------------------------------------------------------
$launcherPayload = New-GZipPackage @("IPBanGUI.ps1", "app.ico") $scriptDir

$csharpLauncher = @"
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Windows.Forms;

[assembly: AssemblyTitle("IPBan Control Center")]
[assembly: AssemblyDescription("IPBan Manager and Control Center")]
[assembly: AssemblyCompany("IPBan Community & Tooling")]
[assembly: AssemblyProduct("IPBan Control Center")]
[assembly: AssemblyCopyright("Copyright (C) 2026")]
[assembly: AssemblyVersion("$appVersion")]
[assembly: AssemblyFileVersion("$appVersion")]
[assembly: AssemblyInformationalVersion("$appDisplayVersion")]

namespace IPBanControlCenter {
    class Program {
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        // Вбудований пакет IPBanGUI.ps1 + app.ico
        private static readonly string EmbeddedPayload = "$launcherPayload";

        [STAThread]
        static void Main(string[] args) {
            bool createdNew = false;
            using (var mutex = new System.Threading.Mutex(true, "Local\\IPBanControlCenter_Exe_SingleInstance", out createdNew)) {
                if (!createdNew) {
                    try {
                        using (var rk = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"SOFTWARE\IPBanControlCenter", false)) {
                            if (rk != null) {
                                object val = rk.GetValue("WindowHandle");
                                if (val != null) {
                                    long hLong = Convert.ToInt64(val);
                                    if (hLong != 0) {
                                        IntPtr hWnd = new IntPtr(hLong);
                                        ShowWindow(hWnd, 9); // SW_RESTORE
                                        SetForegroundWindow(hWnd);
                                    }
                                }
                            }
                        }
                    } catch {}
                    return;
                }
                try {
                    string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                    string ps1 = Path.Combine(baseDir, "IPBanGUI.ps1");

                // 1. Шукаємо поруч із .exe
                if (!File.Exists(ps1)) {
                    ps1 = Path.Combine(Environment.CurrentDirectory, "IPBanGUI.ps1");
                }

                // 2. Шукаємо у стандартній папці встановлення Program Files
                if (!File.Exists(ps1)) {
                    string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                    string defaultInstall = Path.Combine(pf, "IPBan Manager", "IPBanGUI.ps1");
                    if (File.Exists(defaultInstall)) {
                        ps1 = defaultInstall;
                        baseDir = Path.GetDirectoryName(defaultInstall);
                    }
                }

                // 3. Якщо ніде не знайдено, розпаковуємо вбудований скрипт у LocalAppData
                if (!File.Exists(ps1) && !string.IsNullOrEmpty(EmbeddedPayload)) {
                    try {
                        string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                        string targetFolder = Path.Combine(appData, "IPBanControlCenter");
                        Directory.CreateDirectory(targetFolder);

                        byte[] raw = Convert.FromBase64String(EmbeddedPayload);
                        using (MemoryStream ms = new MemoryStream(raw))
                        using (GZipStream gz = new GZipStream(ms, CompressionMode.Decompress))
                        using (BinaryReader br = new BinaryReader(gz)) {
                            int count = br.ReadInt32();
                            for (int i = 0; i < count; i++) {
                                string name = br.ReadString();
                                int len = br.ReadInt32();
                                byte[] data = br.ReadBytes(len);
                                string outPath = Path.Combine(targetFolder, name);
                                File.WriteAllBytes(outPath, data);
                            }
                        }

                        string unpackedPs1 = Path.Combine(targetFolder, "IPBanGUI.ps1");
                        if (File.Exists(unpackedPs1)) {
                            ps1 = unpackedPs1;
                            baseDir = targetFolder;
                        }
                    } catch {}
                }

                if (!File.Exists(ps1)) {
                    MessageBox.Show("\u041D\u0435 \u0432\u0434\u0430\u043B\u043E\u0441\u044F \u0437\u043D\u0430\u0439\u0442\u0438 \u0430\u0431\u043E \u0440\u043E\u0437\u043F\u0430\u043A\u0443\u0432\u0430\u0442\u0438 IPBanGUI.ps1", "\u041F\u043E\u043C\u0438\u043B\u043A\u0430 \u0437\u0430\u043F\u0443\u0441\u043A\u0443", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                string extraArgs = "";
                if (args != null && args.Length > 0) {
                    extraArgs = " " + string.Join(" ", args);
                }

                // Очищаємо застарілий глобальний автозапуск із HKLM, якщо він ще існує
                try {
                    using (var rk = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true)) {
                        if (rk != null && rk.GetValue("IPBanControlCenter") != null) {
                            rk.DeleteValue("IPBanControlCenter", false);
                        }
                    }
                } catch {}

                bool isAdmin = false;
                try {
                    isAdmin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
                } catch {}

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"" + extraArgs;
                if (!isAdmin) {
                    psi.Verb = "runas";
                }
                psi.UseShellExecute = true;
                psi.WorkingDirectory = baseDir;

                Process.Start(psi);
            } catch (System.ComponentModel.Win32Exception) {
                // Користувач відхилив запит UAC
            } catch (Exception ex) {
                MessageBox.Show("\u041F\u043E\u043C\u0438\u043B\u043A\u0430 \u0437\u0430\u043F\u0443\u0441\u043A\u0443:\n" + ex.Message, "\u041F\u043E\u043C\u0438\u043B\u043A\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
}
"@

$opt1 = New-Object System.CodeDom.Compiler.CompilerParameters
$opt1.ReferencedAssemblies.Add("System.dll") | Out-Null
$opt1.ReferencedAssemblies.Add("System.Windows.Forms.dll") | Out-Null
$opt1.GenerateExecutable = $true
$launcherExe = Join-Path $scriptDir "IPBanControlCenter.exe"
$opt1.OutputAssembly = $launcherExe
$opt1.CompilerOptions = "/target:winexe /win32icon:`"$icoPath`" /codepage:65001"

$cp = New-Object Microsoft.CSharp.CSharpCodeProvider
$cr1 = $cp.CompileAssemblyFromSource($opt1, $csharpLauncher)
if ($cr1.Errors.Count -eq 0) {
    Write-Host "✅ Скомпільовано автономний лаунчер: $launcherExe" -ForegroundColor Green
} else {
    Write-Host "❌ Помилка компіляції лаунчера:" -ForegroundColor Red
    $cr1.Errors | ForEach-Object { Write-Host $_.ErrorText }
}

# ------------------------------------------------------------------------------
# 3. Компіляція повністю автономного інсталятора Setup_IPBanGUI.exe
#    (Містить вбудований майстер Installer.ps1, IPBanGUI.ps1,
#     IPBanControlCenter.exe, app.ico, README_IPBan_GUI.md, Run_IPBan_GUI.bat)
# ------------------------------------------------------------------------------
$setupPayload = New-GZipPackage @(
    "Installer.ps1",
    "IPBanGUI.ps1",
    "IPBanControlCenter.exe",
    "app.ico",
    "README_IPBan_GUI.md",
    "Run_IPBan_GUI.bat"
) $scriptDir

$csharpSetup = @"
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;

[assembly: AssemblyTitle("Setup IPBan GUI")]
[assembly: AssemblyDescription("IPBan Manager and Control Center Installer")]
[assembly: AssemblyCompany("IPBan Community & Tooling")]
[assembly: AssemblyProduct("IPBan Manager & Control Center")]
[assembly: AssemblyCopyright("Copyright (C) 2026")]
[assembly: AssemblyVersion("$appVersion")]
[assembly: AssemblyFileVersion("$appVersion")]
[assembly: AssemblyInformationalVersion("$appDisplayVersion")]

namespace IPBanSetup {
    class Program {
        // Повний вбудований архів інсталятора
        private static readonly string PackageBase64 = "$setupPayload";

        [STAThread]
        static void Main(string[] args) {
            string tempDir = null;
            try {
                // 1. Створюємо унікальну тимчасову папку
                tempDir = Path.Combine(Path.GetTempPath(), "IPBanSetup_" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tempDir);

                // 2. Розпаковуємо всі файли з вбудованого архіву
                byte[] rawData = Convert.FromBase64String(PackageBase64);
                using (MemoryStream ms = new MemoryStream(rawData))
                using (GZipStream gz = new GZipStream(ms, CompressionMode.Decompress))
                using (BinaryReader br = new BinaryReader(gz)) {
                    int count = br.ReadInt32();
                    for (int i = 0; i < count; i++) {
                        string name = br.ReadString();
                        int len = br.ReadInt32();
                        byte[] fileBytes = br.ReadBytes(len);
                        string outPath = Path.Combine(tempDir, name);
                        File.WriteAllBytes(outPath, fileBytes);
                    }
                }

                // 3. Знаходимо Installer.ps1
                string installerPath = Path.Combine(tempDir, "Installer.ps1");
                if (!File.Exists(installerPath)) {
                    MessageBox.Show("\u041D\u0435 \u0432\u0434\u0430\u043B\u043E\u0441\u044F \u0440\u043E\u0437\u043F\u0430\u043A\u0443\u0432\u0430\u0442\u0438 \u0444\u0430\u0439\u043B\u0438 \u0456\u043D\u0441\u0442\u0430\u043B\u044F\u0446\u0456\u0457.", "\u041F\u043E\u043C\u0438\u043B\u043A\u0430 \u0456\u043D\u0441\u0442\u0430\u043B\u044F\u0442\u043E\u0440\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                bool isAdmin = false;
                try {
                    isAdmin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
                } catch {}

                // 4. Запускаємо майстер встановлення
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + installerPath + "\"";
                if (!isAdmin) {
                    psi.Verb = "runas";
                }
                psi.UseShellExecute = true;
                psi.WorkingDirectory = tempDir;

                Process p = Process.Start(psi);
                if (p != null) {
                    p.WaitForExit();
                }
            } catch (System.ComponentModel.Win32Exception) {
                // Користувач відхилив запит UAC
            } catch (Exception ex) {
                MessageBox.Show("\u041F\u043E\u043C\u0438\u043B\u043A\u0430 \u0437\u0430\u043F\u0443\u0441\u043A\u0443 \u0456\u043D\u0441\u0442\u0430\u043B\u044F\u0442\u043E\u0440\u0430:\n" + ex.Message, "\u041F\u043E\u043C\u0438\u043B\u043A\u0430 \u0456\u043D\u0441\u0442\u0430\u043B\u044F\u0442\u043E\u0440\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
            } finally {
                // 5. Очищення тимчасової папки
                if (tempDir != null && Directory.Exists(tempDir)) {
                    try {
                        Directory.Delete(tempDir, true);
                    } catch {}
                }
            }
        }
    }
}
"@

$opt2 = New-Object System.CodeDom.Compiler.CompilerParameters
$opt2.ReferencedAssemblies.Add("System.dll") | Out-Null
$opt2.ReferencedAssemblies.Add("System.Windows.Forms.dll") | Out-Null
$opt2.GenerateExecutable = $true
$setupExe = Join-Path $scriptDir "Setup_IPBanGUI.exe"
$opt2.OutputAssembly = $setupExe
$opt2.CompilerOptions = "/target:winexe /win32icon:`"$icoPath`" /codepage:65001"

$cr2 = $cp.CompileAssemblyFromSource($opt2, $csharpSetup)
if ($cr2.Errors.Count -eq 0) {
    Write-Host "✅ Скомпільовано автономний інсталятор: $setupExe" -ForegroundColor Green

    # Автоматичне оновлення папки release/ та ZIP-архіву
    $relDir = Join-Path $scriptDir "release"
    if (-not (Test-Path $relDir)) { New-Item -ItemType Directory -Path $relDir -Force | Out-Null }
    Copy-Item $launcherExe -Destination (Join-Path $relDir "IPBanControlCenter.exe") -Force
    Copy-Item $setupExe -Destination (Join-Path $relDir "Setup_IPBanGUI.exe") -Force

    $zipPath = Join-Path $relDir "IPBanGUI-v2.2.2.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tempZipDir = Join-Path $env:TEMP ("zip_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempZipDir -Force | Out-Null
    Copy-Item $setupExe -Destination $tempZipDir -Force
    Copy-Item $launcherExe -Destination $tempZipDir -Force
    $readmeFile = Join-Path $scriptDir "README.md"
    if (Test-Path $readmeFile) { Copy-Item $readmeFile -Destination $tempZipDir -Force }
    $licFile = Join-Path $scriptDir "LICENSE"
    if (Test-Path $licFile) { Copy-Item $licFile -Destination $tempZipDir -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempZipDir, $zipPath)
    Remove-Item -Path $tempZipDir -Recurse -Force
    Write-Host "✅ Оновлено релізні файли та ZIP-пакет: $zipPath" -ForegroundColor Green
} else {
    Write-Host "❌ Помилка компіляції інсталятора:" -ForegroundColor Red
    $cr2.Errors | ForEach-Object { Write-Host $_.ErrorText }
}

