#!/bin/bash
# Quick script to resize screenshots to App Store requirements

echo "Resizing screenshots to App Store dimensions..."
echo ""
echo "Choose screenshot dimensions:"
echo "1. 1284 × 2778 (Portrait)"
echo "2. 2736 × 1260 (Landscape)"
echo "3. 1290 × 2796 (Portrait)"
echo "4. 2796 × 1290 (Landscape)"
echo "5. 1320 × 2868 (Portrait)"
echo "6. 2868 × 1320 (Landscape)"
echo "7. 2064 × 2752 (iPad Portrait)"
echo "8. 2752 × 2064 (iPad Landscape)"
echo "9. 2048 × 2732 (iPad Portrait)"
echo "10. 2732 × 2048 (iPad Landscape)"
read -p "Enter choice (1-10): " choice

case $choice in
    1)
        WIDTH=1284
        HEIGHT=2778
        echo "Resizing to 1284 × 2778 (Portrait)..."
        ;;
    2)
        WIDTH=2736
        HEIGHT=1260
        echo "Resizing to 2736 × 1260 (Landscape)..."
        ;;
    3)
        WIDTH=1290
        HEIGHT=2796
        echo "Resizing to 1290 × 2796 (Portrait)..."
        ;;
    4)
        WIDTH=2796
        HEIGHT=1290
        echo "Resizing to 2796 × 1290 (Landscape)..."
        ;;
    5)
        WIDTH=1320
        HEIGHT=2868
        echo "Resizing to 1320 × 2868 (Portrait)..."
        ;;
    6)
        WIDTH=2868
        HEIGHT=1320
        echo "Resizing to 2868 × 1320 (Landscape)..."
        ;;
    7)
        WIDTH=2064
        HEIGHT=2752
        echo "Resizing to 2064 × 2752 (iPad Portrait)..."
        ;;
    8)
        WIDTH=2752
        HEIGHT=2064
        echo "Resizing to 2752 × 2064 (iPad Landscape)..."
        ;;
    9)
        WIDTH=2048
        HEIGHT=2732
        echo "Resizing to 2048 × 2732 (iPad Portrait)..."
        ;;
    10)
        WIDTH=2732
        HEIGHT=2048
        echo "Resizing to 2732 × 2048 (iPad Landscape)..."
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

