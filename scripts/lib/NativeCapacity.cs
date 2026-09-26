// Task 3 packet A3: read-only, point-in-time filesystem-volume observations.
// Private paths/identities/SID; not a reservation, copy permission or public log.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;
using static Bgse.Lab.SourceMeasurement;

namespace Bgse.Lab
{
    public sealed class CapacityTarget
    {
        public string Purpose { get; }
        public string DestinationRoot { get; }
        public ulong? SafetyReserveBytes { get; }
        public CapacityTarget(string purpose, string destinationRoot, ulong? safetyReserveBytes)
        { Purpose = purpose; DestinationRoot = destinationRoot; SafetyReserveBytes = safetyReserveBytes; }
    }

    public sealed class CapacityBinding
    {
        public string Purpose { get; }
        public string DestinationRoot { get; }
        public string VolumeId { get; }
        public string ExistingAncestor { get; }
        public string AncestorIdentity { get; }
        public string RootIdentity { get; }
        internal CapacityBinding(string purpose, string destination, string volume, string ancestor,
            string ancestorId, string rootId)
        {
            Purpose = purpose; DestinationRoot = destination; VolumeId = volume;
            ExistingAncestor = ancestor; AncestorIdentity = ancestorId; RootIdentity = rootId;
        }
    }

    public sealed class CapacityObservation
    {
        private readonly CapacityBinding[] bindings;
        private readonly CapacityVolume[] volumes;
        public string CallerSid { get; }
        public CapacityBinding[] Bindings { get { return (CapacityBinding[])bindings.Clone(); } }
        public CapacityVolume[] Volumes { get { return (CapacityVolume[])volumes.Clone(); } }
        internal CapacityObservation(string sid, CapacityBinding[] bindings, CapacityVolume[] volumes)
        {
            CallerSid = sid; this.bindings = (CapacityBinding[])bindings.Clone();
            this.volumes = (CapacityVolume[])volumes.Clone();
        }
    }

    public static class NativeCapacity
    {
        private sealed class Held
        {
            internal CapacityTarget Target;
            internal List<Entry> Entries;
            internal string NativeRoot, Key;
        }

        // x64 ABI only. The upper half of the status/pointer union is NOT NTSTATUS.
        [StructLayout(LayoutKind.Explicit, Size = 16)]
        private struct IoStatus
        {
            [FieldOffset(0)] public int Status;
            [FieldOffset(8)] public ulong Information;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct FullSize
        {
            public long Total, Caller, Actual;
            public uint Sectors, Bytes;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct Device
        {
            public uint Type, Characteristics;
        }
        [DllImport("ntdll.dll", EntryPoint = "NtQueryVolumeInformationFile", ExactSpelling = true)]
        private static extern int QuerySize(SafeFileHandle handle, out IoStatus status,
            out FullSize size, uint length, int kind);
        [DllImport("ntdll.dll", EntryPoint = "NtQueryVolumeInformationFile", ExactSpelling = true)]
        private static extern int QueryDevice(SafeFileHandle handle, out IoStatus status,
            out Device device, uint length, int kind);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern bool GetVolumeInformationByHandleW(SafeFileHandle handle,
            StringBuilder label, uint labelSize, out uint serial, out uint maxComponent,
            out uint flags, StringBuilder filesystem, uint filesystemSize);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle,
            StringBuilder buffer, uint size, uint flags);

        private static void Refuse(string suffix) { throw new MeasurementRefusal("BGSE_E_CAPACITY_" + suffix); }

        private static void CheckPlatformAndLayout()
        {
            if (!OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.X64 ||
                IntPtr.Size != 8 || Marshal.SizeOf<IoStatus>() != 16 ||
                Marshal.OffsetOf<IoStatus>("Status").ToInt32() != 0 ||
                Marshal.OffsetOf<IoStatus>("Information").ToInt32() != 8 ||
                Marshal.SizeOf<FullSize>() != 32 ||
                Marshal.OffsetOf<FullSize>("Total").ToInt32() != 0 ||
                Marshal.OffsetOf<FullSize>("Caller").ToInt32() != 8 ||
                Marshal.OffsetOf<FullSize>("Actual").ToInt32() != 16 ||
                Marshal.OffsetOf<FullSize>("Sectors").ToInt32() != 24 ||
                Marshal.OffsetOf<FullSize>("Bytes").ToInt32() != 28 ||
                Marshal.SizeOf<Device>() != 8 || Marshal.OffsetOf<Device>("Characteristics").ToInt32() != 4)
                Refuse("PLATFORM");
        }

        private static string Caller()
        {
            // No callbacks/awaits/impersonation in the query path. SID is a quota-context
            // binding, not proof of privileges, permission to write or unchanged quotas.
            using (WindowsIdentity thread = WindowsIdentity.GetCurrent(true))
                if (thread != null) Refuse("CONTEXT");
            using (WindowsIdentity process = WindowsIdentity.GetCurrent(false))
            {
                if (process == null || process.User == null) Refuse("CONTEXT");
                return process.User.Value;
            }
        }

