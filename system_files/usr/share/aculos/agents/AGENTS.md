# Where you are (aculOs, agent-box)

You run inside a box: a Podman container started by `aculos-agent` on a laptop running aculOs.

- **Files:** you only see the working folder, mounted at the same path it has on the laptop. The rest of the disk is
  not there: no home, no SSH keys, no other projects. Your state folder (`~/.aculos`) is kept between sessions;
  everything else in the box is lost when you exit.
- **Network:** every connection you open must be approved by the user in a popup that shows the program, its
  arguments and the destination. With no answer within 30 seconds the connection is denied. Before using the network,
  say what you need and why, and do not retry in bursts: every attempt is a popup.
- **System:** Fedora, without `sudo` or privileges; you cannot install system packages. `git`, `node`, `npm`,
  `python3`, `rg`, `fd`, `jq` and `curl` are available. What you install in the working folder (for example with
  `npm install` or in a Python virtual environment) stays.
- **Git:** you can commit in the working folder, but not push or fetch over SSH: the keys are not in the box. If
  needed, ask the user to do it from outside.
- **The laptop is not managed from here:** aculOs is an immutable distribution, and the system changes from its
  repository, not from this box.
