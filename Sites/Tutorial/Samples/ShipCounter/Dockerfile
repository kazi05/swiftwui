# Reproducible wasm build (spec §9). The build args pin the Swift.org WASM SDK
# artifactbundle and its SHA-256 for the EXACT toolchain in the base image;
# override both together (and the SDK id below) when you change the image:
#   docker build --output type=local,dest=dist-docker .
# NOTE: works once the SwiftWUI dependency in Package.swift is a git URL or is
# vendored inside this directory — a path dependency outside the build context
# is invisible to docker (README, "Docker" section).
FROM swift:6.4.0-noble AS build
ARG WASM_SDK_URL=https://download.swift.org/swift-6.4.0-release/wasm-sdk/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE_wasm.artifactbundle.tar.gz
ARG WASM_SDK_CHECKSUM=f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d
WORKDIR /src
COPY . .
RUN swift sdk install "$WASM_SDK_URL" --checksum "$WASM_SDK_CHECKSUM"
RUN swift package --swift-sdk swift-6.4.0-RELEASE_wasm js -c release
RUN mkdir -p dist/app dist/vendor \
 && cp -r .build/plugins/PackageToJS/outputs/Package/. dist/app/ \
 && cp -r vendor/. dist/vendor/ \
 && cp index.html dist/index.html
RUN swift run ShipCounter ssg --out dist

FROM scratch AS export
COPY --from=build /src/dist /
