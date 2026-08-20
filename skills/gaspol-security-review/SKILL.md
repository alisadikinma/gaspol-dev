---
name: gaspol-security-review
description: Use when adding authentication or authorization, handling user input or file uploads, working with secrets or credentials, creating API endpoints, implementing payment or sensitive features, or storing/transmitting sensitive data. Runs a security checklist and gates pre-deployment in gaspol-finish.
---

# gaspol-security-review

Security review for code that touches auth, input, secrets, endpoints, or sensitive
data. Catches the high-frequency vulnerability classes before they ship.

> Ported and adapted from the ECC `security-review` skill (MIT, Affaan Mustafa).
> Blockchain/Solana section dropped; Supabase RLS retained to match the gaspol stack.

## The Iron Law

```
NO SECURITY-SENSITIVE CODE SHIPS WITHOUT THE CHECKLIST — PRESSURE DOES NOT WAIVE IT
```

"We're launching in 20 minutes" is not an exception. If a change touches the
triggers below, the relevant checklist sections run. If a shortcut is insecure
(string-concatenated SQL, JWT in `localStorage`, secrets in source), you STOP and
surface it via AskUserQuestion — you do not silently ship it as done.

## Announce at Start

> "I'm using the gaspol-security-review skill to check this change against the security checklist."

## When to Activate

- Implementing authentication or authorization
- Handling user input or file uploads
- Creating new API endpoints
- Working with secrets or credentials
- Implementing payment features
- Storing or transmitting sensitive data
- Integrating third-party APIs

> **Stack note:** examples below are TypeScript/Supabase-flavored for illustration.
> Apply the *principle* to the project's actual stack (Laravel/Vue/Python/Supabase —
> see the project CLAUDE.md). Parameterized queries, httpOnly cookies, server-side
> authorization, and input validation are framework-agnostic.

## Security Checklist

### 1. Secrets Management

**FAIL — never:**
```typescript
const apiKey = "sk-proj-xxxxx"   // hardcoded secret
const dbPassword = "password123" // in source
```

**PASS — always:**
```typescript
const apiKey = process.env.OPENAI_API_KEY
if (!apiKey) throw new Error('OPENAI_API_KEY not configured')
```

- [ ] No hardcoded API keys, tokens, or passwords
- [ ] All secrets in environment variables
- [ ] `.env*` in `.gitignore`
- [ ] No secrets in git history
- [ ] Production secrets in the hosting platform's secret store

### 2. Input Validation

**Validate every user input with a schema (whitelist, not blacklist):**
```typescript
import { z } from 'zod'
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150),
})
const validated = CreateUserSchema.parse(input) // throws on invalid
```

**File uploads — restrict size, MIME type, AND extension:**
```typescript
const maxSize = 5 * 1024 * 1024 // 5MB
if (file.size > maxSize) throw new Error('File too large')
const allowedTypes = ['image/jpeg', 'image/png', 'image/gif']
if (!allowedTypes.includes(file.type)) throw new Error('Invalid file type')
```

- [ ] All user inputs validated with schemas
- [ ] File uploads restricted (size, type, extension)
- [ ] No direct use of user input in queries
- [ ] Whitelist validation (not blacklist)
- [ ] Error messages don't leak sensitive info

### 3. SQL Injection Prevention

**FAIL — never concatenate:**
```typescript
const query = `SELECT * FROM users WHERE email = '${userEmail}'` // injection
```

**PASS — parameterize / use the query builder:**
```typescript
await supabase.from('users').select('*').eq('email', userEmail)
// or raw: db.query('SELECT * FROM users WHERE email = $1', [userEmail])
```

- [ ] All queries parameterized
- [ ] No string concatenation in SQL
- [ ] ORM / query builder used correctly

### 4. Authentication & Authorization

**Token storage — httpOnly cookie, NOT localStorage (XSS-exposed):**
```typescript
// FAIL: localStorage.setItem('token', token)
// PASS:
res.setHeader('Set-Cookie',
  `token=${token}; HttpOnly; Secure; SameSite=Strict; Max-Age=3600`)
```

**Authorize on the server BEFORE the sensitive operation:**
```typescript
if (requester.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' })
await db.users.delete({ where: { id: userId } })
```

