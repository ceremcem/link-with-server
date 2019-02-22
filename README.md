# Link With Server

Creates a link between the NODE and the LINK UP SERVER.

**WARNING** : `StrictHostKeyChecking` is disabled, you must get prepared for a MITM attack.


# Setup SSH Server on Server Side (for the first time)

1. Install OpenSSH server if not installed.
2. **Recommended**:
    1. Create a standard unix user account (say `forward`) and use it for the connections.
    2. Add following section to `/etc/ssh/sshd_config` file:

            Match User forward
                    AllowTcpForwarding yes
                    PermitTunnel yes
                    ForceCommand echo "This account is only for making link with server"
                    PasswordAuthentication no

        or use a handler script:
        
            Match User forward
                    AllowTcpForwarding yes
                    PermitTunnel yes
                    ForceCommand /path/to/handler.sh
                    PasswordAuthentication no
                    
        *handler.sh*:

           #/bin/bash
           echo "original command was $SSH_ORIGINAL_COMMAND"

    3. Restart sshd on server:

            sudo /etc/init.d/ssh restart


# Setup per Node (on every node deployment)

1. Clone this repository:

       git clone --recursive https://github.com/aktos-io/link-with-server
       cd link-with-server

2. Copy sample config file (`config.sh.sample`) as `config.sh` and edit the configuration file (`./config.sh`) accordingly.

3. IF NECESSARY: Create public/private key pair:

       ./gen-private-key.sh

4. Append your node's public key to `/home/forward/.ssh/authorized_keys` file on LINK_UP_SERVER in your favourite way.

        # Basically, just copy and paste the following command's output:
        $ cat ~/.ssh/id_rsa.pub
        ssh-rsa AAAAB3NzaC1yc2EAA...UCSo974furRP5N foo@example.com  

5. Run `link-with-server.sh` to test connection.

        ./link-with-server.sh

5. Make `link-with-server.sh` run on startup.

    > Running this script in background is your responsibility. <br />
    > Recommended way: Use [aktos-io/service-runner](https://github.com/aktos-io/service-runner) <br />
    > Simplistic way:  Add following line into the `/etc/rc.local` file:
    >
    >     nohup /path/to/link-with-server.sh &
    >


# Hooks

Place any scripts `on/connect` and `on/disconnect` folders.

# Recommended Tools

* [aktos-io/service-runner](https://github.com/aktos-io/service-runner): Run applications on boot and manage/debug them easily.
