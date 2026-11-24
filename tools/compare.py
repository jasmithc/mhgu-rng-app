"""Check the Swift engine against the notebook's own Python code.

Runs each test case through the notebook functions (numpy/numba replaced by small
pure-Python stand-ins) and through `.build/release/rngcheck`, then diffs the text.
Uses the Japanese skill names, which the app leaves unchanged from the notebook.

    swift build -c release && python3 tools/compare.py path/to/mhxx-rng.ipynb

The notebook comes from https://github.com/jasmithc/mhgu-rng (an English translation of
https://github.com/apmnnn/mhxx-rng).
"""
import contextlib
import io
import json
import pathlib
import re
import subprocess
import sys
import types

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
if len(sys.argv) < 2 or not pathlib.Path(sys.argv[1]).is_file():
    sys.exit('usage: python3 %s path/to/mhxx-rng.ipynb\n'
             '(get the notebook from https://github.com/jasmithc/mhgu-rng)' % pathlib.Path(sys.argv[0]).name)
NB = pathlib.Path(sys.argv[1])
CHECK = ROOT / '.build' / 'release' / 'rngcheck'


# --- minimal numpy / numba stand-ins (only what search_combo / search_reward need) ---
class Arr(list):
    def __setitem__(self, k, v):
        if isinstance(k, slice) and not isinstance(v, (list, tuple)):
            for i in range(*k.indices(len(self))):
                list.__setitem__(self, i, v)
        else:
            list.__setitem__(self, k, v)


np = types.ModuleType('numpy')
np.zeros = lambda n, dtype=None: Arr([0] * n)
np.array = lambda a, dtype=None: Arr(list(a))
for name in ('uint8', 'int32', 'int64', 'uint64'):
    setattr(np, name, int)
numba = types.ModuleType('numba')
numba.njit = lambda f: f
typed = types.ModuleType('numba.typed')
typed.List = list
numba.typed = typed
sys.modules.update({'numpy': np, 'numba': numba, 'numba.typed': typed})

ns = {}
cells = json.loads(NB.read_text())['cells']
exec(''.join(cells[0]['source']).split('set_en()')[0], ns)  # s, x..., options
for c in cells[1:4]:
    exec(''.join(c['source']), ns)
ns['set_ja']()

KIND_SETTERS = ['set_blue', 'set_red', 'set_yellow', 'set_white']
ANSI = re.compile(r'\033\[[0-9;]*m')


def py(kind, fn):
    ns[KIND_SETTERS[kind]]()
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        fn(ns)
    return ANSI.sub('', buf.getvalue())


def sw(kind, *args):
    r = subprocess.run([str(CHECK), 'ja', str(kind), *map(str, args)], capture_output=True, text=True)
    return r.stdout


def skill(name):
    return name


combo = '''
00 03 06 09 11 13 16 18 21 23 25 27 30
32 35 38 41 44 47 50 52 55 58 61 65 69
72 75 78 81 85 88 91 93 97 99'''
bad_combo = '00 03 06 09 11 13 17 18 21'
reward_table = {'MysteryBone': 20, 'Fishing': 40, 'RawMeat': 65, 'Whetstone': 85,
                'PowerBait': 90, 'HeavyBait': 95, 'SpeedBait': 100}
reward_str = ' '.join(f'{k}:{v}' for k, v in reward_table.items())
reward = 'PowerBait Fishing RawMeat MysteryBone MysteryBone RawMeat Fishing'

J = lambda i: ns['skill'][i]  # Japanese skill name by global id
ns['set_ja']()

cases = []


def case(name, kind, pyfn, *swargs):
    cases.append((name, kind, pyfn, swargs))


# README examples: Chain Crit 4 / Tenderizer 5 / 3 slots at 4723; Crisis 4 / Rec Level 2 / 0 at 1725
case('search chain crit', 0, lambda n: n['search'](0, 10000, n['parameter'](J(71), 4, J(70), 5, 3, 'マカ')),
     'search', J(71), 4, J(70), 5, 3, 0, 0, 10000)
case('search crisis', 0, lambda n: n['search'](0, 10000, n['parameter'](J(100), 4, J(116), 2, 0, 'マカ')),
     'search', J(100), 4, J(116), 2, 0, 0, 0, 10000)
case('search one skill', 0, lambda n: n['search'](0, 200000, n['parameter'](J(71), 4, '', 0, 3, 'マカ')),
     'search', J(71), 4, '-', 0, 3, 0, 0, 200000)
case('search quest', 1, lambda n: n['search'](0, 300000, n['parameter'](J(70), 5, J(69), 7, 2, '炭鉱')),
     'search', J(70), 5, J(69), 7, 2, 1, 0, 300000)
