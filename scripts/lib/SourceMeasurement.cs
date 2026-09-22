// Task 3 read-only host measurement. This class cannot copy, create, reset or launch.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;

namespace Bgse.Lab
{
    public sealed class MeasurementRefusal : Exception
    {
        public MeasurementRefusal(string code) : base(code) { }
    }

    public sealed class Measurement
    {
        public int files { get; set; }
        public int directories { get; set; }
        public ulong logicalBytes { get; set; }
        public ulong allocationUnitBytes { get; set; }
        public ulong entryOverheadBudgetBytes { get; set; }
        public ulong independentCopyBudgetBytes { get; set; }
        public ulong requiredFreeBytes { get; set; }
        public ulong observedFreeBytes { get; set; }
        public string contentDigest { get; set; }
        public string identityDigest { get; set; }
        public int passes { get; set; }
        public bool atomicSnapshot { get { return false; } }
        public bool capacityPlanningOnly { get { return true; } }
    }

    public static class SourceMeasurement
    {
        // Local NTFS only. No assumptions about compression savings; 64 KiB per
        // entry is an explicit planning allowance, NOT a filesystem upper bound.
        private const ulong EntryOverhead = 65536;
        private const uint Directory = 0x10, Reparse = 0x400;
        private const uint Unsupported = 0x40 | 0x200 | 0x1000 | 0x4000 | 0x40000 | 0x400000;
        private const uint BackupNoFollow = 0x02000000 | 0x00200000;

        [StructLayout(LayoutKind.Sequential)]
        internal struct Info
        {
            public uint Attributes;
            public uint CreationLow, CreationHigh, AccessLow, AccessHigh, WriteLow, WriteHigh;
            public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
            public ulong Size { get { return ((ulong)SizeHigh << 32) | SizeLow; } }
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct Identity
        {
            public ulong Volume, Low, High;
            public override string ToString() { return $"{Volume:x16}:{Low:x16}:{High:x16}"; }
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out Info info);
        [DllImport("kernel32.dll", EntryPoint = "GetFileInformationByHandleEx", ExactSpelling = true, SetLastError = true)]
        private static extern bool GetIdentity(SafeFileHandle handle, int kind, out Identity identity, uint size);
        [DllImport("kernel32.dll", EntryPoint = "GetFileInformationByHandleEx", ExactSpelling = true, SetLastError = true)]
        private static extern bool GetStreams(SafeFileHandle handle, int kind, IntPtr buffer, uint size);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle, StringBuilder buffer, uint size, uint flags);
        [DllImport("kernel32.dll", ExactSpelling = true)]
        private static extern uint GetFileType(SafeFileHandle handle);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern bool GetDiskFreeSpaceW(string root, out uint sectors, out uint bytes,
            out uint freeClusters, out uint clusters);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        private static extern bool GetDiskFreeSpaceExW(string root, out ulong available, out ulong total, out ulong free);

        internal sealed class Entry : IDisposable
        {
            public string Path, Relative, Id, Hash;
            public Info Metadata;
            public SafeFileHandle Handle;
            public bool IsDirectory { get { return (Metadata.Attributes & Directory) != 0; } }
            public void Dispose() { Handle.Dispose(); }
        }

        private static void Refuse(string code) { throw new MeasurementRefusal(code); }

        internal static string LocalPath(string input)
        {
            if (String.IsNullOrEmpty(input) || !Regex.IsMatch(input, @"\A[A-Za-z]:[\\/]"))
                Refuse("BGSE_E_PATH_SYNTAX");
            string path = input.Replace('/', '\\');
            var parts = path.Substring(3).Split('\\');
            // No root-wide source/destination or repeated/trailing separators.
            foreach (string part in parts)
            {
                if (part.Length == 0 || part == "." || part == ".." || part.EndsWith(".") || part.EndsWith(" ") ||
                    Regex.IsMatch(part, "[\\x00-\\x1f<>:\"|?*]") ||
                    Regex.IsMatch(part.Split('.')[0], @"\A(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])\z", RegexOptions.IgnoreCase))
                    Refuse("BGSE_E_PATH_SYNTAX");
            }
            string full = System.IO.Path.GetFullPath(path);
            // .NET may expand existing 8.3 components here; do not silently erase
            // that input alias before native canonical-path comparison.
            if (!full.Equals(path, StringComparison.OrdinalIgnoreCase)) Refuse("BGSE_E_ALIAS");
            return full;
        }

