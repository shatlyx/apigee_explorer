package dev.apigeemap.ui;

import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ComposeSelectionTest {

    private static final String BIG = "x".repeat(50_000);

    private static Map<String, String> proxy() {
        Map<String, String> files = new LinkedHashMap<>();
        files.put("policies/JS-SelectIdp.xml",
                "<Javascript name=\"JS-SelectIdp\"><IncludeURL>jsc://lib.js</IncludeURL>"
                        + "<ResourceURL>jsc://selectIdp.js</ResourceURL></Javascript>");
        files.put("policies/AM-Set.xml", "<AssignMessage/>");
        files.put("proxies/default.xml", "<ProxyEndpoint/>");
        files.put("resources/jsc/lib.js", "var Lib = {};" + "//".repeat(20_000));
        files.put("resources/jsc/selectIdp.js", "function pick() { context.setVariable('idp.name', "
                + "context.getVariable('request.header.host')); }\n//" + BIG);
        files.put("resources/jsc/small.js", "function tiny() {}");
        files.put("resources/xsd/order.xsd", "<xs:schema><xs:element name=\"Order\"/><xs:complexType name=\"Line\"/>"
                + "<!--" + BIG + "--></xs:schema>");
        return files;
    }

    @Test
    void sendsEverythingWhenItFits() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(), "anything", Set.of(), Set.of(), 1_000_000);

        assertEquals(List.copyOf(proxy().keySet()), selection.sent());
        assertTrue(selection.unsent().isEmpty());
    }

    @Test
    void sendsTheScriptTheRequestNamesAndOutlinesTheOthers() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(),
                "à quoi sert selectIdp.js, quels problèmes présente-t-il ?", Set.of(), Set.of(), 100_000);

        assertEquals(List.of("policies/JS-SelectIdp.xml", "policies/AM-Set.xml", "proxies/default.xml",
                "resources/jsc/selectIdp.js", "resources/jsc/small.js"), selection.sent());
        assertEquals(Set.of("resources/jsc/lib.js", "resources/xsd/order.xsd"), selection.unsent().keySet());
        assertTrue(selection.unsent().get("resources/xsd/order.xsd").contains("element Order; complexType Line"),
                selection.manifest());
    }

    @Test
    void aNamedPolicyBringsItsScripts() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(), "Explain JS-SelectIdp", Set.of(), Set.of(),
                120_000);

        assertTrue(selection.sent().containsAll(List.of("resources/jsc/lib.js", "resources/jsc/selectIdp.js")));
        assertEquals(Set.of("resources/xsd/order.xsd"), selection.unsent().keySet());
    }

    @Test
    void theOpenFileAndTheFilesAskedAgainAreSent() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(), "Review this",
                Set.of("resources/xsd/order.xsd"), Set.of("resources/jsc/lib.js"), 120_000);

        assertTrue(selection.sent().containsAll(List.of("resources/xsd/order.xsd", "resources/jsc/lib.js")));
        assertEquals(Set.of("resources/jsc/selectIdp.js"), selection.unsent().keySet());
    }

    @Test
    void aStemInsideALongerNameIsNotAMention() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(), "rename selectIdpV2 and the order-line type",
                Set.of(), Set.of(), 100_000);

        assertEquals(Set.of("resources/jsc/lib.js", "resources/jsc/selectIdp.js", "resources/xsd/order.xsd"),
                selection.unsent().keySet());
    }

    @Test
    void outlinesWhatAScriptDefinesReadsAndSets() {
        String outline = ComposeSelection.outline("resources/jsc/selectIdp.js", proxy().get("resources/jsc/selectIdp.js"));

        assertTrue(outline.contains("defines pick"), outline);
        assertTrue(outline.contains("reads request.header.host"), outline);
        assertTrue(outline.contains("sets idp.name"), outline);
    }

    @Test
    void findsTheFilesLeftOutThatAnAnswerAsksFor() throws Exception {
        ComposeSelection selection = ComposeSelection.of(proxy(), "Review", Set.of(), Set.of(), 100_000);

        assertEquals(List.of("resources/xsd/order.xsd"),
                selection.named("[Send resources/xsd/order.xsd in full to check the types]"));
        assertEquals(List.of("resources/jsc/lib.js"), selection.named("lib.js decides it"));
    }

    @Test
    void refusesWhenTheNeededFilesAreTooLarge() {
        assertThrows(ComposeSelection.TooLarge.class, () -> ComposeSelection.of(proxy(), "Review",
                Set.of("resources/xsd/order.xsd"), Set.of(), 10_000));
    }
}
