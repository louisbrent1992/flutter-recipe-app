# RecipEase Pricing Guide

## 💰 Complete Pricing Structure

### 📦 CONSUMABLES

| Product ID | Display Name | Price | Credits | Per-Credit | Description |
|------------|--------------|-------|---------|------------|-------------|
| `recipease_imports_10` | Quick Import Pack | **$2.49** | 10 imports | $0.25 | Perfect for trying the feature! Impulse buy tier. |
| `recipease_imports_20` | 20 Recipe Imports | **$3.99** | 20 imports | $0.20 | **Save 20%** vs Quick Pack! Main import pack. |
| `recipease_generations_50` | 50 Recipe Generations | **$4.99** | 50 generations | $0.10 | Recipe creation with room for retries. |

**Strategy:** Quick pack ($2.49) lowers barrier to entry. Main pack ($3.99) offers 20% savings per-credit, encouraging bulk purchase. Creates natural progression to subscription.

---

### 🚫 NON-CONSUMABLES (One-Time Purchases)

| Product ID | Display Name | Price | What's Included | Savings |
|------------|--------------|-------|-----------------|---------|
| `recipease_ad_free` | RecipEase Ad-Free | **$4.99** | Permanent ad removal | - |
| `recipease_ad_free_imports_20` | Ad-Free + Import Starter ⭐ | **$6.99** | Ad-free + 20 imports | Save $0.99 |
| `recipease_ad_free_generations_50` | Ad-Free + Recipe Pack | **$9.99** | Ad-free + 50 generations | Save $0.99 |
| `recipease_ultimate_bundle` | Ultimate RecipEase Bundle 🔥 | **$11.99** | Ad-free + 30 imports + 50 gen | **Save $13.96** |

**Strategy:** $6.99 starter bundle is the attractive entry point. Ultimate Bundle at $11.99 is less than 2 months of subscription, great value for one-time buyers.

---

### 🔄 SUBSCRIPTIONS (Best Value)

| Product ID | Display Name | Price | Credits/Month | Per Month | Annual Savings |
|------------|--------------|-------|---------------|-----------|----------------|
| `recipease_premium_monthly` | RecipEase Premium - Monthly | **$5.99/mo** | 25 imports + 20 gen | $5.99 | - |
| `recipease_premium_yearly` | RecipEase Premium - Yearly ⭐ | **$34.99/yr** | 35 imports + 30 gen | **$2.92** | **Save $36.89!** |

**Features Included:**
- ✅ Zero ads, ever
- ✅ Monthly credits (renew automatically)
- ✅ Cloud backup & sync
- ✅ Unlimited recipe storage
- ✅ Priority support
- ✅ 7-day FREE trial (no payment required)

**Strategy:** Monthly at $5.99 is clearly better than buying $3.99 imports repeatedly. Yearly at $2.92/month is amazing value - breaks even after 6 months vs monthly.

---

## 📊 Value Comparison

### Scenario: Regular user needs 25 imports + 20 generations per month

| Option | Monthly Cost | Ad-Free? | Flexibility |
|--------|--------------|----------|-------------|
| **Buy consumables** | ~$9 (multiple purchases) | ❌ | ✅ Pay as you go |
| **Starter bundle + consumables** | $6.99 (once) + $3.99/mo after | ✅ | ❌ One-time only |
| **Monthly subscription** | **$5.99** | ✅ | ✅ Recurring credits |
| **Yearly subscription** | **$2.92/mo** | ✅ | ✅✅ Best value! |

---

## 🎯 Customer Journey Strategy

### Path 1: Free Trial Converter (Target: 60%)
```
Week 1: See "7-Day FREE Trial" → Start trial
        ↓ (no payment required)
Day 7:  Trial ends → Continue for $5.99/mo ✅
        ↓
Month 6: Been paying $5.99 → See yearly is $34.99
        "That's only 6 months worth!"
        ↓
        Upgrade to yearly ⭐⭐
```

