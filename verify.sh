#!/bin/sh
# verify.sh — the README says "Verified against python3's bignum on the
# interpreter and the C backend". This is that sentence, as a program.
#
#   MERE=/path/to/mere-checkout sh verify.sh
#
# ⚠ WHY IT EXISTS. The claim was in the README and nowhere else: one commit,
# one file, no script. A sentence that says a thing was checked is not the
# check, and the next person cannot tell the difference -- least of all the
# author, months later, reading their own README as evidence.
#
# python3 is the oracle because its integers are arbitrary precision and it is
# a separate implementation: agreeing with it says something, agreeing with a
# second copy of this code would not.
#
# Both backends, because the claim names both. They can disagree -- Mere's int
# is 63-bit on the interpreter and 64-bit compiled, and this library carries
# base-1e9 limbs partly for that reason.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
MERE_ROOT="${MERE:-}"
[ -n "$MERE_ROOT" ] || { echo "usage: MERE=/path/to/mere-checkout sh verify.sh" >&2; exit 2; }
M="$MERE_ROOT/_build/default/bin/mere.exe"
[ -x "$M" ] || { echo "verify: $M not found (dune build?)" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || {
  echo "verify: python3 absent — the oracle is missing, so nothing here is checked" >&2
  exit 1; }

tmp=$(mktemp -d) || exit 1
DRV="$DIR/__verify_drv.mere"
trap 'rm -rf "$tmp" "$DRV"' EXIT INT TERM

# The cases. Each is one line of output on both sides, in this order.
cat > "$DRV" <<'EOF'
import "bignum.mere";
let _ = print (Bignum.to_str (Bignum.from_int 0));
let _ = print (Bignum.to_str (Bignum.from_int 999999999));
let _ = print (Bignum.to_str (Bignum.from_int 1000000000));
let _ = print (Bignum.to_str (Bignum.fact 1));
let _ = print (Bignum.to_str (Bignum.fact 25));
let _ = print (Bignum.to_str (Bignum.fact 100));
let _ = print (Bignum.to_str (Bignum.fib 1));
let _ = print (Bignum.to_str (Bignum.fib 90));
let _ = print (Bignum.to_str (Bignum.fib 200));
let _ = print (Bignum.to_str (Bignum.add (Bignum.fact 30) (Bignum.fib 150)));
let _ = print (Bignum.to_str (Bignum.mul (Bignum.fact 20) (Bignum.fib 90)));
let _ = print (Bignum.to_str (Bignum.mul_small (Bignum.fact 40) 999999999));
let _ = print (str_of_int (Bignum.cmp (Bignum.fact 20) (Bignum.fact 21)));
let _ = print (str_of_int (Bignum.cmp (Bignum.fact 21) (Bignum.fact 20)));
print (str_of_int (Bignum.cmp (Bignum.fib 100) (Bignum.fib 100)))
EOF

python3 - > "$tmp/oracle" <<'EOF'
import math
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
def cmp(a, b):
    return (a > b) - (a < b)
for v in [0, 999999999, 1000000000,
          math.factorial(1), math.factorial(25), math.factorial(100),
          fib(1), fib(90), fib(200),
          math.factorial(30) + fib(150),
          math.factorial(20) * fib(90),
          math.factorial(40) * 999999999,
          cmp(math.factorial(20), math.factorial(21)),
          cmp(math.factorial(21), math.factorial(20)),
          cmp(fib(100), fib(100))]:
    print(v)
EOF
cases=$(wc -l < "$tmp/oracle" | tr -d ' ')

# ⚠ A FLOOR. A driver that stopped printing would otherwise agree with an
# oracle that was also read as empty, and this would pass with nothing checked.
[ "$cases" -ge 15 ] || { echo "verify: the oracle produced $cases lines, expected 15" >&2; exit 1; }

fails=0
cd "$DIR" || exit 2
run_backend() {
  label=$1
  case $label in
    interp) "$M" "$DRV" > "$tmp/out.$label" 2>"$tmp/err.$label" ;;
    c)      "$M" -c "$DRV" > "$tmp/prog.c" 2>"$tmp/err.$label" \
              && "${CC:-cc}" -O1 -w "$tmp/prog.c" -o "$tmp/prog" 2>>"$tmp/err.$label" \
              && "$tmp/prog" > "$tmp/out.$label" 2>>"$tmp/err.$label" ;;
  esac || { echo "FAIL  $label: did not run — $(head -1 "$tmp/err.$label")"; fails=$((fails+1)); return; }
  if diff -u "$tmp/oracle" "$tmp/out.$label" > "$tmp/d.$label" 2>&1; then
    echo "PASS  $label: $cases values agree with python3"
  else
    echo "FAIL  $label: disagrees with python3"
    sed 's/^/      /' "$tmp/d.$label" | head -20
    fails=$((fails+1))
  fi
}
run_backend interp
run_backend c

# POISON. The comparison has to be able to see a wrong digit -- a diff against a
# file nobody wrote to would pass just as quietly.
sed 's/^15511210043330985984000000$/15511210043330985984000001/' "$tmp/oracle" > "$tmp/poisoned"
if diff -q "$tmp/poisoned" "$tmp/out.interp" >/dev/null 2>&1; then
  echo "FAIL  poison: one digit was changed and the comparison did not notice"
  fails=$((fails+1))
else
  echo "PASS  poison: a single changed digit is caught"
fi

[ "$fails" -eq 0 ] && { echo "verify: ok ($cases values x 2 backends, oracle python3)"; exit 0; }
echo "verify: $fails failed"; exit 1
