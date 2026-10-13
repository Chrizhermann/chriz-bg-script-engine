// Task 3 exclusive native creation primitive, NOT a copy/provisioning command.
// Caller must separately admit source, protected roots, processes and capacity.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using static Bgse.Lab.SourceMeasurement;

namespace Bgse.Lab
{
    public sealed class FreshTree : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct FileParameters
        {
            public uint Size, Attributes, Flags, SecurityQos;
            public IntPtr Security, Template;
        }

        // Five parameters, as confirmed in the pinned SDK header. Do not use
        // the inconsistent six-argument example from the documentation page.
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern SafeFileHandle CreateDirectory2W(string path, uint access,
            uint share, uint flags, IntPtr security);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern SafeFileHandle CreateFile3(string path, uint access,
            uint share, uint disposition, ref FileParameters parameters);

        private readonly string destination;
        private readonly List<Entry> ancestors;
        private readonly string[] plannedDirectories;
        private readonly List<Entry> created = new List<Entry>();
        private readonly Dictionary<string, Entry> directories = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
        private readonly HashSet<string> names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private bool attempted, ready, disposed, failed;

        public FreshTree(string destinationInput)
        {
            RequireNativeSupport();
            destination = LocalPath(destinationInput);
            FixedNtfs(Path.GetPathRoot(destination));
            ancestors = Ancestors(destination, true);
            string current = ancestors.Last().Path;
            string suffix = destination.Substring(current.TrimEnd('\\').Length).TrimStart('\\');
            var planned = new List<string>();
            foreach (string part in suffix.Split('\\'))
            {
                current = Path.Combine(current, part);
                planned.Add(current);
            }
            plannedDirectories = planned.ToArray();
        }

        // Includes missing intermediate directories, not just the final root.
        // A defensive copy prevents a caller from changing the creation plan.
        public string[] PlannedDirectories { get { return (string[])plannedDirectories.Clone(); } }

        private static void RequireExports(bool directory, bool file)
        {
            if (!directory || !file) throw new MeasurementRefusal("BGSE_E_UNSUPPORTED_HOST");
        }

        public static void RequireNativeSupport()
        {
            // Export detection does not create a probe path. No weaker fallback.
            if (!OperatingSystem.IsWindows() || !Environment.Is64BitProcess)
                throw new MeasurementRefusal("BGSE_E_UNSUPPORTED_HOST");
            IntPtr module;
            if (!NativeLibrary.TryLoad("kernel32.dll", out module))
                throw new MeasurementRefusal("BGSE_E_UNSUPPORTED_HOST");
            try
            {
                IntPtr address;
                RequireExports(NativeLibrary.TryGetExport(module, "CreateDirectory2W", out address),
                    NativeLibrary.TryGetExport(module, "CreateFile3", out address));
            }
            finally { NativeLibrary.Free(module); }
        }

        private void RequireState(bool root)
        {
            if (disposed || failed || (root ? attempted : !ready))
                throw new MeasurementRefusal("BGSE_E_CREATION_STATE");
        }

        private static Entry CreatedHandle(string path, SafeFileHandle handle, bool directory)
        {
            // SafeFileHandle rejects both NULL and INVALID_HANDLE_VALUE; retain
            // neither ambiguous documentation spelling as a success assumption.
            if (handle.IsInvalid)
            {
                int error = Marshal.GetLastWin32Error();
                handle.Dispose();
                throw new MeasurementRefusal(error == 80 || error == 183 ?
                    "BGSE_E_DESTINATION_EXISTS" : "BGSE_E_PATH_ACCESS");
            }
            Entry entry = ValidateHandle(path, handle);
            try
            {
                if (entry.IsDirectory != directory) throw new MeasurementRefusal("BGSE_E_ENTRY_TYPE");
                CheckStreams(entry);
                return entry;
            }
            catch { entry.Dispose(); throw; }
        }

        private static Entry NewDirectory(string path)
        {
            // FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE, with
            // read-only sharing. READ_ATTRIBUTES is required for native identity
            // validation through this returned handle. On the
            // measured host omitting SYNCHRONIZE or including SHARE_WRITE fails
            // with ERROR_INVALID_PARAMETER; do not weaken the creation flags.
            // DISALLOW_PATH_REDIRECTS applies to every path component at creation.
            return CreatedHandle(path, CreateDirectory2W(@"\\?\" + path, 0x100081, 1, 1, IntPtr.Zero), true);
        }

        public void CreateRoot()
        {
            RequireState(true);
            attempted = true;
            try
            {
                VerifyDestination(destination, ancestors);
                foreach (string path in plannedDirectories)
                {
                    Entry entry = NewDirectory(path);
                    created.Add(entry);
                }
                directories.Add(".", created.Last());
                ready = true;
            }
            catch { failed = true; throw; }
        }

        private string Child(string relative)
        {
            if (String.IsNullOrEmpty(relative) || relative.StartsWith('/') || relative.Contains('\\'))
                throw new MeasurementRefusal("BGSE_E_PATH_SYNTAX");
            string path = LocalPath(destination + "\\" + relative.Replace('/', '\\'));
            int separator = relative.LastIndexOf('/');
            string parent = separator < 0 ? "." : relative.Substring(0, separator);
            Entry owned;
            if (!directories.TryGetValue(parent, out owned))
                throw new MeasurementRefusal("BGSE_E_CREATION_STATE");
            // Check retained identity, then compare a validated no-follow reopen.
            // Creation itself also refuses redirects, including one introduced
            // between this observation and the native create operation.
            if (ReadIdentity(owned.Handle) != owned.Id)
                throw new MeasurementRefusal("BGSE_E_DESTINATION_CHANGED");
            using (Entry current = Open(owned.Path, false))
            {
                if (current.Id != owned.Id) throw new MeasurementRefusal("BGSE_E_DESTINATION_CHANGED");
                CheckStreams(current);
            }
            if (!names.Add(relative)) throw new MeasurementRefusal("BGSE_E_DESTINATION_EXISTS");
            return path;
        }

        public void CreateDirectory(string relative)
        {
            RequireState(false);
            try
            {
                Entry entry = NewDirectory(Child(relative));
                created.Add(entry);
                directories.Add(relative, entry);
            }
            catch { failed = true; throw; }
        }

        // The caller owns this returned SAME validated native handle; normally
        // FileStream closes it after write/flush/readback verification. Holding
        // every file handle for a large corpus would be unbounded. This primitive
        // does not claim the closed file remains unchanged; final inventory is
        // the future acquisition command's responsibility.
        public SafeFileHandle CreateFile(string relative)
        {
            RequireState(false);
            try
            {
                return NewFile(Child(relative)).Handle;
            }
            catch { failed = true; throw; }
        }

        private static Entry NewFile(string path)
        {
            var parameters = new FileParameters { Size = (uint)Marshal.SizeOf<FileParameters>(),
                Attributes = 0x80, Flags = 0x10000 | 0x00200000 };
            return CreatedHandle(path, CreateFile3(@"\\?\" + path, 0xC0000000,
                1, 1, ref parameters), false);
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            for (int i = created.Count - 1; i >= 0; i--) created[i].Dispose();
            for (int i = ancestors.Count - 1; i >= 0; i--) ancestors[i].Dispose();
            // Never delete a failed/partial tree or adopt it on a later run.
        }
    }
}