        private static bool Contains(string parent, string path)
        {
            return path.Equals(parent, StringComparison.OrdinalIgnoreCase) ||
                path.StartsWith(parent.TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase);
        }

        internal static string ReadIdentity(SafeFileHandle handle)
        {
            Identity identity;
            if (!GetIdentity(handle, 18, out identity, 24)) Refuse("BGSE_E_PATH_ACCESS");
            return identity.ToString();
        }

        private static Info ReadInfo(SafeFileHandle handle)
        {
            Info info;
            if (!GetFileInformationByHandle(handle, out info)) Refuse("BGSE_E_PATH_ACCESS");
            return info;
        }

        internal static Entry Open(string path, bool mayBeAbsent, bool readData = false)
        {
            // FILE_READ_DATA / FILE_LIST_DIRECTORY makes sharing restrictions
            // effective; a desiredAccess=0 metadata handle does NOT lock rename.
            // Ancestors allow ordinary writes, but not delete/rename. Content read
            // handles additionally deny write until hashing through that handle ends.
            var handle = CreateFileW(@"\\?\" + path, readData ? 0x80000000u : 1u,
                readData ? 1u : 3u, IntPtr.Zero, 3, BackupNoFollow, IntPtr.Zero);
            if (handle.IsInvalid)
            {
                int error = Marshal.GetLastWin32Error();
                handle.Dispose();
                if (mayBeAbsent && (error == 2 || error == 3)) return null;
                Refuse("BGSE_E_PATH_ACCESS");
            }
            return ValidateHandle(path, handle);
        }

