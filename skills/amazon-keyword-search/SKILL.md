---
name: amazon-keyword-search
description: Search Amazon.com for a keyword and return the first 10 visible organic product results with ranking, title, ASIN, price, rating, review count, availability, and product URL. Use for read-only Amazon keyword result checks.
---

# Amazon Keyword Search

Use this skill for one read-only Amazon.com keyword search. It does not place orders, submit reviews, click ads, or manage accounts.

## Requires

- `skills/morelogin-setup`

## Inputs

- Keyword
- Marketplace, default `amazon.com`
- Optional MoreLogin environment keyword or target region
- Optional request to list Sponsored results separately

## Workflow

1. Confirm the keyword and marketplace.
2. Find a suitable environment with `ml-cli env find --keyword "<keyword>"`. If multiple candidates match, ask the user to choose.
3. Open exactly one selected environment with `ml-cli --timeout 30 env open --keyword "<selected>"`.
4. Navigate through the returned browser debug port to `https://www.amazon.com/s?k=<url_encoded_keyword>`.
5. Confirm the page is Amazon.com and record CAPTCHA, consent, sign-in, or delivery-location prompts that may affect results.
6. Read the first 10 visible organic product cards in order. Capture rank, title, ASIN, displayed price, rating, review count, availability text, and product URL.
7. Keep Sponsored results separate and label them `sponsored`.
8. Close the environment with `ml-cli --timeout 30 env close --env-id <envId>`.

## Rules

- Report only values visible at check time; rankings, prices, stock, and delivery are time- and location-sensitive.
- Do not sign in, add to cart, purchase, submit reviews, click ads, or change delivery settings without confirmation.
- If fewer than 10 products are visible, return the actual count and reason.
- Treat missing price, rating, review count, availability, or URL as `not_visible`; do not infer or fill those values. Prefer the product card link, then construct an evidence URL from the ASIN only when the ASIN is present.
- Stop on CAPTCHA or blocking pages instead of repeatedly retrying.

## Output

Return `keyword`, `marketplace`, `checkedAt`, `environment`, `resultCount`, `organicResults`, `sponsoredResults`, `pageNotes`, and `nextActions`. Include product URLs as evidence.
