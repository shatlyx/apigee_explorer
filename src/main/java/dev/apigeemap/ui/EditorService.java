package dev.apigeemap.ui;

import dev.apigeemap.analysis.BundleAnalyzer;
import dev.apigeemap.analysis.BundleLocator;
import dev.apigeemap.analysis.SourceMap;
import dev.apigeemap.analysis.VariableFlow;
import dev.apigeemap.analysis.Xml;
import dev.apigeemap.history.SourceHistory;
import dev.apigeemap.migration.Finding;
import dev.apigeemap.migration.FixContext;
import dev.apigeemap.migration.MigrationReport;
import dev.apigeemap.migration.ProxyDocs;
import dev.apigeemap.model.BundleReport;
import dev.apigeemap.model.Issue;
import dev.apigeemap.model.Policy;
import dev.apigeemap.render.FixContextRenderer;
import dev.apigeemap.simulation.Simulation;
import dev.apigeemap.simulation.Simulator;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.IOException;
import java.io.StringReader;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Stream;

import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.helpers.DefaultHandler;

/**
 * What the Editor page does: lists and reads the files of a proxy, checks what is being typed and saves it. Text that
 * is not saved yet is checked in a throwaway copy of the bundle, so the analysis and the rules run on it as they are.
 * The shared flows the proxy calls are edited with it: a check copies those whose text changes and analyzes the proxy
 * against the copies.
 */
final class EditorService {

    /** Larger files, and those that are not UTF-8 text, are listed but not opened. */
    private static final long MAX_TEXT_SIZE = 1_000_000;
    /** Holds XML the analysis reads; XML under resources/ belongs to scripts and transformations. */
    private static final Set<String> ANALYZED_FOLDERS = Set.of("", "policies", "proxies", "targets", "sharedflows");
    /** Applications, which a request about the proxy does not need. */
    private static final List<String> UNSENT_FOLDERS = List.of("resources/node/", "resources/hosted/");
    /** A proxy is sent with a request when its text files hold at most this many characters. */
    private static final long MAX_COMPOSED = 400_000;
    /** A search stops at this many matches. */
    private static final int MAX_MATCHES = 500;
    /** Characters of its line shown around a match. */
    private static final int SHOWN_BEFORE = 60;
    private static final int SHOWN_AFTER = 120;

    /** A file of a bundle; {@code text} false when it cannot be opened in the editor. */
    record EditorFile(String path, boolean text) {
    }

    /**
     * @param callers for a shared flow, {@link UiService#callers}: the other proxies a change to it reaches; null for the
     *                proxy
     */
    record EditorBundle(String name, boolean editable, List<EditorFile> files, Map<String, Object> callers) {
    }

    /** A place in a file that needs attention, finding or not well-formed XML. */
    record Problem(String bundle, String file, SourceMap.Span span, String severity, String rule, String location,
                   String message, String action) {
    }

    /**
     * @param analyzed false when the XML is not well-formed, or when the bundle could not be analyzed: {@code
     *                 problems} then holds what stopped it, and the findings of the last check still stand
     * @param general  findings and issues about the proxy as a whole
     * @param outline  the flows and variables of what was checked; null when it could not be analyzed
     */
    record Check(boolean analyzed, List<Problem> problems, List<Problem> general, String error,
                 EditorOutline outline) {
    }

    /** A text found in a file, at columns counted from 1 as in the editor, with what is around it on its line. */
    record SearchMatch(String bundle, String file, int line, int column, int endColumn, String before, String match,
                       String after) {
    }

    private final UiService service;
    private final Path historyRoot;

    EditorService(UiService service, Path historyRoot) {
        this.service = service;
        this.historyRoot = historyRoot;
    }

    /** The bundles of the proxy, itself first, with their files. */
    Map<String, Object> workspace(String id) throws IOException {
        List<EditorBundle> bundles = new ArrayList<>();
        Path root = service.bundleDir(id);
        for (Map.Entry<String, Path> bundle : bundles(id).entrySet()) {
            boolean own = bundle.getValue().equals(root);
            bundles.add(new EditorBundle(bundle.getKey(), true, files(bundle.getValue()),
                    own ? null : service.callers(bundle.getValue(), root)));
        }
        return Map.of("proxy", bundles.get(0).name(), "bundles", bundles, "catalog", PolicyCatalog.ENTRIES,
                "builtIns", VariableFlow.builtIns());
    }

    /** {@code id} once checked to name a proxy of the settings, as its Compose conversations are kept under it. */
    String proxy(String id) throws IOException {
        service.bundleDir(id);
        return id;
    }

