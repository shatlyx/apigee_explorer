package dev.apigeemap.ui;

import java.util.List;
import java.util.Map;

/**
 * Applies the edits the backend proposes for a file, {@code [{old, new}]}, to its text: each {@code old} must occur
 * exactly once in the text as it stands when the edit is applied, in their order. Nothing is applied when one does not,
 * so that a wrong edit never lands.
 */
public final class TextEdits {

    /** @param text the new text, or null when the edits cannot be applied; then {@code problem} says why */
    public record Outcome(String text, String problem) {
    }

    private TextEdits() {
    }

    /** The edits of a proposed file, or null when it has none (it then carries its whole content). */
    public static List<?> of(Map<?, ?> edit) {
        return edit.get("edits") instanceof List<?> list && !list.isEmpty() ? list : null;
    }

    public static Outcome apply(String text, List<?> edits) {
        if (text == null) return new Outcome(null, "the file was not sent");
        String current = text;
        for (int i = 0; i < edits.size(); i++) {
            if (!(edits.get(i) instanceof Map<?, ?> edit) || !(edit.get("old") instanceof String old) || old.isEmpty()) {
                return new Outcome(null, "change " + (i + 1) + " says no text to replace");
            }
            String replacement = edit.get("new") instanceof String s ? s : "";
            // a file with Windows line endings, edited as if it had plain ones
            if (!current.contains(old) && current.contains("\r\n") && !old.contains("\r")) {
                old = old.replace("\n", "\r\n");
                replacement = replacement.replace("\r\n", "\n").replace("\n", "\r\n");
            }
            int at = current.indexOf(old);
            if (at < 0) return new Outcome(null, "the text to replace of change " + (i + 1) + " is not in the file");
            if (current.indexOf(old, at + 1) >= 0) {
                return new Outcome(null, "the text to replace of change " + (i + 1) + " occurs more than once in the file");
            }
            current = current.substring(0, at) + replacement + current.substring(at + old.length());
        }
        return new Outcome(current, null);
    }
}
