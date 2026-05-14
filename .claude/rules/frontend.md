---
paths: ["src/**/*.tsx", "src/**/*.jsx", "app/**/*.tsx", "app/**/*.jsx", "components/**/*.tsx"]
---

# Frontend rules

These rules apply whenever Claude is working in frontend source files.

## HTML & semantics
- Use semantic elements: `<button>` for actions, `<a>` for navigation, `<nav>`, `<main>`, `<header>`, `<footer>`, `<form>`.
- Never use `div` or `span` with an `onClick` when a `<button>` or `<a>` fits.

## Accessibility
- Every interactive element must be keyboard-accessible and have a visible focus ring (`:focus-visible`).
- Form inputs must be paired with a `<label>` via `htmlFor` or wrapping element.
- Icon-only buttons must have `aria-label`.
- Color must never be the only signal — pair it with an icon or text for status.

## Components
- Functional components only. Named exports for all components.
- Props interface declared above the component: `interface FooProps { ... }`.
- No prop drilling beyond 2 levels — lift to context or state store.
- No inline object/array literals in JSX props on hot-render paths.

## Hooks
- Hooks at top level only — no conditional hooks.
- `useEffect` dependency arrays must be explicit and correct.
- `useCallback` / `useMemo` only when measurably needed, not preemptively.

## Styling
- Use CSS custom properties (tokens) from your design system — never raw hex or px values that belong in tokens.
- Spacing on the project grid. Border radius from the defined scale.
- Animations use `transform` and `opacity` only. Max 300ms for micro-interactions.
- Always include `@media (prefers-reduced-motion: reduce)` for any animation.

## Imports
- Order: external packages → internal aliases (`@/`) → relative paths.
- No barrel files except at package boundaries.
- No circular imports.
