# Descope Bootstrap Guide: Password + MFA Authentication Flow

**Purpose**: Step-by-step guide for manually configuring a Password + MFA authentication flow in the Descope Console before using `pcc-descope-mgmt` CLI to manage it.

**MFA Strategy**: Password + (Passkeys OR TOTP) - User selects one MFA method during signup

**Time Required**: ~30-45 minutes

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Part 1: Descope Project Setup](#part-1-descope-project-setup)
3. [Part 2: Enable Authentication Methods](#part-2-enable-authentication-methods)
4. [Part 3: Create the Authentication Flow](#part-3-create-the-authentication-flow)
5. [Part 4: Configure Flow Screens](#part-4-configure-flow-screens)
6. [Part 5: Test the Flow](#part-5-test-the-flow)
7. [Part 6: Export and Version Control](#part-6-export-and-version-control)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

---

## Prerequisites

### Required
- [ ] Descope account (free tier is sufficient) - [Sign up here](https://app.descope.com/sign-up)
- [ ] Access to the Descope Console
- [ ] Authenticator app installed (for TOTP testing): Google Authenticator, Authy, or Microsoft Authenticator
- [ ] Passkey-compatible browser (Chrome, Safari, Edge) and device with biometric capability (for Passkey testing)

### Recommended
- [ ] pcc-descope-mgmt CLI installed and configured
- [ ] Access key for the Descope Management API

---

## Part 1: Descope Project Setup

### Step 1.1: Log in to Descope Console

1. Navigate to [https://app.descope.com](https://app.descope.com)
2. Log in with your credentials
3. You'll land on the **Dashboard** for your default project

### Step 1.2: Create a Development Project (if needed)

For testing, use a separate non-production project:

1. Click the **project dropdown** (top-right corner, shows current project name)
2. Click **+ Project** at the bottom of the dropdown
3. Enter project details:
   - **Name**: `pcc-dev` (or your preferred name)
   - **Environment**: Select `Non-production`
4. Click **Create**

> **Note**: Production vs Non-production affects rate limits and is displayed in the console but doesn't change functionality.

### Step 1.3: Note Your Project ID

1. Click **Settings** in the left navigation
2. Click **Project**
3. Copy the **Project ID** - you'll need this for:
   - pcc-descope-mgmt CLI configuration
   - Frontend SDK integration

---

## Part 2: Enable Authentication Methods

### Step 2.1: Enable Password Authentication

1. Navigate to **Settings** > **Authentication Methods** > **Password**
2. Ensure the toggle for **Enable method in API and SDK** is ON
3. Configure password requirements (recommended):
   - **Minimum length**: 12 characters
   - **Require uppercase**: Yes
   - **Require lowercase**: Yes
   - **Require number**: Yes
   - **Require special character**: Yes
4. Click **Save**

### Step 2.2: Enable TOTP (Authenticator Apps)

1. Navigate to **Settings** > **Authentication Methods** > **Authenticator Apps (TOTP)**
2. Ensure the toggle for **Enable method in API and SDK** is ON
3. No additional configuration required
4. Click **Save**

### Step 2.3: Enable Passkeys (WebAuthn)

1. Navigate to **Settings** > **Authentication Methods** > **Passkeys**
2. Ensure the toggle for **Enable method in API and SDK** is ON
3. Configure settings:
   - **User verification**: `Required` (recommended for MFA)
   - **Resident key**: `Preferred`
   - **Authenticator attachment**: `Platform` (for built-in biometrics) or `Cross-platform` (for security keys)
4. Click **Save**

---

## Part 3: Create the Authentication Flow

### Step 3.1: Navigate to Flows

1. Click **Flows** in the left navigation
2. You'll see the Flow Builder interface with existing flows (if any)

### Step 3.2: Create New Flow (Option A - From Template)

Descope provides templates. To use one:

1. Click **+ Flow** (top-right)
2. Select **From Template**
3. Browse templates - look for:
   - "Sign Up or In with MFA"
   - "Password with TOTP"
4. Select a template and click **Use Template**
5. Rename to: `pcc-password-mfa-flow`

**If no suitable template exists, continue to Step 3.3 for manual creation.**

### Step 3.3: Create New Flow (Option B - From Scratch)

1. Click **+ Flow** (top-right)
2. Select **Blank Flow**
3. Name: `pcc-password-mfa-flow`
4. Click **Create**

### Step 3.4: Design the Sign-Up Flow

The flow should follow this logic:

```
START
  │
  ▼
┌─────────────────────────┐
│  Sign-Up Screen         │
│  - Email input          │
│  - Password input       │
│  - Confirm password     │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Action: Sign Up /      │
│  Password               │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  MFA Method Selection   │
│  Screen                 │
│  - Option: Passkeys     │
│  - Option: TOTP         │
└──────────┬──────────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
┌─────────┐ ┌─────────┐
│ Passkey │ │  TOTP   │
│ Setup   │ │  Setup  │
└────┬────┘ └────┬────┘
     │           │
     └─────┬─────┘
           │
           ▼
┌─────────────────────────┐
│  Email Verification     │
│  (OTP to email)         │
└──────────┬──────────────┘
           │
           ▼
        SUCCESS
```

#### Add Sign-Up Screen

1. In the Flow Editor, click **+ Add Screen**
2. Select **Sign Up** screen template
3. Configure screen to include:
   - Email field
   - Password field
   - Confirm Password field
4. Add a **Sign Up / Password** action after the screen

#### Add MFA Selection Screen

1. Click **+ Add Screen** after the Sign Up action
2. Select or create a custom screen with two buttons:
   - Button 1: "Set up Passkey" → leads to Passkey setup
   - Button 2: "Use Authenticator App" → leads to TOTP setup

#### Add Passkey Setup Branch

1. Add a **Sign Up or In / Passkeys** action
2. This will:
   - Prompt the browser's WebAuthn API
   - Register the user's biometric credential
3. On success, continue to email verification

#### Add TOTP Setup Branch

1. Add a **Sign Up or In / TOTP** action
2. This will:
   - Generate a QR code for the authenticator app
   - Display the QR code on a screen
3. Add a screen to display the QR code
4. Add a **Verify TOTP** action to verify the user entered the correct code
5. On success, continue to email verification

#### Add Email Verification

1. Add a **Send Email / OTP** action
2. Add a screen for OTP input
3. Add a **Verify OTP** action
4. On success, complete the flow with **End Flow** action set to "Success"

### Step 3.5: Design the Sign-In Flow

```
START
  │
  ▼
┌─────────────────────────┐
│  Sign-In Screen         │
│  - Email input          │
│  - Password input       │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Action: Sign In /      │
│  Password               │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  Condition: Check       │
│  user.webAuthn exists?  │
└──────────┬──────────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
┌─────────┐ ┌─────────┐
│ Passkey │ │  TOTP   │
│ Verify  │ │  Verify │
└────┬────┘ └────┬────┘
     │           │
     └─────┬─────┘
           │
           ▼
        SUCCESS
```

#### Using Conditions

1. After the Password Sign In action, add a **Condition** block
2. Set condition: `user.webAuthn` exists (for passkey users) vs TOTP enrolled
3. Route to appropriate verification method

> **Tip**: Descope tracks which MFA method a user enrolled with. Use `user.webAuthn` for passkeys and `user.totp` for TOTP.

---

## Part 4: Configure Flow Screens

### Step 4.1: Customize Screen Styling

1. Click on any screen in the flow
2. Use the right panel to customize:
   - Colors and fonts (to match PCC branding)
   - Logo upload
   - Button styles
   - Field labels

### Step 4.2: Configure Error Messages

1. For each action, click the **Error** output
2. Add appropriate error screens or messages:
   - Invalid password
   - MFA verification failed
   - Account locked

### Step 4.3: Save the Flow

1. Click **Save** (top-right)
2. Descope auto-saves, but explicitly saving ensures the latest version is persisted

---

## Part 5: Test the Flow

### Step 5.1: Use the Preview Feature

1. In the Flow Editor, click **Preview** (top-right)
2. This opens a new tab with the flow running

### Step 5.2: Test Sign-Up with TOTP

1. Enter a test email and password
2. Select "Use Authenticator App"
3. Scan the QR code with your authenticator app
4. Enter the 6-digit code
5. Complete email verification
6. Verify you're logged in successfully

### Step 5.3: Test Sign-Up with Passkeys

1. Use a different email address
2. Enter email and password
3. Select "Set up Passkey"
4. Follow browser prompts for biometric/PIN
5. Complete email verification
6. Verify you're logged in successfully

### Step 5.4: Test Sign-In

1. Log out
2. Sign in with each test account
3. Verify the correct MFA method is prompted

### Step 5.5: Check Users in Console

1. Navigate to **Users** in left navigation
2. Verify test users appear with correct MFA indicators

---

## Part 6: Export and Version Control

### Step 6.1: Export the Flow from Console

1. Navigate to **Flows**
2. Find `pcc-password-mfa-flow` in the list
3. Click the **checkbox** next to the flow
4. Click **Export** (top-right of the table)
5. Save the downloaded JSON file

**Alternative (from Flow Editor):**
1. Open the flow in the editor
2. Click the **down arrow** icon (top-right)
3. Select **Export**

### Step 6.2: Store in pcc-descope-mgmt Repository

1. Create a directory for Descope configurations:

```bash
mkdir -p /home/jfogarty/pcc/core/pcc-descope-mgmt/config/flows
```

2. Copy the exported flow:

```bash
cp ~/Downloads/pcc-password-mfa-flow.json \
   /home/jfogarty/pcc/core/pcc-descope-mgmt/config/flows/
```

3. Commit to version control:

```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt
git add config/flows/pcc-password-mfa-flow.json
git commit -m "feat: add Password + MFA authentication flow"
git push
```

### Step 6.3: Export Project Settings (Optional)

For a complete backup:

1. Navigate to **Settings** > **Project**
2. Click **Export** at the top
3. This exports:
   - All flows
   - Styles/themes
   - Authentication method settings
   - Email templates

Store in `config/project-snapshot/` for disaster recovery.

### Step 6.4: Verify with pcc-descope-mgmt CLI

Once exported, verify the CLI can interact with the flow:

```bash
# List flows (should include your new flow)
descope-mgmt flow list

# Export via CLI (alternative to console export)
descope-mgmt flow export --flow-id pcc-password-mfa-flow --output config/flows/
```

---

## Troubleshooting

### Passkey Setup Fails

**Symptoms**: Browser doesn't prompt for biometric, or shows "Not allowed" error

**Solutions**:
1. Ensure you're using HTTPS (even localhost needs secure context)
2. Check browser compatibility (Chrome 67+, Safari 14+, Edge 79+)
3. Verify device has biometric capability or PIN setup
4. Check Descope passkey settings for correct domain configuration

### TOTP Code Invalid

**Symptoms**: Authenticator app code rejected

**Solutions**:
1. Ensure device clock is synchronized (TOTP is time-based)
2. Wait for code refresh (codes expire every 30 seconds)
3. Try removing and re-adding the account in authenticator app

### Flow Not Saving

**Symptoms**: Changes don't persist after refresh

**Solutions**:
1. Check for validation errors (red highlights on actions)
2. Ensure all required connections between actions are made
3. Try explicit Save instead of relying on auto-save

### Preview Shows Blank Screen

**Symptoms**: Preview opens but shows nothing

**Solutions**:
1. Ensure flow has a valid start screen
2. Check browser console for JavaScript errors
3. Verify Descope project ID is correct

---

## Next Steps

After completing this bootstrap:

1. **Resume Week 5**: Add `flow export` and `flow import` commands to pcc-descope-mgmt CLI
2. **Create Environment Configs**: Set up dev/staging/prod tenant configurations
3. **Integrate with pcc-auth-api**: Configure the .NET API to validate Descope JWTs
4. **Build Web Client Auth**: Implement the flow in the React frontend (separate project)

---

## Quick Reference

### Descope Console URLs

| Resource | URL |
|----------|-----|
| Console | https://app.descope.com |
| Documentation | https://docs.descope.com |
| Flow Builder | https://app.descope.com/flows |
| Settings | https://app.descope.com/settings |

### Flow Actions Cheat Sheet

| Action | Purpose |
|--------|---------|
| Sign Up / Password | Create user with password |
| Sign In / Password | Authenticate with password |
| Sign Up or In / Passkeys | Register or verify passkey |
| Sign Up or In / TOTP | Setup or verify authenticator app |
| Send Email / OTP | Send verification code |
| Verify OTP | Validate entered code |
| Condition | Branch based on user attributes |
| End Flow | Complete with success/failure |

### User Attributes for Conditions

| Attribute | Description |
|-----------|-------------|
| `user.webAuthn` | True if user has passkey enrolled |
| `user.totp` | True if user has TOTP enrolled |
| `user.verifiedEmail` | True if email is verified |
| `user.verifiedPhone` | True if phone is verified |

---

## Document History

| Date | Author | Change |
|------|--------|--------|
| 2025-12-01 | Claude | Initial creation |
