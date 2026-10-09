# ─── Ledge — Build / Sign / Distribute ────────────────────────────────────────
#
# make app      → build + crée dist/Ledge.app (signature de développement stable)
# make release  → DMG ad hoc gratuit + EdDSA Sparkle
# make sign     → signe avec Developer ID (nécessite DEVELOPER_ID_APP)
# make notarize → envoie à Apple pour notarisation
# make release-notarized → variante Developer ID + notarisation Apple
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

APP_ICON_CATALOG := Distribution/AppIcon.xcassets
APP_ICON_INFO    := $(DIST_DIR)/AppIcon-Info.plist

GENERATE_APPCAST = $(shell find .build/artifacts -path "*/bin/generate_appcast" 2>/dev/null | head -1)

.PHONY: all app direct-sign direct-dmg direct-appcast sign dmg notarize appcast \
	release release-notarized dmg-image appcast-image verify-release test-release-automation \
	measure-performance clean

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

	# Icône Finder/Dock compilée dans le bundle principal.
	xcrun actool \
	  --compile $(RES_DIR) \
	  --platform macosx \
	  --minimum-deployment-target $(MIN_OS) \
	  --app-icon AppIcon \
	  --output-partial-info-plist $(APP_ICON_INFO) \
	  $(APP_ICON_CATALOG)
	rm -f $(APP_ICON_INFO)

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

	# Notice de la dépendance distribuée avec l'app.
	@if [ -f ".build/checkouts/Sparkle/LICENSE" ]; then \
	  cp ".build/checkouts/Sparkle/LICENSE" "$(RES_DIR)/Sparkle-LICENSE.txt"; \
	  chmod 644 "$(RES_DIR)/Sparkle-LICENSE.txt"; \
	  echo "  licence: Sparkle-LICENSE.txt"; \
	fi

	# Sparkle.framework (si disponible)
	@if sparkle_fw=$$(find .build/artifacts \
	    -path "*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
	    -type d 2>/dev/null | head -1); \
	  [ -n "$$sparkle_fw" ] && [ -d "$$sparkle_fw" ]; then \
	  echo "  Sparkle.framework → Frameworks/"; \
	  ditto "$$sparkle_fw" $(FRAMEWORKS)/Sparkle.framework; \
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
	# …puis l'app avec l'identité DEV stable si elle existe, sinon avec la signature ad hoc.
	codesign --force --sign "$(DEV_SIGN)" $(BINARY)
	codesign --force --sign "$(DEV_SIGN)" $(BUNDLE)
	@echo "✓ $(BUNDLE) — signé avec : $(DEV_SIGN)"

# ─── 2. Distribution directe gratuite ─────────────────────────────────────────

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
	@echo "✓ Bundle signé ad hoc — premier lancement via « Ouvrir quand même »"

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
	Scripts/sign-release-bundle.sh $(BUNDLE) "$(DEVELOPER_ID_APP)"
	@echo "✓ Signé : $(BUNDLE)"

# ─── 4. Image disque ───────────────────────────────────────────────────────────

dmg: sign
	@$(MAKE) dmg-image VERSION="$(VERSION)"

dmg-image:
	@echo "▸ Création du DMG…"
	@Scripts/create-dmg.sh $(BUNDLE) $(DIST_DIR)/$(DMG_NAME) "$(BINARY_NAME) Installer"

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
	codesign --force --sign "$(DEVELOPER_ID_APP)" \
	  --timestamp \
	  --identifier "$(BUNDLE_ID).dmg" \
	  $(DIST_DIR)/$(DMG_NAME)
	codesign --verify --verbose=2 $(DIST_DIR)/$(DMG_NAME)
	xcrun notarytool submit $(DIST_DIR)/$(DMG_NAME) \
	  --apple-id "$(APPLE_ID)" \
	  --team-id "$(TEAM_ID)" \
	  --password "$(APP_PASSWORD)" \
	  --wait
	xcrun stapler staple $(DIST_DIR)/$(DMG_NAME)
	Scripts/verify-notarized-dmg.sh $(DIST_DIR)/$(DMG_NAME)
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
	rm -f $(DIST_DIR)/appcast.xml $(DIST_DIR)/*.delta
	Scripts/generate-appcast.sh "$(GENERATE_APPCAST)" "$(DIST_DIR)"
	@echo "✓ $(DIST_DIR)/appcast.xml"

verify-release:
	@Scripts/verify-release-artifacts.sh

test-release-automation:
	@Scripts/test-release-automation.sh

# ─── 7. Publication ────────────────────────────────────────────────────────────
# `release` publie le parcours gratuit ad hoc. Au premier lancement, l'utilisateur doit tenter
# d'ouvrir Ledge puis l'autoriser dans Confidentialité et sécurité → Ouvrir quand même.
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
	@echo "▸ Publication de la release ad hoc v$(VERSION)…"
	@Scripts/publish-release.sh
	@echo "✓ Release v$(VERSION) publiée → https://github.com/$(GITHUB_REPOSITORY)/releases/tag/v$(VERSION)"

release-notarized: appcast
ifndef CHANGELOG
	$(error Définir CHANGELOG, ex: make release-notarized CHANGELOG="Fix timer ring")
endif
	@echo "▸ Publication de la release notarisée v$(VERSION)…"
	@REQUIRE_NOTARIZATION=true Scripts/publish-release.sh
	@echo "✓ Release notarisée v$(VERSION) publiée → https://github.com/$(GITHUB_REPOSITORY)/releases/tag/v$(VERSION)"

# Mesure un processus Ledge déjà lancé. Préparer le scénario dans l'app, puis exécuter par ex. :
#   make measure-performance SCENARIO=idle DURATION=30 INTERVAL=1
SCENARIO ?= idle
DURATION ?= 30
INTERVAL ?= 1

measure-performance:
	@Scripts/measure-performance.sh "$(SCENARIO)" "$(DURATION)" "$(INTERVAL)"

# ─── Nettoyage ─────────────────────────────────────────────────────────────────

clean:
	rm -rf $(DIST_DIR) .build
	@echo "✓ Nettoyé"
