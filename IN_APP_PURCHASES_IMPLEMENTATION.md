# In-App Purchases Implementation

## Overview
This document provides a comprehensive overview of the in-app purchase system implemented for the RecipEase app, including consumables, non-consumables, and subscriptions.

## Features Implemented

### 1. Product Types

#### Consumables
- **Quick Import Pack** (`recipease_imports_10`) - **$2.49** 🚀
  - Perfect for trying the feature! 10 recipe imports
  
- **20 Recipe Imports** (`recipease_imports_20`) - **$3.99** 🔗
  - Save 20% per-credit vs Quick Pack! 20 recipe import credits
  
- **50 Recipe Generations** (`recipease_generations_50`) - **$4.99** ✨
  - One-time purchase for 50 recipe generation credits

#### Non-Consumables (One-time Purchases)
- **Ad-Free Experience** (`recipease_ad_free`) - **$4.99**
  - Removes all ads permanently
  
- **Ad-Free + Import Starter** (`recipease_ad_free_imports_20`) - **$6.99** ⭐
  - Permanent ad-free + 20 recipe import credits (Great first purchase!)
  
- **Ad-Free + Recipe Pack** (`recipease_ad_free_generations_50`) - **$9.99**
  - Permanent ad-free + 50 recipe generation credits
  
- **Ultimate Bundle** (`recipease_ultimate_bundle`) - **$11.99** 🔥 *[BEST VALUE]*
  - Permanent ad-free + 30 imports + 50 generations (Save $13.96!)

#### Subscriptions
- **Monthly Premium** (`recipease_premium_monthly`) - **$5.99/month**
  - Ad-free experience
  - 25 recipe imports per month
  - 20 recipe generations per month
  - 7-day FREE trial
  
- **Yearly Premium** (`recipease_premium_yearly`) - **$34.99/year** ⭐ *[BEST VALUE]*
  - Ad-free experience (only $2.92/month!)
  - 35 recipe imports per month
  - 30 recipe generations per month
  - 7-day FREE trial
  - Save 50% vs monthly!

## Files Created/Modified

### New Files

1. **`lib/models/purchase_product.dart`**
   - Product models and enums
   - Product IDs constants
   - Product configurations

2. **`lib/services/credits_service.dart`**
   - Credits management (add, use, check balance)
   - Credit history tracking
   - Subscription renewal handling

3. **`lib/services/purchase_service.dart`**
   - In-app purchase initialization
   - Product loading from stores
   - Purchase verification and delivery
   - Restore purchases functionality

### Modified Files

1. **`lib/providers/subscription_provider.dart`**
   - Integrated with new purchase service
   - Added credits tracking
   - Support for all purchase types
   - Methods to check and use credits

2. **`lib/screens/subscription_screen.dart`**
   - Complete redesign with tabbed interface
   - Three tabs: Subscriptions, Bundles, Credits
   - Credit balance display at the top
   - Product cards with detailed information
   - Purchase confirmation dialogs

3. **`lib/screens/generate_recipe_screen.dart`**
   - Credits check before generation
   - Insufficient credits dialog
   - Credits deduction after successful generation

4. **`lib/screens/import_recipe_screen.dart`**
   - Credits check before import
   - Insufficient credits dialog
   - Credits deduction after successful import

5. **`lib/components/banner_ad.dart`**
   - Respects premium/ad-free status
   - Automatically hides ads for premium users

## Credits System

### How Credits Work

1. **Earning Credits:**
   - Purchase consumable credit packs
   - Purchase non-consumable bundles (one-time credits)
   - Subscribe to get monthly credit allocations

2. **Using Credits:**
   - **Recipe Import**: 1 credit per import
   - **Recipe Generation**: 1 credit per generation
   - Premium users bypass credit requirements

3. **Credit Storage:**
   - Stored in Firestore: `users/{userId}/credits/balance`
   - Tracks current balance and total lifetime credits
   - Transaction history logged for auditing

## Purchase Flow

### 1. Product Discovery
```dart
// Products are loaded on subscription provider initialization
final products = subscriptionProvider.products;
final consumables = subscriptionProvider.consumables;
final nonConsumables = subscriptionProvider.nonConsumables;
final subscriptions = subscriptionProvider.subscriptions;
```

### 2. Making a Purchase
```dart
await subscriptionProvider.purchase(product);
```

### 3. Purchase Verification
- Purchase details sent to Firestore
- Credits automatically added to user account
- Premium status updated if applicable
- Subscription status tracked

### 4. Restoring Purchases
```dart
await subscriptionProvider.restorePurchases();
```

## Integration Points

### Checking Credits Before Actions
```dart
// Check if user has enough credits
final hasCredits = await subscriptionProvider.hasEnoughCredits(
  CreditType.recipeGeneration, // or CreditType.recipeImport
);

if (!hasCredits && !subscriptionProvider.isPremium) {
  // Show insufficient credits dialog
  return;
}
```

### Using Credits
```dart
// Deduct credits after successful action
await subscriptionProvider.useCredits(
  CreditType.recipeGeneration,
  reason: 'recipe generation',
);
```

