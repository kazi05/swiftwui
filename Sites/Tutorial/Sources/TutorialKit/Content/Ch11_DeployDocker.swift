/// Chapter 11 — Deploy with Docker.
public enum Ch11 {
    // verbatim contiguous block of Samples/ShipCounter/Dockerfile (Task 11 Step 3)
    static let dockerCode = #"""
FROM swift:6.3.3 AS build
ARG WASM_SDK_URL
WORKDIR /src
COPY . .
RUN swift sdk install "$WASM_SDK_URL"
RUN swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c release
RUN mkdir -p dist/app dist/vendor \
 && cp -r .build/plugins/PackageToJS/outputs/Package/. dist/app/ \
 && cp -r vendor/. dist/vendor/ \
 && cp index.html dist/index.html
RUN swift run ShipCounter ssg --out dist

FROM scratch AS export
COPY --from=build /src/dist /
"""#

    public static let chapter = Chapter(
        slug: "deploy-with-docker", track: .ship, kicker: "CHAPTER · SHIP",
        title: "Deploy with Docker",
        tagline: "One reproducible image: build the wasm bundle, prerender, export static files.",
        minutes: 15, kind: .chapter,
        sections: [
            Section(anchor: "image", kicker: "01 · IMAGE",
                    title: "One multi-stage build",
                    intro: "Swift builds in stage one; only static files leave the image.",
                    steps: [
                        Step("Stage one: a swift:6.3.3 image installs the WASM SDK, builds the release bundle, and runs ssg.",
                             detail: "The SDK artifactbundle URL arrives as a build arg — it must match the image’s toolchain exactly."),
                        Step("Stage two is FROM scratch: docker build --output exports dist/ as plain files."),
                        Step("The template Dockerfile ships with every swiftwui init scaffold."),
                    ],
                    panel: .code(CodePanel(file: "Dockerfile", code: dockerCode,
                                           origin: .fragment(path: "Sites/Tutorial/Samples/ShipCounter/Dockerfile")))),
            Section(anchor: "serve", kicker: "02 · SERVE",
                    title: "Serving the export",
                    intro: "The output is a static site; host it anywhere.",
                    steps: [
                        Step("The exported dist/ is plain static files — nginx, a CDN, any static host works.",
                             detail: "Give .wasm the application/wasm MIME type and add an SPA fallback for non-prerendered routes."),
                        Step("A release build precompresses every text asset next to the original.",
                             detail: ".gz and .br files sit beside each entry; serve them with content negotiation."),
                        Step("It also writes dist/nginx.conf with the MIME types, the fallback and the negotiation already set up."),
                        Step("wasm-opt is optional — the build warns and continues when it is missing, it never fails."),
                        Step("Local preview without Docker: swiftwui serve dist."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "docker build --build-arg WASM_SDK_URL=<url> --output type=local,dest=dist-docker ."),
                        TermLine(.output, "  precompressed 25 file(s) (gzip + brotli); wrote nginx.conf"),
                        TermLine(.command, "swiftwui serve dist-docker"),
                    ])),
            Section(anchor: "installable", kicker: "03 · INSTALLABLE",
                    title: "Make it installable",
                    intro: "PWA support is opt-in and it hands you the files rather than hiding them. Nothing about the framework changes for apps that skip it.",
                    steps: [
                        Step("swiftwui init --pwa, or swiftwui pwa init in an existing project.",
                             detail: "It scaffolds a manifest, icons and sw.js into your repo — you own and edit them."),
                        Step("Every build and ssg regenerates dist/sw-assets.js: a SHA-256 precache manifest.",
                             detail: "sw-assets.js is a reserved name in public/, alongside app, vendor, index.html, styles.css, nginx.conf and __swiftwui."),
                        Step("Per-route prerendered pages are never precached — they are an SEO artifact, not an offline one."),
                        Step("Read \\.appUpdateAvailable in a body and call \\.reloadToUpdate to offer the swap.",
                             detail: "A banner beats a silent reload: the user decides when to lose their place."),
                        Step("A service worker never registers under swiftwui dev.",
                             detail: "Stale caching during hot reload is a debugging trap you should not have to think about."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "swiftwui pwa init"),
                        TermLine(.output, "  created public/manifest.webmanifest"),
                        TermLine(.output, "  created public/sw.js"),
                        TermLine(.output, "  created public/icons/icon-192.png"),
                        TermLine(.command, "swiftwui build -c release --out dist"),
                        TermLine(.note, "> wrote dist/sw-assets.js (precache manifest)"),
                    ])),
        ])
}
