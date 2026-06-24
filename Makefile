# ─── Ledge — Build / Sign / Distribute ────────────────────────────────────────
#
# make app      → build + crée dist/Ledge.app (ad-hoc signé)
# make sign     → signe avec Developer ID (nécessite DEVELOPER_ID_APP)
# make dmg      → crée dist/Ledge-<VERSION>.dmg prêt à distribuer
# make notarize → envoie à Apple pour notarisation (nécessite APPLE_ID + TEAM_ID)
# make clean    → supprime dist/ et .build/
#
# Variables à définir (via env ou CLI) :
#   DEVELOPER_ID_APP   ex. "Developer ID Application: Adrien Marques (XXXXXXXXXX)"
#   APPLE_ID           ex. "adrien@datakeen.co"
#   TEAM_ID            ex. "XXXXXXXXXX"
#   APP_PASSWORD       App-specific password (https://appleid.apple.com)

BINARY_NAME   := Ledge
BUNDLE_ID     := me.adrienmarques.ledge
VERSION       := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Sources/App/Info.plist 2>/dev/null || echo "0.1.0")
DIST_DIR      := dist
BUNDLE        := $(DIST_DIR)/$(BINARY_NAME).app
CONTENTS      := $(BUNDLE)/Contents
MACOS_DIR     := $(CONTENTS)/MacOS
RES_DIR       := $(CONTENTS)/Resources
FRAMEWORKS    := $(CONTENTS)/Frameworks
BINARY        := $(MACOS_DIR)/$(BINARY_NAME)
DMG_NAME      := $(BINARY_NAME)-$(VERSION).dmg
BUILD_DIR     := .build/release

# Sparkle XCFramework (SPM le place dans .build/artifacts)
RELEASE_URL   := https://TODO

SPARKLE_XCF   := $(shell find .build/artifacts -name "Sparkle.xcframework" 2>/dev/null | head -1)
SPARKLE_FW    := $(SPARKLE_XCF)/macos-arm64_x86_64/Sparkle.framework

.PHONY: all app sign dmg notarize release clean

all: app

# ─── 1. Build + bundle ─────────────────────────────────────────────────────────

