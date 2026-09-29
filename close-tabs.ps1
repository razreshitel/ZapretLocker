# Defines Close-BlockedTabs.

if (-not ([System.Management.Automation.PSTypeName]'ZapretLockerWin').Type) {
    Add-Type -AssemblyName System.Windows.Forms

    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Collections.Generic;

public class ZapretLockerWin {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();

    public class Win { public IntPtr Handle; public string Title; public int Pid; }

    public static List<Win> GetWindows() {
        var list = new List<Win>();
        EnumWindows((h, l) => {
            if (IsWindowVisible(h)) {
                int len = GetWindowTextLength(h);
                if (len > 0) {
                    var sb = new StringBuilder(len + 1);
                    GetWindowText(h, sb, sb.Capacity);
                    uint pid;
                    GetWindowThreadProcessId(h, out pid);
                    list.Add(new Win { Handle = h, Title = sb.ToString(), Pid = (int)pid });
                }
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // true if window got focus
    public static bool Activate(IntPtr h) {
        if (IsIconic(h)) ShowWindow(h, 9);
        if (GetForegroundWindow() != h) SetForegroundWindow(h);
        if (GetForegroundWindow() != h) {
            uint pid;
            uint fg = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
            uint me = GetCurrentThreadId();
            if (fg != 0 && fg != me && AttachThreadInput(me, fg, true)) {
                BringWindowToTop(h);
                SetForegroundWindow(h);
                AttachThreadInput(me, fg, false);
            }
        }
        Thread.Sleep(150);
        return GetForegroundWindow() == h;
    }
}
"@
}

function Close-BlockedTabs([string[]]$Keywords, [string[]]$Browsers) {
    foreach ($w in [ZapretLockerWin]::GetWindows()) {
        if ($w.Pid -eq $PID) { continue }
        $title = $w.Title
        if (-not ($Keywords | Where-Object { $title.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 })) { continue }
        $proc = Get-Process -Id $w.Pid -ErrorAction SilentlyContinue
        if (-not $proc -or $Browsers -notcontains $proc.ProcessName) { continue }
        if ([ZapretLockerWin]::Activate($w.Handle)) {
            [System.Windows.Forms.SendKeys]::SendWait("^w")   # closes active tab
            Start-Sleep -Milliseconds 150
        }
    }
}
