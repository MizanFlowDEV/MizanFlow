# MizanFlow Design System

## Design Philosophy

MizanFlow follows a **calm, professional, long-term usability** approach. The design is:

- **Functional, not decorative**: Every visual element serves a purpose
- **Decision-first UI**: Especially in calendar views, information is presented clearly for quick decision-making
- **Visually consistent**: Consistency over creativity
- **Inspired by operational calendars**: Adapted for iOS, not copied

## Core Principles

1. **Clarity over decoration**: Information must be immediately understandable
2. **Consistency**: Same patterns used throughout the app
3. **Accessibility**: All elements meet iOS minimum touch targets and support Dynamic Type
4. **Light/Dark mode**: All colors adapt automatically to system appearance

---

## Design Tokens

All design elements are defined in `MizanFlow/Utilities/DesignTokens.swift`. **Never use hardcoded values** - always reference design tokens.

### Colors

#### Semantic Colors

Use semantic colors for their intended purpose:

- **`DesignTokens.Color.primary`**: Main actions, highlights, links
- **`DesignTokens.Color.secondary`**: Secondary actions, less important elements
- **`DesignTokens.Color.success`**: Positive states, income, completed actions
- **`DesignTokens.Color.warning`**: Warnings, cautions, overtime
- **`DesignTokens.Color.error`**: Errors, destructive actions, expenses
- **`DesignTokens.Color.background`**: Main app background
- **`DesignTokens.Color.surface`**: Cards, elevated surfaces
- **`DesignTokens.Color.separator`**: Dividers, borders
- **`DesignTokens.Color.textPrimary`**: Main text
- **`DesignTokens.Color.textSecondary`**: Secondary text, labels

#### Day Type Colors

Day type colors are managed through `ColorTheme`:

- Use `ColorTheme.backgroundColor(for:)` for calendar cell backgrounds
- Use `ColorTheme.foregroundColor(for:)` for day type indicators
- Use `ColorTheme.textColor(for:)` for text on colored backgrounds
- Use `ColorTheme.indicatorColor(for:)` for calendar cell indicators

**All colors automatically adapt to light/dark mode.**

### Typography

Exactly **4 text styles** are defined. Use system fonts only (SF Pro / system Arabic fallback):

1. **`DesignTokens.Typography.screenTitle`**
   - Size: 28pt, Weight: Bold
   - Use: Main screen titles

2. **`DesignTokens.Typography.sectionTitle`**
   - Size: 17pt, Weight: Semibold
   - Use: Section headers, card titles

3. **`DesignTokens.Typography.body`**
   - Size: 17pt, Weight: Regular
   - Use: Main content text, buttons

4. **`DesignTokens.Typography.caption`**
   - Size: 13pt, Weight: Regular
   - Use: Secondary text, labels, hints

**Do NOT:**
- Use arbitrary font sizes
- Use arbitrary font weights
- Mix font families (system fonts only)

### Spacing

8pt grid system. All spacing must be multiples of 8:

- **`DesignTokens.Spacing.xs`**: 4pt
- **`DesignTokens.Spacing.sm`**: 8pt
- **`DesignTokens.Spacing.md`**: 16pt
- **`DesignTokens.Spacing.lg`**: 24pt
- **`DesignTokens.Spacing.xl`**: 32pt
- **`DesignTokens.Spacing.xxl`**: 48pt

**Do NOT:**
- Use arbitrary spacing values (e.g., 10pt, 15pt)
- Mix spacing systems

### Corner Radius

Consistent corner radii:

- **`DesignTokens.CornerRadius.small`**: 4pt
- **`DesignTokens.CornerRadius.medium`**: 8pt
- **`DesignTokens.CornerRadius.large`**: 12pt
- **`DesignTokens.CornerRadius.xlarge`**: 16pt

### Icons

**SF Symbols only**, outline style:

- **`DesignTokens.Icon.small`**: 12pt
- **`DesignTokens.Icon.medium`**: 16pt
- **`DesignTokens.Icon.large`**: 20pt
- **`DesignTokens.Icon.xlarge`**: 24pt
- **`DesignTokens.Icon.weight`**: Regular (for outline style)

**Usage:**
```swift
Image(systemName: "calendar")
    .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
```

**Do NOT:**
- Use filled icons (`.fill` variants) unless absolutely necessary
- Use arbitrary icon sizes
- Mix icon weights

