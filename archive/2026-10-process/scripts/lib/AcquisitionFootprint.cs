// Task 3 packet A1: private, read-only, pre-first-write path observation ONLY.
// No authorization, inventory, process/capacity admission, copying or launching.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using static Bgse.Lab.SourceMeasurement;

namespace Bgse.Lab
{
    public sealed class PlannedEntry
    {
        public string Relative { get; }
        public bool IsDirectory { get; }
        public PlannedEntry(string relative, bool isDirectory)
        { Relative = relative; IsDirectory = isDirectory; }
    }

    public sealed class FootprintEntry
    {
        public string Path { get; }
        public string Tree { get; }
        public string Relative { get; }
        public bool IsDirectory { get; }
        public bool IsRootChain { get; }
        internal FootprintEntry(string path, string tree, string relative, bool directory, bool rootChain)
        { Path = path; Tree = tree; Relative = relative; IsDirectory = directory; IsRootChain = rootChain; }
    }

    public sealed class AcquisitionFootprint : IDisposable
    {
        private const string Marker = ".bgse-disposable-lab.json";
        private const int MaxEntries = 1000000;
        private const long MaxNameUnits = 64000000;
        private static readonly StringComparer IgnoreCase = StringComparer.OrdinalIgnoreCase;
        private sealed class Chain
        {
            internal string Path;
            internal bool Output;
            internal List<Entry> Entries;
        }
        private readonly List<Chain> chains = new List<Chain>();
        private readonly FootprintEntry[] creations;
        private bool disposed, failed;

        public AcquisitionFootprint(string sourceRoot, string copyRoot, string evidenceRoot,
            string[] protectedRoots, PlannedEntry[] copyEntries, PlannedEntry[] evidenceEntries)
        {
            try
            {
                // Freeze and validate all caller-owned inputs before opening any paths.
                string source = Root(sourceRoot, false), copy = Root(copyRoot, true),
                    evidence = Root(evidenceRoot, true);
                string[] protection = Protection(source, protectedRoots);
                long nameUnits = 0;
                var copyChildren = Children(copy, "copy", copyEntries, ref nameUnits);
                var evidenceChildren = Children(evidence, "evidence", evidenceEntries, ref nameUnits);
                Separate(copy, evidence);
                foreach (string root in protection) { Separate(root, copy); Separate(root, evidence); }
                foreach (string root in protection) Hold(root, false);
                Chain copyChain = Hold(copy, true), evidenceChain = Hold(evidence, true);
                string[] protectedIds = chains.Where(chain => !chain.Output)
                    .Select(chain => chain.Entries.Last().Id).ToArray();
                VerifySeparatePhysicalRoots(protectedIds, copyChain.Entries.Select(entry => entry.Id).ToArray());
                VerifySeparatePhysicalRoots(protectedIds, evidenceChain.Entries.Select(entry => entry.Id).ToArray());

                var all = RootCreations(copyChain, "copy");
                all.AddRange(copyChildren);
                all.AddRange(RootCreations(evidenceChain, "evidence"));
                all.AddRange(evidenceChildren);
                var names = new HashSet<string>(IgnoreCase);
                foreach (FootprintEntry item in all)
                {
                    foreach (string root in protection) Separate(root, item.Path);
                    // Also refuses two independent creators sharing a missing ancestor.
                    if (!names.Add(item.Path)) Refuse("BGSE_E_FOOTPRINT_COLLISION");
                }
                creations = all.ToArray();
                RevalidateCore();
            }
            catch (MeasurementRefusal) { Dispose(); throw; }
            catch { Dispose(); throw new MeasurementRefusal("BGSE_E_FOOTPRINT_ACCESS"); }
        }

        public FootprintEntry[] Creations
        {
            get { RequireActive(); return (FootprintEntry[])creations.Clone(); }
        }

        private static void Refuse(string code) { throw new MeasurementRefusal(code); }

        private static void CheckText(string value)
        {
            if (String.IsNullOrEmpty(value)) Refuse("BGSE_E_PATH_SYNTAX");
            try { new UTF8Encoding(false, true).GetByteCount(value); }
            catch (EncoderFallbackException) { Refuse("BGSE_E_PATH_SYNTAX"); }
        }

        private static string Root(string input, bool output)
        {
            CheckText(input);
            if (input.Length >= 32767) Refuse("BGSE_E_PATH_SYNTAX");
            string path = LocalPath(input);
            foreach (string part in path.Substring(3).Split('\\'))
            {
                if (part.Length > 255) Refuse("BGSE_E_PATH_SYNTAX");
                if (output && IgnoreCase.Equals(part, Marker)) Refuse("BGSE_E_SOURCE_MARKER");
            }
            return path;
        }

        private static string[] Protection(string source, string[] input)
        {
            if (input == null || input.Length == 0 || input.Length > 64)
                Refuse("BGSE_E_PROTECTED_ROOTS");
            string[] roots = (string[])input.Clone();
            var seen = new HashSet<string>(IgnoreCase);
            for (int i = 0; i < roots.Length; i++)
            {
                roots[i] = Root(roots[i], false);
                if (!seen.Add(roots[i])) Refuse("BGSE_E_PROTECTED_ROOTS");
            }
            if (!seen.Contains(source)) Refuse("BGSE_E_PROTECTED_ROOTS");
            return roots;
        }

