# ProjDesk — 一键构建
# 需要 MoonBit 工具链、Node.js

.PHONY: all kernel kernel-test audit registry-check wasm web web-test clean

all: kernel kernel-test audit web web-test

kernel:
	cd moonbit && moon build --target wasm-gc --release
	cp moonbit/_build/wasm-gc/release/build/main/main.wasm web/public/projdesk.wasm
	cp moonbit/_build/wasm-gc/release/build/main/main.wasm cli/projdesk.wasm
	@echo "WASM copied to web/public/ and cli/"

kernel-test:
	cd moonbit && moon test

audit:
	node scripts/audit-claims.js

registry-check:
	node scripts/verify-registry-consumption.js

web:
	cd web && npm run build

web-test:
	cd web && npm run test

clean:
	rm -rf moonbit/_build web/dist web/node_modules
