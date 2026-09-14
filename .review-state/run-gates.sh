#!/usr/bin/env bash
# CR-3 Step 2 三门禁 dry-run（只读审查前置：真实退出码 + 原样输出）
# 门禁集 = CI test job 的等价命令全集体（.github/workflows/ci.yml）
set -u
ROOT="/f/moonbit比赛/moon_ua_parser"
OUT="$ROOT/.review-state/gates"
mkdir -p "$OUT"
cd "$ROOT"

# ---------- GATE-1: 静态检查（workspace 全成员）+ 警告基线原始输出 ----------
{
  echo "=== moon version ==="
  moon version
  echo
  echo "=== GATE-1: moon check --target native (workspace root) ==="
  moon check --target native
  echo "EXIT_CHECK=$?"
} > "$OUT/check.log" 2>&1

TOTAL=$(grep -c "Warning (" "$OUT/check.log" || true)
DEP_OUT=$(awk '/╭─\[/{path=$0} /Warning \(deprecated/{if (path !~ /moon_ua_parser_lib/) n++} END{print n+0}' "$OUT/check.log")
{
  echo "TOTAL_WARNINGS=$TOTAL (baseline 18, may shrink never grow)"
  echo "DEP_OUTSIDE_LIB=$DEP_OUT (must be 0)"
} >> "$OUT/check.log" 2>&1

# ---------- GATE-2: mbti 接口漂移 + 生成一致性（lib 子目录） ----------
cd "$ROOT/moon_ua_parser_lib"
{
  echo "=== GATE-2a: moon info + mbti zero-drift ==="
  moon info
  echo "EXIT_INFO=$?"
  git diff --exit-code -- '*.mbti' '**/*.mbti'
  echo "EXIT_MBTI_DIFF=$?"
  echo
  echo "=== GATE-2b: generation consistency (gen_rules + gen_tests) ==="
  python ../scripts/gen_rules.py && python ../scripts/gen_tests.py
  echo "EXIT_GEN=$?"
  git diff --exit-code -- src/ua_parser/rules tests/differential
  echo "EXIT_GEN_DIFF=$?"
} > "$OUT/gen.log" 2>&1

# ---------- GATE-3: 测试套件 native（workspace 根 = 全成员） ----------
cd "$ROOT"
{
  echo "=== GATE-3: moon test --target native (workspace root) ==="
  moon test --target native
  echo "EXIT_NATIVE_ROOT=$?"
} > "$OUT/test-native.log" 2>&1

# ---------- GATE-4: 中间件逐包集成测试（显式 -p，与 CI 同形） ----------
{
  echo "=== GATE-4: middleware per-package integration tests ==="
  moon test --target native -p moon_ua_parser_middleware_core
  echo "EXIT_MWCORE=$?"
  moon test --target native -p moon_ua_parser_crescent
  echo "EXIT_CRESCENT=$?"
  moon test --target native -p moon_ua_parser_mars
  echo "EXIT_MARS=$?"
} > "$OUT/test-mw.log" 2>&1

# ---------- GATE-5: 测试套件 js（lib） ----------
cd "$ROOT/moon_ua_parser_lib"
{
  echo "=== GATE-5: moon test --target js (moon_ua_parser_lib) ==="
  moon test --target js
  echo "EXIT_JS=$?"
} > "$OUT/test-js.log" 2>&1

# ---------- GATE-6: wasm 7 包测试门 + 构建门（lib） ----------
{
  echo "=== GATE-6a: wasm 7-package test gate ==="
  ulimit -s unlimited 2>/dev/null || true
  moon test -p . -p examples/middleware -p src/ua_parser -p src/ua_parser/rules -p tests/diffstats -p tests/robust -p tests/semantics --target wasm
  echo "EXIT_WASM7=$?"
  echo
  echo "=== GATE-6b: moon build --target wasm ==="
  moon build --target wasm
  echo "EXIT_WASM_BUILD=$?"
} > "$OUT/test-wasm.log" 2>&1

# ---------- GATE-7: perf smoke（native release） ----------
{
  echo "=== GATE-7: perf smoke (bench --smoke, native release) ==="
  moon run --target native --release tests/bench -- --smoke
  echo "EXIT_SMOKE=$?"
} > "$OUT/smoke.log" 2>&1

echo "ALL_GATES_DONE" > "$OUT/DONE.flag"
