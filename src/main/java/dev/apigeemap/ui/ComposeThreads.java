package dev.apigeemap.ui;

import dev.apigeemap.protocol.Json;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * The Compose conversations of the Editor, one JSON file per conversation in a folder: {@code {id, proxy, title,
 * created, updated, turns}}. A turn keeps what was asked and what was answered, with its edits in the form the
 * backend gave them ({@code changes} to replace, or a whole {@code content}), so that they can be applied later to
 * the text as it is then, and whether they were applied.
 */
final class ComposeThreads {

    /** At most this many earlier turns go with a request, the most recent ones, as the backend takes 20. */
    static final int MAX_SENT = 12;
    private static final int MAX_ASKED = 4000;
    private static final int MAX_ANSWERED = 8000;
    private static final int MAX_CHANGES = 50;
    private static final int TITLE = 80;
    private static final Pattern ID = Pattern.compile("[0-9a-f-]{36}");

    private final Path dir;

    private ComposeThreads(Path dir) {
        this.dir = dir;
    }

    static ComposeThreads at(Path dir) {
        return new ComposeThreads(dir);
    }

    /** The conversations about a proxy, most recent first: {@code {id, title, created, updated, turns, applied}}. */
    synchronized List<Map<String, Object>> list(String proxy) throws IOException {
        if (!Files.isDirectory(dir)) return List.of();
        List<Map<String, Object>> found = new ArrayList<>();
        try (Stream<Path> files = Files.list(dir)) {
            for (Path file : files.filter(f -> f.getFileName().toString().endsWith(".json")).toList()) {
                Map<String, Object> thread = read(file);
                if (thread == null || !proxy.equals(thread.get("proxy"))) continue;
                List<Map<String, Object>> turns = turns(thread);
                Map<String, Object> entry = new LinkedHashMap<>();
                entry.put("id", thread.get("id"));
                entry.put("title", thread.get("title"));
                entry.put("created", thread.get("created"));
                entry.put("updated", thread.get("updated"));
                entry.put("turns", turns.size());
                entry.put("applied", turns.stream().filter(t -> Boolean.TRUE.equals(t.get("applied"))).count());
                found.add(entry);
            }
        }
        found.sort(Comparator.comparing((Map<String, Object> t) -> String.valueOf(t.get("updated"))).reversed());
        return found;
    }

    synchronized Optional<Map<String, Object>> get(String proxy, String id) {
        if (id == null || !ID.matcher(id).matches()) return Optional.empty();
        Map<String, Object> thread = read(dir.resolve(id + ".json"));
        return thread != null && proxy.equals(thread.get("proxy")) ? Optional.of(thread) : Optional.empty();
    }

    /**
     * Adds {@code turn} to the conversation {@code id}, or to a new one when {@code id} is null; {@code replace} puts
     * it in place of the last turn instead (the same request asked again). Answers the conversation as saved.
     */
    synchronized Map<String, Object> record(String proxy, String id, Map<String, Object> turn, boolean replace)
            throws IOException {
        Map<String, Object> thread;
        if (id == null) {
            thread = new LinkedHashMap<>();
            thread.put("id", UUID.randomUUID().toString());
            thread.put("proxy", proxy);
            String asked = String.valueOf(turn.get("asked")).strip().replaceAll("\\s+", " ");
            thread.put("title", asked.length() > TITLE ? asked.substring(0, TITLE - 1) + "…" : asked);
            thread.put("created", Instant.now().toString());
            thread.put("turns", new ArrayList<>());
        } else {
            thread = get(proxy, id).orElseThrow(() -> new UiService.UiException(404, "This conversation is gone"));
        }
        List<Map<String, Object>> turns = new ArrayList<>(turns(thread));
        if (replace && !turns.isEmpty()) turns.remove(turns.size() - 1);
        turns.add(turn);
        thread.put("turns", turns);
        thread.put("updated", Instant.now().toString());
        write(thread);
        return thread;
    }

    /** Notes that the edits of a turn were applied to the editor. */
    synchronized void markApplied(String proxy, String id, int index) throws IOException {
        Map<String, Object> thread = get(proxy, id)
                .orElseThrow(() -> new UiService.UiException(404, "This conversation is gone"));
        List<Map<String, Object>> turns = turns(thread);
        if (index < 0 || index >= turns.size()) throw new UiService.UiException(404, "This answer is gone");
        turns.get(index).put("applied", true);
        thread.put("turns", turns);
        write(thread);
    }

