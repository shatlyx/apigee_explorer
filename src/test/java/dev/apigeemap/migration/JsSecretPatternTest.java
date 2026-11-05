package dev.apigeemap.migration;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JsSecretPatternTest {

    /** The pattern before it was made faster: SEC-03 must find exactly what it found. */
    private static final Pattern BEFORE = Pattern.compile(
            "(?i)[\"']?([\\w.-]*(?:password|passwd|secret|api[_-]?key|client[_-]?secret|token)[\\w.-]*)[\"']?"
                    + "\\s*[:=]\\s*[\"']([^\"'{}\\s]{6,})[\"']");

    @Test
    void findsWhatThePatternFoundBefore() {
        List<String> samples = new ArrayList<>(List.of(
                "var password = \"s3cr3t-value\";",
                "var cfg = {\"client_secret\": \"abcdefgh\", 'apiKey': 'zzzzzzzz'};",
                "x\"password\": \"abcdef\"",
                "my.token.value='123456' + other_token = \"short\"",
                "\"\"password\"=\"abcdefg\"",
                "foo.bar-passwordX:'abcdef' ; TOKEN=\"ABCDEFG\"",
                "secretsecret = 'aaaaaa' secret='{nope}' secret = \"a b c d e f\"",
                "context.setVariable('private.token', \"abcdef123\");"));
        Random random = new Random(42);
        String alphabet = "ab.-_\"' =:{}\npasswordtokensecretapikeyclient";
        for (int i = 0; i < 3000; i++) {
            StringBuilder text = new StringBuilder();
            int length = 5 + random.nextInt(60);
            for (int j = 0; j < length; j++) {
                if (random.nextInt(8) == 0) {
                    text.append(List.of("password", "token", "secret", "api_key", "client-secret", "passwd")
                            .get(random.nextInt(6)));
                } else {
                    text.append(alphabet.charAt(random.nextInt(alphabet.length())));
                }
            }
            samples.add(text.toString());
            // and one built to match, or nearly
            String quote = List.of("", "\"", "'").get(random.nextInt(3));
            samples.add(List.of("", "x", "a.b-", " ", "\"").get(random.nextInt(5)) + quote
                    + List.of("", "my", "a.b.", "x-y_").get(random.nextInt(4))
                    + List.of("password", "TOKEN", "apiKey", "client_secret", "Passwd").get(random.nextInt(5))
                    + List.of("", "Value", ".x", "-1").get(random.nextInt(4)) + quote
                    + List.of("", " ", "\n").get(random.nextInt(3)) + List.of("=", ":", " ").get(random.nextInt(3))
                    + List.of("", " ").get(random.nextInt(2)) + List.of("\"", "'", "").get(random.nextInt(3))
                    + "abcdefgh".substring(random.nextInt(5)) + List.of("\"", "'", "}").get(random.nextInt(3))
                    + text.substring(0, random.nextInt(text.length())));
        }
        int matched = 0;
        for (String sample : samples) {
            List<String> before = matches(BEFORE, sample);
            assertEquals(before, matches(SecurityRules.JS_SECRET, sample), sample);
            if (!before.isEmpty()) matched++;
        }
        assertTrue(matched > 100, "the samples match often enough to compare: " + matched);
    }

    @Test
    void staysFastOnLongNames() {
        String name = "a".repeat(20_000);
        String source = (name + " = 1;\n").repeat(20);
        long started = System.nanoTime();
        assertTrue(matches(SecurityRules.JS_SECRET, source).isEmpty());
        assertTrue(System.nanoTime() - started < 2_000_000_000L, "long names are not tried at every place");
    }

    private static List<String> matches(Pattern pattern, String text) {
        List<String> found = new ArrayList<>();
        Matcher matcher = pattern.matcher(text);
        while (matcher.find()) {
            found.add(matcher.start() + ":" + matcher.group() + "|" + matcher.group(1) + "|" + matcher.group(2));
        }
        return found;
    }
}
