---
name: deploy
description: "This skill should be used when the user asks to '/deploy', 'deploy to production', 'push to staging', 'release to server', or mentions deployment workflows."
metadata: {"clawdbot":{"always":false,"emoji":"🚀","requires":{"bins":["rsync","ssh"]}}}
user-invocable: true
---

# Deploy — User Command Skill Example

This is a complete example of a **Category C: User-Invocable Command** skill.

## Characteristics
- `user-invocable: true` - Accessible via `/deploy` command
- Can also be model-triggered if description matches
- Clear command syntax and argument documentation
- Interactive workflow with user confirmation
- May require specific tools (rsync, ssh)

## Use This Pattern When
- Creating slash commands for users
- Building interactive workflows
- Providing on-demand operations
- User-initiated automation

---

User triggered this command via `/deploy`.

## Command Syntax

```
/deploy [environment] [options]
```

**Arguments**:
- `environment` - Target environment: `production`, `staging`, `dev` (default: staging)
- `--skip-tests` - Skip pre-deployment tests (not recommended)
- `--dry-run` - Show what would be deployed without deploying
- `--rollback` - Roll back to previous deployment

## Examples

```bash
# Deploy to staging (default)
/deploy

# Deploy to production
/deploy production

# Dry run to see what would change
/deploy production --dry-run

# Skip tests (emergency only)
/deploy staging --skip-tests

# Roll back production to previous version
/deploy production --rollback
```

## Deployment Workflow

### 1. Pre-Deployment Checks

```markdown
Running pre-deployment checks...
- [ ] Git working directory clean
- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Environment variables set
- [ ] Target server accessible
```

### 2. Ask for Confirmation

```markdown
📦 Ready to deploy to **production**

Changes:
- 12 files modified
- 3 files added
- 1 file deleted

Proceed? (yes/no)
```

Wait for user response. Do NOT proceed without explicit "yes".

### 3. Execute Deployment

```bash
echo "🚀 Deploying to production..."

# Create backup
ssh prod-server "tar -czf /backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz /var/www/app"

# Sync files via rsync
rsync -avz --progress \
  --exclude 'node_modules' \
  --exclude '.git' \
  ./build/ \
  prod-server:/var/www/app/

# Restart services
ssh prod-server "systemctl restart app-service"

echo "✅ Deployment complete"
```

### 4. Post-Deployment Verification

```bash
# Check service status
ssh prod-server "systemctl status app-service"

# Test health endpoint
curl -f https://app.example.com/health || echo "⚠️ Health check failed"

# Monitor logs
ssh prod-server "tail -n 50 /var/log/app/production.log"
```

### 5. Report Results

```markdown
✅ Deployment successful

• Environment: production
• Version: v2.3.1
• Deploy time: 2m 34s
• Services restarted: app-service
• Health check: ✅ Passed
• URL: https://app.example.com

Monitor: ssh prod-server "tail -f /var/log/app/production.log"
```

## Rollback Procedure

If deployment fails or user requests rollback:

```bash
echo "⏮️ Rolling back deployment..."

# List available backups
ssh prod-server "ls -lh /backups/ | tail -10"

# Restore from backup
BACKUP=$(ssh prod-server "ls -t /backups/*.tar.gz | head -1")
ssh prod-server "tar -xzf $BACKUP -C /var/www/"

# Restart services
ssh prod-server "systemctl restart app-service"

echo "✅ Rollback complete"
```

## Error Handling

### Connection Failures
```markdown
❌ Cannot connect to prod-server

Troubleshooting:
1. Check SSH key: ssh prod-server echo "Connection works"
2. Verify server is running: ping prod-server
3. Check firewall: telnet prod-server 22
```

### Test Failures
```markdown
❌ Pre-deployment tests failed

Cannot deploy to production with failing tests.

Options:
1. Fix tests and re-run /deploy
2. Use /deploy --skip-tests (emergency only, not recommended)
3. Deploy to staging first: /deploy staging
```

### Deployment Failures
```markdown
❌ Deployment failed during rsync

Automatic rollback initiated...
✅ Rollback complete - production is stable

Review error logs and try again.
```

## Environment-Specific Config

### Production
- Server: `prod-server`
- Path: `/var/www/app`
- Service: `app-service`
- Requires: All tests passing, code review approval

### Staging
- Server: `staging-server`
- Path: `/var/www/staging`
- Service: `staging-service`
- Requires: Tests passing

### Dev
- Server: `dev-server`
- Path: `/var/www/dev`
- Service: `dev-service`
- Requires: None (for testing)

## Best Practices

1. **Always deploy to staging first**
   ```bash
   /deploy staging
   # Test thoroughly
   /deploy production
   ```

2. **Never skip tests for production**
   - Tests are your safety net
   - Only skip in genuine emergencies

3. **Monitor after deployment**
   ```bash
   # Watch logs for errors
   ssh prod-server "tail -f /var/log/app/production.log"
   ```

4. **Have rollback ready**
   - Backups created automatically
   - Know the rollback command: `/deploy production --rollback`

5. **Communicate deployments**
   - Notify team before production deployments
   - Post deployment status in team channel

## Progressive Disclosure

For detailed deployment strategies:
- Read: `references/deployment-strategies.md`

For environment configuration:
- Read: `references/environment-config.md`

---

**Key Takeaway**: User-invocable skills should have clear command syntax, interactive confirmation steps, comprehensive error handling, and safety mechanisms like automatic backups and rollback procedures.
