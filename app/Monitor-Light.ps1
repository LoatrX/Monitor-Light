<#
    Product : Monitor-Light
    Version : 2.4
    Author  : LoatrX
    Icons   : Bootstrap Icons (MIT)
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = "Monitor-Light"
$script:Version = "2.4"
$script:Byline = "by LoatrX"
$script:GitHubUrl = "https://github.com/LoatrX/Monitor-Light"
$script:AppRoot = Split-Path -Parent $PSScriptRoot
$script:AssetsPath = Join-Path $script:AppRoot "assets\img"
$script:UserProfilePath = Join-Path $script:AppRoot "user_profil"
$script:SettingsPath = Join-Path $script:UserProfilePath "settings.json"
$script:ReadyPath = Join-Path $script:UserProfilePath "ready.flag"
$script:MonitorRows = New-Object System.Collections.ArrayList
$script:DisposableObjects = New-Object System.Collections.ArrayList
$script:Loading = $true
$script:IsExiting = $false
$script:Language = "en"
$script:DisplaySettings = @{}

$nativeCode = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using System.Xml;

public static class MonitorControl
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR
    {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint count);
    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint count, [Out] PHYSICAL_MONITOR[] monitors);
    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetMonitorBrightness(IntPtr monitor, out uint minimum, out uint current, out uint maximum);
    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool SetMonitorBrightness(IntPtr monitor, uint brightness);
    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool DestroyPhysicalMonitor(IntPtr monitor);

    private static readonly List<PHYSICAL_MONITOR> Monitors = new List<PHYSICAL_MONITOR>();

    private static void ReleaseMonitors()
    {
        foreach (PHYSICAL_MONITOR monitor in Monitors)
            if (monitor.hPhysicalMonitor != IntPtr.Zero) DestroyPhysicalMonitor(monitor.hPhysicalMonitor);
        Monitors.Clear();
    }

    public static string[] DetectMonitors()
    {
        ReleaseMonitors();
        MonitorEnumProc callback = delegate(IntPtr hMonitor, IntPtr hdc, IntPtr rect, IntPtr data)
        {
            uint count;
            if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out count) && count > 0)
            {
                PHYSICAL_MONITOR[] physical = new PHYSICAL_MONITOR[count];
                if (GetPhysicalMonitorsFromHMONITOR(hMonitor, count, physical))
                {
                    foreach (PHYSICAL_MONITOR monitor in physical)
                    {
                        uint min, current, max;
                        if (GetMonitorBrightness(monitor.hPhysicalMonitor, out min, out current, out max))
                            Monitors.Add(monitor);
                        else
                            DestroyPhysicalMonitor(monitor.hPhysicalMonitor);
                    }
                }
            }
            return true;
        };

        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
        List<string> names = new List<string>();
        for (int i = 0; i < Monitors.Count; i++)
        {
            string name = Monitors[i].szPhysicalMonitorDescription;
            if (String.IsNullOrWhiteSpace(name)) name = "External display " + (i + 1);
            names.Add(name);
        }
        return names.ToArray();
    }

    public static int GetBrightnessPercent(int index)
    {
        if (index < 0 || index >= Monitors.Count) return -1;
        uint min, current, max;
        if (!GetMonitorBrightness(Monitors[index].hPhysicalMonitor, out min, out current, out max)) return -1;
        if (max <= min) return 0;
        return (int)((current - min) * 100 / (max - min));
    }

    public static bool SetBrightnessPercent(int index, uint percent)
    {
        if (index < 0 || index >= Monitors.Count) return false;
        if (percent > 100) percent = 100;
        uint min, current, max;
        if (!GetMonitorBrightness(Monitors[index].hPhysicalMonitor, out min, out current, out max)) return false;
        uint value = min + ((max - min) * percent / 100);
        return SetMonitorBrightness(Monitors[index].hPhysicalMonitor, value);
    }

    public static int GetCount() { return Monitors.Count; }
    public static void Cleanup() { ReleaseMonitors(); }
}

public sealed class BrightnessSlider : Control
{
    private int currentValue = 50;
    private bool dragging;

