# Reproducible builds and responsive assets

`swiftwui build` resolves `swift`, `swiftc`, and the selected WASM SDK through
the process environment that runs the command. It rejects a missing SDK, an
Embedded SDK, or known mismatched host/compiler/SDK versions. It does not reject
newer matching Swift releases. For a non-default installation, put the matching
toolchain `usr/bin` first in `PATH` and set `SWIFT_EXEC` to its `swiftc` before
running the command.

```sh
swiftwui build -c release --swift-sdk swift-6.3.3-RELEASE_wasm --fixture counter
```

Every build writes `dist/swiftwui-build-report.json`. It records raw, gzip, and
Brotli bytes when those siblings exist, WASM section and import composition, and
the resolved `swift`/`swiftc` paths and tool versions. Compression uses the
existing deterministic gzip settings. Section composition is a structural
signal, not symbol attribution.

To enforce a budget, create `swiftwui-wasm-budget.json` in the app root, or pass
`--budget path`. The fixture and configuration must match the report; this avoids
comparing a debug demo with a release production application.

```json
{
  "fixture": "counter",
  "configuration": "release",
  "maximum": {
    "rawBytes": 10000000,
    "gzipBytes": 3600000,
    "brotliBytes": 2600000
  }
}
```

Run `swiftwui metrics --out dist --fixture counter -c release --budget swiftwui-wasm-budget.json`
to inspect an artifact that was built elsewhere. The command intentionally does
not manufacture compressed siblings; run a release build first when compressed
budgets matter.

## Responsive assets

Image encoders and font subsetters are host tools, so SwiftWUI keeps them outside
the core package. Add an opt-in `swiftwui-assets.json` at the app root. A source
plus widths uses macOS `sips` by default; on other hosts, provide an argument
array for an installed tool such as ImageMagick. `{input}`, `{output}`, and
`{width}` are substituted without shell evaluation.

```json
{
  "images": [{
    "id": "hero",
    "source": "images/hero.webp",
    "widths": [640, 1280],
    "command": ["magick", "{input}", "-resize", "{width}x", "{output}"],
    "sizes": "(max-width: 700px) 100vw, 700px"
  }],
  "fonts": [{
    "command": ["pyftsubset", "public/fonts/Brand.ttf", "--output-file=public/fonts/Brand.woff2", "--flavor=woff2", "--text-file=font-glyphs.txt"]
  }]
}
```

During `swiftwui build`, variants are created under `public/` before that folder
is copied to `dist`; their dimensions and aspect ratio are checked. Each listed
font command runs as an argument array in the project directory; no shell
interpolation is used. Set a font `output` to include its root-relative URL in
the manifest. The build writes
`dist/swiftwui-assets-manifest.json`, with intrinsic dimensions, `src`,
`srcset`, and `sizes`. Use those values with the existing `Img(src:alt:srcset:sizes:)`
API and add a page-level font preload where the font is critical.

The pipeline does not choose encoders, image quality, image crops, or glyph sets.
Those are product decisions and should be pinned in the app's toolchain/CI.
