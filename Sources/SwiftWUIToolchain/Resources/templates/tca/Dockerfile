# Reproducible wasm build (spec §9). Requires the Swift.org WASM SDK artifactbundle
# URL for the EXACT toolchain in the base image:
#   docker build --build-arg WASM_SDK_URL=<artifactbundle url> --output type=local,dest=dist-docker .
# NOTE: works once the SwiftWUI dependency in Package.swift is a git URL or is
# vendored inside this directory — a path dependency outside the build context
# is invisible to docker (README, "Docker" section).
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
RUN swift run {{NAME}} ssg --out dist

FROM scratch AS export
COPY --from=build /src/dist /
