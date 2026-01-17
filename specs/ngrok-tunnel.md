# ngrok Tunnel Support

## Overview

Add optional ngrok tunneling to expose opencode web UI publicly with basic auth protection.

## User Story

Developer wants to share/access ralph session remotely without port forwarding or VPN. ngrok provides instant HTTPS tunnel with optional custom domain.

## Requirements

### New CLI Flags
- `--ngrok <password>`: Enable ngrok tunnel with basic auth (password required)
- `--ngrok-domain <domain>`: Optional custom ngrok domain (uses random subdomain if omitted)

### Behavior
- ngrok launches AFTER opencode web is ready
- Forwards to `localhost:<port>` (the opencode web port)
- Basic auth: username = "ralph", password = provided value
- Print public URL after tunnel established
- Kill ngrok process on cleanup

### Auth
- Basic HTTP auth via ngrok's `--basic-auth` flag
- Format: `--basic-auth "ralph:<password>"`
- Protects entire web UI from unauthorized access

## Technical Implementation

### ngrok Start Function
```nushell
def start-ngrok [
  port: int           # Local port to forward
  password: string    # Basic auth password
  domain?: string     # Optional custom domain
] {
  let auth = $"ralph:($password)"
  
  let args = if ($domain | is-not-empty) {
    ["http", $port, "--basic-auth", $auth, "--domain", $domain]
  } else {
    ["http", $port, "--basic-auth", $auth]
  }
  
  let job_id = (job spawn { ngrok ...$args })
  
  # Poll ngrok API for public URL
  for attempt in 0..30 {
    let result = (curl -s http://localhost:4040/api/tunnels | complete)
    if $result.exit_code == 0 {
      let tunnels = ($result.stdout | from json)
      if ($tunnels.tunnels | length) > 0 {
        let url = $tunnels.tunnels.0.public_url
        return {job_id: $job_id, url: $url}
      }
    }
    sleep 500ms
  }
  
  error make {msg: "ngrok failed to start after 15 seconds"}
}
```

### Updated Main Signature
```nushell
def main [
  # ... existing params ...
  --ngrok: string             # Enable ngrok tunnel with this password
  --ngrok-domain: string      # Custom ngrok domain (optional)
]
```

### Integration Points
1. After `start-web` succeeds, check if `--ngrok` is set
2. Call `start-ngrok $port $ngrok $ngrok_domain`
3. Print public URL: `Tunnel: https://xxx.ngrok.io (auth: ralph:<password>)`
4. Add ngrok job_id to cleanup list

## UI Mockup

```
$ ralph.nu -n "feature" --ngrok mysecretpass

Starting xs store at ./.ralph/store...
Starting opencode web on port 4096...
Web UI: http://localhost:4096
Starting ngrok tunnel...
Tunnel: https://abc123.ngrok.io (auth: ralph:mysecretpass)

feature - Iteration #1...
```

With custom domain:
```
$ ralph.nu -n "feature" --ngrok mysecretpass --ngrok-domain myapp.ngrok.io

...
Tunnel: https://myapp.ngrok.io (auth: ralph:mysecretpass)
```

## Out of Scope
- ngrok paid features beyond custom domains
- Alternative tunnel providers (cloudflare, localtunnel)
- Multiple tunnels
- OAuth/SSO auth methods
- Persistent ngrok config file management

## Tasks

### 1. Add CLI flags
- [x] Add `--ngrok: string` parameter (password, enables tunnel)
- [x] Add `--ngrok-domain: string` parameter (optional domain)

### 2. Implement ngrok start function
- [x] Create `start-ngrok` function with port, password, domain params
- [x] Build ngrok command with `--basic-auth "ralph:<password>"`
- [x] Conditionally add `--domain` flag if provided
- [x] Spawn as background job

### 3. Implement ngrok readiness check
- [x] Poll `http://localhost:4040/api/tunnels` for tunnel URL
- [x] Parse JSON response to extract public_url
- [x] Return job_id and URL on success
- [x] Error after timeout (15s)

### 4. Integrate into main flow
- [x] After `start-web` succeeds, check if `$ngrok` is set
- [x] Call `start-ngrok` with port, password, optional domain
- [x] Print tunnel URL with auth hint
- [x] Track ngrok job_id for cleanup

### 5. Update cleanup
- [x] Ensure ngrok job_id included in cleanup list
- [x] Verify clean shutdown on Ctrl+C

## Open Questions
- None
