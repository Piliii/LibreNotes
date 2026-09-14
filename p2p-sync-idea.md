# P2P Sync — Experimental Architecture Idea

> **Status:** Experimental / Future consideration  
> **Context:** Alternative to the current central-server sync model for the notes app  
> **Goal:** True peer-to-peer sync between devices, with the central server demoted to a last-resort fallback

---

## Background

The current architecture uses a self-hosted central server as the sync intermediary. Every write flows through it, and clients pull from it. This works, but it introduces a dependency on the server being up and reachable.

The P2P idea: devices sync directly with each other whenever possible, only falling back to the server when a direct connection can't be established.

---

## Conflict Resolution (Already Solved)

The existing conflict model carries over to P2P unchanged — the transport layer is being swapped, not the reconciliation logic.

- Every note change carries a **REV** (revision identifier) and **SEQ** (sequence number)
- In case of a conflict (same note edited on two devices independently), the app surfaces **both versions** to the user
- The user manually picks which version to keep — no silent auto-merge
- This is intentional: lossy automatic merges are worse than presenting the conflict

---

## Discovery

Two-phase discovery depending on whether devices are on the same network or different networks.

### Local Discovery (Same LAN)
- Use **mDNS** (multicast DNS) — the same mechanism LocalSend uses
- Each device broadcasts a service announcement on the local network
- Other devices listening for it see it appear automatically
- No pairing, no Bluetooth, no manual IP entry required
- Flutter package: `multicast_dns`

### Remote Discovery (Different Networks)
- Devices register their current addresses (IPv6, IPv4, port) with the user's self-hosted server on startup
- When Device A wants to sync with Device B across networks, it queries the server: *"what's Device B's current address?"*
- The server acts as a **phonebook only** — it never stores note content
- Once addresses are exchanged, the actual connection attempt proceeds through the fallback chain below

---

## Connection Fallback Chain

Attempt in order, use whichever succeeds first:

### 1. Same LAN → Local IP (RFC 1918)
- Detected via mDNS
- Fastest possible path — no internet involved at all
- Zero latency overhead, no dependency on external infrastructure

### 2. IPv6 Direct
- Both devices advertise a global IPv6 address
- Connect directly — no NAT at any layer, cleanest P2P path
- Increasingly viable: most modern ISPs and mobile carriers assign real IPv6 addresses
- **This is the primary path for cross-network sync** — IPv6 sidesteps NAT entirely

### 3. IPv4 Direct
- Both devices have a public IPv4 (e.g. a VPS, some business connections)
- Relatively rare for end-user devices but worth attempting

### 4. NAT Hole Punching
- Both devices behind regular (single-layer) NAT
- Use a **STUN server** to discover external IPs/ports
- Attempt simultaneous open from both sides to punch through NAT
- Success rate: roughly 60–80% depending on NAT type
- **Fails under CGNAT** (see note below)

### 5. TURN Relay
- Hole punching failed (CGNAT, symmetric NAT, etc.)
- Traffic routes through a relay server
- Since the app is E2EE, the relay sees only encrypted bytes — it's dumb pipe
- Could be a shared relay or the user's own server

### 6. User's Self-Hosted Server (Last Resort)
- If everything else fails, fall back to the existing central server model
- The user already runs this server — it's always available as a fallback
- No notes are lost; sync just happens the slow/old way

---

## NAT vs CGNAT — Why It Matters

**Regular NAT** — your home router. One public IP shared across devices. You control the router, so port forwarding and hole punching work.

**CGNAT (Carrier-Grade NAT)** — an extra NAT layer added by the ISP *above* your router:

```
Your device → Your router NAT → ISP NAT → Internet
```

You have no control over the ISP's NAT. Port forwarding doesn't reach it. Hole punching becomes unreliable or impossible. CGNAT is extremely common in regions with IPv4 exhaustion (Iraq, parts of Asia, mobile carriers globally).

**This is why IPv6 is the priority path** — it bypasses all NAT layers entirely. If both devices have IPv6, steps 3–5 of the fallback chain are skipped completely.

---

## Why WebRTC / ICE Is Worth Considering

Steps 2–5 of the fallback chain are essentially what **WebRTC's ICE (Interactive Connectivity Establishment)** protocol implements — it runs through local candidates, reflexive candidates (STUN), and relay candidates (TURN) automatically.

Using WebRTC as the transport layer (even without audio/video) would give the hole punching + relay fallback logic essentially for free. Flutter has `flutter_webrtc` for this.

The tradeoff: WebRTC is a large dependency and adds complexity. But if building hole punching + TURN from scratch, it's worth comparing the effort.

---

## E2EE Stays Intact

The P2P model actually improves the trust model:

- Currently: the central server can't read content (E2EE) but does see metadata (which devices sync when, note counts, etc.)
- With P2P: direct connections leak no metadata to any third party; the relay (if used) sees only encrypted payloads
- The server-as-phonebook only ever sees device addresses and timestamps — no content, no note structure

---

## Implementation Notes

- **Client:** Flutter — `multicast_dns` for local discovery, `flutter_webrtc` or raw TCP/UDP for connections
- **Server:** Dart — lightweight phonebook/signaling endpoint + optional TURN relay
- **IPv6 check:** attempt connection to the advertised IPv6 address; if it times out, proceed to next step
- **The fallback chain should be automatic and invisible to the user** — they just see "syncing"

---

## Open Questions

- Should the STUN/TURN infrastructure be self-hostable, or rely on public STUN servers (Google's, Cloudflare's)?
- How to handle the case where the user's self-hosted server is also unreachable (server down, travelling)?
- Key exchange for new devices joining — still needs the server as a trusted introducer?
- Battery/performance impact of maintaining P2P connections on mobile vs polling a server

---

*Captured from architecture discussion — June 2026*