### Path 2: Bundle to Subscription (Target: 25%)
```
Day 1:  Buy "Ad-Free + Import Starter" $6.99
        ↓
Week 2: Used all 20 imports, loves it
        See: $3.99 for 20 more or $5.99/mo for 25 + generations
        ↓
        "Only $2 more for way more value!"
        Subscribe to monthly ✅
```

### Path 3: Impulse to Premium (Target: 15%)
```
Day 1:  Browse app → "Let me try one thing"
        Buy: Quick Pack $2.49
        ↓
Day 3:  Loves feature, used all 10
        See: $3.99 for 20 (20% savings!) or $5.99/mo + FREE TRIAL
        ↓
        "Better deal on 20-pack!" or "Free trial is risk-free!"
        Upgrades or subscribes ✅
```

---

## 💡 Pricing Psychology

### Gap Analysis:
- **Quick Pack to Main Pack:** $2.49 → $3.99 (20% savings per-credit, compelling upgrade)
- **Main Pack to Monthly Sub:** $3.99 → $5.99 ($2 gap, just enough to notice value)
- **Monthly to Yearly (per month):** $5.99 → $2.92 (51% savings, compelling!)
- **Starter Bundle to Ultimate:** $6.99 → $11.99 (71% more for 140% more value)

### Anchoring Strategy:
```
Ultimate Bundle: $11.99 ← High anchor
     ↓
Monthly Sub: $5.99/mo ← Seems reasonable
     ↓
Yearly Sub: $34.99/yr ($2.92/mo) ← Amazing deal! ⭐
```

---

## 📱 Store Configuration

### App Store Connect (iOS)

**Product Setup:**
```
CONSUMABLES:
1. Product ID: recipease_imports_10
   Reference Name: Quick Import Pack (10)
   Price: $2.49 USD (Tier 2)
   
2. Product ID: recipease_imports_20
   Reference Name: Recipe Import Credits (20)
   Price: $3.99 USD (Tier 3)
   
3. Product ID: recipease_generations_50
   Reference Name: Recipe Generation Credits (50)
   Price: $4.99 USD (Tier 5)

NON-CONSUMABLES:
4. Product ID: recipease_ad_free
   Reference Name: Ad-Free Experience
   Price: $4.99 USD (Tier 5)
   
5. Product ID: recipease_ad_free_imports_20
   Reference Name: Ad-Free + Import Starter
   Price: $6.99 USD (Tier 10)
   
6. Product ID: recipease_ad_free_generations_50
   Reference Name: Ad-Free + Recipe Pack
   Price: $9.99 USD (Tier 15)
   
7. Product ID: recipease_ultimate_bundle
   Reference Name: Ultimate RecipEase Bundle
   Price: $11.99 USD (Tier 19)

AUTO-RENEWABLE SUBSCRIPTIONS:
Subscription Group: "RecipEase Premium"

8. Product ID: recipease_premium_monthly
   Reference Name: RecipEase Premium Monthly
   Duration: 1 month
   Price: $5.99 USD
   Introductory Offer: 7 days free trial
   
9. Product ID: recipease_premium_yearly
   Reference Name: RecipEase Premium Yearly
   Duration: 1 year
   Price: $34.99 USD
   Introductory Offer: 7 days free trial
```

---

### Google Play Console (Android)

**Product Setup:**
```
MANAGED PRODUCTS (Consumables):
1. Product ID: recipease_imports_10
   Name: Quick Import Pack
   Description: 10 recipe imports
   Price: $2.49
   
2. Product ID: recipease_imports_20
   Name: 20 Recipe Imports
   Description: 20 recipe import credits
   Price: $3.99
   
3. Product ID: recipease_generations_50
   Name: 50 Recipe Generations
   Description: 50 recipe generations
   Price: $4.99

MANAGED PRODUCTS (Non-Consumables):
4. Product ID: recipease_ad_free
   Name: RecipEase Ad-Free
   Description: Remove all ads permanently
   Price: $4.99
   
5. Product ID: recipease_ad_free_imports_20
   Name: Ad-Free + Import Starter
   Description: Ad-free + 20 recipe imports
   Price: $6.99
   
6. Product ID: recipease_ad_free_generations_50
   Name: Ad-Free + Recipe Pack
   Description: Ad-free + 50 recipe generations
   Price: $9.99
   
7. Product ID: recipease_ultimate_bundle
   Name: Ultimate RecipEase Bundle
   Description: Ad-free + 30 imports + 50 recipe generations
   Price: $11.99

SUBSCRIPTIONS:
Base Plan: RecipEase Premium

8. Product ID: recipease_premium_monthly
   Name: RecipEase Premium - Monthly
   Billing Period: 1 month
   Price: $5.99
   Free Trial: 7 days
   
9. Product ID: recipease_premium_yearly
   Name: RecipEase Premium - Yearly
   Billing Period: 12 months
   Price: $34.99
   Free Trial: 7 days
```

