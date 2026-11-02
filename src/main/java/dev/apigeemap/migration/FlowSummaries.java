package dev.apigeemap.migration;

import dev.apigeemap.protocol.Json;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Summaries of the shared flows, one JSON file per flow in a folder, with the fingerprint of the files they were
 * written from. When a proxy is documented or planned, a large shared flow it calls is sent as its summary instead of
 * its files: a flow called by many proxies is then read once, and stays summarized until its files change.
 */
public final class FlowSummaries {

    /** A shared flow whose files hold more than this many characters is sent as its summary. */
    public static final int SUMMARIZED_FROM = 8_000;
    /** A summary request holds at most this many flows, as the backend allows, and this many characters. */
    static final int MAX_FLOWS = 30;
    static final int MAX_SENT = 600_000;
    /** Changes when the summaries must be written again. */
    private static final String VERSION = "1";
    /** The path of the summary among the files of a flow. */
    public static final String PATH = "(summary of the shared flow)";

    /** Calls the backend's {@code summarize} operation. */
    public interface Backend {
        Object summarize(Object body) throws IOException;
    }

    private final Path dir;

    private FlowSummaries(Path dir) {
        this.dir = dir;
    }

    public static FlowSummaries at(Path dir) {
        return new FlowSummaries(dir);
    }

    /**
     * The files as sent: those of each large shared flow other than {@code root} replaced by its summary, asked of
     * the backend in one exchange for those not summarized yet or changed since. A flow the backend could not
     * summarize is sent as its files.
     */
    public List<ProxyDocs.SourceFile> substitute(String root, List<ProxyDocs.SourceFile> files, Backend backend,
                                                 PrintStream err) {
        Map<String, List<ProxyDocs.SourceFile>> bundles = new LinkedHashMap<>();
        for (ProxyDocs.SourceFile file : files) bundles.computeIfAbsent(file.bundle(), b -> new ArrayList<>()).add(file);

        Map<String, String> fingerprints = new LinkedHashMap<>();
        Map<String, Map<?, ?>> summaries = new LinkedHashMap<>();
        List<String> missing = new ArrayList<>();
        bundles.forEach((name, own) -> {
            if (name.equals(root) || size(own) <= SUMMARIZED_FROM) return;
            String fingerprint = ProxyDocs.fingerprint(own);
            fingerprints.put(name, fingerprint);
            get(name, fingerprint).ifPresentOrElse(s -> summaries.put(name, s), () -> missing.add(name));
        });
        if (!missing.isEmpty()) {
            for (List<String> batch : batches(missing, bundles)) {
                List<Map<String, Object>> sent = batch.stream()
                        .map(name -> Map.<String, Object>of("name", name, "files", bundles.get(name))).toList();
                Object reply;
                try {
                    reply = backend.summarize(Map.of("sharedFlows", sent));
                } catch (IOException | RuntimeException e) {
                    err.println("Shared flows sent as their files: " + e.getMessage());
                    continue;
                }
                if (!(reply instanceof Map<?, ?> map) || !(map.get("summaries") instanceof List<?> list)) continue;
                for (Object item : list) {
                    if (item instanceof Map<?, ?> summary && summary.get("name") instanceof String name
                            && batch.contains(name) && summary.get("purpose") instanceof String purpose
                            && !purpose.isBlank()) {
                        put(name, fingerprints.get(name), summary);
                        summaries.put(name, summary);
                    }
                }
            }
        }

        List<ProxyDocs.SourceFile> out = new ArrayList<>();
        bundles.forEach((name, own) -> {
            Map<?, ?> summary = summaries.get(name);
            if (summary == null) out.addAll(own);
            else out.add(new ProxyDocs.SourceFile(name, PATH, render(name, summary, own.size(), size(own))));
        });
        return out;
    }

    /** The flows to summarize, in requests the backend takes. */
    private static List<List<String>> batches(List<String> names, Map<String, List<ProxyDocs.SourceFile>> bundles) {
        List<List<String>> batches = new ArrayList<>();
        List<String> batch = new ArrayList<>();
        long size = 0;
        for (String name : names) {
            long own = size(bundles.get(name));
            if (own > MAX_SENT) continue;
            if (!batch.isEmpty() && (batch.size() == MAX_FLOWS || size + own > MAX_SENT)) {
                batches.add(batch);
                batch = new ArrayList<>();
                size = 0;
            }
            batch.add(name);
            size += own;
        }
        if (!batch.isEmpty()) batches.add(batch);
        return batches;
    }

    /** The summary as the backend reads it among the files of a proxy. */
    static String render(String name, Map<?, ?> summary, int files, long characters) {
        StringBuilder out = new StringBuilder("Summary of the shared flow ").append(name).append(", sent instead of its ")
                .append(files).append(" file(s) (").append(characters).append(" characters).\n");
        out.append("Purpose: ").append(text(summary.get("purpose"))).append('\n');
        if (summary.get("steps") instanceof List<?> steps && !steps.isEmpty()) {
            out.append("Steps, in run order:\n");
            for (Object item : steps) {
                if (!(item instanceof Map<?, ?> step)) continue;
                out.append("- `").append(text(step.get("policy"))).append('`');
                if (!text(step.get("type")).isEmpty()) out.append(" (").append(text(step.get("type"))).append(')');
                if (!text(step.get("condition")).isEmpty()) {
                    out.append(", when `").append(text(step.get("condition"))).append('`');
                }
                if (!text(step.get("does")).isEmpty()) out.append(": ").append(text(step.get("does")));
                out.append('\n');
            }
        }
        for (String section : List.of("reads", "sets", "errors", "dependencies", "notes")) {
            if (!(summary.get(section) instanceof List<?> points) || points.isEmpty()) continue;
            out.append(Character.toUpperCase(section.charAt(0))).append(section.substring(1)).append(":\n");
            for (Object point : points) out.append("- ").append(text(point)).append('\n');
        }
        return out.toString();
    }

    private Optional<Map<?, ?>> get(String flow, String fingerprint) {
        Path file = file(flow);
        if (!Files.isRegularFile(file)) return Optional.empty();
        try {
            if (Json.parse(Files.readString(file)) instanceof Map<?, ?> stored && VERSION.equals(stored.get("version"))
                    && fingerprint.equals(stored.get("fingerprint")) && stored.get("summary") instanceof Map<?, ?> s) {
                return Optional.of(s);
            }
        } catch (IOException | RuntimeException e) {
            // an unreadable summary is one to write again
        }
        return Optional.empty();
    }

    private void put(String flow, String fingerprint, Map<?, ?> summary) {
        try {
            Files.createDirectories(dir);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("flow", flow);
            m.put("version", VERSION);
            m.put("fingerprint", fingerprint);
            m.put("summary", summary);
            Path temp = Files.createTempFile(dir, "summary", ".tmp");
            Files.writeString(temp, Json.write(m) + "\n");
            Files.move(temp, file(flow), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            // not kept: it is asked again next time
        }
    }

    private Path file(String flow) {
        return dir.resolve(ScriptReviews.fingerprint(flow).substring(0, 32) + ".json");
    }

    private static long size(List<ProxyDocs.SourceFile> files) {
        return files.stream().mapToLong(f -> f.content().length()).sum();
    }

    private static String text(Object value) {
        return value instanceof String s ? s.strip().replaceAll("\\s+", " ") : "";
    }
}
