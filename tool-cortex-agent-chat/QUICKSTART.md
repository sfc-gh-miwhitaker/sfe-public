# Cortex Agent Chat - Quick Start

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white)
![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=node.js&logoColor=white)

**Get a React + Cortex Agent chat interface running in 5 minutes.**

---

## Prerequisites

| Requirement | Version | Check |
|------------|---------|-------|
| **Node.js** | 16+ | `node --version` |
| **npm** | 8+ | `npm --version` |
| **OpenSSL** | Any | `openssl version` |
| **Snowflake Account** | Enterprise+ | Cortex Agents enabled |
| **Snowflake Role** | ACCOUNTADMIN | Required for setup |

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Generate Keys & Config (1 min)

```bash
cd tools/cortex-agent-chat

# macOS/Linux
./tools/01_setup.sh

# Windows
tools\01_setup.bat
```

**This creates:**
- ✅ RSA key-pair (`rsa_key.pem`, `rsa_key.pub`)
- ✅ Backend config (`.env.server.local` - with private key)
- ✅ Frontend config (`.env.local` - no secrets)
- ✅ Deployment SQL (`deploy_with_key.sql`)

---

### Step 2: Configure Snowflake Account (30 sec)

Edit **both** environment files with your account identifier:

```bash
# Backend config
nano .env.server.local
```

```env
SNOWFLAKE_ACCOUNT=xy12345.us-east-1    # ← Change this
SNOWFLAKE_USER=your_username            # ← Change this
```

```bash
# Frontend config
nano .env.local
```

```env
REACT_APP_SNOWFLAKE_ACCOUNT=xy12345.us-east-1    # ← Must match backend
REACT_APP_SNOWFLAKE_USER=your_username            # ← Must match backend
```

> **Find your account identifier:** Snowsight → Account selector (bottom left) → Copy account locator

---

### Step 3: Deploy to Snowflake (2 min)

1. Open **Snowsight** in your browser
2. Copy entire contents of `deploy_with_key.sql`
3. Paste into Snowsight SQL editor
4. Click **Run All**

**This creates:**
- ✅ Demo Cortex Agent (`SFE_REACT_DEMO_AGENT`)
- ✅ Public key assignment to your user
- ✅ Required schema and grants

---

### Step 4: Start Application (1 min)

```bash
# Install dependencies
npm install

# Start backend + frontend together
npm run dev
```

**Application URLs:**
- 🌐 **Frontend:** http://localhost:3001
- 🚀 **Backend:** http://localhost:4000

**Ready!** Open http://localhost:3001 and start chatting.

---

## ✅ Verification

### Check Key-Pair Setup

```bash
# Verify files exist
ls -l rsa_key.pem rsa_key.pub .env.server.local .env.local

# Confirm private key only in backend config
grep SNOWFLAKE_PRIVATE_KEY_PEM .env.server.local   # ✅ Should find it
grep SNOWFLAKE_PRIVATE_KEY_PEM .env.local          # ❌ Should be empty
```

### Test Snowflake Connection

```sql
-- In Snowsight:
DESC USER your_username;
-- Look for: RSA_PUBLIC_KEY_FP (should be populated)

SHOW AGENTS IN SCHEMA SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT;
-- Should see: SFE_REACT_DEMO_AGENT
```

---

## 🎯 Quick Test

Once the app loads:

1. **Type:** "What can you help me with?"
2. **Watch:** Agent responds in real-time
3. **See:** Streaming text delta updates
4. **Verify:** Full response completes

**Working?** You're done! 🎉

**Not working?** See troubleshooting below.

---

## 🔧 Troubleshooting

### 401 Unauthorized

| Fix | Command |
|-----|---------|
| Check public key assignment | `DESC USER your_username;` in Snowsight |
| Verify account format | Use `xy12345.us-east-1` not full URL |
| Test key-pair auth | `snow connection test --private-key-path rsa_key.pem` |

### 403 Forbidden

```sql
-- Grant required permissions
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE your_role;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT TO ROLE your_role;
```

### 404 Not Found

```sql
-- Verify agent exists
SHOW AGENTS IN SCHEMA SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT;
```

### Port Already in Use

```bash
# Kill existing processes
lsof -ti :3001 | xargs kill
lsof -ti :4000 | xargs kill

# Restart
npm run dev
```

---

## 📚 Next Steps

| What | Where |
|------|-------|
| **Full documentation** | `README.md` |
| **Architecture diagrams** | `diagrams/` |
| **Customize agent** | Edit `.env.local` agent name |
| **Change colors** | Edit `src/App.css` CSS variables |
| **Add features** | See `README.md` → Customization Guide |

---

## 🧹 Cleanup

```bash
# Stop app (Ctrl+C)

# Remove Snowflake objects
# Copy teardown.sql into Snowsight → Run All

# Remove local files
rm -rf node_modules .env.server.local .env.local
rm rsa_key.pem rsa_key.pub deploy_with_key.sql
```

---

## 🔐 Security Reminder

| Rule | Why |
|------|-----|
| ❌ Never commit `.env.server.local` | Contains private key |
| ❌ Never share `rsa_key.pem` | Grants full account access |
| ✅ Private key stays server-side | Backend proxy only |
| ✅ Frontend has no secrets | Safe to deploy |

---

**Questions?** See full `README.md` for detailed explanations, security best practices, and customization options.

**Author:** SE Community | **Expires:** 2026-05-01
