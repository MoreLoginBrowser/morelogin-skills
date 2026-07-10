---
name: amazon-product-detail
description: Read the visible details of one Amazon.com product by ASIN or product URL, including title, price, rating, reviews, bullets, availability, seller, and category signals. Use for read-only product inspection.
---

# Amazon Product Detail

Use this skill to inspect one Amazon.com product. It does not place orders, edit listings, contact sellers, or submit reviews.

## Requires

- `skills/morelogin-setup`

## Inputs

- ASIN or Amazon product URL
- Marketplace, default `amazon.com`
- Optional MoreLogin environment keyword or target region

## Workflow

1. Normalize the input to one Amazon.com product URL. Ask for the URL if the ASIN is ambiguous.
2. Find and open exactly one suitable environment using the MoreLogin setup skill.
3. Navigate to the product URL through the browser debug port.
4. Capture visible title, ASIN, brand, price, currency, rating, review count, availability, seller, shipping text, bullet points, category, and image URLs when available.
5. Note variants, coupons, subscription pricing, sign-in prompts, and delivery-location effects separately.
6. Close the environment after inspection.

## Rules

- Distinguish list price, sale price, coupon discount, and subscription price.
- Use visible page title and body text as fallbacks when a product selector is absent or Amazon renders a variant layout. Mark unavailable fields as `not_visible`.
- Do not infer stock, seller, or delivery date when the page does not show it.
- Do not sign in, add to cart, purchase, submit reviews, or change delivery settings without confirmation.
- Stop on CAPTCHA or blocking pages.

## Output

Return `product`, `pricing`, `rating`, `availability`, `seller`, `bullets`, `variants`, `pageNotes`, and `evidenceUrl`.
