# ─── Ledge — Build / Sign / Distribute ────────────────────────────────────────
#
# make app      → build + crée dist/Ledge.app (signature de développement stable)
# make release  → DMG auto-hébergé, signature ad hoc + EdDSA Sparkle (sans compte Apple)
# make sign     → signe avec Developer ID (optionnel, nécessite DEVELOPER_ID_APP)
# make notarize → envoie à Apple pour notarisation (optionnel)
# make release-notarized → variante Developer ID + notarisation
# make clean    → supprime dist/ et .build/
#
# Variables à définir (via env ou CLI) :
#   GITHUB_TOKEN      optionnel si le token est dans le Trousseau macOS
#   GITHUB_REPOSITORY dépôt de publication (défaut : marcucus/ledge)
#   DEVELOPER_ID_APP   ex. "Developer ID Application: Adrien Marques (XXXXXXXXXX)"
#   SPARKLE_FEED_URL    optionnel, pointe par défaut vers la dernière GitHub Release
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
GITHUB_REPOSITORY ?= marcucus/ledge
SPARKLE_FEED_URL ?= https://github.com/$(GITHUB_REPOSITORY)/releases/latest/download/appcast.xml
BUILD_NUMBER  := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleVersion" Sources/App/Info.plist 2>/dev/null || echo "1")
MIN_OS        := $(shell /usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" Sources/App/Info.plist 2>/dev/null || echo "14.0")

export GITHUB_TOKEN GITHUB_REPOSITORY VERSION BUILD_NUMBER MIN_OS CHANGELOG
export DMG_PATH := $(DIST_DIR)/$(DMG_NAME)
export APPCAST_PATH := $(DIST_DIR)/appcast.xml

SPARKLE_XCF   := $(shell find .build/artifacts -name "Sparkle.xcframework" 2>/dev/null | head -1)
SPARKLE_FW    := $(SPARKLE_XCF)/macos-arm64_x86_64/Sparkle.framework
GENERATE_APPCAST := $(shell find .build/artifacts -path "*/bin/generate_appcast" 2>/dev/null | head -1)

.PHONY: all app direct-sign direct-dmg direct-appcast sign dmg notarize appcast \
	release release-notarized dmg-image appcast-image clean

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
	  ditto $(SPARKLE_FW) $(FRAMEWORKS)/Sparkle.framework; \
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

# ─── 2. Distribution directe, sans compte Apple ────────────────────────────────

direct-sign: app
ifndef SPARKLE_FEED_URL
	$(error Définir SPARKLE_FEED_URL, ex: https://ledge.example/appcast.xml)
endif
	@echo "▸ Préparation de la distribution directe…"
	/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $(SPARKLE_FEED_URL)" $(CONTENTS)/Info.plist 2>/dev/null || \
	  /usr/libexec/PlistBuddy -c "Set :SUFeedURL $(SPARKLE_FEED_URL)" $(CONTENTS)/Info.plist
	codesign --force --sign - $(BINARY)
	codesign --force --sign - $(BUNDLE)
	codesign --verify --deep --strict $(BUNDLE)
	@echo "✓ Bundle signé ad hoc — aucune validation App Store requise"

direct-dmg: direct-sign
	@$(MAKE) dmg-image VERSION="$(VERSION)"

direct-appcast: direct-dmg
	@$(MAKE) appcast-image VERSION="$(VERSION)"

# ─── 3. Parcours Apple optionnel ───────────────────────────────────────────────

sign: app
ifndef DEVELOPER_ID_APP
	$(error Définir DEVELOPER_ID_APP, ex: make sign DEVELOPER_ID_APP="Developer ID Application: Prénom Nom (TEAMID)")
endif
ifndef SPARKLE_FEED_URL
	$(error Définir SPARKLE_FEED_URL, ex: https://ledge.example/appcast.xml)
endif
	@echo "▸ Signature Developer ID…"
	/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $(SPARKLE_FEED_URL)" $(CONTENTS)/Info.plist 2>/dev/null || \
	  /usr/libexec/PlistBuddy -c "Set :SUFeedURL $(SPARKLE_FEED_URL)" $(CONTENTS)/Info.plist
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

# ─── 4. Image disque ───────────────────────────────────────────────────────────

dmg: sign
	@$(MAKE) dmg-image VERSION="$(VERSION)"

dmg-image:
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

# ─── 5. Notarisation Apple ─────────────────────────────────────────────────────
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

# ─── 6. Appcast Sparkle ────────────────────────────────────────────────────────
# Signe le(s) .dmg de dist/ avec la clé EdDSA du Keychain (générée via
# generate_keys, cf. Sources/App/Info.plist → SUPublicEDKey) et écrit/met à jour
# dist/appcast.xml. À uploader avec le(s) .dmg vers l'hébergement choisi pour
# SUFeedURL (cf. docs/10-audit-et-plan.md).

appcast: notarize
	@$(MAKE) appcast-image VERSION="$(VERSION)"

appcast-image:
ifeq ($(strip $(GENERATE_APPCAST)),)
	$(error generate_appcast introuvable — exécuter `swift build` au moins une fois)
endif
	@echo "▸ Génération de l'appcast Sparkle…"
	$(GENERATE_APPCAST) $(DIST_DIR)
	@echo "✓ $(DIST_DIR)/appcast.xml"

# ─── 7. Publication ────────────────────────────────────────────────────────────
# `release` ne dépend d'aucun compte Apple. `release-notarized` conserve le parcours
# Developer ID pour le jour où un certificat sera disponible.
#
# Usage :
#   make release CHANGELOG="Fix timer ring, improve ambient"
#   make release CHANGELOG="$(cat CHANGELOG.md)"
#
# Variables :
#   GITHUB_TOKEN   Optionnel : sinon lu dans le Trousseau macOS
#   GITHUB_REPOSITORY  Dépôt cible au format propriétaire/dépôt
#   CHANGELOG      Texte du changelog (obligatoire)

release: direct-appcast
ifndef CHANGELOG
	$(error Définir CHANGELOG, ex: make release CHANGELOG="Fix timer ring")
endif
	@echo "▸ Publication de la release v$(VERSION)…"
	@Scripts/publish-release.sh
	@echo "✓ Release v$(VERSION) publiée → https://github.com/$(GITHUB_REPOSITORY)/releases/tag/v$(VERSION)"

release-notarized: appcast
ifndef CHANGELOG
	$(error Définir CHANGELOG, ex: make release-notarized CHANGELOG="Fix timer ring")
endif
	@echo "▸ Publication de la release notarisée v$(VERSION)…"
	@Scripts/publish-release.sh
	@echo "✓ Release notarisée v$(VERSION) publiée → https://github.com/$(GITHUB_REPOSITORY)/releases/tag/v$(VERSION)"

# ─── Nettoyage ─────────────────────────────────────────────────────────────────

clean:
	rm -rf $(DIST_DIR) .build
	@echo "✓ Nettoyé"
