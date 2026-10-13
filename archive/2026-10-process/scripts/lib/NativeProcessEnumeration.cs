// Task 3 A4c: a bounded numeric OS response, not atomic process state,
// identity/command coverage, ownership, quiet-window proof or copy admission.
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Bgse.Lab
{
    public sealed class ProcessIdEnumeration
    {
        private readonly uint[] pids;
        public string ObserverVersion { get { return "BGSE-PROCESS-ENUMERATION-1"; } }
        public uint[] Pids { get { return (uint[])pids.Clone(); } }
        public DateTime StartedUtc { get; }
        public DateTime FinishedUtc { get; }
        public double ElapsedMilliseconds { get; }
        internal ProcessIdEnumeration(uint[] values, DateTime started, DateTime finished, double elapsed)
        {
            pids = (uint[])values.Clone();
            StartedUtc = started; FinishedUtc = finished; ElapsedMilliseconds = elapsed;
        }
    }

    // Only same-assembly test fakes may inject a backend. The public entry point
    // always uses the native implementation after its platform guard.
    internal interface IProcessEnumerationApi
    {
        uint Read(uint[] buffer, uint capacityBytes);
    }

    public static class NativeProcessEnumeration
    {
        private const int MaximumEntries = 16384;
        private const int BufferEntries = MaximumEntries + 1;
        private const uint BufferBytes = BufferEntries * sizeof(uint);

        private static void Refuse(string suffix)
        { throw new MeasurementRefusal("BGSE_E_PROCESS_ENUMERATION_" + suffix); }
        private static MeasurementRefusal QueryFailure(int? error = null)
        { return new MeasurementRefusal("BGSE_E_PROCESS_ENUMERATION_QUERY", "enumerate", "query-error", error); }

        public static ProcessIdEnumeration Observe()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ||
                RuntimeInformation.ProcessArchitecture != Architecture.X64 || IntPtr.Size != 8)
                Refuse("PLATFORM");
            return ObserveWith(new WindowsApi());
        }

        internal static ProcessIdEnumeration ObserveWith(IProcessEnumerationApi api)
        {
            if (api == null) Refuse("INPUT");
            DateTime started = DateTime.UtcNow;
            var duration = Stopwatch.StartNew();
            try
            {
                var buffer = new uint[BufferEntries];
                uint bytesWritten = api.Read(buffer, BufferBytes);
                // Validate byte count before allocating/copying/indexing the prefix.
                if (bytesWritten == 0 || bytesWritten > BufferBytes || bytesWritten % sizeof(uint) != 0)
                    Refuse("DATA");
                // A full buffer can be truncated even when the native call succeeds.
                if (bytesWritten == BufferBytes) Refuse("LIMIT");
                int count = (int)(bytesWritten / sizeof(uint));
                var values = new uint[count];
                Array.Copy(buffer, values, count);
                Array.Sort(values);
                for (int i = 1; i < values.Length; i++)
                    if (values[i - 1] == values[i]) Refuse("DATA");
                duration.Stop();
                return new ProcessIdEnumeration(values, started, DateTime.UtcNow, duration.Elapsed.TotalMilliseconds);
            }
            catch (MeasurementRefusal) { throw; }
            catch (Exception) { throw QueryFailure(); } // No private text or inner exception.
        }

        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool K32EnumProcesses([Out] uint[] pids, uint capacityBytes, out uint bytesWritten);

        private sealed class WindowsApi : IProcessEnumerationApi
        {
            public uint Read(uint[] buffer, uint capacityBytes)
            {
                uint bytesWritten;
                if (!K32EnumProcesses(buffer, capacityBytes, out bytesWritten))
                {
                    int error = Marshal.GetLastWin32Error();
                    throw QueryFailure(error);
                }
                return bytesWritten;
            }
        }
    }
}
