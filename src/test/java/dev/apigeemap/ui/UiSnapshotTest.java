package dev.apigeemap.ui;

import com.sun.net.httpserver.HttpServer;
import dev.apigeemap.protocol.Envelope;
import dev.apigeemap.protocol.Json;
import dev.apigeemap.protocol.Keys;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Two workstations sharing a proxy and its shared flows through a backend that keeps snapshots. */
class UiSnapshotTest {

    private static final Path EXAMPLES = Path.of("examples").toAbsolutePath();
    private static final String JAR = "resources/java/lib.jar";

    @TempDir
    Path tmp;

    private final KeyPair keys = Keys.generate();
    private final HttpClient http = HttpClient.newHttpClient();
    private final List<String> types = new CopyOnWriteArrayList<>();
    private final Map<String, Map<Integer, byte[]>> uploads = new ConcurrentHashMap<>();
    private final Map<String, Map<String, Object>> snapshots = new ConcurrentHashMap<>();
    private HttpServer backend;
    private UiServer alice;
    private UiServer bob;
    private final byte[] jar = new byte[SnapshotService.PART * 2 + 100];

    @BeforeEach
    void start() throws Exception {
        new Random(7).nextBytes(jar);
        copy(EXAMPLES.resolve("orders-api"), tmp.resolve("a/proxies/orders-api"));
        copy(EXAMPLES.resolve("sharedflows"), tmp.resolve("a/sharedflows"));
        Path aliceJar = tmp.resolve("a/proxies/orders-api/apiproxy/" + JAR);
        Files.createDirectories(aliceJar.getParent());
        Files.write(aliceJar, jar);
        Files.createDirectories(tmp.resolve("b/proxies"));
        Files.createDirectories(tmp.resolve("b/sharedflows"));
        startBackend();
        alice = workstation(tmp.resolve("a"));
        bob = workstation(tmp.resolve("b"));
    }

    @AfterEach
    void stop() {
        if (alice != null) alice.stop();
        if (bob != null) bob.stop();
        if (backend != null) backend.stop(0);
    }