        private static CapacityTarget[] Inputs(CapacityTarget[] input)
        {
            if (input == null || input.Length != 3) Refuse("INPUT");
            var snapshot = (CapacityTarget[])input.Clone();
            var purposes = new HashSet<string>(StringComparer.Ordinal);
            for (int i = 0; i < snapshot.Length; i++)
            {
                CapacityTarget item = snapshot[i];
                if (item == null || !item.SafetyReserveBytes.HasValue ||
                    (item.Purpose != "working-copy" && item.Purpose != "future-baseline" && item.Purpose != "evidence") ||
                    !purposes.Add(item.Purpose)) Refuse("INPUT");
                string text = item.DestinationRoot;
                if (String.IsNullOrEmpty(text) || text.Length >= 32767) Refuse("INPUT");
                try { new UTF8Encoding(false, true).GetByteCount(text); }
                catch (EncoderFallbackException) { Refuse("INPUT"); }
                string path = LocalPath(text);
                foreach (string part in path.Substring(3).Split('\\'))
                    if (part.Length > 255 || part.Equals(".bgse-disposable-lab.json", StringComparison.OrdinalIgnoreCase))
                        Refuse("INPUT");
                snapshot[i] = new CapacityTarget(item.Purpose, path, item.SafetyReserveBytes);
                for (int j = 0; j < i; j++)
                {
                    string other = snapshot[j].DestinationRoot;
                    if (path.Equals(other, StringComparison.OrdinalIgnoreCase) ||
                        path.StartsWith(other + "\\", StringComparison.OrdinalIgnoreCase) ||
                        other.StartsWith(path + "\\", StringComparison.OrdinalIgnoreCase))
                        throw new MeasurementRefusal("BGSE_E_OVERLAP");
                }
            }
            return snapshot.OrderBy(item => item.Purpose, StringComparer.Ordinal).ToArray();
        }

        private static string VolumeKey(string root)
        {
            if (root == null) Refuse("IDENTITY");
            Match match = Regex.Match(root, @"\A\\Device\\HarddiskVolume([1-9][0-9]{0,9})\\\z",
                RegexOptions.CultureInvariant);
            if (!match.Success) Refuse("IDENTITY");
            return "NTVOLUME_" + match.Groups[1].Value;
        }

        private static void VerifyPhysicalDestinations(string[] keys, string[] paths)
        {
            // Inputs already canonical; the held root's native key binds the suffix.
            // Distinct DOS drive letters do not establish distinct physical outputs.
            for (int i = 0; i < paths.Length; i++)
                for (int j = 0; j < i; j++)
                {
                    if (keys[i] != keys[j]) continue;
                    string left = paths[i].Substring(3), right = paths[j].Substring(3);
                    if (left.Equals(right, StringComparison.OrdinalIgnoreCase) ||
                        left.StartsWith(right + "\\", StringComparison.OrdinalIgnoreCase) ||
                        right.StartsWith(left + "\\", StringComparison.OrdinalIgnoreCase))
                        throw new MeasurementRefusal("BGSE_E_OVERLAP");
                }
        }

        private static string NativePath(SafeFileHandle handle)
        {
            var buffer = new StringBuilder(32768);
            uint count = GetFinalPathNameByHandleW(handle, buffer, 32768, 2);
            return ValidateNativePathResult(count, buffer.ToString());
        }

        private static string ValidateNativePathResult(uint count, string value)
        {
            if (count == 0 || count >= 32768 || value == null || count != value.Length) Refuse("IDENTITY");
            return value;
        }

        private static void Verify(Held held)
        {
            VerifyDestination(held.Target.DestinationRoot, held.Entries);
            foreach (Entry entry in held.Entries)
            {
                if (ReadIdentity(entry.Handle) != entry.Id ||
                    !NativePath(entry.Handle).Equals(held.NativeRoot + entry.Path.Substring(3),
                        StringComparison.OrdinalIgnoreCase)) Refuse("IDENTITY");
            }
        }

        private static void Completion(int status, int completion, ulong returned, uint expected)
        {
            // Only privately opened SYNCHRONOUS handles reach the native calls. No
            // asynchronous/PENDING support is implemented; see the research contract.
            // The direct NTSTATUS is authoritative; IOSB equality is a stricter guard.
            if (status != 0 || completion != 0 || returned != expected) Refuse("NATIVE");
        }

        private static ulong[] ValidateCapacity(int status, int completion, ulong returned,
            long total, long caller, long actual, uint sectors, uint bytes)
        {
            Completion(status, completion, returned, 32);
            if (total < 0 || caller < 0 || actual < 0 || caller > total || caller > actual ||
                sectors == 0 || bytes == 0) Refuse("NATIVE");
            try
            {
                checked
                {
                    ulong unit = (ulong)sectors * bytes;
                    // Check representability even for fields not published downstream.
                    _ = (ulong)total * unit;
                    _ = (ulong)actual * unit;
                    return new [] { unit, (ulong)caller * unit };
                }
            }
            catch (OverflowException) { Refuse("OVERFLOW"); return null; }
        }