        // Takes ownership, including closing a rejected handle. Shared with the
        // separately loaded fresh-creation helper, not a path reopen.
        internal static Entry ValidateHandle(string path, SafeFileHandle handle)
        {
            try
            {
                Info info = ReadInfo(handle);
                if ((info.Attributes & Reparse) != 0) Refuse("BGSE_E_REPARSE_POINT");
                if (GetFileType(handle) != 1 || (info.Attributes & Unsupported) != 0) Refuse("BGSE_E_ENTRY_TYPE");
                if ((info.Attributes & Directory) == 0 && info.Links != 1) Refuse("BGSE_E_HARDLINK");
                var final = new StringBuilder(32768);
                uint length = GetFinalPathNameByHandleW(handle, final, 32768, 0);
                if (length == 0 || length >= 32768) Refuse("BGSE_E_PATH_ACCESS");
                if (!final.ToString().Equals(@"\\?\" + path, StringComparison.OrdinalIgnoreCase)) Refuse("BGSE_E_ALIAS");
                return new Entry { Path = path, Metadata = info, Id = ReadIdentity(handle), Handle = handle };
            }
            catch { handle.Dispose(); throw; }
        }

        internal static List<Entry> Ancestors(string path, bool destination)
        {
            var result = new List<Entry>();
            try
            {
                string current = System.IO.Path.GetPathRoot(path);
                foreach (string part in new [] { "" }.Concat(path.Substring(3).Split('\\')))
                {
                    if (part.Length != 0) current = System.IO.Path.Combine(current, part);
                    Entry entry = Open(current, destination);
                    if (entry == null) return result;
                    result.Add(entry);
                    if (!entry.IsDirectory) Refuse("BGSE_E_ENTRY_TYPE");
                }
                if (destination) Refuse("BGSE_E_DESTINATION_EXISTS");
                return result;
            }
            catch { foreach (Entry entry in result) entry.Dispose(); throw; }
        }

        internal static void VerifyDestination(string destination, List<Entry> original)
        {
            var current = Ancestors(destination, true);
            try
            {
                if (current.Count != original.Count) Refuse("BGSE_E_DESTINATION_CHANGED");
                for (int i = 0; i < current.Count; i++)
                    if (current[i].Id != original[i].Id) Refuse("BGSE_E_DESTINATION_CHANGED");
            }
            finally { foreach (Entry entry in current) entry.Dispose(); }
        }

        private static void VerifySeparateIdentities(string sourceId, string[] destinationIds)
        {
            if (destinationIds.Contains(sourceId)) Refuse("BGSE_E_OVERLAP");
        }

        internal static void CheckStreams(Entry entry)
        {
            // Query the already validated handle. Named streams (including MOTW)
            // are refused, not discarded or copied under an unstated policy.
            const int size = 65536;
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                if (!GetStreams(entry.Handle, 7, buffer, size))
                {
                    if (entry.IsDirectory && Marshal.GetLastWin32Error() == 38) return;
                    Refuse("BGSE_E_STREAMS");
                }
                int offset = 0, count = 0;
                while (true)
                {
                    if (offset < 0 || offset > size - 24) Refuse("BGSE_E_STREAMS");
                    IntPtr item = IntPtr.Add(buffer, offset);
                    int next = Marshal.ReadInt32(item), bytes = Marshal.ReadInt32(item, 4);
                    if (bytes < 0 || bytes % 2 != 0 || bytes > size - offset - 24) Refuse("BGSE_E_STREAMS");
                    string name = Marshal.PtrToStringUni(IntPtr.Add(item, 24), bytes / 2);
                    if (entry.IsDirectory || name != "::$DATA" || ++count != 1) Refuse("BGSE_E_STREAMS");
                    if (next == 0) break;
                    if (next < 24 || next > size - offset - 24) Refuse("BGSE_E_STREAMS");
                    offset += next;
                }
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }

        private static bool SameMetadata(Info left, Info right)
        {
            // Reading may update access time; access time is deliberately not
            // part of the stability contract. This is not an atomic snapshot.
            return left.Attributes == right.Attributes && left.Size == right.Size && left.Links == right.Links &&
                left.CreationLow == right.CreationLow && left.CreationHigh == right.CreationHigh &&
                left.WriteLow == right.WriteLow && left.WriteHigh == right.WriteHigh;
        }

        private static void VerifyUnchanged(Entry entry)
        {
            if (entry.Id != ReadIdentity(entry.Handle) || !SameMetadata(entry.Metadata, ReadInfo(entry.Handle)))
                Refuse("BGSE_E_SOURCE_CHANGED");
        }

        private static List<Entry> Inventory(string root)
        {
            var entries = new List<Entry>();
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            void Visit(string path, string relative)
            {
                LocalPath(path);
                using (Entry metadata = Open(path, false))
                {
                    metadata.Relative = relative;
                    if (!names.Add(relative)) Refuse("BGSE_E_ALIAS");
                    CheckStreams(metadata);
                    if (metadata.IsDirectory)
                    {
                        string[] before = System.IO.Directory.GetFileSystemEntries(path);
                        Array.Sort(before, StringComparer.Ordinal);
                        foreach (string child in before)
                            Visit(child, relative == "." ? System.IO.Path.GetFileName(child) :
                                relative + "/" + System.IO.Path.GetFileName(child));
                        string[] after = System.IO.Directory.GetFileSystemEntries(path);
                        Array.Sort(after, StringComparer.Ordinal);
                        if (!before.SequenceEqual(after)) Refuse("BGSE_E_SOURCE_CHANGED");
                    }
                    else
                    {
                        using (Entry reader = Open(path, false, true))
                        {
                            if (metadata.Id != reader.Id || !SameMetadata(metadata.Metadata, reader.Metadata))
                                Refuse("BGSE_E_SOURCE_CHANGED");
                            CheckStreams(reader);
                            // FileStream owns/disposes this SAME validated no-follow
                            // handle. ReadInfo is performed before stream disposal.
                            using (var stream = new FileStream(reader.Handle, FileAccess.Read))
                            {
                                metadata.Hash = Convert.ToHexString(SHA256.HashData(stream));
                                VerifyUnchanged(reader);
                                CheckStreams(reader);
                            }
                        }
                    }
                    VerifyUnchanged(metadata);
                    entries.Add(metadata);
                }
            }
            Visit(root, ".");
            entries.Sort((left, right) => StringComparer.Ordinal.Compare(left.Relative, right.Relative));
            return entries;
        }

        private static string Digest(List<Entry> entries, bool physical)
        {
            using (var bytes = new MemoryStream())
            {
                using (var writer = new BinaryWriter(bytes, new UTF8Encoding(false, true), true))
                {
                    writer.Write(physical ? "BGSE-observed-identity-v1" : "BGSE-ordinary-content-v1");
                    foreach (Entry entry in entries)
                    {
                        writer.Write(entry.Relative);
                        writer.Write(entry.IsDirectory);
                        writer.Write(entry.IsDirectory ? 0UL : entry.Metadata.Size);
                        writer.Write(entry.Hash ?? "");
                        if (physical)
                        {
                            writer.Write(entry.Id);
                            writer.Write(entry.Metadata.Attributes);
                            writer.Write(entry.Metadata.CreationLow); writer.Write(entry.Metadata.CreationHigh);
                            writer.Write(entry.Metadata.WriteLow); writer.Write(entry.Metadata.WriteHigh);
                        }
                    }
                }
                return Convert.ToHexString(SHA256.HashData(bytes.ToArray()));
            }
        }

        private static void VerifyObservations(List<Entry> first, List<Entry> second)
        {
            if (Digest(first, false) != Digest(second, false) || Digest(first, true) != Digest(second, true))
                Refuse("BGSE_E_SOURCE_CHANGED");
        }

        private static ulong Allowance(string value)
        {
            ulong result;
            if (value == null || !Regex.IsMatch(value, @"\A(?:0|[1-9][0-9]*)\z") ||
                !UInt64.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out result))
                throw new MeasurementRefusal("BGSE_E_CAPACITY");
            return result;
        }

        internal static void FixedNtfs(string root)
        {
            var drive = new DriveInfo(root);
            if (!drive.IsReady || drive.DriveType != DriveType.Fixed || drive.DriveFormat != "NTFS")
                Refuse("BGSE_E_VOLUME");
        }

        public static Measurement Measure(string sourceInput, string destinationInput, string allowanceInput, string reserveInput)
        {
            var held = new List<Entry>();
            try
            {
                ulong allowance = Allowance(allowanceInput), reserve = Allowance(reserveInput);
                string source = LocalPath(sourceInput), destination = LocalPath(destinationInput);
                if (Contains(source, destination) || Contains(destination, source)) Refuse("BGSE_E_OVERLAP");
                FixedNtfs(System.IO.Path.GetPathRoot(source));
                string destinationDrive = System.IO.Path.GetPathRoot(destination);
                FixedNtfs(destinationDrive);
                var sourceAncestors = Ancestors(source, false);
                held.AddRange(sourceAncestors);
                var destinationAncestors = Ancestors(destination, true);
                held.AddRange(destinationAncestors);
                VerifySeparateIdentities(sourceAncestors.Last().Id, destinationAncestors.Select(entry => entry.Id).ToArray());
                var first = Inventory(source);
                var second = Inventory(source);
                string content = Digest(first, false), identity = Digest(first, true);
                VerifyObservations(first, second);
                // Check the whole chain, including components absent in the first
                // observation; opening only the missing final leaf is insufficient.
                VerifyDestination(destination, destinationAncestors);
                foreach (Entry entry in held)
                    if (entry.Id != ReadIdentity(entry.Handle)) Refuse("BGSE_E_SOURCE_CHANGED");
                uint sectors, bytes, freeClusters, clusters;
                ulong available = 0, total, free;
                if (!GetDiskFreeSpaceW(destinationDrive, out sectors, out bytes, out freeClusters, out clusters) ||
                    !GetDiskFreeSpaceExW(destinationDrive, out available, out total, out free)) Refuse("BGSE_E_CAPACITY");
                checked
                {
                    ulong unit = (ulong)sectors * bytes;
                    if (unit == 0) Refuse("BGSE_E_CAPACITY");
                    ulong logical = 0, copy = (ulong)first.Count * EntryOverhead;
                    int files = 0;
                    foreach (Entry entry in first)
                    {
                        if (entry.IsDirectory) continue;
                        files++;
                        logical += entry.Metadata.Size;
                        copy += ((entry.Metadata.Size + unit - 1) / unit) * unit;
                    }
                    ulong required = 2 * copy + allowance + reserve;
                    if (available < required) Refuse("BGSE_E_CAPACITY");
                    return new Measurement { files = files, directories = first.Count - files,
                        logicalBytes = logical, allocationUnitBytes = unit, entryOverheadBudgetBytes = EntryOverhead,
                        independentCopyBudgetBytes = copy, requiredFreeBytes = required, observedFreeBytes = available,
                        contentDigest = content, identityDigest = identity, passes = 2 };
                }
            }
            catch (MeasurementRefusal) { throw; }
            catch (OverflowException) { throw new MeasurementRefusal("BGSE_E_CAPACITY"); }
            catch { throw new MeasurementRefusal("BGSE_E_PATH_ACCESS"); }
            finally { foreach (Entry entry in held) entry.Dispose(); }
        }
    }
}
