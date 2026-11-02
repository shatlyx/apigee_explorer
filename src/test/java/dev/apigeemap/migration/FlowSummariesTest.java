package dev.apigeemap.migration;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FlowSummariesTest {

    @TempDir
    Path dir;

    private static ProxyDocs.SourceFile file(String bundle, String path, int size) {
        return new ProxyDocs.SourceFile(bundle, path, "x".repeat(size));
    }

    private static final List<ProxyDocs.SourceFile> FILES = List.of(
            file("orders-api", "proxies/default.xml", 20_000),
            file("sf-security", "sharedflowbundle/policies/VK.xml", 6_000),
            file("sf-security", "sharedflowbundle/sharedflows/default.xml", 4_000),
            file("sf-logging", "sharedflowbundle/policies/ML.xml", 500));

    private static Map<String, Object> summary(String name) {
        return Map.of("name", name, "purpose", "Checks the API key.",
                "steps", List.of(Map.of("policy", "VK-Check", "type", "VerifyAPIKey", "condition", "",
                        "does", "Reads `request.header.x-api-key`.")),
                "reads", List.of(), "sets", List.of("`verifyapikey.VK-Check.app.name`"),
                "errors", List.of("401 `InvalidApiKey`"), "dependencies", List.of(), "notes", List.of());
    }

    @Test
    void sendsALargeSharedFlowAsItsSummaryAndAsksItOnce() {
        List<Object> asked = new ArrayList<>();
        FlowSummaries.Backend backend = body -> {
            asked.add(body);
            return Map.of("summaries", List.of(summary("sf-security"), summary("sf-logging")), "warnings", List.of());
        };
        FlowSummaries summaries = FlowSummaries.at(dir);

        List<ProxyDocs.SourceFile> sent = summaries.substitute("orders-api", FILES, backend, System.err);

        assertEquals(1, asked.size());
        List<?> flows = (List<?>) ((Map<?, ?>) asked.get(0)).get("sharedFlows");
        assertEquals(List.of("sf-security"), flows.stream().map(f -> ((Map<?, ?>) f).get("name")).toList(),
                "the proxy itself and small flows are sent as they are");
        assertEquals(List.of("orders-api/proxies/default.xml", "sf-security/" + FlowSummaries.PATH,
                        "sf-logging/sharedflowbundle/policies/ML.xml"),
                sent.stream().map(f -> f.bundle() + "/" + f.path()).toList());
        assertEquals("""
                Summary of the shared flow sf-security, sent instead of its 2 file(s) (10000 characters).
                Purpose: Checks the API key.
                Steps, in run order:
                - `VK-Check` (VerifyAPIKey): Reads `request.header.x-api-key`.
                Sets:
                - `verifyapikey.VK-Check.app.name`
                Errors:
                - 401 `InvalidApiKey`
                """, sent.get(1).content());

        assertEquals(sent, summaries.substitute("orders-api", FILES, body -> {
            throw new AssertionError("kept from the first time");
        }, System.err));
    }

    @Test
    void asksAgainWhenTheFlowChanged() {
        FlowSummaries summaries = FlowSummaries.at(dir);
        summaries.substitute("orders-api", FILES, body -> Map.of("summaries", List.of(summary("sf-security"))),
                System.err);
        List<ProxyDocs.SourceFile> changed = new ArrayList<>(FILES);
        changed.set(1, file("sf-security", "sharedflowbundle/policies/VK.xml", 6_001));
        List<Object> asked = new ArrayList<>();

        summaries.substitute("orders-api", changed, body -> {
            asked.add(body);
            return Map.of("summaries", List.of(summary("sf-security")));
        }, System.err);

        assertEquals(1, asked.size());
    }

    @Test
    void sendsTheFilesWhenTheBackendCannotSummarize() {
        ByteArrayOutputStream err = new ByteArrayOutputStream();
        List<ProxyDocs.SourceFile> sent = FlowSummaries.at(dir).substitute("orders-api", FILES, body -> {
            throw new IOException("Unknown operation: summarize");
        }, new PrintStream(err, true));

        assertEquals(FILES, sent);
        assertTrue(err.toString().contains("Unknown operation: summarize"), err.toString());
    }

    @Test
    void doesNotSummarizeTheSharedFlowBeingDocumented() {
        List<ProxyDocs.SourceFile> files = FILES.subList(1, 4);
        List<ProxyDocs.SourceFile> sent = FlowSummaries.at(dir).substitute("sf-security", files, body -> {
            throw new AssertionError("nothing to summarize");
        }, System.err);
        assertEquals(files, sent);
    }
}
