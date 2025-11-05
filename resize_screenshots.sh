#!/bin/bash
# Quick script to resize screenshots to App Store requirements

echo "Resizing screenshots to App Store dimensions..."
echo ""
echo "Choose screenshot dimensions:"
echo "1. iPhone 11 Pro Max / XS Max Portrait (1242 × 2688)"
echo "2. iPhone 11 Pro Max / XS Max Landscape (2688 × 1242)"
echo "3. iPhone 14 Pro / 15 Pro Portrait (1284 × 2778)"
echo "4. iPhone 14 Pro / 15 Pro Landscape (2778 × 1284)"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        WIDTH=1242
        HEIGHT=2688
        echo "Resizing to 1242 × 2688 (Portrait)..."
        ;;
    2)
        WIDTH=2688
        HEIGHT=1242
        echo "Resizing to 2688 × 1242 (Landscape)..."
        ;;
    3)
        WIDTH=1284
        HEIGHT=2778
        echo "Resizing to 1284 × 2778 (Portrait)..."
        ;;
    4)
        WIDTH=2778
        HEIGHT=1284
        echo "Resizing to 2778 × 1284 (Landscape)..."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Create output directory
mkdir -p resized_screenshots

# Resize all PNG files in current directory
for file in *.png; do
    if [ -f "$file" ]; then
        echo "Resizing $file..."
        sips -z $HEIGHT $WIDTH "$file" --out "resized_screenshots/$file" 2>/dev/null || sips --resampleHeightWidth $HEIGHT $WIDTH "$file" --out "resized_screenshots/$file"
        echo "✓ Done: resized_screenshots/$file"
    fi
done

echo ""
echo "All screenshots resized! Check the 'resized_screenshots' folder."
echo "Note: If screenshots look stretched, you may need to crop instead of resize."

