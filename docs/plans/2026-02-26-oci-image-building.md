# OCI Image Building Implementation Plan

**Status: COMPLETED**

**Goal:** Build custom VM images (Linux + Windows) on Oracle Cloud Infrastructure, triggered by PRs or manual dispatch.

**Architecture:** Terraform provisions OCI infrastructure (VCN, storage). Packer builds images on bare metal instances with nested virtualization. GitHub Actions orchestrates the pipeline.

**Tech Stack:** Terraform, Packer (oracle-oci builder), GitHub Actions, OCI CLI

---

## Task 1: Create Directory Structure

**Files:**
- Create: `terraform/`
- Create: `packer/image-builder/`
- Create: `packer/base-images/`
- Create: `packer/cache-images/`
- Create: `packer/win-images/`
- Create: `.github/workflows/`

**Step 1: Create all directories**

```bash
mkdir -p terraform/modules/network terraform/modules/storage
mkdir -p packer/image-builder/scripts
mkdir -p packer/base-images/scripts
mkdir -p packer/cache-images/scripts
mkdir -p packer/win-images/scripts
mkdir -p .github/workflows
```

**Step 2: Commit**

```bash
git add -A && git commit -m "chore: create directory structure for OCI image building"
```

---

## Task 2: Create Shared Utilities

**Files:**
- Create: `lib.sh`
- Create: `IMG_SFX`
- Create: `Makefile`

**Step 1: Create lib.sh**

Shared shell functions for image building (adapted from automation_images).

**Step 2: Create IMG_SFX generation**

Image suffix file for versioning.

**Step 3: Create Makefile**

Build targets for local development.

**Step 4: Commit**

```bash
git add lib.sh IMG_SFX Makefile && git commit -m "feat: add shared utilities and Makefile"
```

---

## Task 3: Terraform - OCI Foundation

**Files:**
- Create: `terraform/main.tf`
- Create: `terraform/variables.tf`
- Create: `terraform/outputs.tf`
- Create: `terraform/versions.tf`
- Create: `terraform/modules/network/main.tf`
- Create: `terraform/modules/network/variables.tf`
- Create: `terraform/modules/network/outputs.tf`
- Create: `terraform/modules/storage/main.tf`
- Create: `terraform/modules/storage/variables.tf`
- Create: `terraform/modules/storage/outputs.tf`

**Step 1: Create provider and versions config**

**Step 2: Create network module (VCN, subnet, security list)**

**Step 3: Create storage module (Object Storage bucket)**

**Step 4: Create main.tf to wire modules together**

**Step 5: Commit**

```bash
git add terraform/ && git commit -m "feat: add Terraform OCI infrastructure"
```

---

## Task 4: Packer - Image Builder Image

**Files:**
- Create: `packer/image-builder/oci.pkr.hcl`
- Create: `packer/image-builder/variables.pkr.hcl`
- Create: `packer/image-builder/scripts/bootstrap.sh`

**Step 1: Create Packer template for image-builder**

Bare metal with nested virt, installs Docker/Podman, Packer, OCI CLI, QEMU/KVM.

**Step 2: Create bootstrap script**

**Step 3: Commit**

```bash
git add packer/image-builder/ && git commit -m "feat: add Packer image-builder template"
```

---

## Task 5: Packer - Linux Base Images

**Files:**
- Create: `packer/base-images/fedora.pkr.hcl`
- Create: `packer/base-images/variables.pkr.hcl`
- Create: `packer/base-images/scripts/fedora-base-setup.sh`

**Step 1: Create Packer template for Fedora base**

Minimal OS with cloud-init.

**Step 2: Create setup script**

**Step 3: Commit**

```bash
git add packer/base-images/ && git commit -m "feat: add Packer Fedora base image template"
```

---

## Task 6: Packer - Linux Cache Images

**Files:**
- Create: `packer/cache-images/fedora-cache.pkr.hcl`
- Create: `packer/cache-images/variables.pkr.hcl`
- Create: `packer/cache-images/scripts/fedora-cache-setup.sh`

**Step 1: Create Packer template for Fedora cache**

Full CI-ready image with all dependencies.

**Step 2: Create setup script (adapted from automation_images)**

**Step 3: Commit**

```bash
git add packer/cache-images/ && git commit -m "feat: add Packer Fedora cache image template"
```

---

## Task 7: Packer - Windows Images

**Files:**
- Create: `packer/win-images/windows-server.pkr.hcl`
- Create: `packer/win-images/variables.pkr.hcl`
- Create: `packer/win-images/scripts/setup.ps1`

**Step 1: Create Packer template for Windows Server**

Windows Server 2022 with WSL/Hyper-V.

**Step 2: Create PowerShell setup script**

**Step 3: Commit**

```bash
git add packer/win-images/ && git commit -m "feat: add Packer Windows Server image template"
```

---

## Task 8: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/build-images.yml`

**Step 1: Create workflow file**

Triggers: pull_request (path filters), workflow_dispatch
Jobs: validate, image-builder, base-images, cache-images, win-images

**Step 2: Commit**

```bash
git add .github/workflows/ && git commit -m "feat: add GitHub Actions workflow for image building"
```

---

## Task 9: Validation Scripts

**Files:**
- Create: `ci/validate.sh`
- Create: `ci/shellcheck.sh`

**Step 1: Create validation scripts**

Packer validate, shellcheck for shell scripts.

**Step 2: Commit**

```bash
git add ci/ && git commit -m "feat: add CI validation scripts"
```

---

## Execution Order

1. Task 1: Directory structure
2. Task 2: Shared utilities
3. Task 3: Terraform infrastructure
4. Task 4: Image-builder Packer template
5. Task 5: Base images Packer template
6. Task 6: Cache images Packer template
7. Task 7: Windows images Packer template
8. Task 8: GitHub Actions workflow
9. Task 9: Validation scripts