    /**
     * Where the bundles of the proxy are, by name, itself first. A proxy saved with broken XML cannot be analyzed:
     * it still opens, alone and under its id, so that it can be repaired.
     */
    private Map<String, Path> bundles(String id) throws IOException {
        Path root = service.bundleDir(id);
        Map<String, Path> bundles = new LinkedHashMap<>();
        try {
            FixContext.bundles(service.analyzed(id)).values().forEach(bundle ->
                    bundles.put(bundle.name(), Path.of(bundle.path()).toAbsolutePath().normalize()));
        } catch (IOException | RuntimeException e) {
            bundles.put(id, root);
        }
        return bundles;
    }

    private static List<EditorFile> files(Path dir) throws IOException {
        try (Stream<Path> paths = Files.walk(dir)) {
            List<EditorFile> files = new ArrayList<>();
            for (Path file : paths.filter(Files::isRegularFile).sorted().toList()) {
                files.add(new EditorFile(Xml.relativePath(dir, file), text(file) != null));
            }
            return files;
        }
    }

    /** The content of a file, or null when it is too large or not UTF-8 text. */
    private static String text(Path file) throws IOException {
        if (Files.size(file) > MAX_TEXT_SIZE) return null;
        try {
            String text = StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(Files.readAllBytes(file))).toString();
            return text.indexOf('\0') >= 0 ? null : text;
        } catch (CharacterCodingException e) {
            return null;
        }
    }

    Map<String, Object> read(String id, String bundleName, String path) throws IOException {
        Path bundle = bundles(id).get(bundleName);
        if (bundle == null) throw new UiService.UiException(404, "Unknown bundle " + bundleName);
        Path file = inside(bundle, path);
        String content = Files.isRegularFile(file) ? text(file) : null;
        if (content == null) throw new UiService.UiException(404, "This file cannot be opened: " + path);
        return Map.of("content", content);
    }

    /**
     * Checks the proxy as it would be with {@code {buffers: [{path, content}]}} saved, in a copy of the bundle deleted
     * right after. Answers with the same check whatever the state of the text.
     */
    Check check(String id, Map<?, ?> request) throws IOException {
        return inShadow(id, request, this::check);
    }

    private Check check(Shadow shadow) throws IOException {
        List<Problem> syntax = new ArrayList<>();
        for (Map.Entry<String, Path> copy : shadow.copies.entrySet()) syntax.addAll(syntax(copy.getKey(), copy.getValue()));
        if (!syntax.isEmpty()) return new Check(false, syntax, List.of(), null, null);
        try {
            BundleReport report = shadow.analyze();
            return check(report, service.migrate(report));
        } catch (IOException | RuntimeException e) {
            return new Check(false, List.of(), List.of(), shadow.hide(String.valueOf(e.getMessage())), null);
        }
    }

    private interface InShadow<T> {
        T run(Shadow shadow) throws IOException;
    }

    /**
     * A throwaway copy of the proxy, and of each shared flow it calls once its text is to change, analyzed against
     * these copies.
     */
    private final class Shadow {

        private final Path dir;
        /** The name of the proxy bundle. */
        final String name;
        /** Where each bundle of the proxy is, by name, the proxy first. */
        final Map<String, Path> sources;
        /** The copies made so far, by bundle name, the proxy first. */
        final Map<String, Path> copies = new LinkedHashMap<>();

        Shadow(Path dir, Map<String, Path> sources) throws IOException {
            this.dir = dir;
            this.sources = sources;
            this.name = sources.keySet().iterator().next();
            Path source = sources.get(name);
            Path copy = dir.resolve(source.getFileName().toString());
            copyTree(source, copy);
            copies.put(name, copy);
        }

        /** The copy of the proxy. */
        Path copy() {
            return copies.get(name);
        }

        boolean has(String bundle) {
            return sources.containsKey(bundle);
        }

        /** The copy of a bundle of the proxy, made now if it was not. */
        Path dir(String bundle) throws IOException {
            Path made = copies.get(bundle);
            if (made != null) return made;
            Path source = sources.get(bundle);
            if (source == null) throw new UiService.UiException(404, "Unknown bundle " + bundle);
            String folder = source.getParent() == null ? "flow" : source.getParent().getFileName().toString();
            Path copy = dir.resolve("flows").resolve(String.valueOf(copies.size())).resolve(folder)
                    .resolve(source.getFileName().toString());
            copyTree(source, copy);
            copies.put(bundle, copy);
            return copy;
        }

        /** The proxy as the copies are now, its shared flows read from their copies where there are. */
        BundleReport analyze() throws IOException {
            Map<Path, Path> replaced = new HashMap<>();
            copies.forEach((bundle, copy) -> {
                if (!bundle.equals(name)) replaced.put(sources.get(bundle), copy);
            });
            BundleAnalyzer analyzer = replaced.isEmpty() ? service.analyzer()
                    : new BundleAnalyzer(service.sharedFlows().replacing(replaced));
            return analyzer.analyze(BundleLocator.locate(copy()));
        }

        /** A message with the folders of the copies replaced by the names of their bundles. */
        String hide(String message) {
            String shown = message;
            for (Map.Entry<String, Path> copy : copies.entrySet()) {
                shown = shown.replace(copy.getValue().toString(), copy.getKey());
            }
            return shown;
        }

        /** Writes a file of a bundle in its copy, or deletes it when {@code content} is null. */
        void write(String bundle, String path, String content) throws IOException {
            Path file = inside(dir(bundle), path);
            if (content == null) {
                Files.deleteIfExists(file);
            } else {
                Files.createDirectories(file.getParent());
                Files.writeString(file, content);
            }
        }
    }

    /**
     * Runs {@code work} on a copy of the proxy with the {@code buffers} of the request, those of shared flows written
     * to copies of them; all deleted right after.
     */
    private <T> T inShadow(String id, Map<?, ?> request, InShadow<T> work) throws IOException {
        Map<String, Path> sources = bundles(id);
        Path temp = Files.createTempDirectory("apigee-map-editor-");
        try {
            Shadow shadow = new Shadow(temp, sources);
            for (Buffer buffer : buffers(request)) {
                shadow.write(buffer.bundle() == null ? shadow.name : buffer.bundle(), buffer.path(),
                        buffer.deleted() ? null : buffer.content());
            }
            return work.run(shadow);
        } finally {
            deleteTree(temp);
        }
    }

    /**
     * Asks the backend about the text being edited, buffers included: to fix {@code {finding: {bundle, rule, location}}}
     * or to answer {@code {request, selection?: {path, text}}}. Nothing is kept or written. Answers {@code {summary,
     * warnings, edits, notApplied, review}}, or {@code {error}}: {@code review} is what the checks say of the text
     * with the edits. A file the backend proposes as edits that do not match its text exactly once is left out, in
     * {@code notApplied}.
     */
    Map<String, Object> assist(String id, Map<?, ?> request) throws IOException {
        return inShadow(id, request, shadow -> {
            Check before = check(shadow);
            if (!before.analyzed()) {
                throw new UiService.UiException(409, "Fix the XML of the proxy first: it cannot be analyzed");
            }
            BundleReport report = shadow.analyze();
            Map<String, Object> answer = request.get("finding") instanceof Map<?, ?> finding
                    ? fix(report, finding) : compose(id, report, before.outline(), shadow.copy(), request);
            if (answer.containsKey("error")) return answer;
            @SuppressWarnings("unchecked")
            List<UiService.ProposedEdit> edits = (List<UiService.ProposedEdit>) answer.get("edits");
            answer.put("review", reviewEdits(shadow, before, edits));
            return answer;
        });
    }

    /**
     * Writes the edits to the copies, those of the proxy and of the shared flows it calls, and answers what the checks
     * say of it then. An edit of a bundle the proxy does not call is left out.
     */
    private Map<String, Object> reviewEdits(Shadow shadow, Check before, List<UiService.ProposedEdit> edits)
            throws IOException {
        for (UiService.ProposedEdit edit : edits) {
            if (shadow.has(edit.bundle())) shadow.write(edit.bundle(), edit.path(), edit.after());
        }
        return review(before, check(shadow));
    }

    /**
     * The edits of an earlier Compose answer, {@code {thread, turn}}, made again on the text as it is now, buffers
     * included, without asking the backend: answers like {@link #assist}. A change whose text to replace is no longer
     * there exactly once, a file to create that exists, a file to delete that is gone and a whole new content for a
     * file that changed since go to {@code notApplied}.
     */
    Map<String, Object> replay(String id, Map<?, ?> request) throws IOException {
        Map<String, Object> thread = service.threads().get(id, String.valueOf(request.get("thread")))
                .orElseThrow(() -> new UiService.UiException(404, "This conversation is gone"));
        List<Map<String, Object>> turns = ComposeThreads.turns(thread);
        int index = request.get("turn") instanceof Number n ? n.intValue() : -1;
        if (index < 0 || index >= turns.size()) throw new UiService.UiException(404, "This answer is gone");
        Map<String, Object> turn = turns.get(index);
        return inShadow(id, request, shadow -> {
            Check before = check(shadow);
            if (!before.analyzed()) {
                throw new UiService.UiException(409, "Fix the XML of the proxy first: it cannot be analyzed");
            }
            List<UiService.ProposedEdit> edits = new ArrayList<>();
            List<Map<String, Object>> notApplied = new ArrayList<>();
            if (turn.get("edits") instanceof List<?> stored) {
                for (Object item : stored) {
                    if (item instanceof Map<?, ?> edit) replayed(shadow, edit, edits, notApplied);
                }
            }
            Map<String, Object> answer = new LinkedHashMap<>();
            answer.put("summary", String.valueOf(turn.get("summary")));
            answer.put("warnings", turn.get("warnings") instanceof List<?> w ? w : List.of());
            answer.put("edits", edits);
            answer.put("notApplied", notApplied);
            answer.put("review", reviewEdits(shadow, before, edits));
            answer.put("thread", thread.get("id"));
            answer.put("turn", index);
            return answer;
        });
    }

    /**
     * Whether changes that only add text around what they replace are in {@code text} already: their text to replace
     * is still there, so making them again would add it twice.
     */
    private static boolean alreadyIn(String text, List<?> changes) {
        for (Object item : changes) {
            if (!(item instanceof Map<?, ?> change) || !(change.get("old") instanceof String old)
                    || !(change.get("new") instanceof String replacement) || old.isEmpty()
                    || !replacement.contains(old) || !text.replace("\r\n", "\n").contains(replacement.replace("\r\n", "\n"))) {
                return false;
            }
        }
        return true;
    }

    private void replayed(Shadow shadow, Map<?, ?> edit, List<UiService.ProposedEdit> edits,
                          List<Map<String, Object>> notApplied) throws IOException {
        String editBundle = String.valueOf(edit.get("bundle"));
        String path = String.valueOf(edit.get("path"));
        String action = String.valueOf(edit.get("action"));
        String reason = String.valueOf(edit.get("reason"));
        Path file = shadow.has(editBundle) ? inside(shadow.dir(editBundle), path) : null;
        String current = file != null && Files.isRegularFile(file) ? text(file) : null;
        String problem = null;
        String after = null;
        List<?> changes = edit.get("changes") instanceof List<?> list && !list.isEmpty() ? list : null;
        switch (file == null ? "unknown" : action) {
            case "unknown" -> problem = "the proxy no longer calls " + editBundle;
            case "delete" -> {
                if (current == null) problem = "the file is already gone";
            }
            case "create" -> {
                if (current != null) problem = "the file exists now";
                else after = edit.get("content") instanceof String content ? content : "";
            }
            default -> {
                if (current == null) {
                    problem = "the file is gone";
                } else if (changes != null && alreadyIn(current, changes)) {
                    problem = "these changes are already in the file";
                } else if (changes != null) {
                    TextEdits.Outcome outcome = TextEdits.apply(current, changes);
                    problem = outcome.problem();
                    after = outcome.text();
                } else if (current.equals(edit.get("before")) && edit.get("content") instanceof String content) {
                    after = content;
                } else {
                    problem = "the file changed since this answer";
                }
            }
        }
        if (problem != null) {
            Map<String, Object> refused = new LinkedHashMap<>();
            refused.put("bundle", editBundle);
            refused.put("path", path);
            refused.put("message", "Not applied: " + problem + ".");
            notApplied.add(refused);
            return;
        }
        edits.add(new UiService.ProposedEdit(editBundle, path, action, reason, current, after, changes));
    }

    /** Plays one call through the proxy as it would be with {@code buffers} saved; see {@link Simulator}. */
    Simulation.Result simulate(String id, Map<?, ?> request) throws IOException {
        return inShadow(id, request, shadow -> {
            Check check = check(shadow);
            if (!check.analyzed()) {
                throw new UiService.UiException(409, "Fix the XML of the proxy first: it cannot be analyzed");
            }
            return Simulator.run(shadow.analyze(), input(request));
        });
    }

    /**
     * Finds {@code text}, whatever its case, in the text files of the proxy as they are with {@code buffers}, and of its
     * shared flows. Answers {@code {matches, truncated}}.
     */
    Map<String, Object> search(String id, Map<?, ?> request) throws IOException {
        if (!(request.get("text") instanceof String wanted) || wanted.isEmpty()) {
            throw new UiService.UiException(400, "Say what to find");
        }
        Map<String, Path> bundles = bundles(id);
        String root = bundles.keySet().iterator().next();
        Map<String, Map<String, Buffer>> unsaved = new HashMap<>();
        buffers(request).forEach(buffer -> unsaved.computeIfAbsent(buffer.bundle() == null ? root : buffer.bundle(),
                b -> new LinkedHashMap<>()).put(buffer.path(), buffer));
        List<SearchMatch> matches = new ArrayList<>();
        for (Map.Entry<String, Path> bundle : bundles.entrySet()) {
            Map<String, Buffer> buffers = unsaved.getOrDefault(bundle.getKey(), Map.of());
            Set<String> paths = new TreeSet<>();
            files(bundle.getValue()).stream().filter(EditorFile::text).forEach(file -> paths.add(file.path()));
            paths.addAll(buffers.keySet());
            for (String path : paths) {
                Buffer buffer = buffers.get(path);
                if (buffer != null && buffer.deleted()) continue;
                String text = buffer != null ? buffer.content() : text(bundle.getValue().resolve(path));
                if (text != null) find(bundle.getKey(), path, text, wanted, matches);
            }
        }
        return Map.of("matches", matches, "truncated", matches.size() >= MAX_MATCHES);
    }

    private static void find(String bundle, String file, String text, String wanted, List<SearchMatch> matches) {
        String[] lines = text.split("\r\n|\r|\n", -1);
        for (int index = 0; index < lines.length; index++) {
            String line = lines[index];
            int at = 0;
            while (at + wanted.length() <= line.length() && matches.size() < MAX_MATCHES) {
                if (!line.regionMatches(true, at, wanted, 0, wanted.length())) {
                    at++;
                    continue;
                }
                int end = at + wanted.length();
                matches.add(new SearchMatch(bundle, file, index + 1, at + 1, end + 1,
                        line.substring(Math.max(0, at - SHOWN_BEFORE), at).stripLeading(), line.substring(at, end),
                        line.substring(end, Math.min(line.length(), end + SHOWN_AFTER))));
                at = end;
            }
        }
    }

    private static Simulation.Input input(Map<?, ?> request) {
        Set<String> failing = new LinkedHashSet<>();
        if (request.get("failing") instanceof List<?> names) names.forEach(n -> failing.add(String.valueOf(n)));
        return new Simulation.Input(string(request, "verb"), string(request, "path"), strings(request, "headers"),
                string(request, "body"), string(request, "status"), string(request, "targetBody"),
                strings(request, "variables"), failing, strings(request, "cacheHits"));
    }

    private static String string(Map<?, ?> request, String name) {
        return request.get(name) instanceof String value ? value : null;
    }

    private static Map<String, String> strings(Map<?, ?> request, String name) {
        Map<String, String> values = new LinkedHashMap<>();
        if (request.get(name) instanceof Map<?, ?> map) {
            map.forEach((key, value) -> values.put(String.valueOf(key), String.valueOf(value)));
        }
        return values;
    }

    private Map<String, Object> fix(BundleReport report, Map<?, ?> picked) throws IOException {
        Finding finding = service.migrate(report).findings().stream()
                .filter(f -> f.bundle().equals(picked.get("bundle")) && f.rule().equals(picked.get("rule"))
                        && f.location().equals(picked.get("location")))
                .findFirst().orElseThrow(() -> new UiService.UiException(404, "This finding is gone"));
        FixContext context = FixContext.of(finding, FixContext.bundles(report));
        return service.ask("fix", new FixContextRenderer().model(context), context.files());
    }

    /**
     * Asks the backend what {@code request} says, within the conversation {@code thread} when given (a new one
     * otherwise), and records the answer in it; {@code again} asks the last request again in place of its answer.
     */
    private Map<String, Object> compose(String id, BundleReport report, EditorOutline outline, Path copy,
                                        Map<?, ?> request) throws IOException {
        if (!(request.get("request") instanceof String asked) || asked.isBlank()) {
            throw new UiService.UiException(400, "Say what you need");
        }
        String threadId = request.get("thread") instanceof String t && !t.isBlank() ? t : null;
        boolean again = Boolean.TRUE.equals(request.get("again")) && threadId != null;
        List<Map<String, Object>> earlier = List.of();
        if (threadId != null) {
            earlier = ComposeThreads.turns(service.threads().get(id, threadId)
                    .orElseThrow(() -> new UiService.UiException(404, "This conversation is gone")));
            if (again && !earlier.isEmpty()) earlier = earlier.subList(0, earlier.size() - 1);
        }
        Map<String, String> texts = new LinkedHashMap<>();
        for (EditorFile file : files(copy)) {
            if (!file.text() || UNSENT_FOLDERS.stream().anyMatch(file.path()::startsWith)) continue;
            texts.put(file.path(), text(copy.resolve(file.path())));
        }
        Set<String> focus = new LinkedHashSet<>();
        if (request.get("open") instanceof String open) focus.add(open);
        if (request.get("selection") instanceof Map<?, ?> selected && selected.get("path") instanceof String path) {
            focus.add(path);
        }
        Set<String> include = new LinkedHashSet<>();
        if (request.get("include") instanceof List<?> paths) paths.forEach(p -> include.add(String.valueOf(p)));
        ComposeSelection selection;
        try {
            selection = ComposeSelection.of(texts, asked, focus, include, MAX_COMPOSED);
        } catch (ComposeSelection.TooLarge e) {
            throw new UiService.UiException(413, e.getMessage());
        }
        List<FixContext.SourceFile> files = new ArrayList<>();
        for (String path : selection.sent()) files.add(new FixContext.SourceFile(report.name(), path, texts.get(path)));
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("proxy", report.name());
        body.put("request", asked);
        if (request.get("selection") != null) body.put("selection", request.get("selection"));
        List<ProxyDocs.SourceFile> flows = service.composedFlows(report);
        if (!flows.isEmpty()) body.put("sharedFlows", flows);
        body.put("flow", outline.text());
        body.put("files", files);
        if (!selection.unsent().isEmpty()) body.put("unsent", selection.manifest());
        if (!earlier.isEmpty()) body.put("thread", ComposeThreads.sent(earlier));
        Map<String, Object> answer = service.ask("compose", body, files);
        if (answer.containsKey("error")) return answer;
        if (!selection.unsent().isEmpty()) {
            answer.put("unsent", List.copyOf(selection.unsent().keySet()));
            answer.put("needed", selection.named(answer.get("summary") + "\n" + answer.get("warnings")));
        }
        String selected = request.get("selection") instanceof Map<?, ?> picked && picked.get("path") instanceof String p
                ? p : null;
        Map<String, Object> thread = service.threads().record(id, threadId,
                ComposeThreads.turn(asked, selected, answer), again);
        answer.put("thread", thread.get("id"));
        answer.put("turn", ComposeThreads.turns(thread).size() - 1);
        return answer;
    }

    /** What changes between two checks: {@code {analyzed, added, resolved}}. */
    private static Map<String, Object> review(Check before, Check after) {
        Map<String, Object> review = new LinkedHashMap<>();
        review.put("analyzed", after.analyzed());
        if (!after.analyzed()) {
            review.put("added", after.problems());
            review.put("resolved", 0);
            return review;
        }
        List<String> had = before.problems().stream().map(EditorService::identity).toList();
        List<String> has = after.problems().stream().map(EditorService::identity).toList();
        review.put("added", after.problems().stream().filter(p -> !had.contains(identity(p))).toList());
        review.put("resolved", had.stream().filter(p -> !has.contains(p)).count());
        return review;
    }

    private static String identity(Problem problem) {
        return problem.rule() + "\u0000" + problem.bundle() + "\u0000" + problem.file() + "\u0000" + problem.location();
    }

    private static Check check(BundleReport report, MigrationReport migration) throws IOException {
        List<Problem> problems = new ArrayList<>();
        List<Problem> general = new ArrayList<>();
        Map<String, BundleReport> bundles = FixContext.bundles(report);
        for (Finding finding : migration.findings()) {
            List<Finding.Subject> placed = placed(finding.subjects());
            if (placed.isEmpty()) general.add(problem(finding, null, null));
            for (Finding.Subject subject : placed) {
                problems.add(problem(finding, subject, subject.span() != null ? subject.span()
                        : start(bundles.get(subject.bundle()), subject.file())));
            }
        }
        for (Issue issue : report.issues()) {
            general.add(new Problem(report.name(), null, null, issue.severity().name(), null, null, issue.message(),
                    null));
        }
        return new Check(true, problems, general, null, EditorOutline.of(report));
    }

    /** One subject per file: a rule that points at a place in a file names the file as a whole too, for its context. */
    private static List<Finding.Subject> placed(List<Finding.Subject> subjects) {
        Map<String, Finding.Subject> byFile = new LinkedHashMap<>();
        for (Finding.Subject subject : subjects) {
            byFile.merge(subject.bundle() + "/" + subject.file(), subject,
                    (first, other) -> first.span() != null ? first : other);
        }
        return List.copyOf(byFile.values());
    }

    private static Problem problem(Finding finding, Finding.Subject subject, SourceMap.Span span) {
        return new Problem(subject == null ? finding.bundle() : subject.bundle(),
                subject == null ? null : subject.file(), span, finding.severity().name(), finding.rule(),
                finding.location(), finding.message(), finding.action());
    }

    /** Where to show a finding about a whole file: its first tag. */
    private static SourceMap.Span start(BundleReport bundle, String file) throws IOException {
        Path path = bundle == null ? null : Path.of(bundle.path()).resolve(file);
        if (path == null || !Files.isRegularFile(path)) return new SourceMap.Span(1, 1, 1, 1);
        return new SourceMap(new String(Files.readAllBytes(path), StandardCharsets.UTF_8)).start();
    }

    /** Where the XML the analysis reads is not well-formed. */
    private static List<Problem> syntax(String bundle, Path dir) throws IOException {
        List<Problem> problems = new ArrayList<>();
        try (Stream<Path> paths = Files.walk(dir, 2)) {
            for (Path file : paths.filter(p -> Files.isRegularFile(p) && p.toString().endsWith(".xml")).sorted().toList()) {
                String path = Xml.relativePath(dir, file);
                int slash = path.lastIndexOf('/');
                if (!ANALYZED_FOLDERS.contains(slash < 0 ? "" : path.substring(0, slash))) continue;
                Problem problem = syntax(bundle, path, new String(Files.readAllBytes(file), StandardCharsets.UTF_8));
                if (problem != null) problems.add(problem);
            }
        }
        return problems;
    }

    private static Problem syntax(String bundle, String path, String text) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            var builder = factory.newDocumentBuilder();
            builder.setErrorHandler(new DefaultHandler());
            builder.parse(new InputSource(new StringReader(text)));
            return null;
        } catch (SAXParseException e) {
            SourceMap.Span at = new SourceMap(text).line(Math.max(1, e.getLineNumber()));
            return new Problem(bundle, path, at == null ? new SourceMap.Span(1, 1, 1, 1) : at, "ERROR", null, null,
                    e.getMessage(), null);
        } catch (SAXException | IOException | javax.xml.parsers.ParserConfigurationException e) {
            return new Problem(bundle, path, new SourceMap.Span(1, 1, 1, 1), "ERROR", null, null, e.getMessage(), null);
        }
    }

    /**
     * Writes {@code {files: [{bundle?, path, content, base}]}} to the proxy and to the shared flows it calls, and records
     * them as one step of history of each bundle, after the changes made by hand before. Nothing is written when a
     * file is no longer {@code base}, the text it was opened with. A file without {@code base} is new, and must not
     * exist yet. Answers the step of the proxy, or of a shared flow when only shared flows changed.
     */
    synchronized SourceHistory.Step save(String id, Map<?, ?> request) throws IOException {
        Map<String, Path> bundles = bundles(id);
        String root = bundles.keySet().iterator().next();
        List<Buffer> files = buffers(request);
        if (files.isEmpty()) throw new UiService.UiException(400, "Nothing to save");
        Map<Path, Map<Path, String>> writes = new LinkedHashMap<>();
        Map<Path, List<String>> names = new LinkedHashMap<>();
        for (Buffer file : files) {
            String bundleName = file.bundle() == null ? root : file.bundle();
            Path bundle = bundles.get(bundleName);
            if (bundle == null) throw new UiService.UiException(404, "The proxy no longer calls " + bundleName);
            String shown = bundleName.equals(root) ? file.path() : bundleName + "/" + file.path();
            Path path = inside(bundle, file.path());
            if (file.deleted()) {
                if (!Objects.equals(text(path), file.base())) {
                    throw new UiService.UiException(409, shown + " changed since it was opened: reload the page");
                }
            } else if (file.base() == null) {
                if (Files.exists(path)) throw new UiService.UiException(409, shown + " already exists");
            } else if (!Files.isRegularFile(path)) {
                throw new UiService.UiException(404, "Unknown file " + shown);
            } else if (!Objects.equals(text(path), file.base())) {
                throw new UiService.UiException(409, shown + " changed since it was opened: reload the page");
            }
            writes.computeIfAbsent(bundle, b -> new LinkedHashMap<>()).put(path, file.deleted() ? null : file.content());
            names.computeIfAbsent(bundle, b -> new ArrayList<>()).add(file.path());
        }
        SourceHistory.Step step = null;
        for (Map.Entry<Path, Map<Path, String>> bundle : writes.entrySet()) {
            try (SourceHistory history = SourceHistory.open(bundle.getKey(), historyRoot)) {
                history.record("Manual changes");
                for (Map.Entry<Path, String> write : bundle.getValue().entrySet()) {
                    if (write.getValue() == null) {
                        Files.delete(write.getKey());
                    } else {
                        Files.createDirectories(write.getKey().getParent());
                        Files.writeString(write.getKey(), write.getValue());
                    }
                }
                List<String> saved = names.get(bundle.getKey());
                SourceHistory.Step recorded = history.record(saved.size() == 1 ? "Edit " + saved.get(0)
                        : "Edit " + saved.size() + " files");
                if (step == null || bundle.getKey().equals(bundles.get(root))) step = recorded;
            }
        }
        return step;
    }

    /**
     * What renaming a policy of the proxy changes, from the saved files; with {@code apply} true in {@code {from, to,
     * apply}} also writes it, as one step of history.
     */
    synchronized PolicyRename.Plan rename(String id, Map<?, ?> request) throws IOException {
        if (!(request.get("from") instanceof String from) || !(request.get("to") instanceof String to)) {
            throw new UiService.UiException(400, "Missing policy name");
        }
        Path bundle = service.bundleDir(id);
        Policy policy = service.analyzed(id).policies().stream().filter(p -> p.name().equals(from)).findFirst()
                .orElseThrow(() -> new UiService.UiException(404, "Unknown policy " + from));
        Map<String, String> texts = new LinkedHashMap<>();
        for (EditorFile file : files(bundle)) {
            if (file.text()) texts.put(file.path(), text(bundle.resolve(file.path())));
        }
        PolicyRename rename = new PolicyRename(from, to, policy.file());
        PolicyRename.Plan plan = rename.plan(texts);
        if (!Boolean.TRUE.equals(request.get("apply"))) return plan;
        try (SourceHistory history = SourceHistory.open(bundle, historyRoot)) {
            history.record("Manual changes");
            for (Map.Entry<String, String> changed : rename.changed().entrySet()) {
                Files.writeString(bundle.resolve(changed.getKey()), changed.getValue());
            }
            if (!plan.file().equals(policy.file())) {
                Files.move(bundle.resolve(policy.file()), bundle.resolve(plan.file()));
            }
            history.record("Rename policy " + from + " to " + to);
        }
        return plan;
    }

    /**
     * @param bundle  the bundle the file belongs to, a shared flow the proxy calls; null for the proxy
     * @param deleted true when the file goes away; it then has no content
     */
    private record Buffer(String bundle, String path, String content, String base, boolean deleted) {
    }

    private static List<Buffer> buffers(Map<?, ?> request) {
        Object list = request.containsKey("files") ? request.get("files") : request.get("buffers");
        if (!(list instanceof List<?> items)) return List.of();
        List<Buffer> buffers = new ArrayList<>();
        for (Object item : items) {
            if (item instanceof Map<?, ?> map && map.get("path") instanceof String path) {
                boolean deleted = Boolean.TRUE.equals(map.get("deleted"));
                if (!deleted && !(map.get("content") instanceof String)) continue;
                buffers.add(new Buffer(map.get("bundle") instanceof String bundle && !bundle.isBlank() ? bundle : null,
                        path, map.get("content") instanceof String content ? content : null,
                        map.get("base") instanceof String base ? base : null, deleted));
            }
        }
        return buffers;
    }

    /** A bundle-relative path, refusing anything outside the bundle. */
    private static Path inside(Path dir, String path) {
        if (path == null || path.isBlank()) throw new UiService.UiException(400, "Missing file");
        Path root = dir.toAbsolutePath().normalize();
        Path file = root.resolve(path).normalize();
        if (!file.startsWith(root) || file.equals(root)) throw new UiService.UiException(400, "Not a file of the bundle: " + path);
        return file;
    }

    private static void copyTree(Path source, Path target) throws IOException {
        try (Stream<Path> paths = Files.walk(source)) {
            for (Path path : paths.toList()) {
                Path copy = target.resolve(source.relativize(path).toString());
                if (Files.isDirectory(path)) {
                    Files.createDirectories(copy);
                } else {
                    Files.copy(path, copy);
                }
            }
        }
    }

    private static void deleteTree(Path dir) throws IOException {
        try (Stream<Path> paths = Files.walk(dir)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) Files.delete(path);
        }
    }
}
