#!/bin/bash

# jmh-run.sh

# Copyright 2016 headissue GmbH, Jens Wilke

# This script to run a benchmark suite with JMH.
#
# Parameters:
#
# --quick   quick run with reduced benchmark time, to check for errors
# --no3pty  only benchmark cache2k and JDK build ins, used for continuous benchmarking against performance regressions
# --perf    run the benchmark with Linux perf (needs testing)

set -e;
# set -x;

test -n "$BENCHMARK_JVM_ARGS" || BENCHMARK_JVM_ARGS="-server -Xmx2G";

test -n "$BENCHMARK_QUICK" || BENCHMARK_QUICK="-f 1 -wi 1 -i 1 -r 1s -foe true";

test -n "$BENCHMARK_DILIGENT" || BENCHMARK_DILIGENT="-f 3 -wi 5 -i 5 -r 20s";

# Tinker benchmark options to do profiling and add assembler code output (linux only).
# Needs additional disassembly library to display assembler code
# see: http://psy-lob-saw.blogspot.de/2013/01/java-print-assembly.html
# download from: https://kenai.com/projects/base-hsdis/downloads
# install with e.g.: mv ~/Downloads/linux-hsdis-amd64.so jdk1.8.0_45/jre/lib/amd64/hsdis-amd64.so.
# For profiling only do one fork, but more measurement iterations
# profilers are described here: http://java-performance.info/introduction-jmh-profilers
test -z "$BENCHMARK_PERF" || BENCHMARK_PERF="-f 1 -wi 2 -i 5 -r 20s -prof perfasm";

STANDARD_PROFILER="-prof comp -prof gc -prof hs_rt -prof org.cache2k.benchmark.jmh.ForcedGcMemoryProfiler";

OPTIONS="$BENCHMARK_DILIGENT";

unset no3pty;

processCommandLine() {
  while true; do
    case "$1" in
      --quick) OPTIONS="$BENCHMARK_QUICK";;
      --perf) OPTIONS="$BENCHMARK_PERF";;
      --no3pty) no3pty=true;;
      -*) echo "unknown option: $1"; exit 1;;
      *) break;;
    esac
    shift 1;
  done
}

filterProgress() {
awk '/^# Run .*/ { print; }';
}

START_TIME=0;

startTimer() {
START_TIME=`date +%s`;
}

stopTimer() {
local t=`date +%s`;
echo "Total runtime $(( $t - $START_TIME ))s";
}

processCommandLine "$@";

JAR="jmh-suite/target/benchmarks.jar";

# Implementations with no eviction (actually not a cache) and not thread safe
SINGLE_THREADED="HashMapFactory"

# Implementations with no eviction (actually not a cache) and thread safe
NO_EVICTION="ConcurrentHashMapFactory"

# Implementations with complete caching features
COMPLETE="Cache2kFactory Cache2kWithExpiryFactory"

TARGET="target/jmh-result";
test -d $TARGET || mkdir -p $TARGET;

if test -z "$no3pty"; then
COMPLETE="$COMPLETE thirdparty.CaffeineCacheFactory thirdparty.GuavaCacheFactory";
fi

startTimer;

#
# Multi threaded with variable thread counts, no eviction needed
#
benchmarks="PopulateParallelOnceBenchmark ReadOnlyBenchmark";
for impl in $NO_EVICTION $COMPLETE; do
  for benchmark in $benchmarks; do
    for threads in 1 2 4; do
      runid="$impl-$benchmark-$threads";
      fn="$TARGET/result-$runid";
      echo;
      echo "## $runid";
      java -jar $JAR $benchmark -jvmArgs "$BENCHMARK_JVM_ARGS" $OPTIONS $STANDARD_PROFILER \
           -t $threads -p cacheFactory=org.cache2k.benchmark.$impl \
           -rf json -rff "$fn.json" \
           2>&1 | tee $fn.out | filterProgress
      echo "=> $fn.out";
    done
  done
done

#
# Multi threaded asymmetrical/fixed thread counts, no eviction needed
#
benchmarks="CombinedReadWriteBenchmark";
for impl in $NO_EVICTION $COMPLETE; do
  for benchmark in $benchmarks; do
    runid="$impl-$benchmark";
    fn="$TARGET/result-$runid";
    echo;
    echo "## $runid";
    java -jar $JAR $benchmark -jvmArgs "$BENCHMARK_JVM_ARGS" $OPTIONS $STANDARD_PROFILER \
         -p cacheFactory=org.cache2k.benchmark.$impl \
         -rf json -rff "$fn.json" \
         2>&1 | tee $fn.out | filterProgress
      echo "=> $fn.out";
  done
done

result=$TARGET/data.json
# merge all results into single json file
cat $TARGET/result-*.json | awk ' /^]/ { f=1; next; } f && /^\[/ { print "  ,"; next; } { print; } END { print "]"; }' > $result

stopTimer;
