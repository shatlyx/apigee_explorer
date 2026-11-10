package dev.apigeemap.ui;

import dev.apigeemap.analysis.BundleAnalyzer;
import dev.apigeemap.analysis.SharedFlowRepository;
import dev.apigeemap.analysis.Xml;
import dev.apigeemap.history.SourceHistory;
import dev.apigeemap.migration.FixContext;
import dev.apigeemap.model.BundleReport;
import dev.apigeemap.model.BundleType;
import dev.apigeemap.model.SharedFlowLink;
import dev.apigeemap.protocol.BackendClient;
import dev.apigeemap.protocol.Json;
import org.w3c.dom.Element;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * Snapshots: the whole of a proxy and of the shared flows it calls, every file as it is on disk, sent to the backend
 * as one zip so that another workstation of the team gets it back whole, to download or to import.
 *
 * <p>The zip holds the proxy under its own folder ({@code apiproxy/}) and each shared flow under
 * {@code sharedflows/<name>/sharedflowbundle/}. It goes in parts of {@link #PART} bytes, one exchange each, every one
 * of them made because the user asked (Send, Download, Import, Delete, opening the list). A zip sent or fetched once
 * is kept in {@code snapshots/} next to the history, as a snapshot never changes: downloading or importing it again
 * calls nothing.
 */
final class SnapshotService {

    /** As the backend: bytes of zip per exchange, and exchanges per snapshot. */
    static final int PART = 750_000;
    static final int MAX_PARTS = 70;
    /** Zips kept in the cache, the most recent ones. */
    static final int KEPT = 10;
    private static final String SHARED_FLOWS = "sharedflows/";
    private static final Set<String> NOISE = Set.of(".DS_Store", "Thumbs.db");
    private static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyyyMMdd-HHmm")
            .withZone(ZoneId.systemDefault());

    /** A zip of a proxy and its shared flows, what it holds, and the shared flows it could not find. */
    record Zipped(byte[] bytes, int files, List<Map<String, Object>> bundles, List<String> missing) {
    }

    /** The bytes of a snapshot and its description as the backend keeps it. */
    record Fetched(byte[] bytes, Map<String, Object> snapshot) {
    }

    private final UiService service;
    private final Path cache;

    SnapshotService(UiService service) {
        this.service = service;
        this.cache = service.historyRoot().toAbsolutePath().normalize().resolveSibling("snapshots");
    }

    /** Zips every file of the proxy and of the shared flows it calls, at any depth, as they are on disk. */
    static Zipped zip(BundleReport root) throws IOException {
        Map<String, BundleReport> bundles = FixContext.bundles(root);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        List<Map<String, Object>> described = new ArrayList<>();
        int files = 0;
        try (ZipOutputStream zip = new ZipOutputStream(out)) {
            for (BundleReport bundle : bundles.values()) {
                Path base = Path.of(bundle.path()).toAbsolutePath().normalize();
                String prefix = bundle != root ? SHARED_FLOWS + bundle.name() + "/sharedflowbundle/"
                        : bundle.type() == BundleType.SHARED_FLOW ? "sharedflowbundle/" : "apiproxy/";
                List<Path> paths;
                try (Stream<Path> walk = Files.walk(base)) {
                    paths = walk.filter(Files::isRegularFile).sorted().toList();
                }
                for (Path file : paths) {
                    ZipEntry entry = new ZipEntry(prefix + Xml.relativePath(base, file));
                    entry.setLastModifiedTime(Files.getLastModifiedTime(file));
                    zip.putNextEntry(entry);
                    Files.copy(file, zip);
                    zip.closeEntry();
                    files++;
                }
                described.add(Map.of("name", bundle.name(), "type", bundle.type().label()));
            }
        }
        Set<String> missing = new LinkedHashSet<>();
        for (BundleReport bundle : bundles.values()) {
            for (SharedFlowLink link : bundle.sharedFlows()) {
                if (link.status() != SharedFlowLink.Status.RESOLVED) missing.add(link.name());
            }
        }
        return new Zipped(out.toByteArray(), files, described, List.copyOf(missing));
    }

    /** Sends the proxy as it is saved, with its shared flows: {@code {snapshot, files, missing}}. */
    Map<String, Object> send(String id, String label) throws IOException {
        if (label != null && label.length() > 200) throw new UiService.UiException(400, "The label takes 200 characters at most");
        BundleReport analysis = service.analyzed(id);
        Zipped zipped = zip(analysis);
        byte[] bytes = zipped.bytes();
        if (bytes.length > (long) PART * MAX_PARTS) {
            throw new UiService.UiException(413, "This proxy and its shared flows make a zip of "
                    + bytes.length / (1024 * 1024) + " MiB: a snapshot takes " + PART * MAX_PARTS / (1024 * 1024)
                    + " MiB at most");
        }
        BackendClient backend = service.backend();
        int parts = Math.max(1, (bytes.length + PART - 1) / PART);
        String upload = null;
        Map<?, ?> answer = Map.of();
        for (int i = 0; i < parts; i++) {
            Map<String, Object> body = new LinkedHashMap<>();
            if (upload != null) body.put("upload", upload);
            body.put("index", i);
            body.put("parts", parts);
            body.put("data", Base64.getEncoder().encodeToString(
                    Arrays.copyOfRange(bytes, i * PART, Math.min(bytes.length, (i + 1) * PART))));
            if (i == parts - 1) {
                body.put("proxy", analysis.name());
                body.put("label", label == null ? "" : label.strip());
                body.put("size", bytes.length);
                body.put("sha256", sha256(bytes));
                body.put("bundles", zipped.bundles());
            }
            answer = map(call(backend, "snapshotPut", body));
            if (upload == null && answer.get("upload") instanceof String started) upload = started;
        }
        Map<String, Object> snapshot = strings(map(answer.get("snapshot")));
        keep(String.valueOf(snapshot.get("id")), bytes, snapshot);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("snapshot", snapshot);
        result.put("files", zipped.files());
        result.put("missing", zipped.missing());
        return result;
    }

    /** The snapshots of the team, the most recent first, each telling whether its zip is already here. */
    Map<String, Object> list() throws IOException {
        Map<?, ?> answer = map(call(service.backend(), "snapshotList", Map.of()));
        List<Map<String, Object>> snapshots = new ArrayList<>();
        if (answer.get("snapshots") instanceof List<?> listed) {
            for (Object item : listed) {
                Map<String, Object> snapshot = strings(map(item));
                snapshot.put("local", kept(String.valueOf(snapshot.get("id"))).isPresent());
                snapshots.add(snapshot);
            }
        }
        return Map.of("snapshots", snapshots);
    }

    /** The zip of a snapshot, from the cache or else from the backend, part after part, checked. */
    Fetched fetch(String id) throws IOException {
        checkId(id);
        Optional<Fetched> kept = kept(id);
        if (kept.isPresent()) return kept.get();
        BackendClient backend = service.backend();
        Map<?, ?> first = map(call(backend, "snapshotGet", Map.of("id", id, "index", 0)));
        Map<String, Object> snapshot = strings(map(first.get("snapshot")));
        int parts = snapshot.get("parts") instanceof Number n ? n.intValue() : 1;
        ByteArrayOutputStream all = new ByteArrayOutputStream();
        all.writeBytes(Base64.getDecoder().decode(String.valueOf(first.get("data"))));
        for (int i = 1; i < parts; i++) {
            Map<?, ?> part = map(call(backend, "snapshotGet", Map.of("id", id, "index", i)));
            all.writeBytes(Base64.getDecoder().decode(String.valueOf(part.get("data"))));
        }
        byte[] bytes = all.toByteArray();
        if (!sha256(bytes).equals(snapshot.get("sha256"))) {
            throw new UiService.UiException(502, "The snapshot did not arrive whole: try again");
        }
        keep(id, bytes, snapshot);
        return new Fetched(bytes, snapshot);
    }

    /** The zip to save, named after the proxy and the time of the snapshot. */
    record Download(String fileName, byte[] bytes) {
    }

    Download download(String id) throws IOException {
        Fetched fetched = fetch(id);
        String proxy = String.valueOf(fetched.snapshot().get("proxy")).replaceAll("[^A-Za-z0-9._-]", "_");
        Instant created = Instant.parse(String.valueOf(fetched.snapshot().get("created")));
        return new Download(proxy + "-" + STAMP.format(created) + ".zip", fetched.bytes());
    }

    /** Deletes a snapshot for the whole team, and its zip here. */
    Map<String, Object> delete(String id) throws IOException {
        checkId(id);
        call(service.backend(), "snapshotDelete", Map.of("id", id));
        Files.deleteIfExists(cache.resolve(id + ".zip"));
        Files.deleteIfExists(cache.resolve(id + ".json"));
        return Map.of("deleted", id);
    }

    /**
     * What importing a snapshot does, bundle by bundle: where it goes, whether it exists, and the files it adds,
     * changes and removes there ({@code apply} false); or does it ({@code apply} true): each bundle that exists and
     * changes is written as one history step, so it can be undone, after a step for changes not recorded yet. A
     * bundle is written whole: files the snapshot does not hold are removed.
     */
    Map<String, Object> importSnapshot(String id, boolean apply) throws IOException {
        Fetched fetched = fetch(id);
        Map<String, Object> snapshot = fetched.snapshot();
        Map<String, Map<String, ZipFile>> content = unzip(fetched.bytes());
        String proxy = String.valueOf(snapshot.get("proxy"));
        List<Target> targets = targets(proxy, content);
        Path proxyBundle = targets.get(0).folder();

        List<Map<String, Object>> bundles = new ArrayList<>();
        for (Target target : targets) {
            Map<String, Object> b = new LinkedHashMap<>();
            b.put("name", target.name());
            b.put("type", target.root() ? "API proxy" : "Shared flow");
            b.put("folder", target.folder().toString());
            b.put("exists", target.exists());
            b.put("added", target.added());
            b.put("changed", target.changed());
            b.put("removed", target.removed());
            if (!target.root() && target.exists() && Files.isDirectory(proxyBundle)) {
                b.put("callers", service.callers(target.folder(), proxyBundle));
            }
            bundles.add(b);
        }
        Map<String, Object> answer = new LinkedHashMap<>();
        answer.put("snapshot", snapshot);
        answer.put("bundles", bundles);
        if (!apply) {
            if (targets.get(0).exists()) answer.put("proxyId", service.proxyId(proxyBundle.getParent()));
            return answer;
        }

        List<String> written = new ArrayList<>();
        synchronized (service) {
            for (Target target : targets) {
                if (target.exists() && !target.differs()) continue;
                write(target, snapshot);
                written.add(target.name());
            }
        }
        answer.put("written", written);
        answer.put("proxyId", service.proxyId(proxyBundle.getParent()));
        return answer;
    }

    /** A file of the zip. */
    private record ZipFile(byte[] bytes, FileTime time) {
    }

    /** Where a bundle of the snapshot goes, and how it differs from what is there. */
    private record Target(String name, boolean root, Path folder, boolean exists, Map<String, ZipFile> files,
                          List<String> added, List<String> changed, List<String> removed) {

        boolean differs() {
            return !added.isEmpty() || !changed.isEmpty() || !removed.isEmpty();
        }
    }

    /**
     * The proxy goes to the proxy of the proxies folder of the same name, or else to a new folder named after it; a
     * shared flow to the shared flow of the same name in the shared flow folders, or else to a new folder in the first
     * one.
     */
    private List<Target> targets(String proxy, Map<String, Map<String, ZipFile>> content) throws IOException {
        List<Target> targets = new ArrayList<>();
        Map.Entry<String, Map<String, ZipFile>> root = content.entrySet().stream()
                .filter(e -> !e.getKey().startsWith(SHARED_FLOWS)).findFirst()
                .orElseThrow(() -> new UiService.UiException(422, "The snapshot holds no proxy"));
        Path proxyFolder = root.getKey().equals("apiproxy") ? proxyFolder(proxy) : null;
        List<Path> flowFolders = service.sharedFlowFolders();
        SharedFlowRepository repository = flowFolders.isEmpty() ? SharedFlowRepository.empty()
                : SharedFlowRepository.scan(flowFolders);
        if (proxyFolder == null) proxyFolder = flowFolder(proxy, repository, flowFolders);
        targets.add(target(proxy, true, proxyFolder, root.getValue()));
        for (Map.Entry<String, Map<String, ZipFile>> flow : content.entrySet()) {
            if (!flow.getKey().startsWith(SHARED_FLOWS)) continue;
            String name = flow.getKey().substring(SHARED_FLOWS.length());
            targets.add(target(name, false, flowFolder(name, repository, flowFolders), flow.getValue()));
        }
        return targets;
    }

    private Path proxyFolder(String proxy) throws IOException {
        Path rootFolder = service.proxiesRoot();
        Path named = null;
        for (Path dir : service.proxyFolders()) {
            Path bundle = dir.resolve("apiproxy");
            try {
                Element descriptor = BundleAnalyzer.descriptor(bundle);
                if (descriptor != null && proxy.equals(Xml.attr(descriptor, "name"))) {
                    if (dir.getFileName().toString().equals(proxy)) return bundle;
                    if (named == null) named = bundle;
                }
            } catch (IOException | RuntimeException e) {
                // a proxy whose descriptor cannot be read is not the one
            }
        }
        return named != null ? named : rootFolder.resolve(folderName(proxy)).resolve("apiproxy");
    }

    private static Path flowFolder(String name, SharedFlowRepository repository, List<Path> folders) {
        Optional<Path> found = repository.find(name);
        if (found.isPresent()) return found.get().toAbsolutePath().normalize();
        if (folders.isEmpty()) {
            throw new UiService.UiException(409, "Set a shared flows folder in Settings first: the snapshot holds "
                    + "the shared flow " + name);
        }
        return folders.get(0).toAbsolutePath().normalize().resolve(folderName(name)).resolve("sharedflowbundle");
    }

    private static Target target(String name, boolean root, Path folder, Map<String, ZipFile> files) throws IOException {
        List<String> added = new ArrayList<>();
        List<String> changed = new ArrayList<>();
        List<String> removed = new ArrayList<>();
        boolean exists = Files.isDirectory(folder);
        Map<String, Path> onDisk = new TreeMap<>();
        if (exists) {
            try (Stream<Path> walk = Files.walk(folder)) {
                walk.filter(Files::isRegularFile).filter(p -> !NOISE.contains(p.getFileName().toString()))
                        .forEach(p -> onDisk.put(Xml.relativePath(folder, p), p));
            }
        }
        for (Map.Entry<String, ZipFile> file : files.entrySet()) {
            Path there = onDisk.get(file.getKey());
            if (there == null) added.add(file.getKey());
            else if (!Arrays.equals(Files.readAllBytes(there), file.getValue().bytes())) changed.add(file.getKey());
        }
        for (String path : onDisk.keySet()) if (!files.containsKey(path)) removed.add(path);
        return new Target(name, root, folder, exists, files, added, changed, removed);
    }

    private void write(Target target, Map<String, Object> snapshot) throws IOException {
        Path folder = target.folder();
        SourceHistory history = target.exists() ? SourceHistory.open(folder, service.historyRoot()) : null;
        try {
            if (history != null) history.record("Manual changes");
            for (String path : target.removed()) Files.deleteIfExists(folder.resolve(path));
            for (Map.Entry<String, ZipFile> file : target.files().entrySet()) {
                Path path = folder.resolve(file.getKey()).normalize();
                if (!path.startsWith(folder)) throw new IOException("Unsafe path in the snapshot: " + file.getKey());
                Files.createDirectories(path.getParent());
                Files.write(path, file.getValue().bytes());
                if (file.getValue().time() != null) Files.setLastModifiedTime(path, file.getValue().time());
            }
            removeEmptyFolders(folder);
            if (history != null) {
                String label = String.valueOf(snapshot.getOrDefault("label", ""));
                history.record("Snapshot imported" + (label.isBlank() ? "" : ": " + label) + "\n\nSent "
                        + snapshot.get("created") + (Boolean.TRUE.equals(snapshot.get("mine"))
                        ? " from this workstation" : " from another workstation") + ", " + target.added().size()
                        + " added, " + target.changed().size() + " changed, " + target.removed().size() + " removed");
            }
        } finally {
            if (history != null) history.close();
        }
    }

    private static void removeEmptyFolders(Path folder) throws IOException {
        List<Path> dirs;
        try (Stream<Path> walk = Files.walk(folder)) {
            dirs = walk.filter(Files::isDirectory).filter(d -> !d.equals(folder))
                    .sorted(Comparator.reverseOrder()).toList();
        }
        for (Path dir : dirs) {
            try (Stream<Path> inside = Files.list(dir)) {
                if (inside.findAny().isEmpty()) Files.delete(dir);
            }
        }
    }

    /**
     * The files of the zip by bundle: the proxy under the name of its folder ({@code apiproxy}), each shared flow under
     * {@code sharedflows/<name>}; paths inside the bundle.
     */
    static Map<String, Map<String, ZipFile>> unzip(byte[] bytes) throws IOException {
        Map<String, Map<String, ZipFile>> bundles = new LinkedHashMap<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            for (ZipEntry entry; (entry = zip.getNextEntry()) != null; ) {
                if (entry.isDirectory()) continue;
                String name = entry.getName().replace('\\', '/');
                if (name.startsWith("/") || Arrays.asList(name.split("/")).contains("..")) {
                    throw new UiService.UiException(422, "Unsafe entry in the snapshot: " + name);
                }
                String bundle;
                String path;
                if (name.startsWith(SHARED_FLOWS)) {
                    String[] parts = name.split("/", 4);
                    if (parts.length < 4 || !parts[2].equals("sharedflowbundle") || parts[1].isBlank()) {
                        throw new UiService.UiException(422, "Unexpected entry in the snapshot: " + name);
                    }
                    bundle = SHARED_FLOWS + parts[1];
                    path = parts[3];
                } else if (name.startsWith("apiproxy/") || name.startsWith("sharedflowbundle/")) {
                    bundle = name.substring(0, name.indexOf('/'));
                    path = name.substring(bundle.length() + 1);
                } else {
                    throw new UiService.UiException(422, "Unexpected entry in the snapshot: " + name);
                }
                bundles.computeIfAbsent(bundle, b -> new TreeMap<>())
                        .put(path, new ZipFile(zip.readAllBytes(), entry.getLastModifiedTime()));
            }
        }
        if (bundles.keySet().stream().filter(b -> !b.startsWith(SHARED_FLOWS)).count() != 1) {
            throw new UiService.UiException(422, "The snapshot does not hold one proxy");
        }
        return bundles;
    }

    private Optional<Fetched> kept(String id) {
        Path zip = cache.resolve(id + ".zip");
        Path meta = cache.resolve(id + ".json");
        if (!Files.isRegularFile(zip) || !Files.isRegularFile(meta)) return Optional.empty();
        try {
            Map<String, Object> snapshot = strings(map(Json.parse(Files.readString(meta))));
            byte[] bytes = Files.readAllBytes(zip);
            return sha256(bytes).equals(snapshot.get("sha256")) ? Optional.of(new Fetched(bytes, snapshot))
                    : Optional.empty();
        } catch (IOException | RuntimeException e) {
            return Optional.empty();
        }
    }

    /** Keeps a zip, and only the {@link #KEPT} most recent ones. */
    private void keep(String id, byte[] bytes, Map<String, Object> snapshot) {
        try {
            checkId(id);
            Files.createDirectories(cache);
            Files.write(cache.resolve(id + ".zip"), bytes);
            Map<String, Object> meta = new LinkedHashMap<>(snapshot);
            meta.remove("mine");
            meta.remove("local");
            Files.writeString(cache.resolve(id + ".json"), Json.write(meta));
            List<Path> zips;
            try (Stream<Path> files = Files.list(cache)) {
                zips = files.filter(p -> p.getFileName().toString().endsWith(".zip"))
                        .sorted(Comparator.comparing((Path p) -> {
                            try {
                                return Files.getLastModifiedTime(p);
                            } catch (IOException e) {
                                throw new UncheckedIOException(e);
                            }
                        }).reversed()).toList();
            }
            for (Path old : zips.subList(Math.min(KEPT, zips.size()), zips.size())) {
                String name = old.getFileName().toString();
                Files.deleteIfExists(old);
                Files.deleteIfExists(cache.resolve(name.substring(0, name.length() - 4) + ".json"));
            }
        } catch (IOException | RuntimeException e) {
            // the cache only saves calls
            System.err.println("snapshot cache: " + e.getMessage());
        }
    }

    private static Object call(BackendClient backend, String type, Object body) {
        try {
            return backend.call(type, body);
        } catch (IOException | RuntimeException e) {
            BackendClient.report(e instanceof IOException io ? io : new IOException(e.getMessage(), e), System.err);
            throw new UiService.UiException(502, String.valueOf(e.getMessage()));
        }
    }

    private static void checkId(String id) {
        if (id == null || !id.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")) {
            throw new UiService.UiException(400, "Unknown snapshot");
        }
    }

    private static String folderName(String name) {
        String safe = name.replaceAll("[^A-Za-z0-9._-]", "_");
        if (safe.isBlank() || safe.equals(".") || safe.equals("..")) throw new UiService.UiException(422, "Bad name: " + name);
        return safe;
    }

    private static Map<?, ?> map(Object value) {
        if (value instanceof Map<?, ?> m) return m;
        throw new UiService.UiException(502, "Unexpected answer from the backend");
    }

    private static Map<String, Object> strings(Map<?, ?> map) {
        Map<String, Object> out = new LinkedHashMap<>();
        map.forEach((k, v) -> out.put(String.valueOf(k), v));
        return out;
    }

    static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
