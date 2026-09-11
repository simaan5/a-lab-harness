# a-lab scripted fixture harness

Dedicated host only (`hostname` must be `a-lab`).

Cage: **ablab-harness 4.2 / 5.0**. Poller talks to the control plane over **HTTPS outbound only**.

No Claude, Grok, Codex, or provider keys.

## Install harness (includes poller binary, does not start it)

```bash
cd /tmp
rm -rf a-lab-harness
git clone https://github.com/simaan5/a-lab-harness.git
cd a-lab-harness
git rev-parse HEAD
chmod +x install-host.sh
sudo ./install-host.sh
```

Confirm SOURCE COMMIT equals INSTALLED COMMIT.

## Connect the poller (Phase 5)

On the Benchmark Lab **Runners** page: Issue runner token.

On a-lab:

```bash
sudo install -m 0600 /dev/null /etc/ablab/poller.env
sudo tee /etc/ablab/poller.env >/dev/null <<'EOF'
ABL_BASE_URL=https://PASTE-CONTROL-PLANE-ORIGIN
ABL_TOKEN=ablab_rt_PASTE
ABL_PROTOCOL=ablab.runner.v1
EOF
sudo chmod 600 /etc/ablab/poller.env
sudo chown root:root /etc/ablab/poller.env
sudo systemctl enable --now ablab-poller
sudo systemctl status ablab-poller --no-pager
```

`ABL_BASE_URL` must be `https://`. The poller refuses HTTP and refuses TLS bypass.

The token is **not** a model API key.

## Do not

- install agents
- put Anthropic/OpenAI/xAI keys on this machine
- open inbound ports for the runner
- treat fixture results as model rankings