    public event EventHandler ValueChanged;
    public int Minimum { get; set; }
    public int Maximum { get; set; }
    public int ThumbSize { get; set; }
    public int SmallChange { get; set; }
    public System.Drawing.Color TrackColor { get; set; }
    public System.Drawing.Color ThumbColor { get; set; }

    public int Value
    {
        get { return currentValue; }
        set
        {
            int next = Math.Max(Minimum, Math.Min(Maximum, value));
            if (next == currentValue) return;
            currentValue = next;
            Invalidate();
            EventHandler handler = ValueChanged;
            if (handler != null) handler(this, EventArgs.Empty);
        }
    }

    public BrightnessSlider()
    {
        Minimum = 0;
        Maximum = 100;
        ThumbSize = 40;
        SmallChange = 2;
        TrackColor = System.Drawing.Color.Black;
        ThumbColor = System.Drawing.Color.FromArgb(0, 94, 255);
        DoubleBuffered = true;
        TabStop = false;
        SetStyle(ControlStyles.Selectable, false);
        Cursor = Cursors.Hand;
        Height = 46;
        MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { dragging = true; SetFromX(e.X); Capture = true; } };
        MouseMove += (s, e) => { if (dragging) SetFromX(e.X); };
        MouseUp += (s, e) => { dragging = false; Capture = false; };
        MouseWheel += (s, e) => { Value += e.Delta > 0 ? SmallChange : -SmallChange; };
    }

    protected override bool ShowFocusCues { get { return false; } }

    private void SetFromX(int x)
    {
        int left = ThumbSize / 2;
        int right = Math.Max(left + 1, Width - ThumbSize / 2);
        double ratio = Math.Max(0, Math.Min(1, (x - left) / (double)(right - left)));
        Value = Minimum + (int)Math.Round(ratio * (Maximum - Minimum));
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        int cy = Height / 2;
        int left = ThumbSize / 2;
        int right = Width - ThumbSize / 2;
        using (Pen track = new Pen(TrackColor, 4))
        {
            track.StartCap = LineCap.Round;
            track.EndCap = LineCap.Round;
            e.Graphics.DrawLine(track, left, cy, right, cy);
        }
        double ratio = (Value - Minimum) / (double)Math.Max(1, Maximum - Minimum);
        int x = left + (int)Math.Round(ratio * (right - left));
        using (SolidBrush thumb = new SolidBrush(ThumbColor))
        {
            e.Graphics.FillEllipse(thumb, x - ThumbSize / 2, cy - ThumbSize / 2, ThumbSize, ThumbSize);
        }
    }
}

public static class SvgRenderer
{
    [DllImport("gdi32.dll")]
    private static extern bool DeleteObject(IntPtr hObject);

    public static System.Drawing.Bitmap Render(string filePath, int width, int height, System.Drawing.Color color)
    {
        XmlDocument doc = new XmlDocument();
        doc.Load(filePath);
        XmlElement root = doc.DocumentElement;
        string viewBox = root.GetAttribute("viewBox");
        double vbX = 0, vbY = 0, vbW = 16, vbH = 16;
        if (!String.IsNullOrWhiteSpace(viewBox))
        {
            string[] p = Regex.Split(viewBox.Trim(), @"[\s,]+");
            if (p.Length == 4)
            {
                vbX = Double.Parse(p[0], CultureInfo.InvariantCulture);
                vbY = Double.Parse(p[1], CultureInfo.InvariantCulture);
                vbW = Double.Parse(p[2], CultureInfo.InvariantCulture);
                vbH = Double.Parse(p[3], CultureInfo.InvariantCulture);
            }
        }

        System.Windows.Media.DrawingVisual visual = new System.Windows.Media.DrawingVisual();
        using (System.Windows.Media.DrawingContext dc = visual.RenderOpen())
        {
            double scale = Math.Min(width / vbW, height / vbH);
            double offsetX = (width - vbW * scale) / 2.0;
            double offsetY = (height - vbH * scale) / 2.0;
            dc.PushTransform(new System.Windows.Media.TranslateTransform(offsetX, offsetY));
            dc.PushTransform(new System.Windows.Media.ScaleTransform(scale, scale));
            dc.PushTransform(new System.Windows.Media.TranslateTransform(-vbX, -vbY));
            System.Windows.Media.Brush brush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(color.A, color.R, color.G, color.B));
            foreach (XmlNode node in doc.SelectNodes("//*[local-name()='path']"))
            {
                XmlAttribute dAttribute = node.Attributes["d"];
                string d = dAttribute == null ? null : dAttribute.Value;
                if (!String.IsNullOrWhiteSpace(d)) dc.DrawGeometry(brush, null, System.Windows.Media.Geometry.Parse(d));
            }
            dc.Pop(); dc.Pop(); dc.Pop();
        }

