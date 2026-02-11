# F1: Authentication & Multi-tenancy

## Description

Meddie is a multi-tenant application. The tenant concept is called a **Space**. Users can belong to multiple Spaces and switch between them. Each Space has its own documents, biomarkers, and conversations — all data is scoped to the current Space.

There is no open registration. All users join through invitations:
- A **platform admin** invites new users to the platform (they register and create their first Space)
- A **Space admin** invites users to their Space (existing or new users)

Authentication uses the Pow library with email/password. OAuth providers can be added later via `PowAssent`.

## Core Concepts

- **Space** — The tenant. A named container that holds documents, biomarkers, and conversations. Each Space has its own members with roles.
- **Membership** — The link between a User and a Space. Each membership has a role: `admin` or `member`.
- **Roles**:
  - `admin` — Can do everything a member can, plus manage users (invite/remove) within the Space.
  - `member` — Can upload documents, view results, use Ask Meddie, and view trends within the Space.
- **Platform admin** — A flag on the user account (`platform_admin`). Only platform admins can invite new users to the platform and see the platform admin area. This flag is **not editable** via any user-facing form — it can only be set via seeds, migrations, or console.

## Behavior

### Registration (Invitation Only)

1. User receives an invitation email with a unique registration link containing a token.
2. User visits the link (e.g., `/invitations/{token}/accept`). The system validates the token and checks it hasn't expired.
3. **New user**: The registration form is shown with fields for name, email (pre-filled from invitation), password, and confirm password. On submission, Pow creates the user, the invitation is marked as accepted.
4. **Existing user** (already has an account from another invitation): They are prompted to log in. After login, the invitation is accepted automatically.
5. **Platform invitation** (no Space): After registration, the user is redirected to a "Create your first Space" page where they enter a Space name. A Space is created with the user as `admin`.
6. **Space invitation** (has Space): After registration/login, a membership is created with role `member` in the inviting Space. The user is redirected to that Space's dashboard.

### Login

1. User visits `/session/new`, enters email and password.
2. Pow verifies credentials. On success, a session is created.
3. If the user has Spaces, they are redirected to the last-used Space's dashboard. If no Spaces exist, they see an empty state.
4. On failure, a generic "Invalid email or password" error is shown.

### Logout

1. User clicks "Sign out". Pow deletes the session and redirects to the login page.

### Session

- Pow manages session tokens via cookies. Sessions expire after 30 days of inactivity.
- The **current Space** is stored in the session. It persists across page navigations and browser restarts (within session lifetime).

### Space Switching

1. A Space switcher is visible in the navigation, showing the current Space name.
2. Clicking it opens a dropdown listing all Spaces the user belongs to.
3. Selecting a different Space updates the session and redirects to that Space's dashboard.
4. All subsequent data queries are scoped to the newly selected Space.

### Platform Admin — Inviting New Users

1. Platform admin navigates to `/platform`.
2. They enter an email address and click "Send invitation".
3. The system creates an `invitations` record with `space_id: null` (platform invite) and generates a unique token.
4. An email is sent with a registration link.
5. The invitation expires after 7 days.

### Space Admin — Inviting Users to a Space

1. Space admin navigates to Space settings → Members.
2. They enter an email address and click "Invite".
3. The system creates an `invitations` record with the current `space_id` and a unique token.
4. **If the email belongs to an existing user**: A membership is created immediately with role `member`. The user sees the Space in their switcher on next load. An email notification is sent.
5. **If the email is new**: An invitation email is sent with a registration link. After registration, the membership is created.

### Space Admin — Removing Users

1. Space admin navigates to Space settings → Members.
2. They click "Remove" next to a member's name.
3. A confirmation dialog appears. On confirm, the membership is deleted.
4. The removed user no longer sees this Space in their switcher.

### Forgot Password

1. User clicks "Forgot password?" on the login page.
2. User enters their email on `/reset-password/new` and submits.
3. The system always shows "If an account exists with that email, you will receive a password reset link." — regardless of whether the email exists (prevents email enumeration).
4. If the email exists, Pow's `PowResetPassword` extension sends an email with a reset token link.
5. User clicks the link (`/reset-password/{token}/edit`), enters a new password and confirmation.
6. On success, the password is updated, the reset token is invalidated, and the user is redirected to the login page with a flash: "Password has been reset successfully."
7. Reset tokens expire after 1 hour.

### Protected Routes & Data Scoping

- All routes except `/session/new`, `/invitations/:token/accept`, `/reset-password/*` require authentication.
- All data-fetching queries include `WHERE space_id = :current_space_id` (documents, biomarkers, conversations, messages).
- A user can only access Spaces they are a member of. Attempting to switch to a non-member Space returns a 404.
- The `/platform` route additionally requires `platform_admin: true`.

