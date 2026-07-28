# Fonts

Three self-hosted variable faces. Latin-subset woff2, generated from upstream
sources — regenerate with the commands below rather than editing in place.

| File | Family | Axes shipped | Upstream | Licence |
|---|---|---|---|---|
| `InstrumentSans-Variable.woff2` | Instrument Sans | `wght 400–700` (`wdth` pinned to 100) | [google/fonts `ofl/instrumentsans`](https://github.com/google/fonts/tree/main/ofl/instrumentsans) | OFL 1.1 — `InstrumentSans-OFL.txt` |
| `Literata-Variable.woff2` | Literata | `opsz 7–72`, `wght 300–700` | [google/fonts `ofl/literata`](https://github.com/google/fonts/tree/main/ofl/literata) | OFL 1.1 — `Literata-OFL.txt` |
| `CommitMono-Variable.woff2` | Commit Mono | `wght 300–700` | [eigilnikolajsen/commit-mono](https://github.com/eigilnikolajsen/commit-mono) | MIT — `CommitMono-LICENSE.txt` |

Instrument Sans is UI and headings, Literata is long-form prose, Commit Mono is
code and every mono label. They are declared in `TutorialKit/Theme.swift` via
`App.fontFaces`; the fallback stacks in `Fonts` keep the site readable before
they load and on a failed fetch.

## Regenerating

Needs `fonttools[woff]` (pulls in brotli, which is what writes woff2):

```sh
python3 -m venv .fontenv && .fontenv/bin/pip install 'fonttools[woff]'
U='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+2074,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+2248,U+25B2-25BE,U+2713-2717,U+FEFF,U+FFFD'

# Instrument Sans — pin the width axis, the design only uses weight
.fontenv/bin/python -m fontTools.varLib.instancer 'InstrumentSans[wdth,wght].ttf' wdth=100 -o is.ttf
.fontenv/bin/python -m fontTools.subset is.ttf --unicodes="$U" --flavor=woff2 \
    --layout-features='*' --no-hinting --desubroutinize -o InstrumentSans-Variable.woff2

# Literata — clamp the weight axis to the range the type scale uses
.fontenv/bin/python -m fontTools.varLib.instancer 'Literata[opsz,wght].ttf' wght=300:700 -o lit.ttf
.fontenv/bin/python -m fontTools.subset lit.ttf --unicodes="$U" --flavor=woff2 \
    --layout-features='*' --no-hinting --desubroutinize -o Literata-Variable.woff2

# Commit Mono — keep the `zero` feature, the theme turns on the slashed zero
.fontenv/bin/python -m fontTools.subset CommitMonoV143-VF.ttf --unicodes="$U" --flavor=woff2 \
    --layout-features='*' --layout-features+=zero --no-hinting --desubroutinize \
    -o CommitMono-Variable.woff2
```

The subset is Latin-1 plus general punctuation, arrows, the euro, the geometric
shapes and check marks the UI draws, and the replacement character — enough for
the tutorial's prose, code and terminal transcripts. Adding a language means
widening `$U` and regenerating all three.

A subsetter can only keep glyphs the source font already has, so widening `$U`
is not enough on its own. Of the three faces only Commit Mono carries `▼ ✓ ✕`,
which is why `.tut-chevron` and `.tut-radio` set the mono family explicitly —
otherwise those marks fall back to a system font at the wrong size. None of the
three has `▾` (U+25BE); the site uses `▼` (U+25BC) instead. Check coverage
before introducing a new symbol:

```sh
.fontenv/bin/python -c "
from fontTools.ttLib import TTFont
print(hex(0x25BC) , 0x25BC in TTFont('CommitMono-Variable.woff2').getBestCmap())"
```