---

## Calendar UI

The calendar is a **critical decision-making tool**. It must be readable at a glance.

### Day Cells

Day cells are **simplified** for clarity:

- **Day number only**: No text labels ("Work", "Off", etc.)
- **Background tint**: Subtle color indicating day type
- **Status indicator**: Small dot (4pt) + thin bar (2pt) at bottom
- **Today indicator**: Border using primary color
- **Selected state**: Border highlight
- **Override indicator**: Red border + red indicator

**States:**
- Work: Green background + indicator
- Off: Gray background + indicator
- Vacation: Yellow background + indicator
- Training: Orange background + indicator
- Holidays: Blue/purple background + indicator
- Override: Red border + red indicator

**Do NOT:**
- Add text labels to cells
- Overload cells with information
- Use color alone to convey meaning (use indicator + background)

### Calendar Legend

The legend shows:
- Mini cell representation (background + indicator)
- Day type description
- Uses design tokens for spacing and typography

---

## Component Guidelines

### Buttons

- Minimum touch target: `DesignTokens.Calendar.minCellSize` (44pt)
- Use semantic colors for button states
- Primary actions: `DesignTokens.Color.primary`
- Destructive actions: `DesignTokens.Color.error`

### Cards/Sections

- Background: `DesignTokens.Color.surface`
- Corner radius: `DesignTokens.CornerRadius.large`
- Padding: `DesignTokens.Spacing.md`
- Section headers: `DesignTokens.Typography.sectionTitle`

### Forms

- Use standard SwiftUI Form components
- Text fields: `DesignTokens.Typography.body`
- Labels: `DesignTokens.Typography.body` with `DesignTokens.Color.textPrimary`
- Hints: `DesignTokens.Typography.caption` with `DesignTokens.Color.textSecondary`

---

## Do's and Don'ts

### ✅ Do

- Use design tokens for all colors, typography, spacing
- Test in both light and dark mode
- Ensure touch targets meet iOS minimums (44pt)
- Use outline SF Symbols
- Keep calendar cells simple and readable
- Use semantic colors for their intended purpose
- Follow the 8pt spacing grid

### ❌ Don't

- Hardcode colors (`.green`, `.blue`, etc.)
- Use arbitrary font sizes or weights
- Mix spacing systems
- Add decorative elements without purpose
- Overload calendar cells with text
- Use filled icons unless necessary
- Create new design patterns without documenting them
- Use color alone to convey information (use indicators)

---

## Examples

### Correct: Using Design Tokens

```swift
HStack {
    Image(systemName: "calendar")
        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
        .foregroundColor(DesignTokens.Color.primary)
    
    Text("Schedule")
        .font(DesignTokens.Typography.sectionTitle)
        .foregroundColor(DesignTokens.Color.textPrimary)
    
    Spacer()
}
.padding(DesignTokens.Spacing.md)
.background(DesignTokens.Color.surface)
.cornerRadius(DesignTokens.CornerRadius.large)
```

### Incorrect: Hardcoded Values

```swift
HStack {
    Image(systemName: "calendar.fill")  // ❌ Filled icon
        .foregroundColor(.blue)          // ❌ Hardcoded color
        .font(.title2)                   // ❌ Arbitrary size
    
    Text("Schedule")
        .font(.headline)                 // ❌ Not using token
        .foregroundColor(.primary)        // ❌ Should use textPrimary
    
    Spacer()
}
.padding(15)                             // ❌ Not 8pt grid
.background(Color.gray.opacity(0.2))     // ❌ Hardcoded color
.cornerRadius(10)                        // ❌ Not using token
```

---

## Future Changes

When adding new UI elements:

1. **Check if design tokens exist** for what you need
2. **If not, add to DesignTokens.swift** (don't create one-off values)
3. **Document the new token** in this file
4. **Use consistently** across the app
5. **Test in light and dark mode**

---

## File Structure

- **`MizanFlow/Utilities/DesignTokens.swift`**: All design tokens
- **`MizanFlow/Utilities/ColorTheme.swift`**: Day type color mappings (uses design tokens)
- **`DESIGN_SYSTEM.md`**: This documentation

---

## Questions?

If you're unsure about a design decision:

1. Check this documentation
2. Look at existing implementations in the codebase
3. Follow the principle: "Functional, not decorative"
4. When in doubt, choose the simpler option