case('greater blue', 0, lambda n: n['search_greater'](0, 300000, n['parameter'](J(70), 5, J(69), 8, 2, 'マカ')),
     'search_greater', J(70), 5, J(69), 8, 2, 0, 0, 300000)
case('greater red', 1, lambda n: n['search_greater'](0, 300000, n['parameter'](J(70), 3, J(71), 3, 1, 'マカ')),
     'search_greater', J(70), 3, J(71), 3, 1, 0, 0, 300000)
case('greater red quest', 1, lambda n: n['search_greater'](0, 300000, n['parameter'](J(70), 3, J(71), 3, 1, '炭鉱')),
     'search_greater', J(70), 3, J(71), 3, 1, 1, 0, 300000)
case('greater yellow skill2 only', 2, lambda n: n['search_greater'](0, 100000, n['parameter']('', 0, J(17), 10, 3, 'マカ')),
     'search_greater', '-', 0, J(17), 10, 3, 0, 0, 100000)
case('greater white skill1 only', 3, lambda n: n['search_greater'](0, 100000, n['parameter'](J(105), 10, '', 0, 1, 'マカ')),
     'search_greater', J(105), 10, '-', 0, 1, 0, 0, 100000)
case('around melding', 0, lambda n: n['around'](4723, 60, 'マカ'), 'around', 4723, 60, 0)
case('around quest red', 1, lambda n: n['around'](296260, 25, '炭鉱'), 'around', 296260, 25, 1)
case('around near zero', 0, lambda n: n['around'](5, 20, 'マカ'), 'around', 5, 20, 0)
case('halcyon r4', 2, lambda n: n['halcyonpush'](1730), 'halcyon', 1730, 4)
case('halcyon r1', 0, lambda n: n['halcyonpush'](98765, 1), 'halcyon', 98765, 1)
case('juju r4', 1, lambda n: n['jujupush'](1730), 'juju', 1730, 4)
case('juju r2', 1, lambda n: n['jujupush'](55555, 2), 'juju', 55555, 2)
case('sequence', 1, lambda n: n['sequence_charm'](221014, 40), 'sequence', 221014, 40)
case('fill slot', 0, lambda n: n['search_fill_slot'](0, 10 ** 6, 20, 3, 'マカ'), 'fill', 0, 10 ** 6, 20, 3, 0)
case('fill slot quest', 1, lambda n: n['search_fill_slot'](0, 300000, 15, 2, '炭鉱'), 'fill', 0, 300000, 15, 2, 1)
case('allpush', 0, lambda n: n['allpush'](1600, 200, True), 'allpush', 1600, 200, 1)
case('allpush small', 1, lambda n: n['allpush'](3, 60, False), 'allpush', 3, 60, 0)
case('watch', 0, lambda n: n['watch'](296260 - 4723), 'watch', 296260 - 4723)
case('watch long', 0, lambda n: n['watch'](123456789), 'watch', 123456789)
case('combo', 0, lambda n: n['search_combo'](0, 10 ** 6, combo), 'combo', 0, 10 ** 6, combo)
case('combo invalid', 0, lambda n: n['search_combo'](0, 1000, bad_combo), 'combo', 0, 1000, bad_combo)
case('reward', 0, lambda n: n['search_reward'](0, 10 ** 6, 28, reward, reward_table),
     'reward', 0, 10 ** 6, 28, reward_str, reward)
case('reward short', 0, lambda n: n['search_reward'](0, 300000, 28, 'Fishing RawMeat Whetstone Fishing', reward_table),
     'reward', 0, 300000, 28, reward_str, 'Fishing RawMeat Whetstone Fishing')
case('far jump', 0, lambda n: n['around'](10 ** 12 + 7, 5, 'マカ'), 'around', 10 ** 12 + 7, 5, 0)

failures = 0
for name, kind, pyfn, swargs in cases:
    expected = py(kind, pyfn).rstrip('\n')
    got = sw(kind, *swargs).rstrip('\n')
    ok = expected == got
    lines = expected.count('\n') + 1
    print(f'{"PASS" if ok else "FAIL"}  {name}  ({lines} lines)')
    if not ok:
        failures += 1
        el, gl = expected.splitlines(), got.splitlines()
        for i in range(max(len(el), len(gl))):
            a = el[i] if i < len(el) else '<missing>'
            b = gl[i] if i < len(gl) else '<missing>'
            if a != b:
                print(f'   line {i + 1}\n   py: {a!r}\n   sw: {b!r}')
                break
print(f'\n{len(cases) - failures}/{len(cases)} passed')
sys.exit(1 if failures else 0)