        System.Windows.Media.Imaging.RenderTargetBitmap target = new System.Windows.Media.Imaging.RenderTargetBitmap(width, height, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
        target.Render(visual);
        System.Windows.Media.Imaging.BitmapEncoder encoder = new System.Windows.Media.Imaging.PngBitmapEncoder();
        encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(target));
        using (MemoryStream stream = new MemoryStream())
        {
            encoder.Save(stream);
            stream.Position = 0;
            using (System.Drawing.Bitmap temp = new System.Drawing.Bitmap(stream)) return new System.Drawing.Bitmap(temp);
        }
    }

    public static System.Drawing.Icon RenderIcon(string filePath, int size, System.Drawing.Color foreground, System.Drawing.Color background)
    {
        using (System.Drawing.Bitmap canvas = new System.Drawing.Bitmap(size, size))
        using (System.Drawing.Graphics g = System.Drawing.Graphics.FromImage(canvas))
        using (System.Drawing.Bitmap glyph = Render(filePath, size - 6, size - 6, foreground))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(System.Drawing.Color.Transparent);
            using (System.Drawing.SolidBrush bg = new System.Drawing.SolidBrush(background)) g.FillEllipse(bg, 0, 0, size - 1, size - 1);
            g.DrawImage(glyph, 3, 3, size - 6, size - 6);
            IntPtr hIcon = canvas.GetHicon();
            try { return (System.Drawing.Icon)System.Drawing.Icon.FromHandle(hIcon).Clone(); }
            finally { DeleteObject(hIcon); }
        }
    }
}
"@

$compilerReferences = @(
    [System.Windows.Forms.Form].Assembly.Location,
    [System.Drawing.Bitmap].Assembly.Location,
    [System.Windows.Media.DrawingVisual].Assembly.Location,
    [System.Windows.DependencyObject].Assembly.Location,
    [System.Xaml.XamlReader].Assembly.Location,
    [System.Xml.XmlDocument].Assembly.Location
) | Select-Object -Unique

Add-Type -TypeDefinition $nativeCode -Language CSharp -ReferencedAssemblies $compilerReferences -ErrorAction Stop

$colorBackground = [System.Drawing.ColorTranslator]::FromHtml("#ebfbfc")
$colorTrack = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$colorThumb = [System.Drawing.ColorTranslator]::FromHtml("#005eff")
$colorText = [System.Drawing.ColorTranslator]::FromHtml("#101820")
$colorMuted = [System.Drawing.ColorTranslator]::FromHtml("#64727d")
$colorDivider = [System.Drawing.ColorTranslator]::FromHtml("#c9dddf")

function Get-Text {
    param([string]$Key)
    $translations = @{
        en = @{
            Detect="Detect display"; Reset="Reset displays to maximum"; Reload="Reload app"; GitHub="View in GitHub"; Switch="Switch to FR"; Exit="Exit";
            Internal="Internal display"; None="No adjustable display detected"
        }
        fr = @{
            Detect="Detecter les ecrans"; Reset="Reinitialiser les ecrans au maximum"; Reload="Recharger l'application"; GitHub="Voir sur GitHub"; Switch="Switch to EN"; Exit="Quitter";
            Internal="Ecran integre"; None="Aucun ecran reglable detecte"
        }
    }
    return $translations[$script:Language][$Key]
}

function Load-Settings {
    if (-not (Test-Path -LiteralPath $script:UserProfilePath)) {
        New-Item -ItemType Directory -Path $script:UserProfilePath -Force | Out-Null
    }

    $script:DisplaySettings = @{}

    if (Test-Path -LiteralPath $script:SettingsPath) {
        try {
            $settings = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json

            if ($settings.Language -in @("en", "fr")) {
                $script:Language = $settings.Language
            }

            if ($null -ne $settings.Displays) {
                foreach ($property in $settings.Displays.PSObject.Properties) {
                    $script:DisplaySettings[$property.Name] = [int]$property.Value
                }
            }
        }
        catch {}
    }
}

