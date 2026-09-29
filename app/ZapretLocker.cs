using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("ZapretLocker")]
[assembly: System.Reflection.AssemblyProduct("ZapretLocker")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.0.0.0")]

namespace ZapretLocker
{
    public static class Program
    {
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

        [STAThread]
        public static void Main()
        {
            try { SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            if (!File.Exists(Setup.ScriptPath))
            {
                MessageBox.Show("Не найден setup.ps1 рядом с программой:\n" + Setup.ScriptPath,
                    "ZapretLocker", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            Application.Run(new MainForm(Setup.LoadActive()));
        }
    }

    public class Settings
    {
        public DateTime Deadline;
        public List<string> Keywords = new List<string>();
        public List<string> Browsers = new List<string>();
        public int Interval = 2;
    }

    public static class Setup
    {
        public static string Dir
        {
            get { return Path.GetDirectoryName(typeof(Setup).Assembly.Location); }
        }

        public static string ScriptPath
        {
            get { return Path.Combine(Dir, "setup.ps1"); }
        }

        public static string ConfigPath
        {
            get { return Path.Combine(Dir, "config.json"); }
        }

        // Running block or null
        public static Settings LoadActive()
        {
            try
            {
                if (!File.Exists(ConfigPath)) return null;
                var d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(ConfigPath, Encoding.UTF8));
                var s = new Settings();
                s.Deadline = DateTime.ParseExact((string)d["deadline"], "s", CultureInfo.InvariantCulture);
                s.Keywords = ToList(d["keywords"]);
                s.Browsers = ToList(d["browsers"]);
                s.Interval = Convert.ToInt32(d["interval"]);
                return s.Deadline > DateTime.Now ? s : null;
            }
            catch { return null; }
        }

        static List<string> ToList(object o)
        {
            if (o is string) return new List<string> { (string)o };
            return ((IEnumerable)o).Cast<object>().Select(x => x.ToString()).ToList();
        }

        // Runs setup.ps1, returns error or null
        public static string Run(Settings s)
        {
            string args = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(ScriptPath) +
                " -Deadline " + Quote(s.Deadline.ToString("s", CultureInfo.InvariantCulture)) +
                " -Keywords " + Quote(string.Join(",", s.Keywords)) +
                " -Browsers " + Quote(string.Join(",", s.Browsers)) +
                " -Interval " + s.Interval;
            var enc = Encoding.GetEncoding(CultureInfo.CurrentCulture.TextInfo.OEMCodePage);
            var psi = new ProcessStartInfo("powershell.exe", args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = enc;
            psi.StandardErrorEncoding = enc;
            psi.WorkingDirectory = Dir;
            using (var p = Process.Start(psi))
            {
                var stdout = p.StandardOutput.ReadToEndAsync();
                string stderr = p.StandardError.ReadToEnd();
                p.WaitForExit();
                if (p.ExitCode == 0) return null;
                string text = (stderr + "\n" + stdout.Result).Trim();
                return text.Length > 0 ? text : "setup.ps1 exit code " + p.ExitCode;
            }
        }

        static string Quote(string s)
        {
            s = s.Replace("\"", "");
            if (s.EndsWith("\\")) s += "\\";
            return "\"" + s + "\"";
        }
    }

    public class MainForm : Form
    {
        static readonly string[][] KnownBrowsers = {
            new[] { "Google Chrome", "chrome" },
            new[] { "Microsoft Edge", "msedge" },
            new[] { "Mozilla Firefox", "firefox" },
            new[] { "Opera / Opera GX", "opera" },
            new[] { "Яндекс Браузер", "browser" },
            new[] { "Brave", "brave" },
            new[] { "Vivaldi", "vivaldi" },
        };

        readonly Settings active;
        readonly List<CheckBox> browserBoxes = new List<CheckBox>();
        RadioButton rbDuration, rbDate;
        NumericUpDown nudHours, nudMinutes, nudInterval;
        DateTimePicker dtpDeadline;
        TextBox txtKeywords, txtOther;
        Label lblStatus;
        Button btnStart;
        bool busy;

        public MainForm(Settings active)
        {
            this.active = active;
            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Segoe UI", 9F);
            Text = "ZapretLocker";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(440, 454);
            try { Icon = Icon.ExtractAssociatedIcon(typeof(MainForm).Assembly.Location); } catch { }

            var grp = new GroupBox { Text = "Срок блокировки", Location = new Point(12, 8), Size = new Size(416, 88) };
            rbDuration = new RadioButton { Text = "На время:", Location = new Point(14, 24), AutoSize = true, Checked = true };
            nudHours = new NumericUpDown { Location = new Point(120, 22), Width = 60, Maximum = 8760, Value = 2 };
            var lh = new Label { Text = "ч", Location = new Point(184, 25), AutoSize = true };
            nudMinutes = new NumericUpDown { Location = new Point(206, 22), Width = 60, Maximum = 59 };
            var lm = new Label { Text = "мин", Location = new Point(270, 25), AutoSize = true };
            rbDate = new RadioButton { Text = "До даты:", Location = new Point(14, 56), AutoSize = true };
            dtpDeadline = new DateTimePicker
            {
                Location = new Point(120, 54), Width = 180,
                Format = DateTimePickerFormat.Custom, CustomFormat = "dd.MM.yyyy   HH:mm",
                Value = DateTime.Now.AddHours(2)
            };
            grp.Controls.AddRange(new Control[] { rbDuration, nudHours, lh, nudMinutes, lm, rbDate, dtpDeadline });

            var lk = new Label { Text = "Слова в заголовке вкладки (через запятую):", Location = new Point(12, 106), AutoSize = true };
            txtKeywords = new TextBox { Location = new Point(12, 126), Width = 416, Text = "YouTube, Twitch" };

            var lb = new Label { Text = "Браузеры:", Location = new Point(12, 160), AutoSize = true };
            for (int i = 0; i < KnownBrowsers.Length; i++)
            {
                browserBoxes.Add(new CheckBox
                {
                    Text = KnownBrowsers[i][0], Tag = KnownBrowsers[i][1], Checked = true, AutoSize = true,
                    Location = new Point(16 + (i % 2) * 208, 182 + (i / 2) * 24)
                });
            }

            var lo = new Label { Text = "Другие процессы (через запятую, без .exe):", Location = new Point(12, 284), AutoSize = true };
            txtOther = new TextBox { Location = new Point(12, 304), Width = 416 };

            var li = new Label { Text = "Проверять каждые", Location = new Point(12, 341), AutoSize = true };
            nudInterval = new NumericUpDown { Location = new Point(130, 338), Width = 50, Minimum = 1, Maximum = 60, Value = 2 };
            var ls = new Label { Text = "сек.", Location = new Point(186, 341), AutoSize = true };

            lblStatus = new Label { Location = new Point(12, 372), Size = new Size(416, 34) };
            btnStart = new Button { Text = "Старт", Location = new Point(12, 410), Size = new Size(416, 32) };
            btnStart.Click += OnStart;

            Controls.Add(grp);
            Controls.AddRange(new Control[] { lk, txtKeywords, lb, lo, txtOther, li, nudInterval, ls, lblStatus, btnStart });
            Controls.AddRange(browserBoxes.ToArray());
            ResumeLayout(false);
            PerformLayout();

            if (active != null) LoadActive();
            nudHours.ValueChanged += delegate { rbDuration.Checked = true; };
            nudMinutes.ValueChanged += delegate { rbDuration.Checked = true; };
            dtpDeadline.ValueChanged += delegate { rbDate.Checked = true; };
            UpdateStatus();
            if (active != null)
            {
                var timer = new Timer { Interval = 1000 };
                timer.Tick += delegate { if (!busy) UpdateStatus(); };
                timer.Start();
            }
        }

        void LoadActive()
        {
            rbDate.Checked = true;
            dtpDeadline.Value = active.Deadline;
            txtKeywords.Text = string.Join(", ", active.Keywords);
            foreach (var cb in browserBoxes)
                cb.Checked = active.Browsers.Contains((string)cb.Tag, StringComparer.OrdinalIgnoreCase);
            var known = KnownBrowsers.Select(b => b[1]).ToList();
            txtOther.Text = string.Join(", ", active.Browsers.Where(b => !known.Contains(b, StringComparer.OrdinalIgnoreCase)));
            nudInterval.Value = Math.Min(nudInterval.Maximum, Math.Max(nudInterval.Minimum, active.Interval));
            btnStart.Text = "Применить";
        }

        const string IdleText = "После старта окно закроется, а отменить блокировку из приложения будет нельзя.";

        static string ActiveText(DateTime deadline, string left)
        {
            return string.Format("Блокировка активна до {0:dd.MM.yyyy HH:mm} (осталось {1}).\nМожно только продлить срок или добавить слова и браузеры.",
                deadline, left);
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            FitStatus();
        }

        // Grow label to longest text
        void FitStatus()
        {
            float k = btnStart.Width / 416f;
            lblStatus.Width = btnStart.Width;   // label gets double-scaled
            string keep = lblStatus.Text;
            int h = 0;
            foreach (string t in new[] { IdleText, ActiveText(DateTime.Now, "99 д 23 ч 59 мин") })
            {
                lblStatus.Text = t;
                h = Math.Max(h, lblStatus.GetPreferredSize(new Size(lblStatus.Width, 0)).Height);
            }
            lblStatus.Text = keep;
            lblStatus.Height = h;
            btnStart.Top = lblStatus.Bottom + (int)(6 * k);
            ClientSize = new Size(ClientSize.Width, btnStart.Bottom + (int)(12 * k));
        }

        void UpdateStatus()
        {
            if (active == null)
            {
                lblStatus.ForeColor = Color.DimGray;
                lblStatus.Text = IdleText;
                return;
            }
            TimeSpan t = active.Deadline - DateTime.Now;
            lblStatus.ForeColor = Color.FromArgb(170, 30, 30);
            lblStatus.Text = t <= TimeSpan.Zero ? "Срок блокировки истёк." : ActiveText(active.Deadline, Remaining(t));
        }

        async void OnStart(object sender, EventArgs e)
        {
            DateTime now = DateTime.Now;
            DateTime deadline;
            if (rbDuration.Checked)
            {
                TimeSpan span = TimeSpan.FromHours((double)nudHours.Value) + TimeSpan.FromMinutes((double)nudMinutes.Value);
                if (span.TotalMinutes < 1) { Warn("Укажите срок хотя бы в 1 минуту."); return; }
                DateTime d = now + span;
                deadline = new DateTime(d.Year, d.Month, d.Day, d.Hour, d.Minute, d.Second);
            }
            else
            {
                DateTime v = dtpDeadline.Value;
                deadline = new DateTime(v.Year, v.Month, v.Day, v.Hour, v.Minute, 0);
                bool sameAsActive = active != null && Minute(deadline) == Minute(active.Deadline);
                if (!sameAsActive && deadline <= now.AddMinutes(1)) { Warn("Дата окончания должна быть в будущем (хотя бы через минуту)."); return; }
            }

            var c = new Settings();
            c.Deadline = deadline;
            c.Keywords = SplitList(txtKeywords.Text);
            c.Browsers = browserBoxes.Where(b => b.Checked).Select(b => (string)b.Tag)
                .Concat(SplitList(txtOther.Text).Select(StripExe))
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            c.Interval = (int)nudInterval.Value;
            if (c.Keywords.Count == 0) { Warn("Введите хотя бы одно слово для поиска вкладок."); return; }
            if (c.Browsers.Count == 0) { Warn("Выберите хотя бы один браузер."); return; }

            bool extending = active != null && active.Deadline > now;
            if (extending)
            {
                string why = Weaker(c);
                if (why != null) { Warn("Пока блокировка активна, условия можно только ужесточить:\n" + why); return; }
                if (c.Deadline < active.Deadline) c.Deadline = active.Deadline;
            }

            string msg = string.Format(
                "Блокировка до {0:dd.MM.yyyy HH:mm} (осталось {1}).\n\nСлова: {2}\nПроцессы: {3}\nПроверка каждые {4} сек.\n\nОтменить из приложения будет нельзя. {5}",
                c.Deadline, Remaining(c.Deadline - now), string.Join(", ", c.Keywords), string.Join(", ", c.Browsers), c.Interval,
                extending ? "Применить?" : "Начать?");
            if (MessageBox.Show(this, msg, Text, MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.Yes)
                return;

            busy = true;
            btnStart.Enabled = false;
            UseWaitCursor = true;
            lblStatus.ForeColor = Color.DimGray;
            lblStatus.Text = "Запуск...";
            string error;
            try { error = await Task.Run(() => Setup.Run(c)); }
            catch (Exception ex) { error = ex.Message; }
            if (error == null) { Close(); return; }

            busy = false;
            btnStart.Enabled = true;
            UseWaitCursor = false;
            UpdateStatus();
            MessageBox.Show(this, "Не удалось запустить блокировку:\n" + error, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        string Weaker(Settings c)
        {
            var lines = new List<string>();
            if (Minute(c.Deadline) < Minute(active.Deadline))
                lines.Add("срок не раньше " + active.Deadline.ToString("dd.MM.yyyy HH:mm"));
            var lostK = active.Keywords.Where(k => !c.Keywords.Contains(k, StringComparer.OrdinalIgnoreCase)).ToList();
            if (lostK.Count > 0) lines.Add("нельзя убрать слова: " + string.Join(", ", lostK));
            var lostB = active.Browsers.Where(b => !c.Browsers.Contains(b, StringComparer.OrdinalIgnoreCase)).ToList();
            if (lostB.Count > 0) lines.Add("нельзя убрать процессы: " + string.Join(", ", lostB));
            if (c.Interval > active.Interval) lines.Add("интервал не больше " + active.Interval + " сек.");
            return lines.Count == 0 ? null : "- " + string.Join("\n- ", lines);
        }

        static List<string> SplitList(string s)
        {
            return s.Replace("\"", "").Split(',').Select(x => x.Trim()).Where(x => x.Length > 0)
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        }

        static DateTime Minute(DateTime d)
        {
            return new DateTime(d.Year, d.Month, d.Day, d.Hour, d.Minute, 0);
        }

        static string StripExe(string s)
        {
            return s.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ? s.Substring(0, s.Length - 4) : s;
        }

        static string Remaining(TimeSpan t)
        {
            if (t.TotalMinutes < 1) return "меньше минуты";
            var parts = new List<string>();
            if (t.Days > 0) parts.Add(t.Days + " д");
            if (t.Hours > 0) parts.Add(t.Hours + " ч");
            if (t.Minutes > 0) parts.Add(t.Minutes + " мин");
            return string.Join(" ", parts);
        }

        void Warn(string text)
        {
            MessageBox.Show(this, text, Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
