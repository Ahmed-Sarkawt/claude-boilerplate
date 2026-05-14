---
paths: ["**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts", "**/*.spec.tsx", "tests/**"]
---

# Testing rules

These rules apply whenever Claude is writing or editing test files.

## Test names
- Describe behavior, not implementation: `it('disables submit when email is invalid')` not `it('calls setError')`.
- Group related tests in `describe` blocks named after the component, function, or route.

## Selectors (React Testing Library)
Priority order — use the first that fits:
1. `getByRole` (most accessible and resilient)
2. `getByLabelText`
3. `getByText`
4. `getByTestId` (last resort — brittle, avoid)

Never select by class name or internal implementation details.

## Assertions
- One behavior per test where possible. Multiple assertions are fine when they describe the same outcome.
- Prefer `toBeInTheDocument`, `toBeVisible`, `toBeDisabled` over checking internal state.
- For async behavior: use `waitFor` or `findBy*` — never `setTimeout` or fixed sleeps.

## Scope
- Unit tests: one unit of behavior in isolation. Mock only what crosses a boundary (network, DB, time).
- Integration tests: real DB fixture, no network mocks.
- E2E tests: no mocks at all — real browser, real server.

## Coverage
- New component → at least: smoke test + one interaction test + one a11y check.
- New route → at least: happy path + one validation failure.
- Tests must fail meaningfully before the implementation exists.

## What tests are not
- Tests are not documentation. Behavior should be clear from the code; tests verify it.
- Tests are not coverage theater. A test that always passes regardless of implementation is worse than no test.
