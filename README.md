# How to Host an Ark: Survival Ascended Dedicated Server Behind a Strict NAT

This guide shows you how to **host a dedicated [Ark: Survival Ascended](https://store.steampowered.com/app/2399830/ARK_Survival_Ascended/) server** when you are behind a **strict NAT**.

A **strict NAT** assigns different external ports for each outgoing connection and blocks unsolicited inbound traffic. This is common with certain ISPs, making it impossible to host a server via direct port forwarding. To work around it, you'll use **Google Cloud Compute + frp (Fast Reverse Proxy)** to tunnel traffic to your local machine.

### Who Is This Guide For?

This guide is for you if:

- You're **behind a strict NAT** or can't **port forward**
- You have a spare **Windows 10/11 PC or laptop** to run the Ark server
- You have a **Google account** (needed for Google Cloud setup)

### Overview: What You’ll Do

1. Create a **Google Cloud VM** with a static IP
2. Set up **frp** (Fast Reverse Proxy) on the cloud VM and your local machine
3. Install and run the **Ark: Survival Ascended dedicated server**
4. Use a **batch script** to run both the proxy and server with one click (Optional)

# Set Up Google Cloud Compute Engine

In this section, you are going to create a new Google Cloud Compute Engine project, add a VM instance and setup [frp](https://github.com/fatedier/frp).

### 1 | Create a New Google Cloud Project

1. Visit the [Google Cloud Console](https://console.cloud.google.com/).

2. Click **"Create Project"**.

3. Example project details:

   | **Field**    | **Value**            |
   | ------------ | -------------------- |
   | Project Name | `fast-reverse-proxy` |
   | Location     | No organization      |

4. Click **Create**.

### 2 | Create a VM Instance

1. Enable the Compute Engine API:
   Visit the [Compute Engine API page](https://console.cloud.google.com/marketplace/product/google/compute.googleapis.com) and click **Enable**. This may take 1–2 minutes.

2. Go to [VM Instances](https://console.cloud.google.com/compute/instances) and click **"Create Instance."** Use the following settings (leave everything else as default):

   **Machine Configuration:**

   | Setting      | Value                          |
   | ------------ | ------------------------------ |
   | Name         | `frankfurt`                    |
   | Region       | `europe-west3` (Frankfurt)     |
   | Zone         | Any                            |
   | Machine Type | `E2`                           |
   | Preset       | `e2-micro` (2 vCPUs, 1 GB RAM) |

   **Networking:**

   - **Network Tags:** `ark-survival-ascended`
   - **External IPv4 Address:**

     - Click **"Reserve Static External IP Address."**
     - **Name:** `ark-survival-ascended`
     - This will generate a **static external IP address.**

3. Click **"Create."**

4. Wait for the instance to start (this may take about 1 minute).

### 3 | Configure Firewall Rules

1. Go to [Firewall Policies](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list).
2. Click **"Create Firewall Rule."**

   Use the following settings:

   | **Field**          | **Value**                                                                          |
   | ------------------ | ---------------------------------------------------------------------------------- |
   | Name               | `ark-survival-ascended`                                                            |
   | Direction          | Ingress                                                                            |
   | Action             | Allow                                                                              |
   | Targets            | Specified target tags                                                              |
   | Target Tags        | `ark-survival-ascended`                                                            |
   | Source IPv4 Ranges | `0.0.0.0/0`                                                                        |
   | Protocols/Ports    | TCP: `7000`, `7500`, `27020` (optional for RCON) <br> UDP: `7777`, `7778`, `27015` |

3. Click **"Create."**

# Install and Run frp on Google Cloud VM

In this section, you will install and configure **[frp](https://github.com/fatedier/frp)** on your newly created **Google Cloud VM**.
This will allow you to tunnel Ark server ports from your local machine through the cloud.

### 1 | Download frp

1. Go to your [VM Instances](https://console.cloud.google.com/compute/instances).
2. Click **"SSH"** in the instance table. This will open a new browser window.
3. Click **"Authorize"** when prompted to allow SSH-in-browser to connect to VMs.
4. A terminal will open. You should see a prompt similar to:

   ```bash
   username@YOUR_VM_NAME:~$
   ```

5. Run the following commands to download and extract [frp](https://github.com/fatedier/frp):

   ```bash
   wget https://github.com/fatedier/frp/releases/download/v0.63.0/frp_0.63.0_linux_amd64.tar.gz
   tar -xzvf frp_0.63.0_linux_amd64.tar.gz
   rm frp_0.63.0_linux_amd64.tar.gz
   cd frp_0.63.0_linux_amd64
   ```

### 2 | Set Up the Configuration

1. Generate the following (write them down – you will need them later):

   - **Dashboard Username:** `<user>`
   - **Dashboard Password:** `<password>`
   - **Token:** `<token>` (for secure connections)

2. Open the `frps.toml` server configuration file in the nano editor:

   ```bash
   nano frps.toml
   ```

3. Paste the contents of [frps.toml](https://github.com/dreamfarer/asa-server/blob/main/frps.toml) into the editor.
   Make sure to replace:

   - `<user>` with your generated username
   - `<password>` with your generated password
   - `<token>` with your generated token

4. To save and exit nano: `CTRL + X` → `Y` → `Enter`

### 3 | Run frps (Fast Reverse Proxy Server) as a systemd Service

1. Create the service file:

   ```bash
   sudo nano /etc/systemd/system/frps.service
   ```

2. Paste the following configuration into the editor.

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

   Replace `<username>` with your SSH username (the one you used in [Download frp](#1--download-frp)):

3. To save and exit nano: `CTRL + X` → `Y` → `Enter`

4. Enable and Start the systemd Service:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable frps
   sudo systemctl start frps
   ```

   Your frp server will now start automatically whenever the VM restarts.

# Install and Run frp on Your Local Machine

In this section, you will install and configure **[frp](https://github.com/fatedier/frp)** on your **local machine**.
This will create a secure tunnel from your local computer to your Google Cloud VM.

> [!IMPORTANT]  
> The local machine must be the same computer where your Ark: Survival Ascended dedicated server will run.

### 1 | Set Up a Common Directory

To eventually automatically start both **frp** and the **Ark: Survival Ascended dedicated server** with a single `.bat` file, you need to organize your files in a **common directory structure**.

Organize your server files like this:

```
<your-directory>
├─ frp
├─ steamcmd
├─ ark
└─ start.bat
```

### 2 | Download frp

1. Download **frp for Windows**:

   [frp_0.63.0_windows_amd64.zip](https://github.com/fatedier/frp/releases/download/v0.63.0/frp_0.63.0_windows_amd64.zip)

2. If your antivirus flags the ZIP as a virus:
   _(This sometimes happens with reverse proxy tools. However, frp is open-source and widely trusted.)_

   - [Restore Quarantined Files](https://learn.microsoft.com/en-us/defender-endpoint/restore-quarantined-files-microsoft-defender-antivirus)
   - [Add an Exclusion](https://support.microsoft.com/en-us/windows/virus-and-threat-protection-in-the-windows-security-app-1362f4cd-d71a-b52a-0b66-c2820032b65e)

3. **Unzip** the file, **move** the extracted contents to: `<your-directory>\frp`

4. After moving the files, **delete** the ZIP file to keep your directory clean.

### 3 | Set Up the Configuration

1. Open the `frpc.toml` client configuration file using any text editor.

2. Paste the contents of [frpc.toml](https://github.com/dreamfarer/asa-server/blob/main/frpc.toml) into the editor.
   Make sure to replace:

   - `<user>` with your generated username
   - `<password>` with your generated password
   - `<token>` with your generated token

3. To save and exit nano: `CTRL + X` → `Y` → `Enter`

### 4 | Run frpc (Fast Reverse Proxy Client)

1. Open **Command Prompt (cmd)** and navigate to the **frp folder**:

   ```
   cd <your-directory>\frp
   ```

2. Run the frp client:

   ```bash
   frpc.exe -c frpc.toml
   ```

### 5 | Check frp Dashboard (Optional)

1. Make sure that both **frps** (on the VM instance) and **frpc** (on your local machine) are **running**.

2. Open your browser on your **local machine** and go to:

   ```
   http://127.0.0.1:7500
   ```

3. In the **frp dashboard**, you should see the following **proxies running**:

   - `game1`
   - `game2`
   - `source-server`

If frps is **not** running, the dashboard will show **No Data**.

# Install and Run the Ark: Survival Ascended Dedicated Server

In this section, you will set up the **Ark: Survival Ascended dedicated server**.

You are encouraged to use the official Ark Wiki’s guides:

- [Dedicated Server Setup](https://ark.wiki.gg/wiki/Dedicated_server_setup)
- [Server Configuration](https://ark.wiki.gg/wiki/Server_configuration)

However, here is a **minimal working example** to get you started.

### 1 | Install the Ark: Survival Ascended Dedicated Server

1. Install **SteamCMD** by following this guide:
   [SteamCMD Download and Installation Guide](https://developer.valvesoftware.com/wiki/SteamCMD#Downloading_SteamCMD)

   Place **SteamCMD** in:

   ```
   <your-directory>\steamcmd
   ```

2. Open **Command Prompt (cmd)** and navigate to your **steamcmd** folder:

   ```
   cd <your-directory>\steamcmd
   ```

3. Run the following command to download the Ark server files.
   Replace `<your-directory>\ark` with the **full path** to your `ark` folder.
   Depending on your network speed, this may take several minutes.

   ```bash
   steamcmd +force_install_dir "<your-directory>\ark" +login anonymous +app_update 2430930 +quit
   ```

### 2 | Run the Ark: Survival Ascended Dedicated Server

1. Open **Command Prompt (cmd)** and navigate to:

   ```
   <your-directory>\ark
   ```

2. Run the following command to start the Ark dedicated server with the **TheIsland** map:

   ```bash
   ArkAscendedServer.exe TheIsland_WP?SessionName=<session-name>?
   ```

   Replace `<session-name>` with the server name you want to appear in the **Ark server browser**. The server may take **1–5 minutes** to fully start, depending on your system.

# Run frpc and the Ark: Survival Ascended Dedicated Server in One Click

In this section, you will use **[start.bat](https://github.com/dreamfarer/asa-server/blob/main/start.bat)** to start both **frpc** (the Fast Reverse Proxy client) and your **Ark: Survival Ascended Dedicated Server** with a single click.

> [!IMPORTANT]  
> Make sure you have completed **all previous setup steps** before using this script.

1. Download the **[start.bat script](https://github.com/dreamfarer/asa-server/blob/main/start.bat)**.
2. Move `start.bat` into your `<your-directory>`.
3. _(Optional)_
   Open `start.bat` with any text editor to customize the **Ark server startup parameters** according to the official [Server Configuration Guide](https://ark.wiki.gg/wiki/Server_configuration).
4. Double-click `start.bat` to start both:

   - **frpc** (the reverse proxy client)
   - **Ark: Survival Ascended Dedicated Server**

   Both services will now run together with one click.
