# ArcadeNode Game Server Image Builder
# Makefile for building game server cartridge images

# Configuration
VERSION ?= latest
REGISTRY ?=
PUSH ?= false

# Image names
IMAGES = minecraft minecraft-bedrock project-zomboid arma-reforger
IMAGE_PREFIX = arcadenode

# Colors
COLOR_RESET = \033[0m
COLOR_GREEN = \033[32m
COLOR_BLUE = \033[34m
COLOR_YELLOW = \033[33m

.PHONY: all clean push help $(IMAGES) list

# Default target: build all images
all: $(IMAGES)
	@echo "$(COLOR_GREEN)All images built successfully!$(COLOR_RESET)"
	@$(MAKE) list

# Build individual images
minecraft:
	@echo "$(COLOR_BLUE)[BUILD]$(COLOR_RESET) Building Minecraft Java Edition..."
	docker build -t $(IMAGE_PREFIX)/minecraft:$(VERSION) ./minecraft
	@[ "$(VERSION)" != "latest" ] && docker tag $(IMAGE_PREFIX)/minecraft:$(VERSION) $(IMAGE_PREFIX)/minecraft:latest || true
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Minecraft Java built"

minecraft-bedrock:
	@echo "$(COLOR_BLUE)[BUILD]$(COLOR_RESET) Building Minecraft Bedrock Edition..."
	docker build -t $(IMAGE_PREFIX)/minecraft-bedrock:$(VERSION) ./minecraft-bedrock
	@[ "$(VERSION)" != "latest" ] && docker tag $(IMAGE_PREFIX)/minecraft-bedrock:$(VERSION) $(IMAGE_PREFIX)/minecraft-bedrock:latest || true
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Minecraft Bedrock built"

project-zomboid:
	@echo "$(COLOR_BLUE)[BUILD]$(COLOR_RESET) Building Project Zomboid..."
	docker build -t $(IMAGE_PREFIX)/project-zomboid:$(VERSION) ./project-zomboid
	@[ "$(VERSION)" != "latest" ] && docker tag $(IMAGE_PREFIX)/project-zomboid:$(VERSION) $(IMAGE_PREFIX)/project-zomboid:latest || true
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Project Zomboid built"

arma-reforger:
	@echo "$(COLOR_BLUE)[BUILD]$(COLOR_RESET) Building Arma Reforger..."
	docker build -t $(IMAGE_PREFIX)/arma-reforger:$(VERSION) ./arma-reforger
	@[ "$(VERSION)" != "latest" ] && docker tag $(IMAGE_PREFIX)/arma-reforger:$(VERSION) $(IMAGE_PREFIX)/arma-reforger:latest || true
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Arma Reforger built"

# List built images
list:
	@echo ""
	@echo "$(COLOR_BLUE)[INFO]$(COLOR_RESET) Built images:"
	@docker images --filter "reference=$(IMAGE_PREFIX)/*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

# Push images to registry
push: all
	@echo "$(COLOR_BLUE)[PUSH]$(COLOR_RESET) Pushing images..."
ifdef REGISTRY
	@for img in $(IMAGES); do \
		echo "Tagging and pushing $$img..."; \
		docker tag $(IMAGE_PREFIX)/$$img:$(VERSION) $(REGISTRY)/$$img:$(VERSION); \
		docker push $(REGISTRY)/$$img:$(VERSION); \
	done
else
	@for img in $(IMAGES); do \
		echo "Pushing $(IMAGE_PREFIX)/$$img:$(VERSION)..."; \
		docker push $(IMAGE_PREFIX)/$$img:$(VERSION); \
	done
endif
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) All images pushed"

# Clean up images
clean:
	@echo "$(COLOR_YELLOW)[CLEAN]$(COLOR_RESET) Removing ArcadeNode images..."
	@docker images --filter "reference=$(IMAGE_PREFIX)/*" -q | xargs -r docker rmi -f
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Cleanup complete"

# Remove dangling images
prune:
	@echo "$(COLOR_YELLOW)[PRUNE]$(COLOR_RESET) Removing dangling images..."
	@docker image prune -f
	@echo "$(COLOR_GREEN)[SUCCESS]$(COLOR_RESET) Prune complete"

# Help target
help:
	@echo "ArcadeNode Game Server Image Builder"
	@echo ""
	@echo "Usage: make [target] [VERSION=tag] [REGISTRY=url]"
	@echo ""
	@echo "Targets:"
	@echo "  all              Build all game server images (default)"
	@echo "  minecraft        Build Minecraft Java Edition image"
	@echo "  minecraft-bedrock Build Minecraft Bedrock Edition image"
	@echo "  project-zomboid  Build Project Zomboid image"
	@echo "  arma-reforger    Build Arma Reforger image"
	@echo "  push             Build and push all images"
	@echo "  list             List built images"
	@echo "  clean            Remove all ArcadeNode images"
	@echo "  prune            Remove dangling images"
	@echo "  help             Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION          Image version tag (default: latest)"
	@echo "  REGISTRY         Registry URL for pushing (optional)"
	@echo ""
	@echo "Examples:"
	@echo "  make                           # Build all images"
	@echo "  make minecraft VERSION=1.21    # Build Minecraft with specific version"
	@echo "  make push REGISTRY=ghcr.io/user # Build and push to registry"
