#!/usr/bin/env python3
"""Agent-socket probe — is a forwarded credential socket a conduit, or an actual oracle?

checks/r9-container.sh leg 3 verifies "SSH_AUTH_SOCK is unset and /tmp/vscode-ssh-auth-*.sock does not
exist". That is the right assertion for the agent's own container, where the answer must be "nothing here".
It is the wrong assertion for judging the OPERATOR's attached container — which is where this script is meant
to be run — because four states look alike from outside and mean very different things:

    absent      no socket, no variable                        -> no channel
    dead        socket exists, nothing answers                -> announced but not live
    conduit     socket answers, holds 0 identities            -> no oracle TODAY; one `ssh-add` re-arms it
    oracle      socket answers, holds >= 1 identity           -> a signing oracle for every key loaded

Measured in motoko's attached devcontainer on 2026-08-22: the forwarded ssh-agent ANSWERED as a CONDUIT with
0 identities, and the extension-created gpg socket was DEAD. Both were therefore latent rather than live —
which is not what "a signing oracle is ambient to the agent's UID" implies without the distinction, and is
also not a control: one `ssh-add` on the host re-arms it, with no signal inside the container.

Adapted, unchanged in substance, from a probe written for another project's confined-agent profile.

Read-only: it sends SSH2_AGENTC_REQUEST_IDENTITIES (11) and gpg-agent's KEYINFO --list, both enumerations.
It NEVER requests a signature, and prints counts and algorithm names only — never a key blob, never a key
comment (comments carry user@host), never a keygrip.

    agent-socket-probe.py                 # probe $SSH_AUTH_SOCK and the usual gpg socket paths
    agent-socket-probe.py --ssh PATH --gpg PATH

Exit status: 0 = nothing reachable is an oracle; 1 = an oracle is reachable; 2 = usage error.
"""

import argparse
import os
import socket
import struct
import subprocess
import sys

SSH2_AGENTC_REQUEST_IDENTITIES = 11
SSH2_AGENT_IDENTITIES_ANSWER = 12


def probe_ssh(path):
    """-> (state, detail) with state in {absent, dead, conduit, oracle}."""
    if not path:
        return "absent", "SSH_AUTH_SOCK unset"
    if not os.path.exists(path):
        return "absent", "%s does not exist" % path
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect(path)
        s.sendall(struct.pack(">IB", 1, SSH2_AGENTC_REQUEST_IDENTITIES))
        header = s.recv(5)
        if len(header) < 5:
            s.close()
            return "dead", "socket accepts connect(2) but returned no answer"
        length, msg_type = struct.unpack(">IB", header)
        body = b""
        while len(body) < length - 1:
            chunk = s.recv(length - 1 - len(body))
            if not chunk:
                break
            body += chunk
        s.close()
    except OSError as exc:
        return "dead", "connect/probe failed: %s" % exc
    if msg_type != SSH2_AGENT_IDENTITIES_ANSWER:
        return "dead", "unexpected response type %d" % msg_type
    count = struct.unpack(">I", body[:4])[0]
    offset, algorithms = 4, []
    try:
        for _ in range(count):
            blob_len = struct.unpack(">I", body[offset:offset + 4])[0]
            blob = body[offset + 4:offset + 4 + blob_len]
            offset += 4 + blob_len
            alg_len = struct.unpack(">I", blob[:4])[0]
            algorithms.append(blob[4:4 + alg_len].decode("ascii", "replace"))
            comment_len = struct.unpack(">I", body[offset:offset + 4])[0]
            offset += 4 + comment_len          # comment deliberately skipped, never printed
    except (struct.error, IndexError):
        algorithms.append("<unparsed>")
    if count == 0:
        return "conduit", "agent answered, 0 identities loaded — one `ssh-add` on the host re-arms it"
    return "oracle", "agent answered, %d identit%s loaded (%s)" % (
        count, "y" if count == 1 else "ies", ", ".join(sorted(set(algorithms))))


