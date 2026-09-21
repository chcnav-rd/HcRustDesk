# RustDesk Flutter Web Client Design

## Date

2026-09-21

## Status

Approved design, ready for implementation planning

## Goal

Provide a browser-accessible RustDesk remote-control client built from the Flutter code in this repository. A user opens `https://<rustdesk-web-domain>/`, enters a device ID and password, and controls the remote device through the existing self-hosted RustDesk `hbbs`/`hbbr` deployment.

The first release supports remote desktop control only. File transfer, terminal, port forwarding, address-book synchronization, and full desktop-client feature parity are out of scope.

## Confirmed Constraints

- The RustDesk rendezvous and relay servers are already deployed and client devices already point to them.
- The server has a domain and HTTPS, so browser traffic can use secure `wss://` WebSocket connections.
- The implementation is based on the Flutter code already present in this repository.
- The first browser target is modern desktop Chrome, Edge, Firefox, and Safari.
- Existing uncommitted work in the repository must not be mixed into this feature branch.

## Chosen Approach

Reuse and restore the existing RustDesk Flutter Web build path rather than creating a new client or adding a server-side gateway.

This approach has the best tradeoff because the repository already contains:

- Flutter Web conditional implementations under `flutter/lib/web/`.
- Existing RustDesk connection and session models shared with desktop/mobile clients.
- Historical RustDesk Flutter Web scaffolding and build instructions in Git history and CI.

The web application is deployed as static files. No additional Flutter runtime, application server, or custom backend is required. The existing RustDesk server remains the rendezvous/relay backend.

## Alternatives Considered

### Separate Flutter Web client

A new Flutter Web project could reuse selected components and avoid desktop/mobile platform branches.

Rejected for the first release because it would require rebuilding connection setup, protocol handling, video rendering, input mapping, and session lifecycle. The risk and workload are substantially higher.

### Server-side gateway

A custom gateway could terminate browser connections, manage authentication, and proxy RustDesk sessions.

Rejected for the first release because it introduces a new long-running service, increases latency and operational complexity, and is unnecessary for direct browser-to-RustDesk-server operation. It may be reconsidered later if centralized user management or auditing becomes a requirement.

## Architecture

### Browser

- Runs the Flutter Web static bundle.
- Presents the RustDesk connection UI.
- Establishes secure WebSocket sessions to the configured RustDesk server.
- Sends input events and renders the remote video stream.

### Web hosting

- Nginx, Caddy, or an equivalent HTTPS reverse proxy serves the generated static files.
- WebSocket routes are proxied to the existing `hbbs`/`hbbr` service.
- Proxy timeouts are configured for long-lived remote-control sessions.
- HTTP caching is enabled for immutable build assets and disabled for `index.html` so upgrades are picked up reliably.

### RustDesk server

- Uses the existing `hbbs`/`hbbr` deployment.
- No server protocol changes are made.
- The browser client uses the same device ID, public key, and relay configuration model as native clients.

## First-Release Functional Scope

### Required

- Enter a RustDesk device ID.
- Enter the device password.
- Connect to devices registered with the self-hosted server.
- Render the remote desktop video stream.
- Send mouse events.
- Send keyboard events.
- Show connection state: connecting, connected, authentication failure, disconnected, and connection error.
- Provide a manual retry/reconnect action.
- Support browser fullscreen mode.
- Preserve only settings that are safe and useful for a browser client.
- Provide clear errors for unsupported browsers or network failures.

### Explicitly excluded

- File transfer.
- Terminal.
- TCP port forwarding.
- Address-book and group synchronization.
- Multi-window desktop workflows.
- Mobile-optimized layout beyond what Flutter already provides.
- RustDesk server installation or reconfiguration.
- Changing native desktop/mobile behavior.

## User Experience

1. The user opens the HTTPS URL.
2. The client loads and shows a connection form.
3. The user enters the device ID and password.
4. The client shows a connecting state and then the remote desktop.
5. The user controls the remote desktop with mouse and keyboard.
6. If the session ends, the client shows the reason and offers reconnect.

The connection form should make the server address/key explicit when they are not embedded in deployment configuration. This avoids silently connecting to the public RustDesk server.

## Security

- The web page is served only over HTTPS.
- Browser-to-server session traffic uses `wss://`.
- The RustDesk public key is supplied through deployment configuration or explicit user input.
- Device passwords are not persisted by default.
- Deployment documentation must warn that any static web deployment is public unless the reverse proxy adds authentication or network access controls.
- If optional access control is needed, it should be handled at the reverse-proxy layer (for example IP allowlist, mTLS, or SSO) rather than adding a custom backend in the first release.
- CORS and mixed-content failures must be surfaced as actionable browser errors.
- Shared-device usage should be treated as sensitive: the client should offer a disconnect action and avoid persistent credentials by default.

## Build and Deployment

### Build

- Restore or reproduce the required `flutter/web` scaffolding from repository history or the documented upstream source.
- Build the JavaScript bridge and protocol assets required by the Flutter Web client.
- Build the Flutter Web release bundle.
- Package the resulting `flutter/build/web` directory as a deployable archive.
- Record the exact Flutter, Rust bridge, Node, Yarn, and protoc versions used to reproduce the build.

### Deployment

- Copy the static bundle to the existing HTTPS web root.
- Configure the reverse proxy to serve the static files.
- Configure WebSocket proxying with long timeouts.
- Validate the deployed page over HTTPS before opening it to users.
- Keep one previous release available for rollback.

A deployment example must be included with the implementation, covering:

- Static file root.
- WebSocket reverse-proxy location.
- Proxy read/send timeouts.
- Cache headers for immutable assets.
- No-cache behavior for `index.html`.

## Testing Plan

### Build validation

- The web bundle builds from a clean checkout without relying on unrelated local modifications.
- Generated bridge and protocol files are reproducible from the documented commands.
- The build archive contains `index.html`, JavaScript, assets, and worker/WASM files needed at runtime.

### Browser validation

- Page loads over HTTPS without mixed-content warnings.
- Device connection succeeds against the self-hosted server.
- Video renders with acceptable latency for a remote desktop session.
- Mouse clicks, drags, scrolling, and basic keyboard input reach the remote device.
- Authentication failure, unknown device, network failure, and disconnect produce actionable UI states.
- Fullscreen and page refresh behave predictably.
- Basic smoke testing is performed in Chrome; other listed browsers receive targeted checks for input and rendering.

### Regression boundaries

- Native desktop and mobile builds are not required to change.
- Existing RustDesk server behavior is not modified.
- Any shared Dart code changes must not break existing unit tests.

## Rollout and Operations

- First deploy to a non-public or restricted HTTPS host for validation.
- Verify against one representative controlled device.
- Promote the same immutable bundle to the production host.
- Retain the previous bundle and reverse-proxy configuration for rollback.
- Monitor WebSocket disconnect rates and client load errors from existing reverse-proxy logs.

## Success Criteria

- A user can control one representative remote device from Chrome over HTTPS.
- Connection and disconnection states are understandable and recoverable.
- The deployable artifact is a static bundle and does not require a new server-side service.
- The build and deployment steps are documented and reproducible.
- No unrelated repository changes are included in the feature branch.
