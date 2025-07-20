# Hosting an Ark: Survival Ascended Dedicated Server Behind a Strict NAT

This guide shows you how to **set up a dedicated server** for [Studio Wildcard](https://www.studiowildcard.com/)'s [Ark: Survival Ascended (ASA)](https://store.steampowered.com/app/2399830/ARK_Survival_Ascended/) when you are behind a strict NAT.

A **strict NAT** assigns different external ports for each outgoing connection and blocks unsolicited inbound traffic. This is common with certain ISPs, making it impossible to host a server via direct port forwarding.

## Who Is This Guide For?

This guide is for you if:

- You want to host a dedicated Ark: Survival Ascended (ASA) server but are behind a **strict NAT** or otherwise **unable** to **port forward** to your local machine.
- You have a spare **Windows 10/11** laptop or computer available to run the ASA dedicated server on.
- You have a **Google account** and a **Steam account**.

## Setup Overview

We will use **Google Cloud Compute Engine** to create a **Virtual Machine (VM)**, set up **[frp (Fast Reverse Proxy)](https://github.com/fatedier/frp)** to tunnel network traffic to your local machine and then set up the Ark: Survival Ascended dedicated server.

## Google Cloud Compute Setup

In this section, we are going to create a new Google Cloud Compute Engine project, add a VM instance and setup [frp](https://github.com/fatedier/frp).

### 1 | Create a New Google Cloud Project

1. Visit the [Google Cloud Console](https://console.cloud.google.com/).

2. Create a new project. For example:

   - **Project name:** `fast-reverse-proxy`
   - **Location:** No organization

3. Click **"Create."**

### 2 | Create a VM Instance

1. Enable the Compute Engine API:
   Visit the [Compute Engine API page](https://console.cloud.google.com/marketplace/product/google/compute.googleapis.com) and click **Enable**. This may take 1–2 minutes.

2. Go to [VM Instances](https://console.cloud.google.com/compute/instances) and click **"Create Instance."** Use the following settings (leave everything else as default):

   **Machine Configuration:**

   - **Name:** `frankfurt`
   - **Region:** `europe-west3` (Frankfurt)
   - **Zone:** Any
   - **Machine Type:** `E2`
   - **Preset:** `e2-micro` (2 vCPUs, 1 core, 1 GB memory)

   **Networking:**

   - **Network Tags:** `ark-survival-ascended`
   - **External IPv4 Address:**

     - Click **"Reserve Static External IP Address."**
     - **Name:** `ark-survival-ascended`
     - This will generate a **static external IP address.**

3. Click **"Create."**

4. Wait for the instance to start (this may take about 1 minute).

### 3 | Set Up Firewall Rules

1. Go to [Firewall Policies](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list).
2. Click **"Create Firewall Rule."**

Use the following settings:

- **Name:** `ark-survival-ascended`
- **Direction of traffic:** Ingress
- **Action:** Allow
- **Targets:** Specified target tags
- **Target Tags:** `ark-survival-ascended` (the tag you set when creating the VM)
- **Source Filter:** IPv4 ranges
- **Source IPv4 ranges:** `0.0.0.0/0` (this allows public access)
- **Destination Filter:** None
- **Protocols and Ports:**

  - **TCP:** `7000`, `7500`, `27020` (optional, for **RCON** remote console server access)
  - **UDP:** `7777`, `7778`, `27015`

3. Click **"Create."**

## Install and Run frp on Google Cloud VM

In this section, we will install and configure **[frp](https://github.com/fatedier/frp)** on your newly created Google Cloud VM.
This will allow you to tunnel Ark server ports from your local machine through the cloud.

### 1 | SSH Into Your VM

1. Go to your [VM Instances](https://console.cloud.google.com/compute/instances).
2. Click **"SSH"** in the instance table. This will open a new browser window.
3. Click **"Authorize"** when prompted to allow SSH-in-browser to connect to VMs.
4. A terminal will open. You should see a prompt similar to:

   ```bash
   username@YOUR_VM_NAME:~$
   ```

### 2 | Download frp

In the SSH terminal, run the following commands:

```bash
wget https://github.com/fatedier/frp/releases/download/v0.63.0/frp_0.63.0_linux_amd64.tar.gz
tar -xzvf frp_0.63.0_linux_amd64.tar.gz
rm frp_0.63.0_linux_amd64.tar.gz
cd frp_0.63.0_linux_amd64
```

### 3 | Set Up the Configuration

1. Generate the following (write them down – you will need them later):

   - **Username:** `<user>` (for frp dashboard access)
   - **Password:** `<password>` (for frp dashboard access)
   - **Token:** `<token>` (for securing the connection between client and server)

2. Open the `frps.toml` server configuration file in the nano editor:

   ```bash
   nano frps.toml
   ```

3. Paste the contents of your prepared configuration file into the editor.
   Make sure to replace:

   - `<user>` with your generated username
   - `<password>` with your generated password
   - `<token>` with your generated token

   Use this template or download the official example here: **[frps.toml](https://github.com/dreamfarer/asa-server/blob/main/frps.toml)**

4. To save and exit nano:

   - Press `CTRL + X`
   - Press `Y` to confirm saving
   - Press `Enter` to finish

### 4 | Run frps (Fast Reverse Proxy Server)

Start **frps** with your new configuration:

```bash
./frps -c frps.toml
```

Your frp server is now running on your Google Cloud VM.

## Set Up a systemd Service (Optional)

In this section, we will set up a **systemd service** on your previously created VM instance.
This is **optional**, but recommended because it ensures that **frps** starts automatically when your VM boots or restarts.

### 1 | Create and Configure the systemd Service

1. While still in the SSH terminal, if **frps** is currently running, stop it by pressing `CTRL + C`.

2. Open the nano editor to create the systemd service file:

   ```bash
   sudo nano /etc/systemd/system/frps.service
   ```

3. Paste the following configuration into the editor.
   **Replace `<username>`** with your **VM's SSH username** (the one you used in [SSH Into Your VM](#1--ssh-into-your-vm)):

   ```ini
   [Unit]
   Description=frps
   After=network.target

   [Service]
   ExecStart=/home/<username>/frp_0.63.0_linux_amd64/frps -c /home/<username>/frp_0.63.0_linux_amd64/frps.toml
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

4. To save and exit nano:

   - Press `CTRL + X`
   - Press `Y` to confirm saving
   - Press `Enter` to finish

### 2 | Enable and Start the systemd Service

Run the following commands to enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl start frps
```

Your **frps** server will now start automatically whenever the VM restarts.

## Install and Run frp on Your Local Server

In this section, we will install and configure **[frp](https://github.com/fatedier/frp)** on your **local machine**, where your Ark: Survival Ascended dedicated server will also run.

This will create a tunnel from your local machine to the Google Cloud VM.

### 1 | Download frp

1. Download **frp for Windows** from the official GitHub repository: [frp\_0.63.0\_windows\_amd64.zip](https://github.com/fatedier/frp/releases/download/v0.63.0/frp_0.63.0_windows_amd64.zip)

2. **Disable Windows Defender temporarily** or **whitelist the ZIP file** if it gets flagged as a virus.
   (This can happen with some reverse proxy tools, but frp is open-source and widely trusted.)

3. **Unzip** the file to your preferred directory and **delete the ZIP file** afterward.

### 2 | Set Up the Configuration

1. Open the `frpc.toml` file (the **client configuration**) using your preferred text editor.

2. Paste the contents of your prepared configuration file into the editor.
   Make sure to replace:

   - `<user>` with your generated username
   - `<password>` with your generated password
   - `<token>` with your generated token

   Use this template or download the official example here: **[frpc.toml](https://github.com/dreamfarer/asa-server/blob/main/frpc.toml)**

### 3 | Run frpc (Fast Reverse Proxy Client)

1. Open **Command Prompt (cmd)** in the directory where you extracted **frpc**.

2. Run the following command to start **frpc** with your configuration:

   ```bash
   frpc.exe -c frpc.toml
   ```

### 4 | Check the Setup (Optional)

1. Make sure that both **frps** (on the VM instance) and **frpc** (on your local machine) are **running**.

2. Open your browser on your **local machine** and go to:

   ```
   http://127.0.0.1:7500
   ```

3. In the **frp dashboard**, you should see the following **proxies running**:

   * `game1`
   * `game2`
   * `source-server`

If **frps is not running**, the dashboard will show `No Data`.

## Important Links

- [ARK: Survival Ascended Dedicated Server Setup Guide](https://ark.wiki.gg/wiki/Dedicated_server_setup)
