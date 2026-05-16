---
name: font_system
description: All KTFPrima font tokens and a mismatch between the comment and implementation for ktfBody
type: project
---

All Font extension tokens in Font+KTFPrima.swift use "KTFPrima-Light" — including ktfBody which is labeled "15pt Regular" in the comment but actually uses KTFPrima-Light. This is likely a documentation error, not an intentional design decision.

Tokens:
- ktfTitleLarge: KTFPrima-Light 26pt
- ktfTitle: KTFPrima-Light 22pt
- ktfTitleSmall: KTFPrima-Light 20pt
- ktfBody: KTFPrima-Light 15pt (comment says Regular — inconsistency)
- ktfCaption: KTFPrima-Light 14pt

HomeView.swift uses Font.custom("KTFPrima-Light", size: 20) directly in donationCard (line 245) instead of .ktfTitleSmall. This is a design system violation — should use the named token.
