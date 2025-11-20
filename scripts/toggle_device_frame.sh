#!/bin/bash
# Script to toggle device frame changes for screenshots
# Usage: ./toggle_device_frame.sh [on|off]

STASH_NAME="Device frame implementation - local only"
MAIN_DART="client/lib/main.dart"

# Check if stash exists
stash_exists() {
    git stash list | grep -q "$STASH_NAME"
}

# Check if main.dart has device frame changes
has_device_frame() {
    git diff HEAD -- "$MAIN_DART" | grep -q "DeviceFrame\|enableDeviceFrame" || \
    grep -q "enableDeviceFrame\|DeviceFrame" "$MAIN_DART" 2>/dev/null
}

# Enable device frame (restore from stash)
enable_frame() {
    if has_device_frame; then
        echo "✓ Device frame is already enabled"
        return 0
    fi
    
    if stash_exists; then
        echo "Restoring device frame changes..."
        git stash pop "$(git stash list | grep "$STASH_NAME" | head -1 | cut -d: -f1)" 2>/dev/null || {
            # Try to find stash by message
            STASH_INDEX=$(git stash list | grep -n "$STASH_NAME" | head -1 | cut -d: -f1)
            if [ -n "$STASH_INDEX" ]; then
                STASH_NUM=$((STASH_INDEX - 1))
                git stash pop "stash@{$STASH_NUM}"
            else
                echo "❌ Could not find device frame stash"
                return 1
            fi
        }
        echo "✓ Device frame enabled - ready for screenshots"
        echo "  Run 'flutter pub get' if needed"
    else
        echo "❌ Device frame stash not found"
        return 1
    fi
}

# Disable device frame (stash changes)
disable_frame() {
    if ! has_device_frame; then
        echo "✓ Device frame is already disabled"
        return 0
    fi
    
    if [ -f "$MAIN_DART" ]; then
        echo "Stashing device frame changes..."
        git stash push -m "$STASH_NAME" "$MAIN_DART"
        echo "✓ Device frame disabled - changes stashed locally"
    else
        echo "❌ $MAIN_DART not found"
        return 1
    fi
}

# Show current status
show_status() {
    if has_device_frame; then
        echo "Status: Device frame is ENABLED"
    else
        echo "Status: Device frame is DISABLED"
    fi
    
    if stash_exists; then
        echo "Stash: Available"
    else
        echo "Stash: Not found"
    fi
}

# Main logic
case "${1:-status}" in
    on|enable)
        enable_frame
        ;;
    off|disable)
        disable_frame
        ;;
    status|"")
        show_status
        ;;
    *)
        echo "Usage: $0 [on|off|status]"
        echo ""
        echo "Commands:"
        echo "  on      - Enable device frame (restore from stash)"
        echo "  off     - Disable device frame (stash changes)"
        echo "  status  - Show current status (default)"
        exit 1
        ;;
esac

