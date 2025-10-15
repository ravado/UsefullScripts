To route traffic from your local network (LAN) to a Tailscale device within an LXC container, you need to set up the container as a subnet router. This process involves preparing the LXC container, enabling IP forwarding, advertising the LAN's subnet to Tailscale, and finally, allowing the route in your Tailscale admin console. 
Prerequisites
A host system with an LXC environment (e.g., Proxmox).
An unprivileged LXC container where you can install Tailscale.
The Tailscale client installed on the LXC container. 
Step 1: Configure the LXC container for Tailscale
Tailscale needs access to the /dev/tun device to create network tunnels, which is not available by default in unprivileged LXC containers. 
Stop the LXC container that will run Tailscale.
Edit the container's configuration file on the host machine. The file is typically located at /etc/pve/lxc/<container-id>.conf for Proxmox.
Add the following lines to the configuration file:
conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
Будьте обачні, використовуючи код.

Restart the LXC container to apply the changes. 
Step 2: Enable IP forwarding inside the LXC container
For the container to function as a router and forward traffic, IP forwarding must be enabled.
Open a terminal inside your LXC container.
Enable IP forwarding by editing the sysctl configuration. Add the following lines to a file in /etc/sysctl.d/, for example 99-tailscale.conf:
sh
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
Будьте обачні, використовуючи код.

Apply the new settings without rebooting by running:
sh
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
Будьте обачні, використовуючи код.

 
Step 3: Start Tailscale and advertise the subnet
This step registers your LAN's subnet with Tailscale and announces that the LXC container can route traffic to it.
Determine your LAN's subnet (e.g., 192.168.1.0/24).
Start Tailscale inside the LXC container with the --advertise-routes flag, replacing 192.168.1.0/24 with your network's subnet:
sh
sudo tailscale up --advertise-routes=192.168.1.0/24
Будьте обачні, використовуючи код.

Follow the on-screen instructions to authenticate and add the LXC to your Tailnet. 
Step 4: Approve the subnet route in the Tailscale admin console
You must explicitly approve the advertised route in the Tailscale web interface.
Log in to the Tailscale admin console.
Navigate to the Machines page.
Find your new LXC container in the list. It should have a "subnets" label.
Click the three-dot menu next to the machine and select Edit route settings.
Toggle the switch to enable the advertised subnet route and click Save. 
Step 5: (Optional) Configure other devices to accept routes
For remote devices to use the LXC container's subnet router, they need to be configured to accept the advertised routes.
On your remote device (laptop, phone, etc.), you must ensure it is configured to accept subnet routes. Most modern Tailscale clients do this automatically, but if you experience issues, you can run:
sh
sudo tailscale up --accept-routes
Будьте обачні, використовуючи код.

 
After completing these steps, devices on your Tailnet will be able to reach your LAN, with the traffic being routed through the LXC container. 
ШІ може помилятися, тому рекомендуємо перевіряти відповіді сервісу




undefined
undefined
undefined
22 сайти
How to Access Multiple LXC Containers Through a Single Tailscale ...
20 лист. 2024 р. — Steps * Advertise Routes on Tailscale Host. On the container with Tailscale installed, run: tailscale up --adverti...
значок сайту
diegocarrasco.com

Install Tailscale on Proxmox - Muhammad Fareez Iqmal
9 черв. 2025 р. — Creating the LXC Container First, we'll create a dedicated LXC container for Tailscale. Click on the "Create CT" bu...
значок сайту
Muhammad Fareez Iqmal

How to install Tailscape in a Proxmox 8.2 LXC Container
15 лист. 2024 р. — I recently needed to set up Tailscale in an AlmaLinux 9 LXC container running on my Proxmox 8.2 server. Following ...
значок сайту
Reddit
Показати всі
well okay, now i have lxc container with ip 192.168.91.45 but how can i reroute requests pointed to 192.168.91.45:873 to my tailscale subnet 100.106.208.27:873 ?
To reroute requests from 192.168.91.45:873 to your Tailscale device at 100.106.208.27:873, you will use iptables with Destination Network Address Translation (DNAT). This rule must be applied on the LXC container that has the IP 192.168.91.45, as this is the machine receiving the initial traffic. 
How it works
Request arrives: A device on your LAN sends a request to 192.168.91.45 on port 873.
DNAT rule matches: The iptables rule on your LXC container's NAT table matches this incoming traffic.
Destination rewrites: The rule rewrites the destination IP address of the packet from 192.168.91.45 to 100.106.208.27.
Packet forwarded: The LXC container, with IP forwarding enabled, sends the packet to the correct Tailscale device. 
Steps to set up the redirection
1. Ensure IP forwarding is enabled
Before applying the iptables rule, confirm that IP forwarding is enabled on the LXC container.
sh
# Check if forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward

# If the output is 0, enable it by running:
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# To make it persistent across reboots, edit the sysctl.conf file
sudo nano /etc/sysctl.conf
# Uncomment or add the following line:
# net.ipv4.ip_forward=1
# Apply the change with:
sudo sysctl -p
Будьте обачні, використовуючи код.

2. Add the iptables DNAT rule
This rule will perform the port redirection. Run this command inside your LXC container: 
sh
sudo iptables -t nat -A PREROUTING -p tcp --dport 873 -j DNAT --to-destination 100.106.208.27:873
Будьте обачні, використовуючи код.

sudo iptables -t nat -A PREROUTING: Adds a rule to the PREROUTING chain of the nat table.
-p tcp --dport 873: Specifies that the rule applies to incoming TCP traffic destined for port 873.
-j DNAT --to-destination 100.106.208.27:873: The "jump" target is DNAT, which rewrites the destination to 100.106.208.27:873. 
3. Handle hairpin NAT (optional, but recommended)
This is for scenarios where a device on the same LAN as the LXC container tries to access 192.168.91.45. The packets don't go out to the internet, so you need a special rule.
Run this command inside your LXC container to handle local source IPs: 
sh
sudo iptables -t nat -A POSTROUTING -p tcp -d 100.106.208.27 --dport 873 -j MASQUERADE
Будьте обачні, використовуючи код.

-t nat -A POSTROUTING: Adds a rule to the POSTROUTING chain to modify outgoing packets.
-d 100.106.208.27 --dport 873: Matches packets destined for the Tailscale device on port 873.
-j MASQUERADE: Rewrites the source IP of these packets to that of the LXC container, ensuring the Tailscale device sends its response back to the LXC container rather than directly to the original LAN device. 
4. Make iptables rules persistent
iptables rules are not saved by default and will disappear on reboot. You need to install a utility to save them. 
For Debian-based systems (like Proxmox and many LXC images):
sh
# Install the utility
sudo apt-get install iptables-persistent

# Save your current rules
sudo netfilter-persistent save
Будьте обачні, використовуючи код.

This will automatically load your rules on every reboot.