package dev.apigeemap.ui;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class TextEditsTest {

    private static Map<String, String> change(String old, String replacement) {
        return Map.of("old", old, "new", replacement);
    }

    @Test
    void appliesTheEditsInTheirOrder() {
        TextEdits.Outcome outcome = TextEdits.apply("var a = 1;\nvar b = 2;\n",
                List.of(change("var a = 1;", "var a = 10;"), change("var a = 10;\nvar b", "var a = 10;\nlet b")));
        assertEquals("var a = 10;\nlet b = 2;\n", outcome.text());
        assertNull(outcome.problem());
    }

    @Test
    void refusesAnEditThatIsNotThereOrIsThereTwice() {
        TextEdits.Outcome absent = TextEdits.apply("a\nb\n", List.of(change("a", "x"), change("c", "y")));
        assertNull(absent.text());
        assertEquals("the text to replace of change 2 is not in the file", absent.problem());

        TextEdits.Outcome twice = TextEdits.apply("<A/><A/>", List.of(change("<A/>", "<B/>")));
        assertNull(twice.text());
        assertEquals("the text to replace of change 1 occurs more than once in the file", twice.problem());

        assertEquals("change 1 says no text to replace", TextEdits.apply("a", List.of(change("", "x"))).problem());
        assertEquals("the file was not sent", TextEdits.apply(null, List.of(change("a", "b"))).problem());
    }

    @Test
    void keepsWindowsLineEndings() {
        TextEdits.Outcome outcome = TextEdits.apply("<A>\r\n  <B/>\r\n</A>\r\n",
                List.of(change("<A>\n  <B/>", "<A>\n  <C/>\n  <B/>")));
        assertEquals("<A>\r\n  <C/>\r\n  <B/>\r\n</A>\r\n", outcome.text());
    }

    @Test
    void aFileWithoutEditsCarriesItsContent() {
        assertNull(TextEdits.of(Map.of("content", "x")));
        assertNull(TextEdits.of(Map.of("edits", List.of())));
        assertEquals(1, TextEdits.of(Map.of("edits", List.of(change("a", "b")))).size());
    }
}
