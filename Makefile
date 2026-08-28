SHELL := /bin/sh

FLUTTER ?= flutter

.DEFAULT_GOAL := help
.PHONY: help deps devices analyze test check run run-android run-ios run-macos run-linux run-windows run-web run-chrome setup-platforms apk clean

help: ## Muestra los comandos disponibles.
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Instala las dependencias de Flutter.
	$(FLUTTER) pub get

devices: ## Lista dispositivos, emuladores y navegadores detectados.
	$(FLUTTER) devices

analyze: ## Ejecuta el analizador estático.
	$(FLUTTER) analyze

test: ## Ejecuta las pruebas unitarias.
	$(FLUTTER) test

check: analyze test ## Ejecuta análisis y pruebas.

run: ## Ejecuta en el dispositivo elegido automáticamente por Flutter.
	$(FLUTTER) run

run-android: ## Ejecuta en un teléfono o emulador Android conectado.
	$(FLUTTER) run -d android

run-ios: ## Ejecuta en un simulador o dispositivo iOS conectado.
	@test -d ios || { echo 'iOS no está generado. Ejecuta: make setup-platforms'; exit 1; }
	$(FLUTTER) run -d ios

run-macos: ## Ejecuta la aplicación de escritorio en macOS.
	@test -d macos || { echo 'macOS no está generado. Ejecuta: make setup-platforms'; exit 1; }
	$(FLUTTER) run -d macos

run-linux: ## Ejecuta la aplicación de escritorio en Linux.
	@test -d linux || { echo 'Linux no está generado. Ejecuta: make setup-platforms'; exit 1; }
	$(FLUTTER) run -d linux

run-windows: ## Ejecuta la aplicación de escritorio en Windows.
	@test -d windows || { echo 'Windows no está generado. Ejecuta: make setup-platforms'; exit 1; }
	$(FLUTTER) run -d windows

run-web: run-chrome ## Alias para ejecutar en Chrome.

run-chrome: ## Ejecuta la versión web local en Chrome.
	@test -d web || { echo 'Web no está generado. Ejecuta: make setup-platforms'; exit 1; }
	$(FLUTTER) run -d chrome

setup-platforms: ## Genera plataformas faltantes (iOS, web y escritorio) sin reemplazar código Dart.
	$(FLUTTER) create --platforms=android,ios,web,macos,linux,windows .

apk: ## Compila el APK release local.
	$(FLUTTER) build apk --release

clean: ## Elimina artefactos de compilación generados.
	$(FLUTTER) clean
