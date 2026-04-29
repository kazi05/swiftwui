# SwiftWUI build pipeline.
#
# Top-level entry points for non-Swift contributors and CI runners. Each
# target is composable and idempotent; the release pipeline produces a
# directory under `dist/` that can be uploaded directly to a static host
# (Cloudflare Pages, Netlify, S3, etc.) without further processing.
#
# Override SDK / TARGET / OUT on the command line, e.g.:
#   make release TARGET=Counter OUT=dist
#
# Required tools by target:
#   dev / build / release : swift, swiftwasm SDK installed via `swift sdk install`
#   release (optimised)   : binaryen (`brew install binaryen`) for wasm-opt
#   release (compressed)  : brotli, gzip, openssl  (all standard on macOS / Linux)

SDK    ?= swift-6.2.3-RELEASE_wasm
TARGET ?= Counter
OUT    ?= dist
PORT   ?= 8080

# Path to the PackageToJS plugin output for the chosen target. Used for
# debug serving and as the source for `release` to copy from.
PACKAGE_JS_OUT := .build/plugins/PackageToJS/outputs/Package

.PHONY: help
help:
	@echo "SwiftWUI Makefile targets:"
	@echo "  dev           Run the SwiftWUI dev server on http://localhost:$(PORT)"
	@echo "  build         Debug build of $(TARGET) via swift package js"
	@echo "  release       Optimised release build → $(OUT)/  (brotli + SRI)"
	@echo "  test          swift test --parallel"
	@echo "  test-seq      swift test (sequential, 100% deterministic)"
	@echo "  test-coverage swift test with code-coverage data emitted"
	@echo "  lint          swift format lint --recursive --strict Sources Tests"
	@echo "  format        swift format format --recursive --in-place Sources Tests"
	@echo "  size          Report .wasm / .js / brotli sizes in $(OUT)/"
	@echo "  clean         Remove .build, $(OUT), node_modules"
	@echo "  showcase-build  Native build of the Examples/Showcase project"
	@echo "  sync-templates  Sync Examples/Showcase to SwiftWUICLI Templates/ resource bundle"
	@echo "  ci              build + test + showcase-build (full CI)"
	@echo "Variables: SDK=$(SDK)  TARGET=$(TARGET)  OUT=$(OUT)  PORT=$(PORT)"

.PHONY: dev
dev:
	swift run swiftwui-dev dev --target $(TARGET) --port $(PORT)

.PHONY: build
build:
	swift package --swift-sdk $(SDK) js -c debug --product $(TARGET)

.PHONY: release
release:
	@echo ">>> Release build: $(TARGET) → $(OUT)/"
	swift package --swift-sdk $(SDK) -c release \
	  -Xswiftc -Osize \
	  -Xswiftc -wmo \
	  -Xswiftc -gnone \
	  -Xswiftc -disable-reflection-metadata \
	  -Xlinker --strip-all \
	  js --product $(TARGET)
	@mkdir -p $(OUT)
	@cp -R $(PACKAGE_JS_OUT)/* $(OUT)/
	@echo ">>> wasm-opt -Oz pass"
	@if command -v wasm-opt >/dev/null 2>&1; then \
	  wasm-opt -Oz --strip-debug --strip-producers --converge \
	    $(OUT)/$(TARGET).wasm -o $(OUT)/$(TARGET).wasm; \
	else \
	  echo "warning: wasm-opt not found (brew install binaryen)"; \
	fi
	@echo ">>> compressing"
	@for f in $(OUT)/*.wasm $(OUT)/*.js; do \
	  [ -f "$$f" ] || continue; \
	  command -v gzip >/dev/null 2>&1 && gzip -9 -k -f "$$f"; \
	  command -v brotli >/dev/null 2>&1 && brotli -q 11 -k -f "$$f"; \
	done
	@echo ">>> SHA-384 SRI hashes"
	@for f in $(OUT)/*.wasm $(OUT)/*.js; do \
	  [ -f "$$f" ] || continue; \
	  hash=$$(openssl dgst -sha384 -binary "$$f" | openssl base64 -A); \
	  echo "sha384-$$hash" > "$$f.sri"; \
	done
	@$(MAKE) --no-print-directory size

.PHONY: size
size:
	@if [ ! -d $(OUT) ]; then echo "no $(OUT)/ — run \`make release\` first"; exit 1; fi
	@echo "--- $(OUT)/ artefact sizes ---"
	@for f in $(OUT)/*.wasm $(OUT)/*.js $(OUT)/*.wasm.br $(OUT)/*.js.br $(OUT)/*.wasm.gz $(OUT)/*.js.gz; do \
	  [ -f "$$f" ] || continue; \
	  size=$$(wc -c < "$$f" | tr -d ' '); \
	  if [ "$$size" -gt 1048576 ]; then \
	    printf "  %-40s %.1f MB\n" "$$(basename $$f)" "$$(echo "$$size/1048576" | bc -l)"; \
	  else \
	    printf "  %-40s %.1f KB\n" "$$(basename $$f)" "$$(echo "$$size/1024" | bc -l)"; \
	  fi; \
	done

.PHONY: test
test:
	swift test --parallel

.PHONY: test-seq
test-seq:
	swift test

.PHONY: test-coverage
test-coverage:
	swift test --enable-code-coverage --parallel

.PHONY: lint
lint:
	swift format lint --recursive --strict Sources Tests

.PHONY: format
format:
	swift format format --recursive --in-place Sources Tests

.PHONY: clean
clean:
	rm -rf .build $(OUT)
	@find . -name node_modules -type d -prune -exec rm -rf {} + 2>/dev/null || true

.PHONY: showcase-build
showcase-build:
	cd Examples/Showcase && swift build

.PHONY: ci
ci: build test showcase-build
	@echo "CI green."

.PHONY: sync-templates
sync-templates:
	rm -rf Sources/SwiftWUICLI/Templates/showcase
	mkdir -p Sources/SwiftWUICLI/Templates
	rsync -a --exclude='.build' --exclude='node_modules' \
	      --exclude='.swiftpm' --exclude='dist' \
	      --exclude='Package.resolved' \
	      Examples/Showcase/ Sources/SwiftWUICLI/Templates/showcase/
	rm -rf Sources/SwiftWUICLI/Templates/showcase/.build
	rm -rf Sources/SwiftWUICLI/Templates/showcase/.swiftpm
	@# Replace literal "Showcase" / "showcase" with placeholder tokens.
	@# BSD/GNU sed: -i '' on macOS, -i '' on linux gnu requires no space.
	@# Use a portable workaround that writes to .bak then deletes.
	find Sources/SwiftWUICLI/Templates/showcase -type f \
	  \( -name '*.swift' -o -name '*.html' -o -name '*.md' \) \
	  -exec sed -i.bak 's/Showcase/{{PROJECT_NAME}}/g; s/showcase/{{project_name}}/g' {} +
	find Sources/SwiftWUICLI/Templates/showcase -type f -name '*.bak' -delete
