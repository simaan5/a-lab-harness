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
`sudo chown root:root /etc/ablab/poller.env`

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
