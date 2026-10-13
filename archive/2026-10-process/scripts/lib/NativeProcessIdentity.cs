// Task 3 A4b: one explicitly selected process object, not enumeration,
// command-line provenance, executable-file identity or activity clearance.
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Bgse.Lab
{
    public sealed class ProcessIdentityObservation
    {
        public string ObserverVersion { get { return "BGSE-PROCESS-IDENTITY-1"; } }
        public uint Pid { get; }
        public ulong CreationFileTime { get; }
        public string ImagePath { get; }
        public DateTime StartedUtc { get; }
        public DateTime FinishedUtc { get; }
        public double ElapsedMilliseconds { get; }
        internal ProcessIdentityObservation(uint pid, ulong creation, string image, DateTime started,
            DateTime finished, double elapsed)
        {
            Pid = pid; CreationFileTime = creation; ImagePath = image;
            StartedUtc = started; FinishedUtc = finished; ElapsedMilliseconds = elapsed;
        }
    }

    // Test-only implementations compile in the same assembly. Public Observe
    // never accepts a caller-supplied backend or a caller-owned handle.
    internal interface IProcessIdentityApi
    {
        IProcessIdentitySession Open(uint pid, uint access, bool inherit);
    }
    internal interface IProcessIdentitySession : IDisposable
    {
        uint GetPid();
        ulong GetCreationFileTime();
        uint ReadImage(char[] buffer);
        uint Poll();
    }

    public static class NativeProcessIdentity
    {
        private const uint QueryAndSynchronize = 0x00101000;
        private const int ImageCapacity = 32767;

        private static void Refuse(string suffix)
        { throw new MeasurementRefusal("BGSE_E_PROCESS_IDENTITY_" + suffix); }
        private static MeasurementRefusal QueryFailure(string operation, int? error = null)
        { return new MeasurementRefusal("BGSE_E_PROCESS_IDENTITY_QUERY", operation, "query-error", error); }

        private static void ValidateInput(uint pid, ulong? expected)
        { if (pid == 0 || expected == 0) Refuse("INPUT"); }

        private static void Running(IProcessIdentitySession session)
        {
            uint result = session.Poll();
            if (result == 0x102) return; // WAIT_TIMEOUT from a zero-duration wait.
            if (result == 0) Refuse("EXITED");
            if (result == UInt32.MaxValue) throw QueryFailure("wait");
            Refuse("DATA");
        }

        private static ulong Identity(IProcessIdentitySession session, uint requested)
        {
            uint actual = session.GetPid();
            if (actual == 0) Refuse("DATA");
            if (actual != requested) Refuse("CHANGED");
            ulong creation = session.GetCreationFileTime();
            if (creation == 0) Refuse("DATA");
            return creation;
        }

        private static string Image(IProcessIdentitySession session)
        {
            var buffer = new char[ImageCapacity];
            Array.Fill(buffer, '\uffff');
            uint length = session.ReadImage(buffer);
            if (length == 0 || length >= buffer.Length || buffer[length] != '\0') Refuse("DATA");
            for (int i = 0; i < length; i++)
            {
                char value = buffer[i];
                if (value == '\0') Refuse("DATA");
                if (Char.IsHighSurrogate(value))
                {
                    if (++i >= length || !Char.IsLowSurrogate(buffer[i])) Refuse("DATA");
                }
                else if (Char.IsLowSurrogate(value)) Refuse("DATA");
            }
            return new string(buffer, 0, (int)length);
        }

        public static ProcessIdentityObservation Observe(uint pid, ulong? expectedCreationFileTime)
        {
            ValidateInput(pid, expectedCreationFileTime);
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ||
                RuntimeInformation.ProcessArchitecture != Architecture.X64 || IntPtr.Size != 8 ||
                Marshal.SizeOf<FileTime>() != 8 || Marshal.OffsetOf<FileTime>(nameof(FileTime.High)).ToInt32() != 4)
                Refuse("PLATFORM");
            return ObserveWith(pid, expectedCreationFileTime, new WindowsApi());
        }

        internal static ProcessIdentityObservation ObserveWith(uint pid, ulong? expectedCreationFileTime,
            IProcessIdentityApi api)
        {
            ValidateInput(pid, expectedCreationFileTime);
            if (api == null) Refuse("INPUT");
            DateTime started = DateTime.UtcNow;
            var duration = Stopwatch.StartNew();
            try
            {
                ulong creation;
                string image;
                using (IProcessIdentitySession session = api.Open(pid, QueryAndSynchronize, false))
                {
                    if (session == null) Refuse("DATA");
                    Running(session);
                    creation = Identity(session, pid);
                    if (expectedCreationFileTime.HasValue && creation != expectedCreationFileTime.Value) Refuse("CHANGED");
                    image = Image(session);
                    if (Identity(session, pid) != creation) Refuse("CHANGED");
                    if (!String.Equals(Image(session), image, StringComparison.Ordinal)) Refuse("CHANGED");
                    Running(session);
                }
                // Disposal is a prerequisite to returning any successful observation.
                duration.Stop();
                return new ProcessIdentityObservation(pid, creation, image, started, DateTime.UtcNow,
                    duration.Elapsed.TotalMilliseconds);
            }
            catch (MeasurementRefusal) { throw; }
            catch (Exception) { throw QueryFailure("observe"); } // No inner exception/private text.
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FileTime
        {
            public uint Low, High;
            public ulong Value { get { return ((ulong)High << 32) | Low; } }
        }

        private sealed class OwnedProcessHandle : SafeHandleZeroOrMinusOneIsInvalid
        {
            internal bool? CloseSucceeded { get; private set; }
            internal int CloseError { get; private set; }
            public OwnedProcessHandle() : base(true) { }
            protected override bool ReleaseHandle()
            {
                bool result = CloseHandle(handle);
                CloseError = result ? 0 : Marshal.GetLastWin32Error();
                CloseSucceeded = result;
                return result;
            }
        }

        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern OwnedProcessHandle OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint pid);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern uint GetProcessId(OwnedProcessHandle process);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessTimes(OwnedProcessHandle process, out FileTime creation,
            out FileTime exit, out FileTime kernel, out FileTime user);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool QueryFullProcessImageNameW(OwnedProcessHandle process, uint flags,
            [Out, MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.U2)] char[] image, ref uint count);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern uint WaitForSingleObject(OwnedProcessHandle process, uint milliseconds);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        private sealed class WindowsApi : IProcessIdentityApi
        {
            public IProcessIdentitySession Open(uint pid, uint access, bool inherit)
            {
                OwnedProcessHandle handle = OpenProcess(access, inherit, pid);
                if (handle == null || handle.IsInvalid)
                {
                    int error = Marshal.GetLastWin32Error();
                    handle?.Dispose();
                    throw QueryFailure("open", error);
                }
                // Transfer only after construction succeeds; unexpected construction
                // failure must not strand a successfully acquired handle.
                try { return new WindowsSession(handle); }
                catch { handle.Dispose(); throw; }
            }
        }

        private sealed class WindowsSession : IProcessIdentitySession
        {
            private readonly OwnedProcessHandle handle;
            private bool disposed;
            internal WindowsSession(OwnedProcessHandle handle) { this.handle = handle; }
            public uint GetPid()
            {
                uint pid = GetProcessId(handle);
                if (pid == 0) throw QueryFailure("pid", Marshal.GetLastWin32Error());
                return pid;
            }
            public ulong GetCreationFileTime()
            {
                FileTime creation, exit, kernel, user;
                if (!GetProcessTimes(handle, out creation, out exit, out kernel, out user))
                    throw QueryFailure("creation", Marshal.GetLastWin32Error());
                // Live exit FILETIME is undefined. Do not inspect it.
                return creation.Value;
            }
            public uint ReadImage(char[] buffer)
            {
                uint count = (uint)buffer.Length;
                if (!QueryFullProcessImageNameW(handle, 0, buffer, ref count))
                    throw QueryFailure("image", Marshal.GetLastWin32Error());
                return count;
            }
            public uint Poll()
            {
                uint result = WaitForSingleObject(handle, 0);
                if (result == UInt32.MaxValue) throw QueryFailure("wait", Marshal.GetLastWin32Error());
                return result;
            }
            public void Dispose()
            {
                if (disposed) return;
                disposed = true;
                handle.Dispose();
                if (handle.CloseSucceeded != true) throw QueryFailure("close", handle.CloseError);
            }
        }
    }
}