def local_gpg_agent(socket_path):
    """Return a reason string if a LOCAL gpg-agent owns this socket, else None.

    This check exists because probing without it produced a false reading on 2026-08-17: an earlier
    `gpg-connect-agent` call started a local agent, which replaced the extension-created socket, and the probe
    then reported that local agent's empty keyring as though it were the host's forwarded channel. A check that
    answers confidently about the wrong process is worse than no check. Two independent signals, either of which
    is enough to withhold a verdict about the host:
      * a gpg-agent process whose --homedir is this directory;
      * the sibling socket set (.extra/.browser/.ssh), which a local agent creates and the extension does not.
    """
    home = os.path.dirname(socket_path)
    siblings = [s for s in ("S.gpg-agent.extra", "S.gpg-agent.browser", "S.gpg-agent.ssh")
                if os.path.exists(os.path.join(home, s))]
    running = []
    try:
        out = subprocess.run(["pgrep", "-af", "gpg-agent"], capture_output=True, text=True, check=False)
        running = [ln for ln in out.stdout.splitlines() if home in ln]
    except OSError:
        pass
    if running:
        return "a local gpg-agent is running for %s (pid %s)" % (home, running[0].split()[0])
    if len(siblings) >= 2:
        return "the local-agent sibling socket set exists (%s)" % ", ".join(siblings)
    return None


def probe_gpg(paths):
    """gpg-agent speaks Assuan: a live agent greets with OK before we ask KEYINFO --list."""
    results = []
    for path in paths:
        if not os.path.exists(path):
            results.append((path, "absent", "does not exist"))
            continue
        local = local_gpg_agent(path)
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(5)
            s.connect(path)
            greeting = s.recv(4096).decode("utf-8", "replace")
            if not greeting.startswith("OK"):
                s.close()
                results.append((path, "dead", "socket exists, no Assuan greeting"))
                continue
            s.sendall(b"KEYINFO --list\n")
            data = s.recv(65536).decode("utf-8", "replace")
            s.close()
        except OSError as exc:
            results.append((path, "dead", "socket exists but no agent answered (%s)" % exc))
            continue
        keys = [ln for ln in data.splitlines() if ln.startswith("S KEYINFO")]
        if local:
            results.append((path, "local", "%s — this says NOTHING about the host's gpg-agent. Stop it "
                                           "(gpgconf --kill gpg-agent), re-attach, then re-probe. Local agent "
                                           "holds %d key(s)" % (local, len(keys))))
        elif keys:
            results.append((path, "oracle",
                            "%d key(s) known to the agent — commit signing as the host user is reachable" % len(keys)))
        else:
            results.append((path, "conduit", "agent answered, no keys — an oracle as soon as the host loads one"))
    return results


def main():
    ap = argparse.ArgumentParser(description="forwarded-socket probe (read-only)")
    ap.add_argument("--ssh", default=os.environ.get("SSH_AUTH_SOCK"),
                    help="ssh-agent socket (default $SSH_AUTH_SOCK)")
    ap.add_argument("--gpg", action="append", default=None, help="gpg-agent socket (repeatable)")
    args = ap.parse_args()

    gpg_paths = args.gpg or [
        os.path.expanduser("~/.gnupg/S.gpg-agent"),
        os.path.expanduser("~/.gnupg/S.gpg-agent.extra"),
    ]

    print("forwarded-socket probe (read-only; no signature is ever requested)")
    oracle_found = False

    state, detail = probe_ssh(args.ssh)
    print("  ssh-agent  %-8s %s" % (state.upper(), detail))
    print("             path: %s" % (args.ssh or "<unset>"))
    if state == "oracle":
        oracle_found = True

    for path, gstate, detail in probe_gpg(gpg_paths):
        print("  gpg-agent  %-8s %s" % (gstate.upper(), detail))
        print("             path: %s" % path)
        if gstate == "oracle":
            oracle_found = True

    announced = os.environ.get("REMOTE_CONTAINERS_SOCKETS")
    if announced:
        print("  note: the Dev Containers extension announces these forwarded sockets here:")
        print("        %s" % announced)

    print()
    if oracle_found:
        print("RESULT: an ORACLE is reachable from this UID — keys loaded on the host can sign here.")
        return 1
    print("RESULT: no oracle reachable now. A conduit is not a control: one `ssh-add`, or a Keychain-backed key")
    print("        loading on first host ssh use, turns it into one with no signal inside the container.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
