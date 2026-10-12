# a-lab poller (Phase 5)

Outbound HTTPS only. No inbound ports. Scripted fixtures only.

## Credential file

Create **on a-lab**, not in git:

```
sudo install -m 0600 /dev/null /etc/ablab/poller.env
sudo nano /etc/ablab/poller.env
```

```
ABL_BASE_URL=https://YOUR-CONTROL-PLANE-ORIGIN
ABL_TOKEN=ablab_rt_...
ABL_PROTOCOL=ablab.runner.v1
```

`sudo chmod 600 /etc/ablab/poller.env`
`sudo chown ablab:ablab /etc/ablab/poller.env`

The token is a **runner credential**, not a model API key.

The origin **must be https://**. The poller refuses HTTP and refuses `curl -k`.

## Start

```
sudo systemctl enable --now ablab-poller
sudo systemctl status ablab-poller --no-pager
```

## Do not

- install Claude / Grok / Codex
- put Anthropic/OpenAI/xAI keys in poller.env
- open inbound firewall ports
- use SSH as the job protocol

## Non-root design

- systemd runs the poller as system user `ablab` (not in the `docker` group).
- It reads `poller.env` itself; the service has no `EnvironmentFile`, so `ABL_TOKEN` is never
  in an inherited environment, and `ABL_TOKEN`/`ABL_BASE_URL` are scrubbed from every child.
- Privileged work goes through `/etc/sudoers.d/ablab-poller`, which allows exactly
  `ablab-run-attempt`, `ablab-cancel-attempt`, `ablab-stop-all`, `ablab-resume` (validated with `visudo -c`).
- Evidence is group-readable by `ablab` only.
- User-Agent: `ablab-poller/<VERSION>`.
