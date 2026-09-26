// Task 3 packet A2: PURE accounting of supplied values, not disk observation,
// reservation, copy authorization, a native provider or runtime admission.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Bgse.Lab
{
    public sealed class CapacityVolume
    {
        public string VolumeId { get; }
        public ulong? AllocationUnitBytes { get; }
        public ulong? AvailableBytes { get; }
        public ulong? SafetyReserveBytes { get; }
        public CapacityVolume(string volumeId, ulong? allocationUnitBytes, ulong? availableBytes,
            ulong? safetyReserveBytes)
        {
            VolumeId = volumeId; AllocationUnitBytes = allocationUnitBytes;
            AvailableBytes = availableBytes; SafetyReserveBytes = safetyReserveBytes;
        }
    }

    public sealed class CapacityAllocation
    {
        private readonly ulong?[] fileByteLimits;
        public string VolumeId { get; }
        public string Purpose { get; }
        public ulong?[] FileByteLimits { get { return fileByteLimits == null ? null : (ulong?[])fileByteLimits.Clone(); } }
        public ulong? DirectoryCount { get; }
        public ulong? ExtraAllowanceBytes { get; }
        public CapacityAllocation(string volumeId, string purpose, ulong?[] fileByteLimits,
            ulong? directoryCount, ulong? extraAllowanceBytes)
        {
            // Bound the defensive copy itself, not only later arithmetic.
            if (fileByteLimits != null && fileByteLimits.Length > 1000000)
                throw new MeasurementRefusal("BGSE_E_CAPACITY_INPUT");
            this.fileByteLimits = fileByteLimits == null ? null : (ulong?[])fileByteLimits.Clone();
            VolumeId = volumeId; Purpose = purpose;
            DirectoryCount = directoryCount; ExtraAllowanceBytes = extraAllowanceBytes;
        }
    }

    public sealed class VolumeBudget
    {
        public string VolumeId { get; }
        public ulong AllocationUnitBytes { get; }
        public ulong WorkingCopyBytes { get; }
        public ulong FutureBaselineBytes { get; }
        public ulong EvidenceBytes { get; }
        public ulong SafetyReserveBytes { get; }
        public ulong RequiredBytes { get; }
        public ulong AvailableBytes { get; }
        public ulong RemainingBytes { get; }
        internal VolumeBudget(CapacityVolume volume, ulong working, ulong baseline, ulong evidence,
            ulong required)
        {
            VolumeId = volume.VolumeId; AllocationUnitBytes = volume.AllocationUnitBytes.Value;
            WorkingCopyBytes = working; FutureBaselineBytes = baseline; EvidenceBytes = evidence;
            SafetyReserveBytes = volume.SafetyReserveBytes.Value; RequiredBytes = required;
            AvailableBytes = volume.AvailableBytes.Value;
            RemainingBytes = checked(AvailableBytes - RequiredBytes);
        }
    }

    public static class AcquisitionCapacity
    {
        // Planning margin, NOT a proven filesystem allocation upper bound.
        private const ulong EntryOverhead = 65536, MaxEntries = 1000000;
        private static readonly string[] Purposes = { "working-copy", "future-baseline", "evidence" };

        private static void Invalid() { throw new MeasurementRefusal("BGSE_E_CAPACITY_INPUT"); }
        private static void Key(string value)
        {
            if (value == null || !Regex.IsMatch(value, @"\A[A-Z0-9][A-Z0-9_-]{0,127}\z",
                RegexOptions.CultureInvariant)) Invalid();
        }
        private static ulong Known(ulong? value)
        {
            if (!value.HasValue) Invalid();
            return value.Value;
        }

        private static ulong Budget(CapacityAllocation allocation, ulong unit)
        {
            ulong?[] files = allocation.FileByteLimits;
            ulong directories = Known(allocation.DirectoryCount), extra = Known(allocation.ExtraAllowanceBytes);
            if (files == null || directories == 0 || directories > MaxEntries ||
                (ulong)files.Length > MaxEntries - directories) Invalid();
            checked
            {
                ulong result = ((ulong)files.Length + directories) * EntryOverhead;
                foreach (ulong? limit in files)
                {
                    ulong length = Known(limit);
                    // Avoid length+unit-1 overflow when the rounded result fits.
                    ulong clusters = length / unit;
                    if (length % unit != 0) clusters++;
                    result += clusters * unit;
                }
                return result + extra;
            }
        }

        public static VolumeBudget[] Calculate(CapacityVolume[] volumes, CapacityAllocation[] allocations)
        {
            try
            {
                if (volumes == null || volumes.Length == 0 || volumes.Length > 3 ||
                    allocations == null || allocations.Length != 3) Invalid();
                var volumeSnapshot = (CapacityVolume[])volumes.Clone();
                var allocationSnapshot = (CapacityAllocation[])allocations.Clone();
                var byId = new Dictionary<string, CapacityVolume>(StringComparer.Ordinal);
                foreach (CapacityVolume volume in volumeSnapshot)
                {
                    if (volume == null) Invalid();
                    Key(volume.VolumeId);
                    if (Known(volume.AllocationUnitBytes) == 0) Invalid();
                    Known(volume.AvailableBytes); Known(volume.SafetyReserveBytes);
                    if (!byId.TryAdd(volume.VolumeId, volume)) Invalid();
                }
                var purposes = new HashSet<string>(StringComparer.Ordinal);
                var referenced = new HashSet<string>(StringComparer.Ordinal);
                var totals = new Dictionary<string, ulong[]>(StringComparer.Ordinal);
                foreach (CapacityAllocation allocation in allocationSnapshot)
                {
                    if (allocation == null) Invalid();
                    Key(allocation.VolumeId);
                    int index = Array.IndexOf(Purposes, allocation.Purpose);
                    if (index < 0 || !purposes.Add(allocation.Purpose) || !byId.ContainsKey(allocation.VolumeId)) Invalid();
                    referenced.Add(allocation.VolumeId);
                    if (!totals.ContainsKey(allocation.VolumeId)) totals.Add(allocation.VolumeId, new ulong[3]);
                    totals[allocation.VolumeId][index] = Budget(allocation, byId[allocation.VolumeId].AllocationUnitBytes.Value);
                }
                if (referenced.Count != byId.Count) Invalid();
                var result = new List<VolumeBudget>();
                foreach (string id in byId.Keys.OrderBy(value => value, StringComparer.Ordinal))
                {
                    CapacityVolume volume = byId[id];
                    ulong[] amounts = totals[id];
                    ulong required = checked(amounts[0] + amounts[1] + amounts[2] + volume.SafetyReserveBytes.Value);
                    if (volume.AvailableBytes.Value < required)
                        throw new MeasurementRefusal("BGSE_E_CAPACITY_INSUFFICIENT");
                    result.Add(new VolumeBudget(volume, amounts[0], amounts[1], amounts[2], required));
                }
                // No partial result is returned when a later volume refuses.
                return result.ToArray();
            }
            catch (OverflowException) { throw new MeasurementRefusal("BGSE_E_CAPACITY_OVERFLOW"); }
        }
    }
}
