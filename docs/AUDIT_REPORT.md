# Frontend Audit Report — ArcadeNode

**Date:** March 1, 2026  
**Scope:** All 22 frontend source files under `frontend/src/`, plus configuration files  
**Framework:** React 18 + TypeScript + Vite + Tailwind CSS + TanStack Query + Zustand

### 22. No `package-lock.json` committed
**File:** `Dockerfile`  
The Dockerfile runs `npm install` but there is no `package-lock.json` visible in the workspace. Builds will not be deterministic — different builds may resolve different dependency versions.


---

## Summary

| Severity     | Count | Key Areas                                                          |
| ------------ | ----- | ------------------------------------------------------------------ |
| **Critical** | 4     | Credentials leak, localStorage tokens, open registration, no CSRF  |
| **High**     | 6     | Broken SPA navigation, non-functional settings, silent errors      |
| **Medium**   | 6     | `any` types, duplicate code, stale effects, missing error states   |
| **Low**      | 9     | UX inconsistencies, missing security headers, color mismatches     |

---

## Recommended Priority Actions

1. **Remove default credentials** from the Login page and add an invite/approval flow for registration.
2. **Fix the `<a>` tag** to `<Link>` in Dashboard and wire up the ServerDetail settings form with proper state management and a save endpoint.
3. **Add `toast.error()`** to the DeployWizard mutation error handler so users receive feedback on failures.
4. **Extract shared utilities**: `getStatusColor`, the gamepad SVG icon, and a typed error handler.
5. **Fix undefined `dark-*` Tailwind classes** in DeployWizard — either add them to `tailwind.config.js` or migrate to the existing `panel-*` theme tokens.
6. **Add security headers** to `nginx.conf` and set `sourcemap: false` in `vite.config.ts` for production.
