package dev.apigeemap.ui;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LatestRunTest {

    @Test
    void anAskMadeWhileItRunsStopsItAndBothAnswerTheNewRun() throws Exception {
        LatestRun latest = new LatestRun();
        CountDownLatch started = new CountDownLatch(1);
        AtomicInteger runs = new AtomicInteger();
        List<String> stopped = new CopyOnWriteArrayList<>();
        LatestRun.Operation operation = stale -> {
            int run = runs.incrementAndGet();
            if (run == 1) {
                started.countDown();
                long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10);
                while (!stale.getAsBoolean()) {
                    if (System.nanoTime() > deadline) throw new IllegalStateException("never stopped");
                    Thread.onSpinWait();
                }
                stopped.add("run 1");
                throw new LatestRun.Superseded();
            }
            return Map.of("run", run);
        };

        CompletableFuture<Map<String, Object>> first = CompletableFuture.supplyAsync(() -> call(latest, operation));
        assertTrue(started.await(10, TimeUnit.SECONDS));
        assertTrue(latest.since("p").isPresent());
        Map<String, Object> second = latest.run("p", operation);

        assertEquals(Map.of("run", 2), second);
        assertEquals(Map.of("run", 2), first.get(10, TimeUnit.SECONDS));
        assertEquals(List.of("run 1"), stopped);
        assertEquals(2, runs.get());
        assertTrue(latest.since("p").isEmpty());
    }

    @Test
    void anAskAfterARunRunsAgain() throws Exception {
        LatestRun latest = new LatestRun();
        AtomicInteger runs = new AtomicInteger();
        LatestRun.Operation operation = stale -> Map.of("run", runs.incrementAndGet());

        assertEquals(Map.of("run", 1), latest.run("p", operation));
        assertEquals(Map.of("run", 2), latest.run("p", operation));
        assertEquals(Map.of("run", 3), latest.run("q", operation), "each proxy runs on its own");
    }

    private static Map<String, Object> call(LatestRun latest, LatestRun.Operation operation) {
        try {
            return latest.run("p", operation);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
