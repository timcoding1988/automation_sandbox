# OCI Image Building Makefile
# Simplified from automation_images for Oracle Cloud Infrastructure only

SHELL := $(shell command -v bash;)

##### Functions #####

# Return $(1) if non-empty, otherwise $(2)
def_if_empty = $(if $(1),$(1),$(2))

# Return value of variable $(1) or error if empty
err_if_empty = $(if $(strip $($(1))),$(strip $($(1))),$(error Required variable $(1) is undefined or empty))

##### OS Release Configuration #####

# Current Fedora release for base images
export FEDORA_RELEASE = 43

##### Paths and Variables #####

# Image suffix from file
_IMG_SFX ?= $(file <IMG_SFX)

# Temp directory for build artifacts
override _TEMPDIR ?= $(abspath $(if $(TEMPDIR),$(TEMPDIR),/tmp/oci_images_tmp))

# Packer configuration
PACKER_LOG ?=
export PACKER_LOG
export CHECKPOINT_DISABLE = 1

# Packer build arguments (can be overridden)
PACKER_BUILD_ARGS ?=
PACKER_BUILDS ?=

# Directory containing packer templates
PKR_DIR ?= $(CURDIR)/packer

# OCI Configuration (set via environment or ~/.oci/config)
export OCI_TENANCY_OCID
export OCI_USER_OCID
export OCI_FINGERPRINT
export OCI_REGION ?= us-ashburn-1
export OCI_KEY_FILE

# Align help output
override _HLPFMT = "%-25s %s\n"

##### Targets #####

.PHONY: help
help: ## Show this help message
	@printf $(_HLPFMT) "Target:" "Description:"
	@printf $(_HLPFMT) "-------------------" "--------------------------------------------"
	@grep -E '^[[:print:]]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":(.*)?## "}; {printf $(_HLPFMT), $$1, $$2}'

.PHONY: IMG_SFX
IMG_SFX: ## Generate a new date-based image suffix
	@echo "$$(date -u +%Y%m%dt%H%M%Sz)-f$(FEDORA_RELEASE)" > "$@"
	@cat IMG_SFX

$(_TEMPDIR):
	mkdir -p $@

##### Terraform Targets #####

.PHONY: tf-init
tf-init: ## Initialize Terraform
	cd terraform && terraform init

.PHONY: tf-plan
tf-plan: ## Plan Terraform changes
	cd terraform && terraform plan

.PHONY: tf-apply
tf-apply: ## Apply Terraform changes
	cd terraform && terraform apply

.PHONY: tf-destroy
tf-destroy: ## Destroy Terraform resources
	cd terraform && terraform destroy

##### Packer Validation #####

.PHONY: packer-validate
packer-validate: ## Validate all Packer templates
	packer validate $(PKR_DIR)/image-builder/
	packer validate $(PKR_DIR)/base-images/
	packer validate $(PKR_DIR)/cache-images/
	packer validate $(PKR_DIR)/win-images/

##### Image Building Targets #####

# Common packer build function
define packer_build
	packer build \
		-force \
		-var img_sfx="$(call err_if_empty,_IMG_SFX)" \
		-var oci_tenancy_ocid="$(call err_if_empty,OCI_TENANCY_OCID)" \
		-var oci_user_ocid="$(call err_if_empty,OCI_USER_OCID)" \
		-var oci_fingerprint="$(call err_if_empty,OCI_FINGERPRINT)" \
		-var oci_key_file="$(call err_if_empty,OCI_KEY_FILE)" \
		-var oci_region="$(call err_if_empty,OCI_REGION)" \
		$(if $(PACKER_BUILDS),-only=$(PACKER_BUILDS)) \
		$(if $(PACKER_BUILD_ARGS),$(PACKER_BUILD_ARGS)) \
		$(1)
endef

.PHONY: image-builder
image-builder: packer/image-builder/manifest.json ## Build image-builder (bare metal with nested virt)
packer/image-builder/manifest.json: $(wildcard packer/image-builder/*.pkr.hcl) $(wildcard packer/image-builder/scripts/*)
	$(call packer_build,$(PKR_DIR)/image-builder/)

.PHONY: base-images
base-images: packer/base-images/manifest.json ## Build Fedora base images
packer/base-images/manifest.json: $(wildcard packer/base-images/*.pkr.hcl) $(wildcard packer/base-images/scripts/*)
	$(call packer_build,$(PKR_DIR)/base-images/)

.PHONY: cache-images
cache-images: packer/cache-images/manifest.json ## Build Fedora cache images (CI-ready)
packer/cache-images/manifest.json: $(wildcard packer/cache-images/*.pkr.hcl) $(wildcard packer/cache-images/scripts/*)
	$(call packer_build,$(PKR_DIR)/cache-images/)

.PHONY: win-images
win-images: packer/win-images/manifest.json ## Build Windows Server images
packer/win-images/manifest.json: $(wildcard packer/win-images/*.pkr.hcl) $(wildcard packer/win-images/scripts/*)
	$(call packer_build,$(PKR_DIR)/win-images/)

##### CI Targets #####

.PHONY: validate
validate: ## Run all validation checks
	@echo "Validating shell scripts..."
	shellcheck lib.sh ci/*.sh packer/*/scripts/*.sh 2>/dev/null || true
	@echo "Validating Packer templates..."
	$(MAKE) packer-validate

##### Import from automation_images #####

# Path to automation_images repo (for local builds)
AUTOMATION_IMAGES_PATH ?= ../automation_images

.PHONY: import-fedora
import-fedora: ## Import Fedora image from automation_images to OCI
	@if [ ! -f "$(AUTOMATION_IMAGES_PATH)/base_images/manifest.json" ]; then \
		echo "Error: No manifest found at $(AUTOMATION_IMAGES_PATH)/base_images/manifest.json"; \
		echo "Build base images in automation_images first, or set AUTOMATION_IMAGES_PATH"; \
		exit 1; \
	fi
	@QCOW2_PATH=$$(jq -r '.builds[-1].files[0].name' "$(AUTOMATION_IMAGES_PATH)/base_images/manifest.json"); \
	./scripts/import-fedora-to-oci.sh "$(AUTOMATION_IMAGES_PATH)/$$QCOW2_PATH" "fedora-b$(_IMG_SFX)"

.PHONY: import-fedora-url
import-fedora-url: ## Import Fedora cloud image directly from Fedora Project
	@echo "Downloading Fedora $(FEDORA_RELEASE) cloud image..."
	@mkdir -p $(_TEMPDIR)
	@curl -L -o "$(_TEMPDIR)/fedora-$(FEDORA_RELEASE).qcow2" \
		"https://download.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_RELEASE)/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-$(FEDORA_RELEASE)-1.6.qcow2" || \
		curl -L -o "$(_TEMPDIR)/fedora-$(FEDORA_RELEASE).qcow2" \
		"https://download.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_RELEASE)/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-$(FEDORA_RELEASE)-1.6.x86_64.qcow2"
	./scripts/import-fedora-to-oci.sh "$(_TEMPDIR)/fedora-$(FEDORA_RELEASE).qcow2" "fedora-$(FEDORA_RELEASE)-base-$(_IMG_SFX)"

##### Cleanup #####

.PHONY: clean
clean: ## Remove generated files
	-rm -rf $(_TEMPDIR)
	-rm -f packer/*/manifest.json
	-rm -f packer/imported-manifest.json
