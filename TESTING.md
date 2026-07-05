# Testing

Build and run the full Verilator regression:

```sh
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Verilator assertion checks are enabled by default. Disable them only for debugging:

```sh
cmake -S . -B build -DENABLE_ASSERTS=OFF
```

Randomized tests use a reproducible seed. The default seed is `0xC0DE2026`.
Override it with either decimal or hexadecimal input:

```sh
TEST_SEED=0x1234 ctest --test-dir build --output-on-failure
```

Chip-level tests collect lightweight commit trace entries. They are printed only
when `TRACE_COMMITS=1` is set, or included in invariant failure logs:

```sh
TRACE_COMMITS=1 ctest --test-dir build -R test_basic_ops --output-on-failure
```
