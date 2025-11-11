# Email OAuth Setup Guide

This guide walks you through setting up OAuth credentials for Gmail and Outlook integration.

## Prerequisites

- Access to [Google Cloud Console](https://console.cloud.google.com)
- Access to [Azure Portal](https://portal.azure.com)
- Ambia backend deployed and accessible

---

## Part 1: Gmail OAuth Setup

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "Select a project" → "New Project"
3. Enter project name: `Ambia Email Integration`
4. Click "Create"

### Step 2: Enable Gmail API

1. In the left sidebar, navigate to **APIs & Services** → **Library**
2. Search for "Gmail API"
3. Click on **Gmail API**
4. Click **Enable**

### Step 3: Configure OAuth Consent Screen

1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Select **External** user type
3. Click **Create**

**App Information:**
- App name: `Ambia`
- User support email: `<your-email>`
- Developer contact: `<your-email>`

**Scopes:**
4. Click **Add or Remove Scopes**
5. Add these scopes:
   - `https://www.googleapis.com/auth/gmail.readonly`
   - `https://www.googleapis.com/auth/gmail.metadata`
6. Click **Save and Continue**

**Test Users** (for development):
7. Add your personal Gmail address
8. Click **Save and Continue**

### Step 4: Create OAuth Credentials

1. Navigate to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `Ambia Web Client`

**Authorized redirect URIs:**
Add these URLs:
```
http://localhost:3000/api/oauth/gmail/callback
https://your-production-domain.com/api/oauth/gmail/callback
```

5. Click **Create**
6. **COPY** your:
   - Client ID
   - Client Secret

### Step 5: Add to Environment Variables

Add to your `.env` file:
```bash
# Gmail OAuth
GMAIL_CLIENT_ID=your_client_id_here
GMAIL_CLIENT_SECRET=your_client_secret_here
GMAIL_REDIRECT_URI=http://localhost:3000/api/oauth/gmail/callback
```

---

## Part 2: Outlook OAuth Setup

### Step 1: Register Application in Azure

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **+ New registration**

**Register an application:**
- Name: `Ambia Email Integration`
- Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
- Redirect URI:
  - Platform: **Web**
  - URI: `http://localhost:3000/api/oauth/outlook/callback`

4. Click **Register**

### Step 2: Add Additional Redirect URI

1. In your app registration, go to **Authentication**
2. Under "Web" → "Redirect URIs", click **+ Add URI**
3. Add: `https://your-production-domain.com/api/oauth/outlook/callback`
4. Click **Save**

### Step 3: Create Client Secret

1. Navigate to **Certificates & secrets**
2. Click **+ New client secret**
3. Description: `Ambia Backend Secret`
4. Expires: **24 months** (recommended)
5. Click **Add**
6. **IMMEDIATELY COPY** the secret value (you won't see it again!)

### Step 4: Configure API Permissions

1. Navigate to **API permissions**
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Select **Delegated permissions**
5. Search and add these permissions:
   - `Mail.Read`
   - `Mail.ReadBasic`
   - `User.Read`
6. Click **Add permissions**

**Optional:** Click "Grant admin consent" (if you have admin access)

### Step 5: Get Application (Client) ID

1. Go to **Overview**
2. **COPY** the "Application (client) ID"

### Step 6: Add to Environment Variables

Add to your `.env` file:
```bash
# Outlook OAuth
OUTLOOK_CLIENT_ID=your_application_id_here
OUTLOOK_CLIENT_SECRET=your_client_secret_here
OUTLOOK_REDIRECT_URI=http://localhost:3000/api/oauth/outlook/callback
```

---

## Part 3: Backend Configuration

### Create `.env` file

Your complete `.env` should include:

```bash
# Database
DB_HOST=your-rds-endpoint.us-east-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=ambia
DB_USER=admin
DB_PASSWORD=your_db_password

# Gmail OAuth
GMAIL_CLIENT_ID=your_gmail_client_id
GMAIL_CLIENT_SECRET=your_gmail_client_secret
GMAIL_REDIRECT_URI=http://localhost:3000/api/oauth/gmail/callback

# Outlook OAuth
OUTLOOK_CLIENT_ID=your_outlook_client_id
OUTLOOK_CLIENT_SECRET=your_outlook_client_secret
OUTLOOK_REDIRECT_URI=http://localhost:3000/api/oauth/outlook/callback

# Encryption (for storing tokens)
OAUTH_ENCRYPTION_KEY=<generate-32-byte-hex-string>

# Claude API
CLAUDE_API_KEY=your_claude_api_key
```

### Generate Encryption Key

Run this command to generate a secure encryption key:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copy the output to `OAUTH_ENCRYPTION_KEY` in your `.env` file.

---

##Part 4: Testing OAuth Flow

### Test Gmail OAuth

1. Start your backend server
2. Navigate to: `http://localhost:3000/api/oauth/gmail/authorize?userId=<test-user-id>`
3. You should see Google's consent screen
4. Grant permissions
5. You'll be redirected back with success/error message

### Test Outlook OAuth

1. Navigate to: `http://localhost:3000/api/oauth/outlook/authorize?userId=<test-user-id>`
2. You should see Microsoft's consent screen
3. Sign in and grant permissions
4. You'll be redirected back with success/error message

---

## Security Notes

1. **Never commit** `.env` files to version control
2. Add `.env` to your `.gitignore`
3. For production:
   - Use environment variables (not `.env` files)
   - Enable HTTPS for all redirect URIs
   - Rotate secrets periodically
4. OAuth tokens are encrypted at rest in the database

---

## Troubleshooting

### "redirect_uri_mismatch" Error
- Check that redirect URIs in OAuth config **exactly match** the URIs in Google/Azure console
- Include protocol (http:// or https://)
- No trailing slashes

### "invalid_client" Error
- Double-check your client ID and secret in `.env`
- Ensure no extra spaces or quotes

### "insufficient_permissions" Error
- Verify all required scopes are added in Google/Azure console
- For Azure, grant admin consent for the permissions

---

## Production Deployment

Before deploying to production:

1. Update redirect URIs to use your production domain
2. Enable HTTPS (required for OAuth)
3. Move from "Testing" to "Published" status (Google)
4. For Outlook, ensure app is verified if needed
5. Set up token refresh in Lambda (automated email scanning)

---

## Next Steps

After completing this setup:
1. Test OAuth flows
2. Implement email scanning Lambda
3. Test with real emails
4. Monitor sync logs in database
