package dev.apigeemap.migration;

import dev.apigeemap.protocol.Json;
import org.mozilla.javascript.CompilerEnvirons;
import org.mozilla.javascript.Context;
import org.mozilla.javascript.Parser;
import org.mozilla.javascript.ast.AstNode;
import org.mozilla.javascript.ast.AstRoot;
import org.mozilla.javascript.ast.Assignment;
import org.mozilla.javascript.ast.ExpressionStatement;
import org.mozilla.javascript.ast.FunctionNode;
import org.mozilla.javascript.ast.VariableDeclaration;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Makes the source files sent to be documented or planned smaller without leaving any out: XML loses its comments
 * and indentation, schemas and WSDL their annotations, JSON its spaces, and a minified JavaScript library becomes an
 * outline (its banner and the names it defines). What the files say about the flows is kept as it is.
 */
public final class SourceCompactor {

    /** A script larger than this with a line longer than {@link #MINIFIED_LINE} is taken for a minified library. */
    static final int LIBRARY = 20_000;
    static final int MINIFIED_LINE = 2_000;
    private static final int MAX_NAMES = 100;
    private static final Pattern ANNOTATION = Pattern.compile(
            "<((?:[\\w-]+:)?(?:annotation|documentation))\\b[^>]*?(?:/>|>.*?</\\1\\s*>)", Pattern.DOTALL);

    private static final Pattern MANIFEST_VERSION = Pattern.compile("\\s+version=\"[^\"]*\"");

    private SourceCompactor() {
    }

    public static List<ProxyDocs.SourceFile> compact(List<ProxyDocs.SourceFile> files) {
        return files.stream().map(SourceCompactor::compact).toList();
    }

    public static ProxyDocs.SourceFile compact(ProxyDocs.SourceFile file) {
        String path = file.path().toLowerCase(Locale.ROOT);
        String extension = path.substring(path.lastIndexOf('.') + 1);
        String content = switch (extension) {
            // the manifest of an export holds a SHA-512 per resource: the names are what a reader needs
            case "xml" -> path.endsWith("manifests/manifest.xml")
                    ? MANIFEST_VERSION.matcher(xml(file.content())).replaceAll("") : xml(file.content());
            case "xsl", "xslt" -> xml(file.content());
            case "xsd", "wsdl" -> xml(ANNOTATION.matcher(file.content()).replaceAll(""));
            case "json" -> json(file.content());
            case "js" -> library(path, file.content()) ? outline(file.content()) : lines(file.content());
            default -> lines(file.content());
        };
        return content.length() < file.content().length()
                ? new ProxyDocs.SourceFile(file.bundle(), file.path(), content) : file;
    }

    /**
     * Without the XML declaration, comments and indentation: text made only of spaces between two tags becomes one
     * line break. CDATA sections are kept as they are.
     */
    static String xml(String text) {
        StringBuilder out = new StringBuilder(text.length());
        int i = 0;
        while (i < text.length()) {
            if (text.startsWith("<![CDATA[", i)) {
                int end = text.indexOf("]]>", i);
                end = end < 0 ? text.length() : end + 3;
                out.append(text, i, end);
                i = end;
            } else if (text.startsWith("<!--", i)) {
                int end = text.indexOf("-->", i);
                i = end < 0 ? text.length() : end + 3;
            } else if (text.startsWith("<?xml", i)) {
                int end = text.indexOf("?>", i);
                i = end < 0 ? text.length() : end + 2;
            } else if (text.charAt(i) == '<') {
                int end = text.indexOf('>', i);
                end = end < 0 ? text.length() : end + 1;
                out.append(text, i, end);
                i = end;
            } else {
                int end = i;
                while (end < text.length() && text.charAt(end) != '<') end++;
                String between = text.substring(i, end);
                if (!between.isBlank()) out.append(between);
                else if (out.length() > 0 && end < text.length()) out.append('\n');
                i = end;
            }
        }
        return out.toString().replaceAll("\n{2,}", "\n").strip();
    }

    /** Without the spaces outside strings, when it parses; numbers and strings stay as written. */
    static String json(String text) {
        try {
            Json.parse(text);
        } catch (RuntimeException e) {
            return lines(text);
        }
        StringBuilder out = new StringBuilder(text.length());
        boolean string = false;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (string) {
                out.append(c);
                if (c == '\\' && i + 1 < text.length()) out.append(text.charAt(++i));
                else if (c == '"') string = false;
            } else if (c == '"') {
                string = true;
                out.append(c);
            } else if (!Character.isWhitespace(c)) {
                out.append(c);
            }
        }
        return out.toString();
    }

    /** Without the spaces at the end of lines and the runs of empty lines. */
    static String lines(String text) {
        return text.replaceAll("[ \\t]+(\\r?\\n)", "$1").replaceAll("(\\r?\\n){3,}", "\n\n");
    }

    static boolean library(String path, String text) {
        if (path.endsWith(".min.js")) return true;
        if (text.length() <= LIBRARY) return false;
        int start = 0;
        for (int i = 0; i <= text.length(); i++) {
            if (i == text.length() || text.charAt(i) == '\n') {
                if (i - start > MINIFIED_LINE) return true;
                start = i + 1;
            }
        }
        return false;
    }

    /** What a library is, for a reader of the proxy: its size, its banner and the names it defines at the top level. */
    static String outline(String text) {
        StringBuilder out = new StringBuilder("// Minified library of ").append(text.length())
                .append(" characters, shown as an outline: its banner and the names it defines at the top level.\n");
        Matcher banner = Pattern.compile("^\\s*(/\\*.*?\\*/|(?://[^\\n]*\\n\\s*)+)", Pattern.DOTALL).matcher(text);
        if (banner.find()) {
            String b = banner.group(1).strip();
            out.append(b.length() > 500 ? b.substring(0, 500) + " …" : b).append('\n');
        }
        Set<String> names = names(text);
        if (!names.isEmpty()) out.append("// Defines: ").append(String.join(", ", names)).append('\n');
        return out.toString();
    }

    /** The names a script defines at the top level, at most 100; empty when it does not parse. */
    public static Set<String> names(String text) {
        Set<String> names = new LinkedHashSet<>();
        AstRoot root;
        try (Context cx = Context.enter()) {
            cx.setLocale(Locale.ENGLISH);
            CompilerEnvirons env = new CompilerEnvirons();
            env.setLanguageVersion(Context.VERSION_ES6);
            env.setRecordingComments(false);
            env.setStrictMode(false);
            root = new Parser(env).parse(text, "library", 1);
        } catch (RuntimeException e) {
            return names;
        }
        for (var node : root) {
            if (names.size() == MAX_NAMES) break;
            if (node instanceof FunctionNode f && f.getFunctionName() != null) {
                names.add(f.getName());
            } else if (node instanceof VariableDeclaration v) {
                v.getVariables().forEach(init -> names.add(brief(init.getTarget())));
            } else if (node instanceof ExpressionStatement s && s.getExpression() instanceof Assignment a) {
                names.add(brief(a.getLeft()));
            }
        }
        names.removeIf(String::isEmpty);
        return names;
    }

    private static String brief(AstNode node) {
        String source = node.toSource();
        return source.length() > 80 || source.contains("\n") ? "" : source;
    }
}
