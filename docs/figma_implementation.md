# Figma implementation notes

Source: https://www.figma.com/design/0p4HA8Ysl1vbNuq2yhQx59/WattWise?node-id=0-1

The Figma plugin successfully accessed every requested tab and the appliance form on 12 November 2026. No requested screen is inaccessible.

| Frame | Node | Implementation |
| --- | --- | --- |
| Dashboard | 14:6 | lib/features/dashboard/screens/dashboard_screen.dart |
| Scan Bill | 22:9 | lib/features/scan_bill/screens/scan_bill_screen.dart |
| Mira(Chatbot) | 17:8 | lib/features/mira/screens/mira_screen.dart |
| Settings | 33:21 | lib/features/settings/screens/settings_screen.dart |
| Appliance Form (Right) | 44:41 | lib/features/dashboard/screens/appliance_form.dart |

The reference frames are 393 × 852. Flutter uses responsive layout and scrolling instead of absolute coordinates. Android/iOS render their own status and navigation bars. Shared design tokens include #168B4A green, #F7F7F7 background, #242827 text, #686D6A secondary text, 18 px card corners, and the green summary gradient. Inter is bundled with its OFL license.

Original SVG exports are bundled under assets/figma; there are no temporary Figma URLs in runtime code. Navigation icon colors adapt to state and dark mode. Dynamic graphs and selected bill imagery are rendered from app data.

## Deliberate behavior differences

- The Figma sample totals are internally inconsistent across some dashboard rows. Actual totals are computed from the appliance model; no sample values are saved.
- No automatic “12% savings” or “5% increase” is displayed without comparable usage records.
- The chart shows explicitly labeled projections because the model has no meter readings or usage-event history. Period selection changes the projection period and is not historical measurement.
- Bill breakdown and rate cards use reviewed data, handle missing/zero consumption, and disclose when charges do not equal total payable. Credits are listed but excluded from positive charge wedges.
- Uploaded bill previews display the user's selected image. New users see an upload/review empty state instead of the example bill.
- Mira starts with a welcome message and live availability state, not a fabricated exchange. The white/green icon variants match their appropriate navigation and avatar slots.
- Settings extends the design with offline persistence. No official POP rate or time schedule is inferred from enrollment.
- Appliance form includes quantity and days/month to preserve the existing calculation contract.
- Dark mode is an adaptation of the light designs; no separate dark Figma frames were present on the supplied UI page.