    synchronized void delete(String proxy, String id) throws IOException {
        if (get(proxy, id).isPresent()) Files.deleteIfExists(dir.resolve(id + ".json"));
    }

    /** The turns of a conversation, as mutable maps. */
    static List<Map<String, Object>> turns(Map<String, Object> thread) {
        List<Map<String, Object>> turns = new ArrayList<>();
        if (thread.get("turns") instanceof List<?> list) {
            for (Object item : list) {
                if (item instanceof Map<?, ?> turn) {
                    Map<String, Object> copy = new LinkedHashMap<>();
                    turn.forEach((key, value) -> copy.put(String.valueOf(key), value));
                    turns.add(copy);
                }
            }
        }
        return turns;
    }

    /**
     * What the backend gets of earlier turns: the {@link #MAX_SENT} most recent, {@code {asked, answered, changes,
     * applied}}, cut to the sizes it takes.
     */
    static List<Map<String, Object>> sent(List<Map<String, Object>> turns) {
        List<Map<String, Object>> sent = new ArrayList<>();
        for (Map<String, Object> turn : turns.subList(Math.max(0, turns.size() - MAX_SENT), turns.size())) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("asked", cut(String.valueOf(turn.get("asked")), MAX_ASKED));
            m.put("answered", cut(String.valueOf(turn.get("summary")), MAX_ANSWERED));
            List<String> changes = new ArrayList<>();
            if (turn.get("edits") instanceof List<?> edits) {
                for (Object item : edits) {
                    if (item instanceof Map<?, ?> edit && changes.size() < MAX_CHANGES) {
                        changes.add(cut(edit.get("bundle") + "/" + edit.get("path") + " (" + edit.get("action") + ")",
                                300));
                    }
                }
            }
            m.put("changes", changes);
            m.put("applied", Boolean.TRUE.equals(turn.get("applied")));
            sent.add(m);
        }
        return sent;
    }

    /**
     * A turn from what was asked and the answer of the editor: its edits keep the backend's {@code changes}, or the
     * whole {@code content} with the text it replaces ({@code before}), never the text after edits.
     */
    static Map<String, Object> turn(String asked, String selected, Map<String, Object> answer) {
        Map<String, Object> turn = new LinkedHashMap<>();
        turn.put("asked", asked);
        turn.put("selection", selected);
        turn.put("at", Instant.now().toString());
        turn.put("summary", answer.get("summary"));
        turn.put("warnings", answer.get("warnings"));
        List<Map<String, Object>> edits = new ArrayList<>();
        if (answer.get("edits") instanceof List<?> list) {
            for (Object item : list) {
                if (!(item instanceof UiService.ProposedEdit edit)) continue;
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("bundle", edit.bundle());
                m.put("path", edit.path());
                m.put("action", edit.action());
                m.put("reason", edit.reason());
                if (edit.changes() != null) {
                    m.put("changes", edit.changes());
                } else if (!edit.action().equals("delete")) {
                    m.put("content", edit.after());
                    if (edit.action().equals("replace")) m.put("before", edit.before());
                }
                edits.add(m);
            }
        }
        turn.put("edits", edits);
        turn.put("notApplied", answer.getOrDefault("notApplied", List.of()));
        if (answer.get("unsent") != null) turn.put("unsent", answer.get("unsent"));
        if (answer.get("needed") != null) turn.put("needed", answer.get("needed"));
        turn.put("applied", false);
        return turn;
    }

    private static String cut(String text, int max) {
        return text.length() > max ? text.substring(0, max - 1) + "…" : text;
    }

    private static Map<String, Object> read(Path file) {
        if (!Files.isRegularFile(file)) return null;
        try {
            if (!(Json.parse(Files.readString(file)) instanceof Map<?, ?> map) || !(map.get("id") instanceof String)) {
                return null;
            }
            Map<String, Object> thread = new LinkedHashMap<>();
            map.forEach((key, value) -> thread.put(String.valueOf(key), value));
            return thread;
        } catch (IOException | RuntimeException e) {
            // an unreadable conversation is one that is not listed
            return null;
        }
    }

    private void write(Map<String, Object> thread) throws IOException {
        Files.createDirectories(dir);
        Path temp = Files.createTempFile(dir, "thread", ".tmp");
        Files.writeString(temp, Json.write(thread) + "\n");
        Files.move(temp, dir.resolve(thread.get("id") + ".json"), StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE);
    }
}
