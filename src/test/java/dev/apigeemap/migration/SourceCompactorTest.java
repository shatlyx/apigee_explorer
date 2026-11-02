package dev.apigeemap.migration;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SourceCompactorTest {

    @Test
    void dropsCommentsAndIndentationButKeepsTextAndCdata() {
        String xml = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <!-- the payload -->
                <AssignMessage name="AM-Set">
                    <DisplayName>AM Set</DisplayName>
                    <Set>
                        <Payload contentType="application/json"><![CDATA[{
                          "a" : 1   <!-- not a comment -->
                        }]]></Payload>
                        <Headers/>
                    </Set>
                    <Condition>request.verb = "GET"</Condition>
                </AssignMessage>
                """;
        assertEquals("<AssignMessage name=\"AM-Set\">\n<DisplayName>AM Set</DisplayName>\n<Set>\n"
                + "<Payload contentType=\"application/json\"><![CDATA[{\n          \"a\" : 1   <!-- not a comment -->\n"
                + "        }]]></Payload>\n<Headers/>\n</Set>\n<Condition>request.verb = \"GET\"</Condition>\n"
                + "</AssignMessage>", SourceCompactor.xml(xml));
    }

    @Test
    void dropsTheAnnotationsOfSchemas() {
        ProxyDocs.SourceFile xsd = new ProxyDocs.SourceFile("orders-api", "resources/xsd/order.xsd", """
                <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
                  <xs:element name="order">
                    <xs:annotation><xs:documentation>An order, as the shop keeps it.</xs:documentation></xs:annotation>
                    <xs:complexType><xs:sequence><xs:element name="id" type="xs:string"/></xs:sequence></xs:complexType>
                  </xs:element>
                </xs:schema>
                """);
        String content = SourceCompactor.compact(xsd).content();
        assertFalse(content.contains("annotation") || content.contains("as the shop keeps it"), content);
        assertTrue(content.contains("<xs:element name=\"id\" type=\"xs:string\"/>"), content);
    }

    @Test
    void dropsTheHashesOfTheManifest() {
        String hash = "SHA-512:" + "ab12".repeat(32);
        ProxyDocs.SourceFile manifest = new ProxyDocs.SourceFile("orders-api", "apiproxy/manifests/manifest.xml", """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Manifest name="manifest">
                    <Policies>
                        <VersionInfo resourceName="AM-Set" version="%s"/>
                    </Policies>
                </Manifest>
                """.formatted(hash));
        assertEquals("<Manifest name=\"manifest\">\n<Policies>\n<VersionInfo resourceName=\"AM-Set\"/>\n</Policies>\n"
                + "</Manifest>", SourceCompactor.compact(manifest).content());
    }

    @Test
    void dropsTheSpacesOfJsonOutsideStrings() {
        assertEquals("{\"a b\":\"x \\\" y\",\"n\":1.50,\"l\":[1,2]}",
                SourceCompactor.json("{\n  \"a b\" : \"x \\\" y\",\n  \"n\": 1.50,\n  \"l\": [ 1, 2 ]\n}\n"));
        assertEquals("{ not json", SourceCompactor.json("{ not json"));
    }

    @Test
    void outlinesAMinifiedLibrary() {
        String library = "/*! tinylib v1.2 | MIT */\nvar TinyLib={};function sha(a){return a}TinyLib.hex=function(b){return b};"
                + "var pad='" + "x".repeat(SourceCompactor.LIBRARY) + "';";
        ProxyDocs.SourceFile file = new ProxyDocs.SourceFile("orders-api", "resources/jsc/tinylib.js", library);

        String outline = SourceCompactor.compact(file).content();

        assertTrue(outline.startsWith("// Minified library of " + library.length() + " characters"), outline);
        assertTrue(outline.contains("/*! tinylib v1.2 | MIT */"), outline);
        assertTrue(outline.contains("// Defines: TinyLib, sha, TinyLib.hex, pad"), outline);
    }

    @Test
    void keepsAScriptWrittenForTheProxy() {
        ProxyDocs.SourceFile script = new ProxyDocs.SourceFile("orders-api", "resources/jsc/check.js",
                "// checks the order\nvar id = context.getVariable('order.id');\n");
        assertSame(script, SourceCompactor.compact(script));
    }

    @Test
    void makesTheExamplesSmaller() throws Exception {
        Path root = Path.of("examples/authorization/oauth-authorization");
        List<ProxyDocs.SourceFile> files;
        try (var walk = Files.walk(root)) {
            files = walk.filter(Files::isRegularFile).filter(p -> p.toString().endsWith(".xml")).map(p -> {
                try {
                    return new ProxyDocs.SourceFile("b", root.relativize(p).toString(), Files.readString(p));
                } catch (java.io.IOException e) {
                    throw new java.io.UncheckedIOException(e);
                }
            }).toList();
        }
        long before = files.stream().mapToLong(f -> f.content().length()).sum();
        long after = SourceCompactor.compact(files).stream().mapToLong(f -> f.content().length()).sum();
        System.out.println("SourceCompactor: " + before + " -> " + after + " characters");
        assertTrue(after < before * 0.9, before + " -> " + after);
    }
}