        private static List<FootprintEntry> Children(string root, string tree, PlannedEntry[] input,
            ref long nameUnits)
        {
            if (input == null || input.Length > MaxEntries) Refuse("BGSE_E_FOOTPRINT_INPUT");
            var snapshot = (PlannedEntry[])input.Clone();
            var entries = new Dictionary<string, PlannedEntry>(IgnoreCase);
            var result = new List<FootprintEntry>();
            foreach (PlannedEntry entry in snapshot)
            {
                if (entry == null) Refuse("BGSE_E_FOOTPRINT_INPUT");
                string relative = entry.Relative;
                CheckText(relative);
                nameUnits += relative.Length;
                if (nameUnits > MaxNameUnits) Refuse("BGSE_E_FOOTPRINT_INPUT");
                if (relative.StartsWith('/') || relative.Contains('\\')) Refuse("BGSE_E_PATH_SYNTAX");
                string path = Root(root + "\\" + relative.Replace('/', '\\'), true);
                if (!entries.TryAdd(relative, entry)) Refuse("BGSE_E_FOOTPRINT_COLLISION");
                result.Add(new FootprintEntry(path, tree, relative, entry.IsDirectory, false));
            }
            foreach (PlannedEntry entry in snapshot)
            {
                int separator = entry.Relative.LastIndexOf('/');
                if (separator < 0) continue;
                string parent = entry.Relative.Substring(0, separator);
                PlannedEntry directory;
                if (!entries.TryGetValue(parent, out directory) || !directory.IsDirectory ||
                    !String.Equals(directory.Relative, parent, StringComparison.Ordinal))
                    Refuse("BGSE_E_FOOTPRINT_PARENT");
            }
            result.Sort((left, right) => StringComparer.Ordinal.Compare(left.Relative, right.Relative));
            return result;
        }

        private static bool Contains(string parent, string path)
        {
            return IgnoreCase.Equals(parent, path) ||
                path.StartsWith(parent + "\\", StringComparison.OrdinalIgnoreCase);
        }

        private static void Separate(string left, string right)
        {
            if (Contains(left, right) || Contains(right, left)) Refuse("BGSE_E_OVERLAP");
        }

        private static void VerifySeparatePhysicalRoots(string[] protectedIds, string[] outputAncestorIds)
        {
            var ids = new HashSet<string>(protectedIds, StringComparer.Ordinal);
            if (outputAncestorIds.Any(ids.Contains)) Refuse("BGSE_E_OVERLAP");
        }

        private Chain Hold(string path, bool output)
        {
            FixedNtfs(System.IO.Path.GetPathRoot(path));
            var chain = new Chain { Path = path, Output = output, Entries = Ancestors(path, output) };
            chains.Add(chain);
            if (!output) CheckStreams(chain.Entries.Last());
            return chain;
        }

        private static List<FootprintEntry> RootCreations(Chain chain, string tree)
        {
            var result = new List<FootprintEntry>();
            string current = chain.Entries.Last().Path;
            string suffix = chain.Path.Substring(current.TrimEnd('\\').Length).TrimStart('\\');
            foreach (string component in suffix.Split('\\'))
            {
                current = System.IO.Path.Combine(current, component);
                result.Add(new FootprintEntry(current, tree, null, true, true));
            }
            return result;
        }

        private void RequireActive()
        {
            if (disposed || failed) Refuse("BGSE_E_FOOTPRINT_STATE");
        }

        // Only before any output creation; this is not a mutation-time lease.
        public void Revalidate()
        {
            RequireActive();
            try { RevalidateCore(); }
            catch (MeasurementRefusal) { failed = true; throw; }
            catch { failed = true; throw new MeasurementRefusal("BGSE_E_FOOTPRINT_ACCESS"); }
        }

        private void RevalidateCore()
        {
            foreach (Chain chain in chains)
            {
                FixedNtfs(System.IO.Path.GetPathRoot(chain.Path));
                var current = Ancestors(chain.Path, chain.Output);
                try
                {
                    string code = chain.Output ? "BGSE_E_DESTINATION_CHANGED" : "BGSE_E_SOURCE_CHANGED";
                    if (current.Count != chain.Entries.Count) Refuse(code);
                    for (int i = 0; i < current.Count; i++)
                        if (current[i].Id != chain.Entries[i].Id ||
                            ReadIdentity(chain.Entries[i].Handle) != chain.Entries[i].Id) Refuse(code);
                    if (!chain.Output) CheckStreams(current.Last());
                }
                finally { foreach (Entry entry in current) entry.Dispose(); }
            }
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            for (int i = chains.Count - 1; i >= 0; i--)
                for (int j = chains[i].Entries.Count - 1; j >= 0; j--) chains[i].Entries[j].Dispose();
        }
    }
}