        private static void ValidateDevice(uint type, uint characteristics, string fs, uint flags)
        {
            if (type != 7 || (characteristics & (1u | 2u | 16u)) != 0 || fs != "NTFS" ||
                (flags & 0x80000u) != 0) Refuse("VOLUME");
        }

        private static ulong[] Sample(Entry ancestor)
        {
            // No path-based free-space, drive-type or filesystem fallback. The same
            // retained, synchronous SourceMeasurement.Open handle owns all three queries.
            IoStatus io;
            Device device;
            int status = QueryDevice(ancestor.Handle, out io, out device, 8, 4);
            Completion(status, io.Status, io.Information, 8);
            var fs = new StringBuilder(261);
            uint serial, maxComponent, flags;
            if (!GetVolumeInformationByHandleW(ancestor.Handle, null, 0, out serial,
                out maxComponent, out flags, fs, 261)) Refuse("NATIVE");
            ValidateDevice(device.Type, device.Characteristics, fs.ToString(), flags);
            FullSize size;
            status = QuerySize(ancestor.Handle, out io, out size, 32, 7);
            return ValidateCapacity(status, io.Status, io.Information,
                size.Total, size.Caller, size.Actual, size.Sectors, size.Bytes);
        }

        private static CapacityVolume[] Group(CapacityBinding[] bindings, CapacityVolume[] samples)
        {
            var volumes = new Dictionary<string, CapacityVolume>(StringComparer.Ordinal);
            var roots = new Dictionary<string, string>(StringComparer.Ordinal);
            var keys = new Dictionary<string, string>(StringComparer.Ordinal);
            for (int i = 0; i < bindings.Length; i++)
            {
                CapacityBinding binding = bindings[i];
                CapacityVolume sample = samples[i];
                string root, key;
                if ((roots.TryGetValue(binding.VolumeId, out root) && root != binding.RootIdentity) ||
                    (keys.TryGetValue(binding.RootIdentity, out key) && key != binding.VolumeId)) Refuse("IDENTITY");
                roots[binding.VolumeId] = binding.RootIdentity;
                keys[binding.RootIdentity] = binding.VolumeId;
                CapacityVolume previous;
                if (volumes.TryGetValue(binding.VolumeId, out previous))
                {
                    if (previous.AllocationUnitBytes != sample.AllocationUnitBytes ||
                        previous.SafetyReserveBytes != sample.SafetyReserveBytes) Refuse("IDENTITY");
                    sample = new CapacityVolume(binding.VolumeId, sample.AllocationUnitBytes,
                        Math.Min(previous.AvailableBytes.Value, sample.AvailableBytes.Value), sample.SafetyReserveBytes);
                }
                volumes[binding.VolumeId] = sample;
            }
            return volumes.Values.OrderBy(item => item.VolumeId, StringComparer.Ordinal).ToArray();
        }

        public static CapacityObservation Observe(CapacityTarget[] targets)
        {
            var held = new List<Held>();
            try
            {
                CheckPlatformAndLayout();
                CapacityTarget[] inputs = Inputs(targets);
                string sid = Caller();
                foreach (CapacityTarget target in inputs)
                {
                    var item = new Held { Target = target, Entries = Ancestors(target.DestinationRoot, true) };
                    held.Add(item); // Own successful opens before any subsequent possible refusal.
                    if (item.Entries.Count == 0) Refuse("VOLUME");
                    item.NativeRoot = NativePath(item.Entries[0].Handle);
                    item.Key = VolumeKey(item.NativeRoot);
                    Verify(item);
                }
                VerifyPhysicalDestinations(held.Select(item => item.Key).ToArray(),
                    held.Select(item => item.Target.DestinationRoot).ToArray());
                var bindings = new List<CapacityBinding>();
                var samples = new List<CapacityVolume>();
                foreach (Held item in held)
                {
                    if (Caller() != sid) Refuse("CONTEXT");
                    Entry ancestor = item.Entries.Last();
                    ulong[] values = Sample(ancestor);
                    bindings.Add(new CapacityBinding(item.Target.Purpose, item.Target.DestinationRoot,
                        item.Key, ancestor.Path, ancestor.Id, item.Entries[0].Id));
                    samples.Add(new CapacityVolume(item.Key, values[0], values[1], item.Target.SafetyReserveBytes));
                }
                foreach (Held item in held) Verify(item);
                if (Caller() != sid) Refuse("CONTEXT");
                CapacityBinding[] resultBindings = bindings.ToArray();
                return new CapacityObservation(sid, resultBindings, Group(resultBindings, samples.ToArray()));
            }
            catch (MeasurementRefusal) { throw; }
            catch { throw new MeasurementRefusal("BGSE_E_CAPACITY_NATIVE"); }
            finally
            {
                for (int i = held.Count - 1; i >= 0; i--)
                    for (int j = held[i].Entries.Count - 1; j >= 0; j--) held[i].Entries[j].Dispose();
            }
        }
    }
}
