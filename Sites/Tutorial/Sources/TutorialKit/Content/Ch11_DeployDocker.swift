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
                    title: "Serving — and one honest caveat",
                    intro: "The output is a static site; host it anywhere. One prerequisite applies today.",
                    steps: [
                        Step("The exported dist/ is plain static files — nginx, a CDN, any static host works.",
                             detail: "Give .wasm the application/wasm MIME type and add an SPA fallback for non-prerendered routes."),
                        Step("Honest limitation: the Docker build needs a published SwiftWUI package — a path dependency outside the build context cannot resolve.",
                             detail: "Works as-is the day SwiftWUI has a public git URL; the Dockerfile documents this."),
                        Step("Local preview without Docker: swiftwui serve dist."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "docker build --build-arg WASM_SDK_URL=<url> --output type=local,dest=dist-docker ."),
                        TermLine(.note, "> note: requires a published SwiftWUI package —"),
                        TermLine(.note, ">       path dependencies stay outside the build context"),
                        TermLine(.command, "swiftwui serve dist-docker"),
                    ])),
        ])
}
