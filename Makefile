# RecipEase Build Automation
# Ensures ShareExtension is properly embedded in iOS builds

.PHONY: help ios-debug ios-release ios-simulator clean embed-shareext

help: ## Show this help message
	@echo "RecipEase Build Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

ios-debug: ## Build iOS app in debug mode with ShareExtension
	@echo "🚀 Building iOS app (Debug) with ShareExtension..."
	@cd client && ./flutter_build.sh debug ios

ios-release: ## Build iOS app in release mode with ShareExtension  
	@echo "🚀 Building iOS app (Release) with ShareExtension..."
	@cd client && ./flutter_build.sh release ios

ios-ipa: ## Build iOS IPA for distribution with ShareExtension (Codemagic compatible)
	@echo "🚀 Building iOS IPA for distribution with ShareExtension..."
	@cd client && ./flutter_build.sh release ipa

ios-simulator: ## Build iOS app for simulator with ShareExtension
	@echo "🚀 Building iOS app for simulator with ShareExtension..."
	@cd client && flutter build ios --simulator --debug
	@cd client && ./ios/scripts/embed_share_extension.sh

run-ios: ## Run iOS app with ShareExtension on device/simulator
	@echo "🚀 Running iOS app with ShareExtension..."
	@cd client && make ios-debug
	@cd client && flutter install

embed-shareext: ## Manually embed ShareExtension in existing build
	@echo "📋 Manually embedding ShareExtension..."
	@cd client && ./ios/scripts/embed_share_extension.sh

clean: ## Clean all build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@cd client && flutter clean
	@echo "✅ Clean completed"

# Development shortcuts
dev-ios: ios-debug ## Alias for ios-debug

# CI/CD targets
ci-ios-debug: ## CI build for iOS debug
	@cd client && flutter clean
	@cd client && flutter pub get
	@make ios-debug

ci-ios-release: ## CI build for iOS release  
	@cd client && flutter clean
	@cd client && flutter pub get
	@make ios-release