    @Test
    void sendsEveryFileAndAnotherWorkstationImportsThemWhole() throws Exception {
        HttpResponse<String> sent = send(alice, "/api/snapshots/send?id=orders-api", "{\"label\":\"before the review\"}");
        assertEquals(200, sent.statusCode(), sent.body());
        Map<?, ?> snapshot = (Map<?, ?>) ((Map<?, ?>) Json.parse(sent.body())).get("snapshot");
        String id = (String) snapshot.get("id");
        assertEquals(3, types.stream().filter("snapshotPut"::equals).count(), "the zip goes in parts");

        Map<?, ?> listed = (Map<?, ?>) Json.parse(get(bob, "/api/snapshots").body());
        Map<?, ?> seen = (Map<?, ?>) ((List<?>) listed.get("snapshots")).get(0);
        assertEquals("orders-api", seen.get("proxy"));
        assertEquals(false, seen.get("local"));

        Map<?, ?> preview = (Map<?, ?>) Json.parse(send(bob, "/api/snapshots/import?id=" + id, "").body());
        List<?> bundles = (List<?>) preview.get("bundles");
        assertEquals(List.of("orders-api", "sf-logging", "sf-security"),
                bundles.stream().map(b -> ((Map<?, ?>) b).get("name")).toList());
        assertTrue(bundles.stream().noneMatch(b -> Boolean.TRUE.equals(((Map<?, ?>) b).get("exists"))));
        assertFalse(Files.exists(tmp.resolve("b/proxies/orders-api")), "a preview writes nothing");
        long gets = types.stream().filter("snapshotGet"::equals).count();

        HttpResponse<String> imported = send(bob, "/api/snapshots/import?id=" + id + "&apply=true", "");
        assertEquals(200, imported.statusCode(), imported.body());
        assertEquals("orders-api", ((Map<?, ?>) Json.parse(imported.body())).get("proxyId"));
        assertEquals(gets, types.stream().filter("snapshotGet"::equals).count(), "the zip fetched once is kept");
        assertSameTree(tmp.resolve("a/proxies/orders-api/apiproxy"), tmp.resolve("b/proxies/orders-api/apiproxy"));
        assertSameTree(tmp.resolve("a/sharedflows/sf-logging/sharedflowbundle"),
                tmp.resolve("b/sharedflows/sf-logging/sharedflowbundle"));
        assertArrayEquals(jar, Files.readAllBytes(tmp.resolve("b/proxies/orders-api/apiproxy/" + JAR)));

        // Bob changes and adds files; importing again puts back the snapshot, as a step he can undo
        Path policy = tmp.resolve("b/proxies/orders-api/apiproxy/policies/FC-Logging.xml");
        String original = Files.readString(policy);
        Files.writeString(policy, original.replace("sf-logging", "sf-other"));
        Files.writeString(tmp.resolve("b/proxies/orders-api/apiproxy/policies/Extra.xml"), "<AssignMessage/>");
        preview = (Map<?, ?>) Json.parse(send(bob, "/api/snapshots/import?id=" + id, "").body());
        Map<?, ?> proxy = (Map<?, ?>) ((List<?>) preview.get("bundles")).get(0);
        assertEquals(List.of("policies/FC-Logging.xml"), proxy.get("changed"));
        assertEquals(List.of("policies/Extra.xml"), proxy.get("removed"));
        assertEquals(List.of(), ((Map<?, ?>) ((List<?>) preview.get("bundles")).get(1)).get("changed"));
        Map<?, ?> done = (Map<?, ?>) Json.parse(send(bob, "/api/snapshots/import?id=" + id + "&apply=true", "").body());
        assertEquals(List.of("orders-api"), done.get("written"), "unchanged shared flows are left alone");
        assertEquals(original, Files.readString(policy));
        assertFalse(Files.exists(tmp.resolve("b/proxies/orders-api/apiproxy/policies/Extra.xml")));
        String history = get(bob, "/api/history?id=orders-api").body();
        assertTrue(history.contains("Snapshot imported: before the review"), history);
        assertTrue(history.contains("\"original\": true") || history.contains("\"original\":true"), "Bob's edits are kept in the step before");

        // the download is the zip as sent
        HttpResponse<byte[]> zip = http.send(HttpRequest.newBuilder(URI.create(bob.url() + "api/snapshots/download?id="
                + id)).build(), HttpResponse.BodyHandlers.ofByteArray());
        assertEquals(200, zip.statusCode());
        assertTrue(zip.headers().firstValue("Content-Disposition").orElse("").contains("orders-api-"));
        assertEquals(snapshot.get("sha256"), SnapshotService.sha256(zip.body()));

        assertEquals(200, send(bob, "/api/snapshots/delete?id=" + id, "").statusCode());
        assertTrue(snapshots.isEmpty());
    }

    private UiServer workstation(Path dir) throws Exception {
        Path settings = dir.resolve("settings.json");
        new Settings(dir.resolve("proxies").toString(), List.of(dir.resolve("sharedflows").toString()),
                dir.resolve("out").toString(), List.of(), Map.of(), Map.of(), List.of()).save(settings);
        Path config = dir.resolve("backend.properties");
        Files.writeString(config, "url=http://127.0.0.1:" + backend.getAddress().getPort() + "\npublicKey="
                + Keys.encode(keys.getPublic()) + "\n");
        UiServer server = UiServer.start(settings, dir.resolve("history"), config, 0);
        send(server, "/api/token", "{\"token\":\"t\"}", "PUT");
        return server;
    }

