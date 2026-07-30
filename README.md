# mbignum

Arbitrary-precision natural numbers in pure [Mere](https://merelang.org/) — a
reusable library. A big natural is a little-endian list of base-1e9 limbs
(`int list`), normalized so 0 is uniquely the empty list. Everything is an
ordinary immutable value: no mutation, no region parameters to thread.

```mere
import "github.com/284km/mbignum/bignum.mere";

Bignum.to_str (Bignum.fact 100)     // "93326215443...000000"
Bignum.to_str (Bignum.fib 200)      // "280571172992510140037611932413038677189525"
Bignum.to_str (Bignum.mul a b)      // full schoolbook product
Bignum.cmp x y                      // -1 / 0 / 1
```

## API

| function | type | notes |
|----------|------|-------|
| `from_int` | `int -> big` | naturals only (n ≤ 0 → 0) |
| `add` | `big -> big -> big` | limb-carry addition |
| `mul_small` | `big -> int -> big` | multiply by a machine int |
| `mul` | `big -> big -> big` | schoolbook multiply |
| `cmp` | `big -> big -> int` | -1 / 0 / 1 |
| `to_str` | `big -> str` | decimal, most-significant first |
| `fact` | `int -> big` | n! |
| `fib` | `int -> big` | nth Fibonacci |

`big = int list`. Naturals only — no sign, subtraction, or division yet.
Base 1e9 keeps limb products under 2^63 on the 64-bit backends; addition's
limb sum stays under 2^31, which is why it also survives the 32-bit Wasm
backend (multiply, whose product is ~1e18, does not — a Wasm build needs a
smaller base).

## Installing as a dependency

```toml
# your mere.toml
[dependencies]
mbignum = { git = "https://github.com/284km/mbignum", rev = "<commit>" }
```

Then `mere install` fetches it into `.mere_modules/github.com/284km/mbignum/`,
where the full-path import above resolves.

Verified against `python3`'s bignum on the interpreter and the C backend.