## Data Model

**users**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| name | `string` | NOT NULL |
| email | `string` | NOT NULL, UNIQUE, indexed |
| password_hash | `string` | NOT NULL |
| platform_admin | `boolean` | NOT NULL, default: `false` |
| locale | `string` | NOT NULL, default: `"pl"`, values: `pl`, `en` |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

Pow manages this schema. The `password` virtual field is used for input but never stored. The `platform_admin` field is **excluded from all user-facing changesets** to prevent mass-assignment — it is only settable via seeds, migrations, or IEx console.

**spaces**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| name | `string` | NOT NULL |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**memberships**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| user_id | `uuid` | FK → users, NOT NULL |
| space_id | `uuid` | FK → spaces, NOT NULL |
| role | `string` | NOT NULL, values: `admin`, `member` |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**Indexes**: Unique composite index on `(user_id, space_id)`.

**invitations**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| email | `string` | NOT NULL |
| space_id | `uuid` | FK → spaces, nullable. `null` = platform invite, non-null = Space invite |
| invited_by_id | `uuid` | FK → users, NOT NULL |
| token | `string` | NOT NULL, UNIQUE, indexed |
| accepted_at | `utc_datetime` | nullable |
| expires_at | `utc_datetime` | NOT NULL, default: 7 days from creation |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

## UI Description

### Login Page (`/session/new`)

Centered form card with email and password fields and a "Sign in" button. "Forgot password?" link below the form. No registration link — users can only join via invitation.

### Forgot Password Page (`/reset-password/new`)

Centered form card with email field and "Send reset link" button. Link back to login below.

### Reset Password Page (`/reset-password/:token/edit`)

Only accessible via a valid reset token. Centered form card with new password field, confirm password field, and "Reset password" button.

### Registration Page (`/invitations/:token/accept`)

Only accessible via a valid invitation token. Centered form card with:
- Name field
- Email field (pre-filled, read-only)
- Password field
- Confirm password field
- "Create account" button

### Create Your First Space (after platform invite registration)

Centered card with:
- "Welcome to Meddie! Create your first Space to get started."
- Space name field, pre-filled with `"{Name}'s Health"` (e.g., "Tomek's Health"). Hint text below the field: "A space groups people, documents and results. You can create your personal space or a family space."
- "Create Space" button

### Navigation

- **Space switcher**: Dropdown in the top-left showing current Space name. Lists all Spaces the user belongs to. "Create new Space" option at the bottom.
- **User menu**: Top-right showing user name, with dropdown: "Sign out".
- **Platform link**: If user is platform admin, a "Platform" link appears in the navigation.

### Space Settings (`/spaces/:id/settings`)

Accessible to Space admins only. Tabs or sections:
- **General**: Edit Space name.
- **Members**: List of all members with their role and join date. "Invite" button opens an email input form. "Remove" button next to each member (except self). Admin badge shown next to admin members.

### Platform Admin Area (`/platform`)

Only accessible to platform admins. Contains:
- **Invite new user**: Email input with "Send invitation" button. List of pending platform invitations below.
- **All Spaces**: Table listing every Space on the platform with name, member count, and creation date.

### Empty State (No Spaces)

When a user has no Spaces (e.g., removed from all):
- "You don't have any Spaces yet. Create a new Space or wait for an invitation."
- "Create Space" button.

## Edge Cases

- **Duplicate email invitation**: If an invitation is sent to an email that already has a pending invitation for the same Space, show: "An invitation has already been sent to this email."
- **Expired invitation token**: Show: "This invitation has expired. Please ask for a new one."
- **Accepting invitation to a Space the user is already in**: Skip membership creation, redirect to the Space dashboard.
- **Removing the last admin**: Prevent removal. Show: "You are the only admin. Transfer admin role to another member before leaving."
- **User removed from all Spaces**: They see the empty state with an option to create a new Space.
- **Invitation for existing user to a new Space**: If the email belongs to an existing user, create the membership immediately (no registration needed). Send a notification email instead.
- **Expired reset token**: Show: "This reset link has expired. Please request a new one." with a link back to the forgot password page.
- **Password reset for non-existent email**: Same success message is shown (prevents email enumeration).
- **Platform admin flag protection**: The `platform_admin` field uses a separate changeset that is never exposed to user input. Pow's `changeset/2` and `registration_changeset/2` callbacks explicitly cast only `name`, `email`, `password`, and `password_confirmation`.
