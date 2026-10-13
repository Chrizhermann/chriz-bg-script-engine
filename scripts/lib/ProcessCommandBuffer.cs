// Task 3 A4d: pure validation of caller-supplied x64 little-endian bytes.
// No native query, pointer dereference, process identity or clearance claim.
using System;
using System.Text;

namespace Bgse.Lab
{
    public static class ProcessCommandBuffer
    {
        private const int HeaderBytes = 16;
        private const int MaximumBufferBytes = 65552;
        private static readonly Encoding StrictUtf16Le = new UnicodeEncoding(false, false, true);

        private static void Refuse(string suffix)
        { throw new MeasurementRefusal("BGSE_E_PROCESS_COMMAND_" + suffix); }

        private static ushort Read16(byte[] bytes, int offset)
        { return (ushort)(bytes[offset] | (bytes[offset + 1] << 8)); }

        private static ulong Read64(byte[] bytes, int offset)
        {
            ulong value = 0;
            for (int i = 0; i < 8; i++) value |= ((ulong)bytes[offset + i]) << (8 * i);
            return value;
        }

        public static string Decode(byte[] buffer, ulong originalBase, uint returnedBytes, int status)
        {
            // The half-open allocation end must itself be representable.
            // Bounds are checked before cloning caller-owned memory.
            if (buffer == null || buffer.Length < HeaderBytes || buffer.Length > MaximumBufferBytes ||
                originalBase == 0 || originalBase > UInt64.MaxValue - (ulong)buffer.Length)
                Refuse("INPUT");
            if (status != 0)
                throw new MeasurementRefusal("BGSE_E_PROCESS_COMMAND_STATUS", "decode", "ntstatus", status);

            var snapshot = (byte[])buffer.Clone();
            if (returnedBytes < HeaderBytes || returnedBytes > snapshot.Length) Refuse("DATA");

            ushort length = Read16(snapshot, 0);
            ushort maximum = Read16(snapshot, 2);
            ulong address = Read64(snapshot, 8);
            if ((length & 1) != 0 || (maximum & 1) != 0 || length > maximum) Refuse("DATA");

            if (address == 0)
            {
                if (length != 0 || maximum != 0) Refuse("DATA");
                return String.Empty;
            }

            // The address is only a number. Never dereference it or use an
            // unchecked pointer/offset as an array index.
            if (address < originalBase) Refuse("DATA");
            ulong offset = address - originalBase;
            if (offset < HeaderBytes || offset > returnedBytes || maximum > (ulong)returnedBytes - offset)
                Refuse("DATA");

            string value;
            try { value = StrictUtf16Le.GetString(snapshot, (int)offset, length); }
            catch (DecoderFallbackException) { Refuse("DATA"); return null; }
            if (value.IndexOf('\0') >= 0) Refuse("DATA");
            return value;
        }
    }
}