    /** A backend keeping snapshots as the real one does, without its checks. */
    private void startBackend() throws IOException {
        backend = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        backend.createContext("/v1/exchange", exchange -> {
            try (exchange) {
                Envelope.Opened opened = Envelope.open(keys.getPrivate(), Keys.keyId(keys.getPublic()),
                        exchange.getRequestBody().readAllBytes());
                Map<?, ?> request = (Map<?, ?>) Json.parse(new String(opened.plaintext(), StandardCharsets.UTF_8));
                String type = (String) request.get("type");
                Map<?, ?> body = (Map<?, ?>) request.get("body");
                types.add(type);
                Object answer = switch (type) {
                    case "snapshotPut" -> put(body);
                    case "snapshotList" -> Map.of("snapshots", new ArrayList<>(snapshots.values()));
                    case "snapshotGet" -> {
                        Map<String, Object> s = snapshots.get((String) body.get("id"));
                        int index = ((Number) body.get("index")).intValue();
                        yield Map.of("snapshot", s, "index", index, "data", Base64.getEncoder().encodeToString(
                                uploads.get((String) body.get("id")).get(index)));
                    }
                    case "snapshotDelete" -> {
                        snapshots.remove((String) body.get("id"));
                        yield Map.of("deleted", body.get("id"));
                    }
                    default -> throw new IllegalStateException(type);
                };
                Map<String, Object> reply = new LinkedHashMap<>();
                reply.put("id", request.get("id"));
                reply.put("ok", true);
                reply.put("body", answer);
                byte[] sealed = opened.exchange().sealResponse(Json.write(reply).getBytes(StandardCharsets.UTF_8));
                exchange.sendResponseHeaders(200, sealed.length);
                try (OutputStream out = exchange.getResponseBody()) {
                    out.write(sealed);
                }
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        });
        backend.start();
    }

    private Map<String, Object> put(Map<?, ?> body) {
        String id = body.get("upload") instanceof String upload ? upload : UUID.randomUUID().toString();
        int index = ((Number) body.get("index")).intValue();
        int parts = ((Number) body.get("parts")).intValue();
        uploads.computeIfAbsent(id, k -> new ConcurrentHashMap<>())
                .put(index, Base64.getDecoder().decode((String) body.get("data")));
        if (index < parts - 1) return Map.of("upload", id, "received", index);
        ByteArrayOutputStream all = new ByteArrayOutputStream();
        for (int i = 0; i < parts; i++) all.writeBytes(uploads.get(id).get(i));
        assertEquals(body.get("sha256"), SnapshotService.sha256(all.toByteArray()));
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("id", id);
        snapshot.put("proxy", body.get("proxy"));
        snapshot.put("label", body.get("label"));
        snapshot.put("size", body.get("size"));
        snapshot.put("sha256", body.get("sha256"));
        snapshot.put("parts", parts);
        snapshot.put("created", "2026-11-10T10:00:00Z");
        snapshot.put("from", "abc");
        snapshot.put("bundles", body.get("bundles"));
        snapshot.put("mine", false);
        snapshots.put(id, snapshot);
        return Map.of("snapshot", snapshot);
    }

    private static void assertSameTree(Path expected, Path actual) throws IOException {
        List<String> left = files(expected);
        assertEquals(left, files(actual));
        for (String file : left) {
            assertArrayEquals(Files.readAllBytes(expected.resolve(file)), Files.readAllBytes(actual.resolve(file)), file);
        }
    }

    private static List<String> files(Path dir) throws IOException {
        try (Stream<Path> walk = Files.walk(dir)) {
            return walk.filter(Files::isRegularFile).map(p -> dir.relativize(p).toString().replace('\\', '/')).sorted().toList();
        }
    }

    private static void copy(Path from, Path to) throws IOException {
        try (Stream<Path> paths = Files.walk(from)) {
            for (Path path : paths.sorted(Comparator.naturalOrder()).toList()) {
                Path target = to.resolve(from.relativize(path).toString());
                if (Files.isDirectory(path)) Files.createDirectories(target);
                else Files.copy(path, target);
            }
        }
    }

    private HttpResponse<String> get(UiServer server, String path) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create(server.url() + path.substring(1))).build(),
                HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> send(UiServer server, String path, String body) throws Exception {
        return send(server, path, body, "POST");
    }

    private HttpResponse<String> send(UiServer server, String path, String body, String method) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create(server.url() + path.substring(1)))
                .method(method, HttpRequest.BodyPublishers.ofString(body)).header(UiServer.CSRF_HEADER, "1").build(),
                HttpResponse.BodyHandlers.ofString());
    }
}