app:
	@echo "▸ Build release…"
	swift build -c release

	@echo "▸ Création du bundle…"
	rm -rf $(BUNDLE)
	mkdir -p $(MACOS_DIR) $(RES_DIR) $(FRAMEWORKS)

	# Binaire principal
	cp $(BUILD_DIR)/App $(BINARY)
	chmod +x $(BINARY)

	# Info.plist
	cp Sources/App/Info.plist $(CONTENTS)/Info.plist

	# Bundles de ressources SPM (localisation…)
	@for b in $(BUILD_DIR)/*.bundle; do \
	  [ -d "$$b" ] && cp -r "$$b" $(RES_DIR)/ && echo "  ressources: $$b" || true; \
	done

	# Sparkle.framework (si disponible)
	@if [ -d "$(SPARKLE_FW)" ]; then \
	  echo "  Sparkle.framework → Frameworks/"; \
	  cp -r $(SPARKLE_FW) $(FRAMEWORKS)/; \
	  install_name_tool -add_rpath @executable_path/../Frameworks $(BINARY) 2>/dev/null || true; \
	else \
	  echo "  ⚠  Sparkle.framework non trouvé (exécuter swift build d'abord)"; \
	fi

	# Signature ad-hoc : binaires internes Sparkle en premier, puis l'app
	@if [ -d "$(FRAMEWORKS)/Sparkle.framework" ]; then \
	  codesign --force --sign - $(FRAMEWORKS)/Sparkle.framework/Autoupdate 2>/dev/null || true; \
	  codesign --force --sign - --identifier org.sparkle-project.Sparkle \
	    $(FRAMEWORKS)/Sparkle.framework 2>/dev/null || true; \
	fi
	codesign --force --sign - $(BINARY)
	codesign --force --sign - $(BUNDLE)
	@echo "✓ $(BUNDLE) — signature ad-hoc"

# ─── 2. Signature Developer ID ─────────────────────────────────────────────────

sign: app
ifndef DEVELOPER_ID_APP
	$(error Définir DEVELOPER_ID_APP, ex: make sign DEVELOPER_ID_APP="Developer ID Application: Prénom Nom (TEAMID)")
endif
	@echo "▸ Signature Developer ID…"
	@if [ -d "$(FRAMEWORKS)/Sparkle.framework" ]; then \
	  codesign --force --options runtime --sign "$(DEVELOPER_ID_APP)" \
	    --entitlements Scripts/Sparkle.entitlements \
	    $(FRAMEWORKS)/Sparkle.framework; \
	fi
	codesign --force --deep --options runtime \
	  --entitlements Scripts/App.entitlements \
	  --sign "$(DEVELOPER_ID_APP)" $(BUNDLE)
	codesign --verify --deep --strict $(BUNDLE)
	@echo "✓ Signé : $(BUNDLE)"

# ─── 3. DMG ────────────────────────────────────────────────────────────────────

dmg: app
	@echo "▸ Création du DMG…"
	rm -f $(DIST_DIR)/$(DMG_NAME)
	@# Crée un DMG temporaire en lecture-écriture
	hdiutil create \
	  -volname "$(BINARY_NAME)" \
	  -srcfolder $(BUNDLE) \
	  -ov -format UDRW \
	  $(DIST_DIR)/tmp_$(DMG_NAME)

	@# Convertit en DMG compressé en lecture seule
	hdiutil convert $(DIST_DIR)/tmp_$(DMG_NAME) \
	  -format UDZO \
	  -o $(DIST_DIR)/$(DMG_NAME)
	rm -f $(DIST_DIR)/tmp_$(DMG_NAME)
	@echo "✓ $(DIST_DIR)/$(DMG_NAME)"

# ─── 4. Notarisation Apple ─────────────────────────────────────────────────────
# Prérequis : DEVELOPER_ID_APP, APPLE_ID, TEAM_ID, APP_PASSWORD

notarize: dmg
ifndef DEVELOPER_ID_APP
	$(error Définir DEVELOPER_ID_APP)
endif
ifndef APPLE_ID
	$(error Définir APPLE_ID)
endif
ifndef TEAM_ID
	$(error Définir TEAM_ID)
endif
ifndef APP_PASSWORD
	$(error Définir APP_PASSWORD (app-specific password depuis appleid.apple.com))
endif
	@echo "▸ Envoi pour notarisation…"
	xcrun notarytool submit $(DIST_DIR)/$(DMG_NAME) \
	  --apple-id "$(APPLE_ID)" \
	  --team-id "$(TEAM_ID)" \
	  --password "$(APP_PASSWORD)" \
	  --wait
	xcrun stapler staple $(DIST_DIR)/$(DMG_NAME)
	@echo "✓ Notarisé et agrafé : $(DIST_DIR)/$(DMG_NAME)"

# ─── 5. Publication ────────────────────────────────────────────────────────────
# Prérequis : toutes les variables de notarize + RELEASE_URL (+ RELEASE_TOKEN optionnel)
#
# Usage :
#   make release CHANGELOG="Fix timer ring, improve ambient"
#   make release CHANGELOG="$(cat CHANGELOG.md)"
#
# Variables :
#   RELEASE_TOKEN  Bearer token (optionnel)
#   CHANGELOG      Texte du changelog (obligatoire)

release: dmg
ifndef CHANGELOG
	$(error Définir CHANGELOG, ex: make release CHANGELOG="Fix timer ring")
endif
	@echo "▸ Publication de la release v$(VERSION)…"
	@curl --fail --silent --show-error \
	  -X POST \
	  $(if $(RELEASE_TOKEN),-H "Authorization: Bearer $(RELEASE_TOKEN)") \
	  -F "version=$(VERSION)" \
	  -F "changelog=$(CHANGELOG)" \
	  -F "file=@$(DIST_DIR)/$(DMG_NAME)" \
	  "$(RELEASE_URL)"
	@echo "✓ Release v$(VERSION) publiée → $(RELEASE_URL)"

# ─── Nettoyage ─────────────────────────────────────────────────────────────────

clean:
	rm -rf $(DIST_DIR) .build
	@echo "✓ Nettoyé"
