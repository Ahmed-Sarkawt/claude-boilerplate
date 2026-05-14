---
paths: ["server/**/*.ts", "api/**/*.ts", "lib/**/*.ts", "routes/**/*.ts"]
---

# Backend rules

These rules apply whenever Claude is working in backend / server source files.

## Security (non-negotiable)
- All SQL must be parameterized. No string interpolation into queries. Ever.
- All user input validated at the route boundary with a schema (zod or equivalent) before touching business logic or the DB.
- No secrets, tokens, or credentials in source files or logs.
- No `eval`. No dynamic `require` with user-controlled paths.

## Database
- DB connection must be a pooled singleton — not opened per request.
- Migrations are append-only. Never modify an existing migration file.
- Always use transactions when a request touches more than one table.

## Routes
- Every route must have explicit error handling. Unhandled promise rejections are bugs.
- Return consistent error shapes: `{ error: string, code?: string }`.
- Validate the response shape as well as the request shape.

## Logging
- Log at the boundary: what came in, what went out, how long it took.
- Never log PII (email, name, payment info) in plain text.
- Use structured logging (JSON) so logs are searchable.

## Performance
- N+1 queries are bugs. Use joins or batch-load patterns.
- No blocking I/O on the hot path (synchronous file reads, `execSync`).
- Set explicit timeouts on outbound HTTP requests.