**Row Level Security (Supabase) — enable on every table:**
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own data" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own data" ON users FOR UPDATE USING (auth.uid() = id);
```

- [ ] Tokens in httpOnly cookies (not localStorage)
- [ ] Authorization checked before sensitive operations (server-side)
- [ ] Row Level Security enabled in Supabase
- [ ] Role-based access control implemented
- [ ] Session management secure

### 5. XSS Prevention

- Sanitize any user-provided HTML (`DOMPurify` with an allow-list of tags/attrs).
- Configure a Content-Security-Policy header.
- Prefer the framework's built-in escaping; avoid `dangerouslySetInnerHTML` / `v-html` on raw input.

- [ ] User-provided HTML sanitized
- [ ] CSP headers configured
- [ ] No unvalidated dynamic content rendering

### 6. CSRF Protection

- CSRF token (or double-submit cookie) on every state-changing request.
- `SameSite=Strict` on session cookies.

- [ ] CSRF protection on state-changing operations
- [ ] `SameSite=Strict` on all cookies

### 7. Rate Limiting

- Rate-limit all API endpoints; stricter limits on expensive operations (search, generation, auth).
- Both IP-based and user-based (authenticated) limits.

- [ ] Rate limiting on all API endpoints
- [ ] Stricter limits on expensive operations

### 8. Sensitive Data Exposure

- Never log passwords, tokens, card numbers, CVV — redact to `last4`/`userId`.
- Return generic errors to users; log detailed errors server-side only. No stack traces to the client.

- [ ] No secrets/tokens/passwords in logs
- [ ] Error messages generic for users; details server-side only

### 9. Dependency Security

```bash
npm audit            # check vulnerabilities
npm audit fix        # fix what's auto-fixable
npm ci               # reproducible installs in CI
```

- [ ] Dependencies up to date; `npm audit` (or equivalent) clean
- [ ] Lock files committed
- [ ] Automated dependency alerts enabled (e.g. Dependabot)

## Security Testing

Add automated tests for the controls you implemented:

```typescript
test('requires authentication', async () => {
  expect((await fetch('/api/protected')).status).toBe(401)
})
test('requires admin role', async () => {
  const r = await fetch('/api/admin', { headers: { Authorization: `Bearer ${userToken}` } })
  expect(r.status).toBe(403)
})
test('rejects invalid input', async () => {
  const r = await fetch('/api/users', { method: 'POST', body: JSON.stringify({ email: 'nope' }) })
  expect(r.status).toBe(400)
})
```

## Pre-Deployment Security Checklist

This is the gate `gaspol-finish` runs before presenting merge/PR options. Before ANY
production deployment:

- [ ] **Secrets**: no hardcoded secrets, all in env vars
- [ ] **Input Validation**: all user inputs validated
- [ ] **SQL Injection**: all queries parameterized
- [ ] **XSS**: user content sanitized
- [ ] **CSRF**: protection enabled
- [ ] **Authentication**: proper token handling (httpOnly)
- [ ] **Authorization**: role checks in place (server-side)
- [ ] **Rate Limiting**: enabled on all endpoints
- [ ] **HTTPS**: enforced in production
- [ ] **Security Headers**: CSP, X-Frame-Options configured
- [ ] **Error Handling**: no sensitive data in errors
- [ ] **Logging**: no sensitive data logged
- [ ] **Dependencies**: up to date, no known vulnerabilities
- [ ] **Row Level Security**: enabled in Supabase
- [ ] **CORS**: properly configured
- [ ] **File Uploads**: validated (size, type, extension)

## Red Flags (rationalizations that do NOT waive the checklist)

| Rationalization | Reality |
|---|---|
| "We're launching now, skip security" | One vulnerability compromises everything. The checklist runs. |
| "It's internal-only" | Internal tools get exposed, reused, and leaked. Validate anyway. |
| "I'll add validation later" | Later never comes. Validate at the boundary now. |
| "localStorage is easier than cookies" | localStorage is XSS-readable. Use httpOnly cookies for tokens. |
| "Concatenating SQL is fine, the input is ours" | Inputs change owners. Parameterize unconditionally. |
| "The user said don't ask" | Surfacing an insecure shortcut is not optional — STOP and present options. |

## Integration

- **Triggered by:** `gaspol-plan` / `gaspol-execute` when a phase touches auth, secrets,
  user input, file upload, API endpoint, or payment (same keyword/intent mechanism as
  the design skill's auto-trigger).
- **Gates:** `gaspol-finish` — the Pre-Deployment Security Checklist runs in the
  pre-finish verification chain before merge/PR options are presented.
- **Complements:** `gaspol-verify` Layer 3 (placeholder scan) and `gaspol-review`
  (general quality) — this skill is the security-specific lens.
- **Type:** rigid skill (resists pressure; has a `tests/pressure/` case).

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Auth & RLS](https://supabase.com/docs/guides/auth)
- [Web Security Academy](https://portswigger.net/web-security)

---

**Remember:** Security is not optional. When in doubt, err on the side of caution.
