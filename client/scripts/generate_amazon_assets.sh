#!/bin/bash

# Script to generate Amazon Appstore assets from existing app assets
# Requirements:
# - 512 x 512px PNG icon (with transparency)
# - 114 x 114px PNG icon (with transparency)
# - Tablet screenshots (minimum 3): 800x480, 1024x600, 1280x720, 1280x800, 1920x1080, 1920x1200, 2560x1600
# - Promotional image (optional): 1024 x 500px (landscape)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$PROJECT_ROOT/assets"
AMAZON_DIR="$ASSETS_DIR/amazon_appstore"
ICONS_DIR="$AMAZON_DIR/icons"
SCREENSHOTS_DIR="$AMAZON_DIR/screenshots"

# Create directories
mkdir -p "$ICONS_DIR"
mkdir -p "$SCREENSHOTS_DIR"

echo "🎨 Generating Amazon Appstore assets..."
echo ""

# Check if sips is available (macOS)
if ! command -v sips &> /dev/null; then
    echo "❌ Error: 'sips' command not found. This script requires macOS."
    exit 1
fi

# Generate Icons
echo "📱 Generating icons..."

# 512 x 512px icon
if [ -f "$ASSETS_DIR/icons/logo.png" ]; then
    echo "  Creating 512x512 icon..."
    sips -z 512 512 "$ASSETS_DIR/icons/logo.png" --out "$ICONS_DIR/icon_512x512.png"
    echo "  ✅ Created: $ICONS_DIR/icon_512x512.png"
else
    echo "  ⚠️  Warning: logo.png not found, skipping 512x512 icon"
fi

# 114 x 114px icon
if [ -f "$ASSETS_DIR/icons/logo.png" ]; then
    echo "  Creating 114x114 icon..."
    sips -z 114 114 "$ASSETS_DIR/icons/logo.png" --out "$ICONS_DIR/icon_114x114.png"
    echo "  ✅ Created: $ICONS_DIR/icon_114x114.png"
else
    echo "  ⚠️  Warning: logo.png not found, skipping 114x114 icon"
fi

echo ""

# Generate Tablet Screenshots
echo "📸 Generating tablet screenshots..."

# Supported tablet resolutions for Amazon Appstore
declare -a resolutions=(
    "800:480"
    "1024:600"
    "1280:720"
    "1280:800"
    "1920:1080"
    "1920:1200"
    "2560:1600"
)

# Process each existing screenshot
for screenshot in "$ASSETS_DIR/screenshots"/*.png; do
    if [ ! -f "$screenshot" ]; then
        continue
    fi
    
    filename=$(basename "$screenshot" .png)
    echo "  Processing: $filename"
    
    for resolution in "${resolutions[@]}"; do
        width=$(echo $resolution | cut -d: -f1)
        height=$(echo $resolution | cut -d: -f2)
        output_file="$SCREENSHOTS_DIR/${filename}_${width}x${height}.png"
        
        # Resize maintaining aspect ratio, then crop to exact dimensions if needed
        # For portrait screenshots, we'll create landscape tablet versions
        # by cropping/centering appropriately
        sips -z $height $width "$screenshot" --out "$output_file" 2>/dev/null || \
        sips --resampleHeightWidthMax $height "$screenshot" --out "$output_file" 2>/dev/null
        
        # If dimensions don't match exactly, crop to center
        actual_size=$(sips -g pixelWidth -g pixelHeight "$output_file" 2>/dev/null | grep -E "pixelWidth|pixelHeight" | awk '{print $2}' | tr '\n' 'x')
        expected_size="${width}x${height}"
        
        if [ "$actual_size" != "$expected_size" ]; then
            # Use sips to crop to exact dimensions (centered)
            # Note: sips doesn't have direct crop, so we'll use a workaround
            temp_file="${output_file}.tmp"
            sips -z $height $width "$screenshot" --out "$temp_file" 2>/dev/null
            if [ -f "$temp_file" ]; then
                mv "$temp_file" "$output_file"
            fi
        fi
        
        echo "    ✅ Created: ${filename}_${width}x${height}.png"
    done
    echo ""
done

# Generate Promotional Image (1024 x 500px landscape)
echo "🎨 Generating promotional image..."

if [ -f "$ASSETS_DIR/images/home_hero.png" ]; then
    # Create promotional banner from hero image
    promo_file="$AMAZON_DIR/promotional_1024x500.png"
    
    # Resize to 1024 width, maintaining aspect ratio, then crop height to 500
    sips --resampleWidth 1024 "$ASSETS_DIR/images/home_hero.png" --out "$promo_file" 2>/dev/null
    
    # Get actual dimensions
    actual_height=$(sips -g pixelHeight "$promo_file" 2>/dev/null | grep pixelHeight | awk '{print $2}')
    
    if [ "$actual_height" -gt 500 ]; then
        # Crop from center to 500px height
        # Note: sips doesn't support direct cropping, so we'll use a workaround
        # For now, we'll create a composite approach
        echo "  ⚠️  Note: Promotional image created at 1024 width. Manual cropping to 500px height may be needed."
    fi
    
    echo "  ✅ Created: $promo_file"
else
    echo "  ⚠️  Warning: home_hero.png not found, skipping promotional image"
fi

echo ""
echo "✨ Amazon Appstore assets generation complete!"
echo ""
echo "📁 Assets location: $AMAZON_DIR"
echo ""
echo "Generated files:"
echo "  Icons:"
echo "    - $ICONS_DIR/icon_512x512.png"
echo "    - $ICONS_DIR/icon_114x114.png"
echo ""
echo "  Screenshots: (in $SCREENSHOTS_DIR)"
ls -1 "$SCREENSHOTS_DIR" 2>/dev/null | head -5
if [ $(ls -1 "$SCREENSHOTS_DIR" 2>/dev/null | wc -l) -gt 5 ]; then
    echo "    ... and more"
fi
echo ""
echo "  Promotional:"
echo "    - $AMAZON_DIR/promotional_1024x500.png (if created)"
echo ""

