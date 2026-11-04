package dev.apigeemap.ui;

import dev.apigeemap.migration.SourceCompactor;
import dev.apigeemap.protocol.Json;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Which files of a proxy a compose request sends, when they do not all fit. The policies and endpoints always go, in
 * full: the request may change any of them. A file under {@code resources/} goes in full when the request needs it
 * (the file being edited, a file or policy the request names, a script of such a policy, a file asked for again) or
 * when it is small; the others are described by an outline worked out here, without asking the backend.
 *
 * @param sent     the paths sent in full, in the order of the files
 * @param unsent   the paths left out, each with its outline, as the model reads them; empty when nothing is left out
 */
record ComposeSelection(List<String> sent, Map<String, String> unsent) {

    /** A resource this small goes when there is room, needed or not. */
    static final int SMALL = 8_000;
    private static final int MAX_NAMES = 30;
    private static final Pattern URL = Pattern.compile("<(?:ResourceURL|IncludeURL)>\\s*(\\w+)://([^<\\s]+)\\s*<");
    private static final Pattern XML_NAME = Pattern.compile(
            "<(?:\\w+:)?(element|complexType|simpleType|operation|service)\\b[^>]*?\\bname=\"([^\"]+)\"");
    private static final Pattern VARIABLE = Pattern.compile("\\b(get|set)Variable\\(\\s*['\"]([^'\"]+)['\"]");

    /** Thrown when the files the request needs are too large on their own. */
    static final class TooLarge extends Exception {
        TooLarge(String message) {
            super(message);
        }
    }

    /**
     * @param files   path to content of each text file of the proxy, in order
     * @param request what is asked
     * @param focus   the paths being edited or selected
     * @param include the paths asked for again, in full
     * @param budget  the most characters to send
     */
    static ComposeSelection of(Map<String, String> files, String request, Collection<String> focus,
                               Collection<String> include, long budget) throws TooLarge {
        long total = files.values().stream().mapToLong(String::length).sum();
        if (total <= budget) return new ComposeSelection(List.copyOf(files.keySet()), Map.of());

        Set<String> wanted = new LinkedHashSet<>();
        String asked = request.toLowerCase(Locale.ROOT);
        for (Map.Entry<String, String> file : files.entrySet()) {
            String path = file.getKey();
            boolean named = mentions(asked, name(path)) || mentions(asked, stem(path));
            boolean policy = path.startsWith("policies/");
            if (!path.startsWith("resources/")) wanted.add(path);
            if (focus.contains(path) || include.contains(path) || named) {
                wanted.add(path);
                if (policy) wanted.addAll(resources(file.getValue()));
            }
        }
        wanted.retainAll(files.keySet());
        long size = wanted.stream().mapToLong(p -> files.get(p).length()).sum();
        if (size > budget) {
            throw new TooLarge("Even the policies, endpoints and files this request needs are too large to be sent ("
                    + size + " characters, at most " + budget + "): close or name fewer large files");
        }
        List<String> rest = files.keySet().stream().filter(p -> !wanted.contains(p))
                .sorted(Comparator.comparingInt(p -> files.get(p).length())).toList();
        for (String path : rest) {
            int length = files.get(path).length();
            if (length > SMALL || size + length > budget) break;
            wanted.add(path);
            size += length;
        }
        List<String> sent = new ArrayList<>();
        Map<String, String> unsent = new LinkedHashMap<>();
        for (Map.Entry<String, String> file : files.entrySet()) {
            if (wanted.contains(file.getKey())) sent.add(file.getKey());
            else unsent.put(file.getKey(), outline(file.getKey(), file.getValue()));
        }
        return new ComposeSelection(sent, unsent);
    }

    /** The files left out, one line each, as the backend gives them to the model. */
    String manifest() {
        StringBuilder out = new StringBuilder();
        unsent.forEach((path, outline) -> out.append(path).append(": ").append(outline).append('\n'));
        return out.toString();
    }

    /** The paths left out that a text names, such as the warnings of an answer asking for them. */
    List<String> named(String text) {
        String lower = text.toLowerCase(Locale.ROOT);
        return unsent.keySet().stream().filter(p -> lower.contains(p.toLowerCase(Locale.ROOT))
                || mentions(lower, name(p))).toList();
    }

    /** {@code jsc://file.js} in a policy is the file resources/jsc/file.js. */
    static List<String> resources(String policy) {
        List<String> paths = new ArrayList<>();
        Matcher url = URL.matcher(policy);
        while (url.find()) paths.add("resources/" + url.group(1) + "/" + url.group(2));
        return paths;
    }

    /** Its size and what it defines: functions and variables of a script, types of a schema, keys of JSON. */
    static String outline(String path, String text) {
        String lower = path.toLowerCase(Locale.ROOT);
        Set<String> parts = new LinkedHashSet<>();
        if (lower.endsWith(".js")) {
            Set<String> names = SourceCompactor.names(text);
            if (!names.isEmpty()) parts.add("defines " + join(names));
            Set<String> read = new LinkedHashSet<>();
            Set<String> written = new LinkedHashSet<>();
            Matcher variable = VARIABLE.matcher(text);
            while (variable.find()) (variable.group(1).equals("get") ? read : written).add(variable.group(2));
            if (!read.isEmpty()) parts.add("reads " + join(read));
            if (!written.isEmpty()) parts.add("sets " + join(written));
        } else if (lower.endsWith(".json")) {
            try {
                if (Json.parse(text) instanceof Map<?, ?> map) {
                    parts.add("keys " + join(map.keySet().stream().map(String::valueOf).toList()));
                }
            } catch (RuntimeException e) {
                parts.add("not valid JSON");
            }
        } else if (lower.endsWith(".xsd") || lower.endsWith(".wsdl") || lower.endsWith(".xml")) {
            Map<String, Set<String>> kinds = new LinkedHashMap<>();
            Matcher name = XML_NAME.matcher(text);
            while (name.find()) kinds.computeIfAbsent(name.group(1), k -> new LinkedHashSet<>()).add(name.group(2));
            kinds.forEach((kind, names) -> parts.add(kind + " " + join(names)));
        }
        String head = text.length() + " characters";
        return parts.isEmpty() ? head : head + "; " + String.join("; ", parts);
    }

    private static String join(Collection<String> names) {
        List<String> shown = names.stream().limit(MAX_NAMES).toList();
        return String.join(", ", shown) + (names.size() > MAX_NAMES ? " and " + (names.size() - MAX_NAMES) + " more" : "");
    }

    private static String name(String path) {
        return path.substring(path.lastIndexOf('/') + 1).toLowerCase(Locale.ROOT);
    }

    private static String stem(String path) {
        String name = name(path);
        int dot = name.indexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    /** Whether {@code text} has {@code word} on its own, not inside a longer name. */
    private static boolean mentions(String text, String word) {
        if (word.length() < 3) return false;
        int from = 0;
        while (true) {
            int at = text.indexOf(word, from);
            if (at < 0) return false;
            int end = at + word.length();
            boolean before = at == 0 || !part(text.charAt(at - 1));
            boolean after = end == text.length() || !part(text.charAt(end)) || text.charAt(end) == '.'
                    && (end + 1 == text.length() || !part(text.charAt(end + 1)));
            if (before && after) return true;
            from = at + 1;
        }
    }

    private static boolean part(char c) {
        return Character.isLetterOrDigit(c) || c == '_' || c == '-' || c == '.';
    }
}
