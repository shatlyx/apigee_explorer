package dev.apigeemap.migration;

import dev.apigeemap.analysis.VariableFlow;
import dev.apigeemap.migration.Finding.Subject;
import dev.apigeemap.model.BundleReport;
import dev.apigeemap.model.Issue;
import dev.apigeemap.model.Policy;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/** The scripts of a proxy to review, and what a review of them needs to know. */
public final class ScriptReviewRequest {

    /**
     * A script to review, at one place: a file run by several policies of a bundle is reviewed once for all of them.
     *
     * @param file        the script file, or the policy file of an inline script
     * @param fingerprint of the script and of what the review sees around it, see {@link #fingerprints}
     */
    public record Target(String bundle, List<String> policies, String file, boolean inline, String fingerprint) {
    }

    private ScriptReviewRequest() {
    }

    /** The JavaScript run by the active policies of the proxy and of the shared flows it calls, each place once. */
    public static List<Target> scripts(BundleReport root) throws IOException {
        List<Target> targets = new ArrayList<>();
        for (BundleReport bundle : FixContext.bundles(root).values()) {
            Map<String, String> fingerprints = fingerprints(bundle);
            places(bundle).forEach((file, scripts) -> targets.add(new Target(bundle.name(),
                    scripts.stream().map(Scripts.Script::policy).toList(), file,
                    scripts.get(0).file().equals("inline"), fingerprints.get(file))));
        }
        return List.copyOf(targets);
    }

    /**
     * The fingerprint of each script of the bundle, by its file (the policy file for an inline script): the source
     * and the context the review is given, the policies that run it with where they run and how their variables flow,
     * and the files around them. A remark kept under it holds while neither the script nor the proxy around it
     * changes, and a script copied into another proxy is reviewed again there.
     */
    static Map<String, String> fingerprints(BundleReport bundle) throws IOException {
        Map<String, BundleReport> bundles = FixContext.bundles(bundle);
        Map<String, VariableFlow> flows = new HashMap<>();
        Map<String, String> fingerprints = new LinkedHashMap<>();
        for (Map.Entry<String, List<Scripts.Script>> place : places(bundle).entrySet()) {
            List<Subject> subjects = place.getValue().stream().map(t -> policyFile(bundle, t.policy()))
                    .filter(f -> f != null).map(f -> new Subject(bundle.name(), f)).toList();
            FixContext context = FixContext.of(review(bundle, subjects), bundles, flows);
            StringBuilder key = new StringBuilder();
            place.getValue().forEach(t -> key.append(t.source()).append('\0'));
            // the records print every field, file contents included; a new format only means reviewing again
            key.append(context.policies()).append('\0').append(context.files());
            fingerprints.put(place.getKey(), ScriptReviews.fingerprint(key.toString()));
        }
        return fingerprints;
    }

    /** The JavaScript of the active policies of the bundle by file, the policy file for an inline script. */
    private static Map<String, List<Scripts.Script>> places(BundleReport bundle) throws IOException {
        Map<String, List<Scripts.Script>> places = new LinkedHashMap<>();
        for (Scripts.Script script : Scripts.of(bundle)) {
            if (script.python()) continue;
            String file = script.file().equals("inline") ? policyFile(bundle, script.policy()) : script.file();
            if (file != null) places.computeIfAbsent(file, f -> new ArrayList<>()).add(script);
        }
        return places;
    }

    private static Finding review(BundleReport root, List<Subject> subjects) {
        return new Finding("REV-01", Finding.Category.DESIGN, Issue.Severity.INFO, root.name(), "scripts",
                "Script review", "", Finding.Fix.MANUAL, subjects);
    }

    /** The policies that run the targets, where they run, how their variables flow, and the files around them. */
    public static FixContext context(BundleReport root, List<Target> targets) throws IOException {
        Map<String, BundleReport> bundles = FixContext.bundles(root);
        List<Subject> subjects = new ArrayList<>();
        for (Target target : targets) {
            BundleReport bundle = bundles.get(target.bundle());
            for (String name : target.policies()) {
                String policy = policyFile(bundle, name);
                if (policy != null) subjects.add(new Subject(target.bundle(), policy));
            }
        }
        return FixContext.of(review(root, subjects), bundles);
    }

    /** The findings about the targets or their policies, so that the review does not repeat them. */
    public static List<Finding> known(List<Finding> findings, FixContext context) {
        Set<String> files = context.policies().stream().map(p -> p.bundle() + "/" + p.file())
                .collect(Collectors.toSet());
        context.files().stream().filter(f -> f.path().startsWith("resources/jsc/"))
                .forEach(f -> files.add(f.bundle() + "/" + f.path()));
        return findings.stream().filter(f -> !f.rule().equals("REV-01"))
                .filter(f -> f.subjects().stream().anyMatch(s -> files.contains(s.bundle() + "/" + s.file())))
                .toList();
    }

    private static String policyFile(BundleReport bundle, String name) {
        if (bundle == null) return null;
        return bundle.policies().stream().filter(p -> p.name().equals(name)).map(Policy::file).findFirst()
                .orElse(null);
    }
}
