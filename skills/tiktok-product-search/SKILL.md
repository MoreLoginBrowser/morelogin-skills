---
name: tiktok-product-search
description: Search TikTok Shop for products by keyword or category and return visible product listings with price, sales, rating, seller, and URL. Use for read-only product discovery, not creator or account operations.
---

# TikTok Product Search

Use this skill for a focused TikTok Shop product search. Creator discovery, video research, and ad verification are separate skills.

## Requires

- `skills/morelogin-setup`

## Inputs

- Product keyword or category
- TikTok Shop market or region
- Optional MoreLogin browser environment or cloud phone keyword
- Optional result limit, default 10 and maximum 50

## Workflow

1. Confirm keyword, market, and result limit.
2. Use `ml-cli env find --keyword "<keyword>"` for browser work or `ml-cli cloudphone find --keyword "<keyword>"` for mobile work. Ask the user to choose when multiple resources match.
3. Open one selected resource using the timeout guidance from `skills/morelogin-setup`.
4. Confirm the selected resource has a TikTok or TikTok Shop entry point. If the cloud phone has no installed app and no usable browser surface, stop and report `blockedReason: no_tiktok_entry`.
5. Navigate to the applicable TikTok Shop search page or use its visible search UI.
6. Record visible cards in displayed order: rank, title, price, sales text, rating, seller/shop, shipping or availability text, and URL.
7. Mark promoted or sponsored cards separately when labeled.
8. Stop on login walls, CAPTCHA, or regional unavailability and report the limitation.
9. Close the resource after the read-only check.

## Rules

- Do not send messages, follow creators, like content, place orders, or change account settings.
- Report displayed sales text verbatim; do not turn it into an exact number unless the page provides one.
- Do not combine results from different markets without labeling each market.

## Output

Return `keyword`, `market`, `checkedAt`, `resource`, `resultCount`, `products`, `blockedReason`, and `nextActions`.
