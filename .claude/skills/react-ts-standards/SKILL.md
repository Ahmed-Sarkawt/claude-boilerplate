---
name: react-ts-standards
description: Use whenever writing React + TypeScript code. Encodes the standard patterns this project enforces: strict TypeScript, no any, accessibility-first, tested, design-system-clean.
---

# React + TypeScript Standards

## TypeScript

- `strict: true` always. No exceptions.
- No `any`. If you genuinely don't know the type, use `unknown` and narrow with a type guard.
- No `@ts-ignore`. Use `@ts-expect-error` with a comment explaining the suppression.
- `interface` for object shapes, `type` for unions, mapped types, and utilities.
- Explicit return types on all exported functions. Optional on pure local helpers.

## Components

- Functional components only.
- Named exports for components, default export only at route/page boundaries.
- Props interface declared immediately above the component:
  ```tsx
  interface FooProps {
    label: string;
    onClick: () => void;
  }
  ```
- `children` typed as `React.ReactNode`, never `any`.
- No prop drilling beyond 2 levels — lift state to context or a store.

## Hooks

- Custom hooks start with `use` and live in `src/hooks/`.
- Effects have explicit, correct dependency arrays.
- Never `// eslint-disable-next-line react-hooks/exhaustive-deps` without a comment that explains the invariant you're relying on.
- `useCallback` and `useMemo` only when measurably needed. Don't apply them preemptively.

## Forms

- Controlled inputs always.
- Schema validation with zod (or equivalent) declared next to the form, not inline.
- Every `<input>` paired with a `<label>` via `htmlFor` or wrapping element.
- `aria-invalid` and `aria-describedby` wired to error messages.

## Accessibility

- Every interactive element keyboard-accessible.
- `:focus-visible` ring on all focusable elements.
- `aria-label` on every icon-only button.
- Semantic HTML: `<button>` for actions, `<a>` for navigation, `<nav>`, `<main>`, `<header>`, `<form>`.
- Color is never the only signal for state or status.

## Tests

- Vitest + @testing-library/react.
- Test file lives next to component: `Foo.tsx` ↔ `Foo.test.tsx`.
- Test names: `it('does X when Y')` — behavior, not implementation.
- Selector priority: `getByRole` → `getByLabelText` → `getByText` → `getByTestId`.

## Imports

- Order: external packages → internal aliases (`@/`) → relative paths.
- No unused imports.
- No circular imports.
- No barrel files except at package boundaries.

## Naming

- Components: `PascalCase.tsx`
- Hooks: `useCamelCase.ts`
- Utilities: `camelCase.ts`
- Types and interfaces: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
