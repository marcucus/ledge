# ─── Ledge — Build / Sign / Distribute ────────────────────────────────────────
#
# make app      → build + crée dist/Ledge.app (ad-hoc signé)
# make sign     → signe avec Developer ID (nécessite DEVELOPER_ID_APP)
# make dmg      → crée dist/Ledge-<VERSION>.dmg prêt à distribuer
# make notarize → envoie à Apple pour notarisation (nécessite APPLE_ID + TEAM_ID)
# make appcast  → signe le(s) .dmg et génère dist/appcast.xml (Sparkle)
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

# Identité de signature pour le build de DEV (`make app`). Une identité stable (certificat
# Apple Development) garde le même "designated requirement" entre les rebuilds → l'autorisation
# Accessibilité accordée à Ledge.app PERSISTE (contrairement à l'ad-hoc dont le hash change).
# Auto-détecte le 1er certificat Apple Development ; sinon repli sur ad-hoc ("-").
DEV_IDENTITY  := $(shell security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Apple Development" | sed -E 's/.*"(.*)"/\1/')
DEV_SIGN      := $(if $(DEV_IDENTITY),$(DEV_IDENTITY),-)

# Sparkle XCFramework (SPM le place dans .build/artifacts)
RELEASE_URL   := https://TODO

SPARKLE_XCF   := $(shell find .build/artifacts -name "Sparkle.xcframework" 2>/dev/null | head -1)
SPARKLE_FW    := $(SPARKLE_XCF)/macos-arm64_x86_64/Sparkle.framework
GENERATE_APPCAST := $(shell find .build/artifacts -path "*/bin/generate_appcast" 2>/dev/null | head -1)

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

	# Localisation des clés Info.plist (NSAppleEventsUsageDescription, etc.) :
	# macOS ne lit InfoPlist.strings qu'à la racine de Resources/<lang>.lproj/,
	# pas dans un sous-bundle SPM — on les copie donc directement ici.
	@for lang in en fr; do \
	  src="Sources/App/Resources/$$lang.lproj/InfoPlist.strings"; \
	  if [ -f "$$src" ]; then \
	    mkdir -p "$(RES_DIR)/$$lang.lproj"; \
	    cp "$$src" "$(RES_DIR)/$$lang.lproj/InfoPlist.strings"; \
	  fi; \
	done

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

	# Binaires internes Sparkle (ad-hoc, pas concernés par TCC) en premier…
	@if [ -d "$(FRAMEWORKS)/Sparkle.framework" ]; then \
	  codesign --force --sign - $(FRAMEWORKS)/Sparkle.framework/Autoupdate 2>/dev/null || true; \
	  codesign --force --sign - --identifier org.sparkle-project.Sparkle \
	    $(FRAMEWORKS)/Sparkle.framework 2>/dev/null || true; \
	fi
	# …puis l'app avec l'identité DEV stable (→ autorisation Accessibilité persistante).
	codesign --force --sign "$(DEV_SIGN)" $(BINARY)
	codesign --force --sign "$(DEV_SIGN)" $(BUNDLE)
	@echo "✓ $(BUNDLE) — signé avec : $(DEV_SIGN)"

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

# ─── 5. Appcast Sparkle ────────────────────────────────────────────────────────
# Signe le(s) .dmg de dist/ avec la clé EdDSA du Keychain (générée via
# generate_keys, cf. Sources/App/Info.plist → SUPublicEDKey) et écrit/met à jour
# dist/appcast.xml. À uploader avec le(s) .dmg vers l'hébergement choisi pour
# SUFeedURL (cf. docs/10-audit-et-plan.md).

appcast: notarize
ifeq ($(strip $(GENERATE_APPCAST)),)
	$(error generate_appcast introuvable — exécuter `swift build` au moins une fois)
endif
	@echo "▸ Génération de l'appcast Sparkle…"
	$(GENERATE_APPCAST) $(DIST_DIR)
	@echo "✓ $(DIST_DIR)/appcast.xml"

# ─── 6. Publication ────────────────────────────────────────────────────────────
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
