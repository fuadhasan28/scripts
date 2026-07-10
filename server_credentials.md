# Server SSH Credentials and Connection Guide

This document contains credentials and connection commands for accessing servers via SSH.

> [!WARNING]
> Keep this file secure and ensure it is not committed to public repositories (add it to your `.gitignore` to prevent leaks).

---

## 1. Server Inventory

| Environment | IP Address | Username | Authentication | Description |
| :--- | :--- | :--- | :--- | :--- |
| Production | `10.112.165.130` | `nopapp` | Password | Linux Application Server |
| Staging/Template | `[SERVER_IP]` | `[USERNAME]` | Private Key (`.pem` / `.id_rsa`) | Template for key-based auth |

---

## 2. Server Details & Connection Commands

### 2.1 Linux Server (Password Auth)
*   **IP Address:** `10.112.165.130`
*   **Username:** `nopapp`
*   **Password:** `nopapp@bs23`

#### Connection Command
To connect directly using password authentication:
```bash
ssh nopapp@10.112.165.130
```
*(You will be prompted to enter the password: `nopapp@bs23`)*

#### One-Liner Connection (Using sshpass)
If you have `sshpass` installed and want to connect in a single command (useful for automation/scripts):
```bash
sshpass -p 'nopapp@bs23' ssh nopapp@10.112.165.130
```

---

### 2.2 Template: Server with Private Key (.pem / .key) Auth
*   **IP Address:** `[SERVER_IP]`
*   **Username:** `[USERNAME]`
*   **Private Key File:** `[path/to/key.pem]`

#### Step 1: Set Secure Key Permissions
Before using a private key file (`.pem` or `.key`), SSH clients require the key file permissions to be restricted (read-only for the owner). Run:
```bash
chmod 400 /path/to/key.pem
```
*(On Windows PowerShell, you can restrict permissions via standard file properties or WSL/Git Bash).*

#### Step 2: Connection Command
Use the `-i` flag to specify the identity file:
```bash
ssh -i /path/to/key.pem [USERNAME]@[SERVER_IP]
```

---

## 3. SSH Configuration File Setup (Recommended)

To simplify connecting to these servers without typing long commands or credentials every time, you can configure them in your local SSH config file (`~/.ssh/config`).

Open or create `~/.ssh/config` on your local machine and add the following:

```text
# Server with Password
Host nop-prod
    HostName 10.112.165.130
    User nopapp

# Server with Key File
Host nop-stage
    HostName [STAGE_SERVER_IP]
    User [USERNAME]
    IdentityFile [~/.ssh/key.pem]
```

Once configured, you can connect simply by typing:
```bash
ssh nop-prod
# or
ssh nop-stage
```

---

## 4. Useful SSH Tricks & Commands

### Copying Files (SCP)
*   **Upload a file using Password:**
    ```bash
    scp /path/to/local/file.txt nopapp@10.112.165.130:/home/nopapp/
    ```
*   **Upload a file using Key:**
    ```bash
    scp -i /path/to/key.pem /path/to/local/file.txt [USERNAME]@[SERVER_IP]:/home/[USERNAME]/
    ```

### Copy SSH Key for Passwordless Login
If you want to log in to the password-auth server without typing the password every time, copy your local SSH public key to it:
```bash
ssh-copy-id nopapp@10.112.165.130
```
