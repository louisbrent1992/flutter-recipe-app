# Amazon Appstore Assets

This directory contains all assets required for Amazon Appstore submission.

## Generated Assets

### Icons
- **icon_512x512.png** - 512 x 512px PNG icon (with transparency)
- **icon_114x114.png** - 114 x 114px PNG icon (with transparency)

### Screenshots
Located in the `screenshots/` directory. Generated for all required tablet resolutions:

- 800 x 480px
- 1024 x 600px
- 1280 x 720px
- 1280 x 800px
- 1920 x 1080px
- 1920 x 1200px
- 2560 x 1600px

**Note:** Screenshots were generated from portrait phone screenshots. You may want to:
1. Take actual tablet screenshots for better quality
2. Or manually adjust/crop the generated screenshots to better showcase tablet layouts

Minimum 3 screenshots are required. You have 21 screenshots generated (3 source images × 7 resolutions).

### Promotional Image
- **promotional_1024x500.png** - 1024 x 500px landscape promotional banner (optional)

## Usage

1. Upload the icons to Amazon Developer Console:
   - 512x512 icon → "512 x 512px PNG (with transparency)"
   - 114x114 icon → "114 x 114px PNG (with transparency)"

2. Upload at least 3 screenshots from the `screenshots/` directory in your preferred resolutions.

3. (Optional) Upload the promotional image if desired.

## Regenerating Assets

To regenerate these assets, run:
```bash
cd client
./scripts/generate_amazon_assets.sh
```

## Source Files

Assets were generated from:
- Icons: `assets/icons/logo.png`
- Screenshots: `assets/screenshots/*.png`
- Promotional: `assets/images/home_hero.png`