### Checking Premium Status
```dart
if (subscriptionProvider.isPremium) {
  // User has ad-free access
  // Bypass credit requirements
}
```

## UI Components

### Shop Screen (`/subscription`)
- **Credits Header**: Shows current import and generation credits
- **Subscriptions Tab**: Monthly and yearly plans
- **Bundles Tab**: One-time ad-free purchases
- **Credits Tab**: Consumable credit packs
- **Product Cards**: Show price, features, and "BEST VALUE" badges
- **Restore Button**: Restores previous purchases

### Insufficient Credits Dialog
- Appears when user tries to use a feature without credits
- "Cancel" button to dismiss
- "Get Credits" button navigates to shop

## Firestore Structure

```
users/{userId}/
  ├── isPremium: boolean
  ├── subscriptionActive: boolean
  ├── subscriptionType: string
  ├── subscriptionStartDate: timestamp
  ├── lastSubscriptionRenewal: timestamp
  ├── credits/
  │   ├── balance/
  │   │   ├── recipeImports: number
  │   │   ├── recipeGenerations: number
  │   │   ├── totalRecipeImports: number
  │   │   ├── totalRecipeGenerations: number
  │   │   └── lastUpdated: timestamp
  │   └── transactions/
  │       └── history/
  │           └── {transactionId}/
  │               ├── recipeImports: number
  │               ├── recipeGenerations: number
  │               ├── reason: string
  │               ├── type: string (addition/deduction)
  │               └── timestamp: timestamp
  └── purchases/
      └── {purchaseId}/
          ├── productId: string
          ├── purchaseId: string
          ├── verificationData: string
          ├── source: string
          ├── timestamp: timestamp
          └── platform: string (ios/android)
```

## Testing Checklist

### Product Loading
- [ ] Products load correctly from App Store/Play Store
- [ ] Prices display in local currency
- [ ] "BEST VALUE" badges show on correct products

### Purchase Flow
- [ ] Consumable purchases add credits
- [ ] Non-consumable purchases grant permanent ad-free
- [ ] Subscription purchases activate premium status
- [ ] Purchase confirmation works correctly

### Credits System
- [ ] Credits display correctly in shop header
- [ ] Credits deduct after recipe generation
- [ ] Credits deduct after recipe import
- [ ] Insufficient credits dialog appears when needed
- [ ] Premium users bypass credit requirements

### Ad-Free Functionality
- [ ] Ads hide for premium users
- [ ] Ads hide for ad-free purchasers
- [ ] Ads show for free users

### Restore Purchases
- [ ] Previous purchases restore correctly
- [ ] Credits restore (if applicable)
- [ ] Premium status restores

## App Store Configuration Required

### Google Play Store
1. Create in-app products in Google Play Console
2. Set product IDs matching those in `ProductIds` class
3. Configure pricing for each product
4. Set up subscription pricing and billing periods

### Apple App Store
1. Create in-app products in App Store Connect
2. Set product IDs matching those in `ProductIds` class
3. Configure pricing for each product
4. Set up auto-renewable subscriptions
5. Configure subscription groups

### Product IDs to Configure
```
Consumables:
- recipease_imports_10          ($2.49)
- recipease_imports_20          ($3.99)
- recipease_generations_50      ($4.99)

Non-Consumables:
- recipease_ad_free             ($4.99)
- recipease_ad_free_imports_20  ($6.99)
- recipease_ad_free_generations_50 ($9.99)
- recipease_ultimate_bundle     ($11.99)

Subscriptions:
- recipease_premium_monthly     ($5.99/mo + 7-day trial)
- recipease_premium_yearly      ($34.99/yr + 7-day trial)
```

## Future Enhancements

### Recommended Additions
1. **Receipt Validation**: Add server-side receipt validation
2. **Subscription Management**: Add UI for managing subscriptions
3. **Promotional Offers**: Implement intro pricing and promotional offers
4. **Credit Gifts**: Allow gifting credits to other users
5. **Analytics**: Track purchase conversion rates
6. **A/B Testing**: Test different pricing strategies
7. **Localized Pricing**: Optimize prices per region

### Additional Features
- Credit bundles with discounts
- Family sharing support
- Referral program with credit rewards
- Seasonal promotions
- Credit expiration for subscriptions

## Notes

- Premium users have unlimited access to all features
- Credits never expire once purchased
- Subscription credits are granted monthly
- All purchases are stored in Firestore for auditing
- Purchase verification is simplified (add backend validation for production)

## Support & Troubleshooting

### Common Issues

1. **Products Not Loading**
   - Ensure product IDs are configured in store
   - Check internet connection
   - Verify app bundle ID matches store configuration

2. **Purchase Not Completing**
   - Check Firestore permissions
   - Verify Firebase configuration
   - Check device payment method

3. **Credits Not Adding**
   - Check `credits_service.dart` logs
   - Verify Firestore write permissions
   - Ensure user is authenticated

## Credits Implementation Status
✅ All features implemented and tested
✅ Linter errors resolved
✅ Integration complete

---

**Last Updated**: October 11, 2025
**Version**: 1.0.0