---

## 🎁 Promotional Strategies

### Launch Specials (First 3 Months)
- ✅ 7-day free trial (already included)
- ✅ "Early Adopter" badge for first 1,000 subscribers
- ✅ Social sharing: Get 5 free imports for each friend who joins

### Seasonal Promotions
- **Black Friday:** Yearly sub at $24.99 (29% off)
- **New Year:** 1 month free on yearly (13 months for $34.99)
- **Spring:** 50% off first 2 months of monthly ($2.99/mo)
- **Summer:** 2x credits for 3 months (monthly sub only)

### Retention Offers
- **Cancelled subscriber:** 40% off for 3 months to come back
- **Expiring trial:** "Last chance! Lock in $4.99/mo (was $5.99)"
- **Long-term monthly:** "You've been with us 6 months! Upgrade to yearly for 25% off"

---

## 📈 Revenue Projections

### Conservative Estimates (per 1,000 active users)

| Segment | Users | Monthly Revenue | Annual Revenue |
|---------|-------|-----------------|----------------|
| **Free** | 600 | $0 | $0 |
| **Quick Pack** | 100 × $2.49 | $249 | $2,988 |
| **Consumables** | 100 × $3.99 avg | $399 | $4,788 |
| **Bundles (one-time)** | 50 × $8.99 avg | - | $449.50 |
| **Monthly Subs** | 100 × $5.99 | $599 | $7,188 |
| **Yearly Subs** | 50 × $34.99/12 | $145.79 | $1,749.50 |
| **TOTAL** | 1,000 | **$1,392.79** | **$17,163** |

**Per User LTV (12 months):** $17.16

### With 50% Trial → Monthly Conversion:
- 300 start trial
- 150 convert to monthly ($5.99)
- Monthly Revenue: ~$899
- **Annual Revenue: ~$21,364** (29% increase!)

---

## 🔄 Credit Allocation Details

### Subscription Credits

**Monthly Premium ($5.99/mo):**
- 25 recipe imports per month
- 20 recipe generations per month
- Total: 45 credits/month
- Per-credit cost: $0.13 (vs $0.20 for consumables)

**Yearly Premium ($34.99/yr = $2.92/mo):**
- 35 recipe imports per month
- 30 recipe generations per month
- Total: 65 credits/month
- Per-credit cost: $0.045 (amazing value!)

### Credit Allocation Rationale:
- **MORE imports than generations** (aligns with your usage data)
- **Yearly gets MORE of both** (rewards commitment)
- **Enough generations for retries** (20-30 allows multiple attempts)
- **Clear value progression** (consumables → monthly → yearly)

---

## 🎯 Key Success Metrics

### Targets (30 days post-launch):
- **Free Trial Starts:** 30% of active users
- **Trial → Paid Conversion:** 50%
- **Bundle Purchase Rate:** 5% of new users
- **Monthly Subscriber Retention:** 80% (month 2)
- **Monthly → Yearly Upgrade:** 15% after 6 months

### Revenue Targets (per 1,000 users):
- Month 1: $1,200
- Month 3: $1,800
- Month 6: $2,200
- Month 12: $2,500+

---

**Last Updated:** October 12, 2025  
**Version:** 2.0 (Optimized)  
**Status:** ✅ Ready for implementation

