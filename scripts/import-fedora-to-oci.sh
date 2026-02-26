#!/bin/bash
# Import Fedora QCOW2 image from automation_images to OCI
#
# Usage: ./import-fedora-to-oci.sh <path-to-qcow2> [image-name]
#
# Prerequisites:
#   - OCI CLI configured (~/.oci/config)
#   - Object Storage bucket exists
#   - Compartment OCID set via OCI_COMPARTMENT_OCID env var

set -euo pipefail

# Configuration
: "${OCI_COMPARTMENT_OCID:?OCI_COMPARTMENT_OCID must be set}"
: "${OCI_BUCKET:=oci-images-import}"
: "${OCI_NAMESPACE:=$(oci os ns get --query 'data' -r)}"

QCOW2_PATH="${1:?Usage: $0 <path-to-qcow2> [image-name]}"
IMAGE_NAME="${2:-fedora-imported-$(date +%Y%m%d%H%M%S)}"

# Validate input file
if [[ ! -f "$QCOW2_PATH" ]]; then
    echo "Error: File not found: $QCOW2_PATH" >&2
    exit 1
fi

echo "=== OCI Fedora Image Import ==="
echo "Source:      $QCOW2_PATH"
echo "Image name:  $IMAGE_NAME"
echo "Compartment: $OCI_COMPARTMENT_OCID"
echo "Bucket:      $OCI_BUCKET"
echo "Namespace:   $OCI_NAMESPACE"
echo ""

# Determine file format
FILE_EXT="${QCOW2_PATH##*.}"
case "$FILE_EXT" in
    qcow2)
        SOURCE_TYPE="QCOW2"
        ;;
    vmdk)
        SOURCE_TYPE="VMDK"
        ;;
    raw|img)
        # Need to convert raw to QCOW2 for OCI import
        echo "Converting raw image to QCOW2..."
        QCOW2_CONVERTED="/tmp/${IMAGE_NAME}.qcow2"
        qemu-img convert -f raw -O qcow2 "$QCOW2_PATH" "$QCOW2_CONVERTED"
        QCOW2_PATH="$QCOW2_CONVERTED"
        SOURCE_TYPE="QCOW2"
        ;;
    gz|tar.gz)
        # Extract compressed file first
        echo "Extracting compressed image..."
        EXTRACT_DIR="/tmp/oci-import-$$"
        mkdir -p "$EXTRACT_DIR"
        tar -xzf "$QCOW2_PATH" -C "$EXTRACT_DIR"
        QCOW2_PATH=$(find "$EXTRACT_DIR" -name "*.raw" -o -name "*.qcow2" | head -1)
        if [[ -z "$QCOW2_PATH" ]]; then
            echo "Error: No raw or qcow2 file found in archive" >&2
            exit 1
        fi
        # Convert if raw
        if [[ "$QCOW2_PATH" == *.raw ]]; then
            echo "Converting raw image to QCOW2..."
            QCOW2_CONVERTED="/tmp/${IMAGE_NAME}.qcow2"
            qemu-img convert -f raw -O qcow2 "$QCOW2_PATH" "$QCOW2_CONVERTED"
            QCOW2_PATH="$QCOW2_CONVERTED"
        fi
        SOURCE_TYPE="QCOW2"
        ;;
    *)
        echo "Error: Unsupported file format: $FILE_EXT" >&2
        exit 1
        ;;
esac

# Step 1: Ensure bucket exists
echo "Step 1: Checking Object Storage bucket..."
if ! oci os bucket get --bucket-name "$OCI_BUCKET" &>/dev/null; then
    echo "Creating bucket: $OCI_BUCKET"
    oci os bucket create \
        --compartment-id "$OCI_COMPARTMENT_OCID" \
        --name "$OCI_BUCKET" \
        --storage-tier Standard
fi

# Step 2: Upload to Object Storage
OBJECT_NAME="${IMAGE_NAME}.qcow2"
echo "Step 2: Uploading to Object Storage..."
echo "  Object: $OBJECT_NAME"

oci os object put \
    --bucket-name "$OCI_BUCKET" \
    --file "$QCOW2_PATH" \
    --name "$OBJECT_NAME" \
    --force

# Step 3: Import as Custom Image
echo "Step 3: Importing as OCI Custom Image..."
OBJECT_URI="https://objectstorage.us-ashburn-1.oraclecloud.com/n/${OCI_NAMESPACE}/b/${OCI_BUCKET}/o/${OBJECT_NAME}"

IMPORT_RESULT=$(oci compute image import from-object-uri \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --display-name "$IMAGE_NAME" \
    --source-image-type "$SOURCE_TYPE" \
    --uri "$OBJECT_URI" \
    --operating-system "Fedora" \
    --operating-system-version "$(echo $IMAGE_NAME | grep -oP '\d+' | head -1 || echo 'Custom')" \
    --launch-mode PARAVIRTUALIZED)

IMAGE_OCID=$(echo "$IMPORT_RESULT" | jq -r '.data.id')
echo ""
echo "=== Import Started ==="
echo "Image OCID: $IMAGE_OCID"
echo ""

# Step 4: Wait for import to complete
echo "Step 4: Waiting for import to complete..."
oci compute image get --image-id "$IMAGE_OCID" --wait-for-state AVAILABLE --wait-interval-seconds 30

echo ""
echo "=== Import Complete ==="
echo "Image OCID: $IMAGE_OCID"
echo "Image Name: $IMAGE_NAME"
echo ""
echo "Use this OCID as OCI_FEDORA_BASE_OCID in GitHub secrets"

# Output manifest for CI integration
cat > "$(dirname "$0")/../packer/imported-manifest.json" <<EOF
{
  "image_ocid": "$IMAGE_OCID",
  "image_name": "$IMAGE_NAME",
  "source_file": "$QCOW2_PATH",
  "imported_at": "$(date -Iseconds)"
}
EOF

echo "Manifest written to packer/imported-manifest.json"
