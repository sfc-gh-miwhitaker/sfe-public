# Step 2: Org Policy — managed-settings.json + MDM Deployment

## Governance Lesson: IT Enforces Without User Action

Organization-level policy is the highest-priority layer. Users cannot override it. IT deploys it via standard enterprise tools (MDM, SCCM, Ansible).

**Time:** 15 minutes | **Build:** `managed-settings.json`

## Before You Start

- [ ] Admin/sudo access on your machine (to create the file)
- [ ] Completed Step 1 (understand the hierarchy)

## Why Org-Level Policy Matters

| Without Org Policy | With Org Policy |
|--------------------|-----------------|
| Users can run `--dangerously-allow-all-tool-calls` | Bypass mode is disabled |
| Any Snowflake account can be used | Only approved accounts allowed |
| Old CLI versions permitted | Minimum version enforced |
| No visibility that it's managed | Banner shows "Managed by IT" |

## The managed-settings.json Schema

```json
{
  "version": "1.0",
  "permissions": {
    "onlyAllow": ["pattern1", "pattern2"],
    "deny": ["pattern3"],
    "defaultMode": "allow",
    "dangerouslyAllowAll": false
  },
  "settings": {
    "forceNoHistoryMode": false,
    "forceSandboxEnabled": true,
    "forceSandboxMode": "regular"
  },
  "required": {
    "minimumVersion": "0.25.0"
  },
  "defaults": {
    "connectionName": "prod",
    "theme": "dark"
  },
  "ui": {
    "showManagedBanner": true,
    "bannerText": "Managed by Corporate IT",
    "hideDangerousOptions": true
  }
}
```

## Exercise 1: Create a Test managed-settings.json

Create the file locally (you'll need admin access):

**macOS:**
```bash
sudo mkdir -p "/Library/Application Support/Cortex"
sudo tee "/Library/Application Support/Cortex/managed-settings.json" << 'EOF'
{
  "version": "1.0",
  "permissions": {
    "dangerouslyAllowAll": false,
    "defaultMode": "allow"
  },
  "settings": {
    "forceSandboxEnabled": true
  },
  "required": {
    "minimumVersion": "1.0.0"
  },
  "ui": {
    "showManagedBanner": true,
    "bannerText": "[Workshop Test] Managed by IT"
  }
}
EOF
```

**Linux:**
```bash
sudo mkdir -p /etc/cortex
sudo tee /etc/cortex/managed-settings.json << 'EOF'
{
  "version": "1.0",
  "permissions": {
    "dangerouslyAllowAll": false,
    "defaultMode": "allow"
  },
  "settings": {
    "forceSandboxEnabled": true
  },
  "required": {
    "minimumVersion": "1.0.0"
  },
  "ui": {
    "showManagedBanner": true,
    "bannerText": "[Workshop Test] Managed by IT"
  }
}
EOF
```

## Exercise 2: Verify It's Loaded

Restart Cortex Code:

```bash
cortex
```

**What to notice:**
- The banner text appears: "[Workshop Test] Managed by IT"
- Try running: `cortex --dangerously-allow-all-tool-calls`
- It should be blocked (because `dangerouslyAllowAll: false`)

## Exercise 3: Add Account Restrictions

Edit the managed-settings.json to restrict which Snowflake accounts can be used:

```json
{
  "version": "1.0",
  "permissions": {
    "dangerouslyAllowAll": false,
    "onlyAllow": [
      "account(mycompany-prod)",
      "account(mycompany-staging)"
    ],
    "defaultMode": "allow"
  },
  "ui": {
    "showManagedBanner": true,
    "bannerText": "[Workshop Test] Production accounts only"
  }
}
```

**Test:** Try connecting to a different account — it should be blocked.

## Exercise 4: Clean Up (Important!)

Remove the test file so it doesn't affect future sessions:

**macOS:**
```bash
sudo rm "/Library/Application Support/Cortex/managed-settings.json"
```

**Linux:**
```bash
sudo rm /etc/cortex/managed-settings.json
```

## MDM Deployment Examples

In production, IT deploys managed-settings.json via enterprise tools:

### Jamf Pro (macOS)

See [reference/mdm-examples/jamf-profile.mobileconfig](../reference/mdm-examples/jamf-profile.mobileconfig) for a Configuration Profile that:
- Creates the directory
- Deploys the JSON file
- Sets correct permissions

### Microsoft Intune (Windows/macOS)

See [reference/mdm-examples/intune-config.json](../reference/mdm-examples/intune-config.json) for a custom configuration policy.

### Ansible

```yaml
- name: Deploy Cortex Code managed settings
  copy:
    content: "{{ managed_settings | to_nice_json }}"
    dest: /etc/cortex/managed-settings.json
    owner: root
    group: root
    mode: '0644'
  vars:
    managed_settings:
      version: "1.0"
      permissions:
        dangerouslyAllowAll: false
      ui:
        showManagedBanner: true
        bannerText: "Managed by IT"
```

## Key Configuration Options

| Option | What It Does | Recommended For |
|--------|--------------|-----------------|
| `dangerouslyAllowAll: false` | Prevents `--dangerously-allow-all-tool-calls` | All orgs |
| `onlyAllow: ["account(...)"]` | Restricts Snowflake accounts | Regulated industries |
| `minimumVersion` | Forces CLI updates | Security-conscious orgs |
| `forceSandboxEnabled: true` | Always run in sandbox mode | High-security environments |
| `showManagedBanner: true` | Visual indicator of management | All managed deployments |
| `hideDangerousOptions: true` | Hides unsafe options from help | Reducing attack surface |

## Validation

| Test | Expected Result |
|------|-----------------|
| Run `cortex` | Banner shows "Managed by IT" text |
| Run `cortex --dangerously-allow-all-tool-calls` | Blocked (if `dangerouslyAllowAll: false`) |
| Connect to unauthorized account | Blocked (if `onlyAllow` is set) |
| Run old CLI version | Error message (if `minimumVersion` is set) |

## What You Learned

1. **Org policy is the highest layer** — users cannot override it
2. **Standard MDM deployment** — same tools you use for everything else
3. **Key controls available** — bypass prevention, account restrictions, version requirements
4. **Visible management** — banner shows users they're in a managed environment

## Common Questions

**Q: What if a user deletes the file?**
A: They need admin access. MDM can also prevent deletion or re-deploy on schedule.

**Q: Can I test without admin access?**
A: The settings only work in the system paths. For testing, you need admin.

**Q: What about remote/BYOD users?**
A: MDM handles this. Jamf/Intune work on enrolled devices regardless of location.

## Next Step

Org policy sets the floor. Now let's build user-level standards that apply to every session.

→ [Step 3: User Standards](03_user_standards.md)
