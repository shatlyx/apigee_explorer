package dev.apigeemap.ui;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.BooleanSupplier;

/**
 * One operation per proxy where the last ask wins: an ask made while the operation runs stops it at its next check
 * of {@code stale}, and it starts again for the latest ask. Every ask then answers what that run answered, so an
 * answer never predates the ask. One run at a time per proxy. Kept in memory only.
 */
final class LatestRun {

    interface Operation {
        /** @param stale true once a later ask came: the operation should then throw {@link Superseded} */
        Map<String, Object> run(BooleanSupplier stale) throws IOException;
    }

    /** Thrown by an operation stopped for a later ask; its result is never kept. */
    static final class Superseded extends RuntimeException {
        Superseded() {
            super("Superseded by a later ask", null, false, false);
        }
    }

    private record Done(long ask, Map<String, Object> result) {
    }

    private static final class State {
        final AtomicLong asks = new AtomicLong();
        final AtomicInteger waiting = new AtomicInteger();
        volatile Instant since;
        Done done;
    }

    private final Map<String, State> states = new ConcurrentHashMap<>();

    /** Runs the operation for this ask, or answers what the run for a later ask answered. */
    Map<String, Object> run(String id, Operation operation) throws IOException {
        return run(id, operation, false);
    }

    /**
     * As {@link #run(String, Operation)}, but with {@code join} it waits for the run in progress, if any, instead of
     * stopping it: for a page opened again while it runs.
     */
    Map<String, Object> run(String id, Operation operation, boolean join) throws IOException {
        State state = states.computeIfAbsent(id, k -> new State());
        long mine;
        synchronized (state.waiting) {
            boolean joins = join && state.waiting.get() > 0;
            mine = joins ? state.asks.get() : state.asks.incrementAndGet();
            if (state.waiting.getAndIncrement() == 0) state.since = Instant.now();
        }
        try {
            synchronized (state) {
                while (true) {
                    if (state.done != null && state.done.ask() >= mine) return state.done.result();
                    long target = state.asks.get();
                    try {
                        Map<String, Object> result = operation.run(() -> state.asks.get() != target);
                        state.done = new Done(target, result);
                        return result;
                    } catch (Superseded superseded) {
                        // a later ask came: run again for it
                    }
                }
            }
        } finally {
            synchronized (state.waiting) {
                if (state.waiting.decrementAndGet() == 0) state.since = null;
            }
        }
    }

    /** When the first of the asks still waiting for the proxy was made, while any is. */
    Optional<Instant> since(String id) {
        State state = states.get(id);
        return state == null ? Optional.empty() : Optional.ofNullable(state.since);
    }
}
