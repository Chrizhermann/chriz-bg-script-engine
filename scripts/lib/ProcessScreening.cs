// Task 3 packet A4a: pure screening of supplied scalar facts, NOT process
// enumeration, coordination, handle-use proof, clearance or copy admission.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Bgse.Lab
{
    public sealed class ProcessFact
    {
        public uint Pid { get; }
        public ulong? CreationFileTime { get; }
        public string Name { get; }
        public string ImagePath { get; }
        public string CommandLine { get; }
        public ProcessFact(uint pid, ulong? creationFileTime, string name, string imagePath, string commandLine)
        {
            if (pid == 0) ProcessScreening.Invalid();
            Pid = pid; CreationFileTime = creationFileTime; Name = name;
            ImagePath = imagePath; CommandLine = commandLine;
        }
    }

    public sealed class ProcessInstance
    {
        public uint Pid { get; }
        public ulong CreationFileTime { get; }
        public ProcessInstance(uint pid, ulong creationFileTime)
        {
            if (pid == 0 || creationFileTime == 0) ProcessScreening.Invalid();
            Pid = pid; CreationFileTime = creationFileTime;
        }
    }

    public sealed class ProcessScope
    {
        private readonly string[] watchedRoots, helperImages;
        private readonly ProcessInstance[] declaredHelpers;
        public string[] WatchedRoots { get { return (string[])watchedRoots.Clone(); } }
        public string[] HelperImages { get { return (string[])helperImages.Clone(); } }
        public ProcessInstance[] DeclaredHelpers { get { return (ProcessInstance[])declaredHelpers.Clone(); } }
        public ProcessScope(string[] watchedRoots, string[] helperImages, ProcessInstance[] declaredHelpers)
        {
            // Bound allocations before copying; validate only the private snapshot.
            if (watchedRoots == null || watchedRoots.Length < 1 || watchedRoots.Length > 64 ||
                helperImages == null || helperImages.Length > 256 ||
                declaredHelpers == null || declaredHelpers.Length > 16384) ProcessScreening.Invalid();
            this.watchedRoots = (string[])watchedRoots.Clone();
            this.helperImages = (string[])helperImages.Clone();
            this.declaredHelpers = (ProcessInstance[])declaredHelpers.Clone();
            NormalizePaths(this.watchedRoots);
            NormalizePaths(this.helperImages);
            var seen = new HashSet<uint>();
            foreach (ProcessInstance helper in this.declaredHelpers)
                if (helper == null || !seen.Add(helper.Pid)) ProcessScreening.Invalid();
        }

        private static void NormalizePaths(string[] paths)
        {
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < paths.Length; i++)
            {
                ProcessScreening.ValidateText(paths[i], 32766);
                string normalized = ProcessScreening.LexicalPath(paths[i]);
                if (normalized == null || !seen.Add(normalized)) ProcessScreening.Invalid();
                paths[i] = normalized;
            }
        }
    }

    // Private observation artifact: even PIDs/times are not publication evidence.
    public sealed class ProcessScreeningRecord
    {
        private readonly string[] reasons;
        public uint Pid { get; }
        public ulong? CreationFileTime { get; }
        public string State { get; }
        public string[] Reasons { get { return (string[])reasons.Clone(); } }
        internal ProcessScreeningRecord(ProcessFact fact, bool unresolved, HashSet<string> reasons)
        {
            Pid = fact.Pid; CreationFileTime = fact.CreationFileTime;
            State = unresolved ? "unresolved" : reasons.Count == 0 ? "not-selected" : "candidate";
            this.reasons = reasons.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        }
    }

    public sealed class ProcessScreeningResult
    {
        private readonly ProcessScreeningRecord[] records;
        public string SelectorVersion { get { return "BGSE-PROCESS-1"; } }
        public ProcessScreeningRecord[] Records { get { return (ProcessScreeningRecord[])records.Clone(); } }
        internal ProcessScreeningResult(ProcessScreeningRecord[] records)
        {
            this.records = (ProcessScreeningRecord[])records.Clone();
        }
    }

    public static class ProcessScreening
    {
        internal static void Invalid() { throw new MeasurementRefusal("BGSE_E_PROCESS_INPUT"); }
        private static void Incomplete() { throw new MeasurementRefusal("BGSE_E_PROCESS_COVERAGE"); }

        internal static int ValidateText(string text, int limit)
        {
            if (text == null) return 0; // Missing facts are classified, not invented.
            if (text.Length > limit) Invalid();
            for (int i = 0; i < text.Length; i++)
            {
                char value = text[i];
                if (value == '\0') Invalid();
                if (Char.IsHighSurrogate(value))
                {
                    if (++i >= text.Length || !Char.IsLowSurrogate(text[i])) Invalid();
                }
                else if (Char.IsLowSurrogate(value)) Invalid();
            }
            return text.Length;
        }

        // Pure lexical grammar only: deliberately no System.IO.Path/native lookup,
        // normalization of dot segments, current directory, aliases or reparse points.
        internal static string LexicalPath(string input)
        {
            if (String.IsNullOrEmpty(input) || input.Length < 4 ||
                !((input[0] >= 'A' && input[0] <= 'Z') || (input[0] >= 'a' && input[0] <= 'z')) ||
                input[1] != ':' || (input[2] != '\\' && input[2] != '/')) return null;
            string path = input.Replace('/', '\\');
            foreach (string part in path.Substring(3).Split('\\'))
            {
                if (part.Length == 0 || part.Length > 255 || part == "." || part == ".." ||
                    part.EndsWith(".", StringComparison.Ordinal) || part.EndsWith(" ", StringComparison.Ordinal)) return null;
                foreach (char value in part)
                    if (value < 32 || "<>:\"|?*".IndexOf(value) >= 0) return null;
                string stem = part.Split('.')[0];
                if (stem.Equals("CON", StringComparison.OrdinalIgnoreCase) ||
                    stem.Equals("PRN", StringComparison.OrdinalIgnoreCase) ||
                    stem.Equals("AUX", StringComparison.OrdinalIgnoreCase) ||
                    stem.Equals("NUL", StringComparison.OrdinalIgnoreCase)) return null;
                if (stem.Length == 4 && (stem.StartsWith("COM", StringComparison.OrdinalIgnoreCase) ||
                    stem.StartsWith("LPT", StringComparison.OrdinalIgnoreCase)) && "123456789¹²³".IndexOf(stem[3]) >= 0) return null;
            }
            return path;
        }

        private static bool KnownTool(string name)
        {
            if (String.IsNullOrEmpty(name)) return false;
            return name.Equals("Baldur.exe", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("InfinityLoader.exe", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("EEex.exe", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("WeiDU.exe", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("NearInfinity.exe", StringComparison.OrdinalIgnoreCase) ||
                (name.Length > 10 && name.StartsWith("setup-", StringComparison.OrdinalIgnoreCase) &&
                 name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
        }

        private static bool AtOrBelow(string path, string root)
        {
            return path.Equals(root, StringComparison.OrdinalIgnoreCase) ||
                (path.Length > root.Length && path[root.Length] == '\\' &&
                 path.StartsWith(root, StringComparison.OrdinalIgnoreCase));
        }

        private static bool TextDelimiter(char value)
        {
            return Char.IsWhiteSpace(value) || value == '\'' || value == '"';
        }

        private static bool CommandRoot(string command, string root)
        {
            int offset = 0;
            while ((offset = command.IndexOf(root, offset, StringComparison.OrdinalIgnoreCase)) >= 0)
            {
                int end = offset + root.Length;
                if (end == command.Length || command[end] == '\\' || TextDelimiter(command[end])) return true;
                offset++;
            }
            return false;
        }

        private static bool NearInfinityArgument(string command)
        {
            const string name = "NearInfinity.jar";
            int offset = 0;
            while ((offset = command.IndexOf(name, offset, StringComparison.OrdinalIgnoreCase)) >= 0)
            {
                int end = offset + name.Length;
                if ((offset == 0 || command[offset - 1] == '\\' || TextDelimiter(command[offset - 1])) &&
                    (end == command.Length || TextDelimiter(command[end]))) return true;
                offset++;
            }
            return false;
        }

        public static ProcessScreeningResult Screen(ProcessScope scope, ProcessFact[] facts, bool enumerationComplete)
        {
            if (!enumerationComplete || facts == null) Incomplete();
            if (scope == null || facts.Length > 16384) Invalid();
            var snapshot = (ProcessFact[])facts.Clone();
            var byPid = new Dictionary<uint, ProcessFact>();
            long textCount = 0;
            foreach (ProcessFact fact in snapshot)
            {
                if (fact == null || !byPid.TryAdd(fact.Pid, fact)) Invalid();
                textCount += ValidateText(fact.Name, 255);
                textCount += ValidateText(fact.ImagePath, 32766);
                textCount += ValidateText(fact.CommandLine, 32767);
                if (textCount > 8388608) Invalid();
            }
            var declared = new HashSet<uint>();
            foreach (ProcessInstance helper in scope.DeclaredHelpers)
            {
                ProcessFact fact;
                if (!byPid.TryGetValue(helper.Pid, out fact) || fact.CreationFileTime != helper.CreationFileTime) Incomplete();
                declared.Add(helper.Pid);
            }
            string[] roots = scope.WatchedRoots;
            var images = new HashSet<string>(scope.HelperImages, StringComparer.OrdinalIgnoreCase);
            var records = new List<ProcessScreeningRecord>();
            foreach (ProcessFact fact in snapshot.OrderBy(value => value.Pid))
            {
                var reasons = new HashSet<string>(StringComparer.Ordinal);
                bool unresolved = false;
                if (!fact.CreationFileTime.HasValue || fact.CreationFileTime == 0)
                { reasons.Add("unknown-creation"); unresolved = true; }
                if (String.IsNullOrEmpty(fact.Name))
                { reasons.Add("unknown-name"); unresolved = true; }
                if (fact.CommandLine == null)
                { reasons.Add("unknown-command"); unresolved = true; }
                string image = null;
                if (String.IsNullOrEmpty(fact.ImagePath))
                { reasons.Add("unknown-image"); unresolved = true; }
                else
                {
                    image = LexicalPath(fact.ImagePath);
                    if (image == null) { reasons.Add("uninterpretable-image"); unresolved = true; }
                    string spelling = fact.ImagePath.Replace('/', '\\');
                    if (KnownTool(spelling.Substring(spelling.LastIndexOf('\\') + 1))) reasons.Add("known-tool");
                }
                if (KnownTool(fact.Name)) reasons.Add("known-tool");
                if (image != null)
                {
                    if (roots.Any(root => AtOrBelow(image, root))) reasons.Add("image-root");
                    if (images.Contains(image)) reasons.Add("helper-image");
                }
                if (declared.Contains(fact.Pid)) reasons.Add("declared-helper");
                if (fact.CommandLine != null)
                {
                    string command = fact.CommandLine.Replace('/', '\\');
                    if (roots.Any(root => CommandRoot(command, root))) reasons.Add("command-root");
                    if (NearInfinityArgument(command)) reasons.Add("near-infinity-argument");
                }
                records.Add(new ProcessScreeningRecord(fact, unresolved, reasons));
            }
            return new ProcessScreeningResult(records.ToArray());
        }
    }
}