function Save-Settings {
    if (-not (Test-Path -LiteralPath $script:UserProfilePath)) {
        New-Item -ItemType Directory -Path $script:UserProfilePath -Force | Out-Null
    }

    $settings = [ordered]@{
        Language = $script:Language
        Displays = $script:DisplaySettings
        UpdatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    }

    $settings |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}

function Get-DisplayKey {
    param(
        [string]$Type,
        [string]$InstanceName,
        [string]$Name,
        [int]$ExternalIndex
    )

    if ($Type -eq "Internal") {
        return "Internal::$InstanceName"
    }

    return "External::$ExternalIndex::$Name"
}

function Get-SvgBitmap {
    param([string]$FileName, [int]$Size, [System.Drawing.Color]$Color)
    $path = Join-Path $script:AssetsPath $FileName
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $bitmap = [SvgRenderer]::Render($path, $Size, $Size, $Color)
    [void]$script:DisposableObjects.Add($bitmap)
    return $bitmap
}

function Set-RoundedRegion {
    param([System.Windows.Forms.Control]$Control, [int]$Radius = 14)
    if ($Control.Width -le 0 -or $Control.Height -le 0) { return }
    $d = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($Control.Width - $d, 0, $d, $d, 270, 90)
    $path.AddArc($Control.Width - $d, $Control.Height - $d, $d, $d, 0, 90)
    $path.AddArc(0, $Control.Height - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $old = $Control.Region
    $Control.Region = New-Object System.Drawing.Region($path)
    if ($null -ne $old) { $old.Dispose() }
    $path.Dispose()
}

function Get-IntegratedMonitors {
    $result = @()
    try {
        $items = @(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Where-Object Active)
        foreach ($item in $items) {
            $result += [PSCustomObject]@{
                Type="Internal"; Name=(Get-Text "Internal"); Brightness=[int]$item.CurrentBrightness
                InstanceName=[string]$item.InstanceName; ExternalIndex=-1
            }
        }
    } catch {}
    return @($result)
}

function Set-IntegratedBrightness {
    param([string]$InstanceName, [int]$Brightness)
    try {
        $method = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop |
            Where-Object InstanceName -eq $InstanceName | Select-Object -First 1
        if ($null -eq $method) { return $false }
        Invoke-CimMethod -InputObject $method -MethodName WmiSetBrightness -Arguments @{
            Timeout=[uint32]0; Brightness=[byte]$Brightness
        } -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Set-RowBrightness {
    param($Row)

    $success = $false

    if ($Row.Type -eq "Internal") {
        $success = Set-IntegratedBrightness -InstanceName $Row.InstanceName -Brightness $Row.Slider.Value
    }
    else {
        $success = [MonitorControl]::SetBrightnessPercent($Row.ExternalIndex, [uint32]$Row.Slider.Value)
    }

    if ($success) {
        $script:DisplaySettings[$Row.DisplayKey] = [int]$Row.Slider.Value
        Save-Settings
    }
}

function Clear-Rows {
    foreach ($row in $script:MonitorRows) {
        $row.Timer.Stop(); $row.Timer.Dispose()
        $displayPanel.Controls.Remove($row.Panel); $row.Panel.Dispose()
    }
    $script:MonitorRows.Clear()
}

function New-MonitorRow {
    param([string]$Type, [int]$ExternalIndex, [string]$InstanceName, [string]$Name, [int]$Brightness, [int]$Top)

    $displayKey = Get-DisplayKey -Type $Type -InstanceName $InstanceName -Name $Name -ExternalIndex $ExternalIndex

    if ($script:DisplaySettings.ContainsKey($displayKey)) {
        $Brightness = [int]$script:DisplaySettings[$displayKey]
    }

    $row = New-Object System.Windows.Forms.Panel
    $row.Location = [System.Drawing.Point]::new(0, $Top)
    $row.Size = [System.Drawing.Size]::new(370, 92)
    $row.BackColor = $colorBackground

    $icon = New-Object System.Windows.Forms.PictureBox
    $icon.Location = [System.Drawing.Point]::new(14, 12)
    $icon.Size = [System.Drawing.Size]::new(24, 24)
    $icon.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $icon.Image = if ($Type -eq "Internal") { $script:LaptopBitmap } else { $script:DisplayBitmap }
    $row.Controls.Add($icon)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = $Name
    $nameLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
    $nameLabel.ForeColor = $colorText
    $nameLabel.Location = [System.Drawing.Point]::new(48, 12)
    $nameLabel.Size = [System.Drawing.Size]::new(245, 24)
    $nameLabel.AutoEllipsis = $true
    $row.Controls.Add($nameLabel)

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = "$Brightness %"
    $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10.5)
    $valueLabel.ForeColor = $colorThumb
    $valueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $valueLabel.Location = [System.Drawing.Point]::new(298, 10)
    $valueLabel.Size = [System.Drawing.Size]::new(58, 26)
    $row.Controls.Add($valueLabel)

    $slider = New-Object BrightnessSlider
    $slider.Location = [System.Drawing.Point]::new(44, 40)
    $slider.Size = [System.Drawing.Size]::new(312, 46)
    $slider.BackColor = $colorBackground
    $slider.TrackColor = $colorTrack
    $slider.ThumbColor = $colorThumb
    $slider.ThumbSize = 18
    $slider.SmallChange = 2
    $slider.Value = [Math]::Max(0, [Math]::Min(100, $Brightness))
    $row.Controls.Add($slider)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 100
    $data = [PSCustomObject]@{
        Type=$Type; ExternalIndex=$ExternalIndex; InstanceName=$InstanceName
        DisplayKey=$displayKey; Panel=$row; Slider=$slider; ValueLabel=$valueLabel; Timer=$timer
    }
    $slider.Tag = $data; $timer.Tag = $data
    $slider.Add_ValueChanged({
        $this.Tag.ValueLabel.Text = "$($this.Value) %"
        if (-not $script:Loading) { $this.Tag.Timer.Stop(); $this.Tag.Timer.Start() }
    })
    $timer.Add_Tick({ $this.Stop(); Set-RowBrightness -Row $this.Tag })
    [void]$script:MonitorRows.Add($data)
    $displayPanel.Controls.Add($row)

    if ($script:DisplaySettings.ContainsKey($displayKey)) {
        Set-RowBrightness -Row $data
    }
}

function Get-TaskbarEdge {
    param([System.Windows.Forms.Screen]$Screen)
    $b=$Screen.Bounds; $w=$Screen.WorkingArea
    if ($w.Top -gt $b.Top) { return "Top" }
    if ($w.Left -gt $b.Left) { return "Left" }
    if ($w.Right -lt $b.Right) { return "Right" }
    return "Bottom"
}

function Position-NearTaskbar {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $area = $screen.WorkingArea
    $margin = 10
    switch (Get-TaskbarEdge $screen) {
        "Top" { $x=$area.Right-$form.Width-$margin; $y=$area.Top+$margin }
        "Left" { $x=$area.Left+$margin; $y=$area.Bottom-$form.Height-$margin }
        "Right" { $x=$area.Right-$form.Width-$margin; $y=$area.Bottom-$form.Height-$margin }
        default { $x=$area.Right-$form.Width-$margin; $y=$area.Bottom-$form.Height-$margin }
    }
    $x=[Math]::Max($area.Left+$margin,[Math]::Min($x,$area.Right-$form.Width-$margin))
    $y=[Math]::Max($area.Top+$margin,[Math]::Min($y,$area.Bottom-$form.Height-$margin))
    $form.Location=[System.Drawing.Point]::new([int]$x,[int]$y)
}

function Refresh-Monitors {
    $script:Loading = $true
    Clear-Rows
    $internal = @(Get-IntegratedMonitors)
    $externalNames = [MonitorControl]::DetectMonitors()
    $externalCount = [MonitorControl]::GetCount()
    $top = 0

    foreach ($item in $internal) {
        New-MonitorRow -Type Internal -ExternalIndex -1 -InstanceName $item.InstanceName -Name $item.Name -Brightness $item.Brightness -Top $top
        $top += 92
    }
    for ($i=0; $i -lt $externalCount; $i++) {
        $brightness=[MonitorControl]::GetBrightnessPercent($i)
        if ($brightness -lt 0) { $brightness=50 }
        New-MonitorRow -Type External -ExternalIndex $i -InstanceName "" -Name $externalNames[$i] -Brightness $brightness -Top $top
        $top += 92
    }

    $count=$internal.Count+$externalCount
    if ($count -eq 0) {
        $emptyLabel.Visible=$true
        $contentHeight=70
    } else {
        $emptyLabel.Visible=$false
        $contentHeight=$count*92
    }

    # No scrollbar: the window expands to show every detected display.
    $footerHeight=25
    $panelHeight=$contentHeight+$footerHeight
    $form.ClientSize=[System.Drawing.Size]::new(416,$panelHeight+20)
    $mainPanel.Size=[System.Drawing.Size]::new(388,$panelHeight)
    $displayPanel.Size=[System.Drawing.Size]::new(370,$contentHeight)
    $footerLabel.Location=[System.Drawing.Point]::new(10,$contentHeight+3)
    Set-RoundedRegion -Control $mainPanel -Radius 14
    Set-RoundedRegion -Control $form -Radius 18

Position-NearTaskbar
$script:Loading = $false
}

function Reset-DisplaysToMaximum {
    foreach ($row in $script:MonitorRows) {
        $row.Slider.Value = 100
        Set-RowBrightness -Row $row
    }

    Save-Settings
}

function Build-TrayMenu {
    $trayMenu.Items.Clear()

    $titleItem=New-Object System.Windows.Forms.ToolStripMenuItem("Monitor-Light v2.4")
    $titleItem.Enabled=$true
    $titleItem.ToolTipText="Open Monitor-Light"
    $titleItem.Font=New-Object System.Drawing.Font("Segoe UI Semibold",9)
    $byItem=New-Object System.Windows.Forms.ToolStripMenuItem($script:Byline)
    $byItem.Enabled=$false
    $byItem.Font=New-Object System.Drawing.Font("Segoe UI",8)
    $detectItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "Detect"))
    $resetItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "Reset"))
    $reloadItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "Reload"))
    $githubItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "GitHub"))
    $languageItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "Switch"))
    $exitItem=New-Object System.Windows.Forms.ToolStripMenuItem((Get-Text "Exit"))

    [void]$trayMenu.Items.Add($titleItem)
    [void]$trayMenu.Items.Add($byItem)
    [void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$trayMenu.Items.Add($detectItem)
    [void]$trayMenu.Items.Add($resetItem)
    [void]$trayMenu.Items.Add($reloadItem)
    [void]$trayMenu.Items.Add($githubItem)
    [void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$trayMenu.Items.Add($languageItem)
    [void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$trayMenu.Items.Add($exitItem)

    $titleItem.Add_Click({ Show-Panel })
    $detectItem.Add_Click({ Refresh-Monitors; if ($form.Visible) { Position-NearTaskbar } })
    $resetItem.Add_Click({ Reset-DisplaysToMaximum })
    $reloadItem.Add_Click({ Reload-App })
    $githubItem.Add_Click({ Start-Process $script:GitHubUrl })
    $languageItem.Add_Click({
        $script:Language = if ($script:Language -eq "en") { "fr" } else { "en" }
        Save-Settings
        Build-TrayMenu
        Refresh-Monitors
    })
    $exitItem.Add_Click({ Exit-App })
}

function Show-Panel {
    if ($script:IsExiting) { return }
    Refresh-Monitors; Position-NearTaskbar
    $form.Show(); $form.Activate(); $form.BringToFront()
}

function Hide-Panel { if (-not $script:IsExiting) { $form.Hide() } }

function Reload-App {
    $launcher=Join-Path $PSScriptRoot "Monitor-Light-Launcher.vbs"
    if (Test-Path $launcher) { Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList "`"$launcher`"" }
    else { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" }
    Exit-App
}

function Exit-App {
    if ($script:IsExiting) { return }
    $script:IsExiting=$true
    Remove-Item -LiteralPath $script:ReadyPath -Force -ErrorAction SilentlyContinue
    $form.Hide()
    foreach ($row in $script:MonitorRows) { $row.Timer.Stop(); $row.Timer.Dispose() }
    [MonitorControl]::Cleanup()
    $trayIcon.Visible=$false
    $trayIcon.Dispose(); $trayMenu.Dispose(); $form.Dispose()
    foreach ($obj in $script:DisposableObjects) { $obj.Dispose() }
    if ($null -ne $script:TrayIconObject) { $script:TrayIconObject.Dispose() }
    [System.Windows.Forms.Application]::Exit()
}

Load-Settings
$script:LaptopBitmap=Get-SvgBitmap "laptop.svg" 24 $colorText
$script:DisplayBitmap=Get-SvgBitmap "display.svg" 24 $colorText

$form=New-Object System.Windows.Forms.Form
$form.Text="Monitor-Light v2.4"
$form.StartPosition=[System.Windows.Forms.FormStartPosition]::Manual
$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None
$form.ShowInTaskbar=$false
$form.TopMost=$true
$form.BackColor=$colorBackground
$form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi
$form.ClientSize=[System.Drawing.Size]::new(416,120)
$form.KeyPreview=$true

$mainPanel=New-Object System.Windows.Forms.Panel
$mainPanel.Location=[System.Drawing.Point]::new(14,10)
$mainPanel.BackColor=$colorBackground
$form.Controls.Add($mainPanel)

$displayPanel=New-Object System.Windows.Forms.Panel
$displayPanel.Location=[System.Drawing.Point]::new(9,0)
$displayPanel.BackColor=$colorBackground
$mainPanel.Controls.Add($displayPanel)

$emptyLabel=New-Object System.Windows.Forms.Label
$emptyLabel.Text=(Get-Text "None")
$emptyLabel.Font=New-Object System.Drawing.Font("Segoe UI",9.5)
$emptyLabel.ForeColor=$colorMuted
$emptyLabel.TextAlign=[System.Drawing.ContentAlignment]::MiddleCenter
$emptyLabel.Location=[System.Drawing.Point]::new(10,10)
$emptyLabel.Size=[System.Drawing.Size]::new(350,48)
$displayPanel.Controls.Add($emptyLabel)

$footerLabel=New-Object System.Windows.Forms.Label
$footerLabel.Text="by LoatrX"
$footerLabel.Font=New-Object System.Drawing.Font("Segoe UI",7.5)
$footerLabel.ForeColor=$colorMuted
$footerLabel.TextAlign=[System.Drawing.ContentAlignment]::MiddleRight
$footerLabel.Size=[System.Drawing.Size]::new(360,18)
$mainPanel.Controls.Add($footerLabel)

$trayMenu=New-Object System.Windows.Forms.ContextMenuStrip
$trayMenu.Font=New-Object System.Drawing.Font("Segoe UI",9)
Build-TrayMenu

$trayIcon=New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Text="Monitor-Light v2.4"
$iconPath=Join-Path $script:AssetsPath "icon.svg"
if (Test-Path $iconPath) {
    $script:TrayIconObject=[SvgRenderer]::RenderIcon($iconPath,32,$colorThumb,$colorBackground)
    $trayIcon.Icon=$script:TrayIconObject
} else {
    $trayIcon.Icon=[System.Drawing.SystemIcons]::Application
}
$trayIcon.ContextMenuStrip=$trayMenu
$trayIcon.Visible=$true

if (-not (Test-Path -LiteralPath $script:UserProfilePath)) {
    New-Item -ItemType Directory -Path $script:UserProfilePath -Force | Out-Null
}
Set-Content -LiteralPath $script:ReadyPath -Value "Monitor-Light $($script:Version) ready" -Encoding UTF8
$trayIcon.Add_MouseClick({
    param($sender,$eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($form.Visible) { Hide-Panel } else { Show-Panel }
    }
})

$form.Add_Deactivate({ Hide-Panel })
$form.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { Hide-Panel } })
$form.Add_FormClosing({ param($sender,$eventArgs); if (-not $script:IsExiting) { $eventArgs.Cancel=$true; Hide-Panel } })

Refresh-Monitors
$form.Hide()
[System.Windows.Forms.Application]::Run()
