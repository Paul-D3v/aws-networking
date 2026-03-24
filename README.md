# AWS Networking Lab

**Course:** Cloud Computing  
**Assignment:** AWS Networking — VPC, NAT Gateway, Security Groups & NACLs  
**Due:** March 29, 2026

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Prerequisites](#prerequisites)
4. [Step 1 — VPC & Subnets](#step-1--vpc--subnets)
5. [Step 2 — NAT Gateway Setup & Testing](#step-2--nat-gateway-setup--testing)
6. [Step 3 — Security Groups](#step-3--security-groups)
7. [Step 4 — Network ACLs (NACLs)](#step-4--network-acls-nacls)
8. [Deployment Guide](#deployment-guide)
9. [Security Groups vs NACLs](#security-groups-vs-nacls)
10. [Cleanup](#cleanup)

---

## Architecture Overview

```
Internet
    │
    ▼
Internet Gateway (IGW)
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC  10.0.0.0/16                     │
│                                                         │
│   ┌──────────────────┐    ┌──────────────────┐          │
│   │  Public Subnet   │    │  Public Subnet   │          │
│   │  AZ-1            │    │  AZ-2            │          │
│   │  10.0.1.0/24     │    │  10.0.2.0/24     │          │
│   │                  │    │                  │          │
│   │  [Bastion Host]  │    │                  │          │
│   │  [NAT Gateway]◄──┤    │                  │          │
│   └────────┬─────────┘    └──────────────────┘          │
│            │ (routes 0.0.0.0/0 → NAT GW)                │
│   ┌────────▼─────────┐    ┌──────────────────┐          │
│   │  Private Subnet  │    │  Private Subnet  │          │
│   │  AZ-1            │    │  AZ-2            │          │
│   │  10.0.3.0/24     │    │  10.0.4.0/24     │          │
│   │                  │    │                  │          │
│   │  [App Instance]  │    │  [App Instance]  │          │
│   └──────────────────┘    └──────────────────┘          │
└─────────────────────────────────────────────────────────┘
```

**CIDR Summary**

| Resource           | CIDR / Value     | AZ     |
|--------------------|------------------|--------|
| VPC                | `10.0.0.0/16`    | —      |
| Public Subnet 1    | `10.0.1.0/24`    | AZ-1   |
| Public Subnet 2    | `10.0.2.0/24`    | AZ-2   |
| Private Subnet 1   | `10.0.3.0/24`    | AZ-1   |
| Private Subnet 2   | `10.0.4.0/24`    | AZ-2   |
| NAT Gateway EIP    | Allocated by AWS | AZ-1   |

---

## Repository Structure

```
aws-networking/
├── cloudformation/
│   └── vpc-stack.yaml          # Complete infrastructure as code
├── policies/
│   ├── security-groups/
│   │   ├── public-sg.json      # SG for public subnet instances
│   │   └── private-sg.json     # SG for private subnet instances
│   └── nacl/
│       ├── public-nacl.json    # NACL rules for public subnets
│       └── private-nacl.json   # NACL rules for private subnets
├── scripts/
│   ├── deploy.sh               # One-command stack deployment
│   ├── test-nat-gateway.sh     # Automated NAT Gateway connectivity test
│   └── teardown.sh             # Stack deletion script
├── screenshots/                # VPC and NAT Gateway verification screenshots
└── README.md
```

---

## Prerequisites

- AWS CLI v2 installed and configured (`aws configure`)
- An AWS account with permissions to create VPCs, EC2, and IAM resources
- Bash shell (Linux, macOS, or WSL on Windows)
- An existing EC2 key pair in your target region

---

## Step 1 — VPC & Subnets

### What is a VPC?
A **Virtual Private Cloud (VPC)** is a logically isolated section of the AWS cloud where you can launch AWS resources in a virtual network you define. It gives you full control over networking — IP address ranges, subnets, route tables, and gateways.

### What was created

**VPC** (`10.0.0.0/16`)  
A `/16` CIDR provides 65,536 IP addresses, giving us room to carve out multiple subnets across availability zones.

**Internet Gateway**  
An IGW is attached to the VPC to enable communication between instances in public subnets and the internet.

**Public Subnets** (`10.0.1.0/24` and `10.0.2.0/24`)  
- Spread across two Availability Zones for fault tolerance.
- `MapPublicIpOnLaunch: true` — instances auto-receive public IPs.
- Route table has a default route (`0.0.0.0/0`) pointing to the IGW.

**Private Subnets** (`10.0.3.0/24` and `10.0.4.0/24`)  
- No public IPs assigned to instances.
- Route table has a default route (`0.0.0.0/0`) pointing to the NAT Gateway.
- Instances can initiate outbound requests but cannot be reached from the internet directly.

### How to verify in the AWS Console

1. Navigate to **VPC → Your VPCs** and confirm `aws-networking-lab-vpc` is listed.
2. Under **Subnets**, confirm four subnets appear, two per AZ.
3. Under **Route Tables**, confirm:
   - Public RT has a route to the IGW.
   - Private RT has a route to the NAT Gateway.

---

## Step 2 — NAT Gateway Setup & Testing

### What is a NAT Gateway?
A **Network Address Translation (NAT) Gateway** allows instances in a **private subnet** to initiate outbound connections to the internet (e.g., to download packages or reach external APIs) while preventing the internet from initiating inbound connections to those instances.

### How it works

```
Private Instance → NAT Gateway (public subnet) → Internet Gateway → Internet
                   (translates private IP → Elastic IP)
```

The NAT Gateway:
- Lives in the **public subnet** (it needs a route to the IGW).
- Has a dedicated **Elastic IP** (static, public).
- The private route table sends all `0.0.0.0/0` traffic to it.

### Testing NAT Gateway connectivity

Run the test script, providing your bastion's public IP, the private instance's IP, and your key pair:

```bash
chmod +x scripts/test-nat-gateway.sh

./scripts/test-nat-gateway.sh \
    <BASTION_PUBLIC_IP> \
    <PRIVATE_INSTANCE_IP> \
    ~/.ssh/your-key.pem
```

The script performs four checks:
1. SSH to the bastion host.
2. SSH to the private instance through the bastion (ProxyJump).
3. `curl https://checkip.amazonaws.com` from the private instance to confirm internet access.
4. Compare the returned IP against the NAT Gateway's Elastic IP — they should match.

**Expected output:**

```
✅ Bastion reachable
✅ Private instance reachable via bastion
✅ Internet reachable via NAT Gateway
   Egress IP: 54.xxx.xxx.xxx   ← matches NAT GW EIP in Console
```

### Manual verification via AWS Console

1. Go to **VPC → NAT Gateways** and confirm status is **Available**.
2. Note the **Elastic IP** displayed.
3. SSH into your private instance via the bastion and run:
   ```bash
   curl https://checkip.amazonaws.com
   ```
4. The returned IP should match the NAT Gateway EIP.

---

## Step 3 — Security Groups

Security Groups act as **stateful, instance-level firewalls**. Because they are stateful, return traffic is automatically allowed — you only need to define inbound rules for requests.

### Public Security Group (`public-sg.json`)

Applied to instances in the public subnet (e.g., bastion host, web servers):

| Direction | Protocol | Port(s)   | Source      | Purpose                    |
|-----------|----------|-----------|-------------|----------------------------|
| Inbound   | TCP      | 80        | `0.0.0.0/0` | HTTP web traffic           |
| Inbound   | TCP      | 443       | `0.0.0.0/0` | HTTPS web traffic          |
| Inbound   | TCP      | 22        | `0.0.0.0/0` | SSH (restrict IP in prod)  |
| Outbound  | All      | All       | `0.0.0.0/0` | Allow all outbound         |

> ⚠️ **Production note:** Restrict SSH (`port 22`) to your specific IP (e.g., `203.0.113.5/32`) instead of `0.0.0.0/0`.

### Private Security Group (`private-sg.json`)

Applied to instances in the private subnet (e.g., app servers, databases):

| Direction | Protocol | Port(s)   | Source            | Purpose                        |
|-----------|----------|-----------|-------------------|--------------------------------|
| Inbound   | TCP      | 22        | Public SG (ref)   | SSH only from bastion          |
| Inbound   | TCP      | 8080      | Public SG (ref)   | App traffic from public layer  |
| Inbound   | ICMP     | —         | Public SG (ref)   | Ping for connectivity tests    |
| Outbound  | All      | All       | `0.0.0.0/0`       | Outbound via NAT Gateway       |

Using a **Security Group reference** (rather than a CIDR) is best practice — only instances belonging to the public SG can reach the private instances, not any arbitrary IP in that subnet.

---

## Step 4 — Network ACLs (NACLs)

NACLs are **stateless, subnet-level** firewalls. Unlike Security Groups, NACLs evaluate rules in number order (lowest first) and require explicit rules for both request and return traffic.

### Public NACL (`public-nacl.json`)

Applied to both public subnets:

| Rule # | Direction | Protocol | Port(s)     | Action | Reason                           |
|--------|-----------|----------|-------------|--------|----------------------------------|
| 100    | Inbound   | TCP      | 80          | Allow  | HTTP                             |
| 110    | Inbound   | TCP      | 443         | Allow  | HTTPS                            |
| 120    | Inbound   | TCP      | 22          | Allow  | SSH                              |
| 130    | Inbound   | TCP      | 1024–65535  | Allow  | Ephemeral return ports (stateless)|
| 32767  | Inbound   | ALL      | ALL         | Deny   | Deny everything else             |
| 100    | Outbound  | ALL      | ALL         | Allow  | Allow all outbound               |

### Private NACL (`private-nacl.json`)

Applied to both private subnets:

| Rule # | Direction | Protocol | Port(s)     | Action | Reason                               |
|--------|-----------|----------|-------------|--------|--------------------------------------|
| 100    | Inbound   | ALL      | ALL         | Allow  | Allow all traffic from VPC CIDR      |
| 110    | Inbound   | TCP      | 1024–65535  | Allow  | Return traffic from NAT GW responses |
| 32767  | Inbound   | ALL      | ALL         | Deny   | Deny all internet-originated traffic |
| 100    | Outbound  | ALL      | ALL         | Allow  | Allow all outbound (via NAT GW)      |

### Why ephemeral ports matter in NACLs

Because NACLs are **stateless**, when a client (e.g., a private instance) sends an HTTP request outbound, the server's response returns on a random **ephemeral port** (1024–65535). Without allowing these return ports inbound, the response would be silently dropped — even though the original request was allowed.

Security Groups handle this automatically (they are stateful). NACLs do not.

---

## Security Groups vs NACLs

| Feature             | Security Group              | NACL                          |
|---------------------|-----------------------------|-------------------------------|
| Level               | Instance                    | Subnet                        |
| Stateful?           | ✅ Yes                      | ❌ No (must allow return traffic)|
| Default behavior    | Deny all inbound            | Allow all (default NACL)      |
| Rule evaluation     | All rules evaluated         | Rules evaluated in order      |
| Supports DENY rules | ❌ No (allow only)          | ✅ Yes                        |
| Use case            | Fine-grained instance control| Broad subnet-level guardrails |

**Best practice:** use both layers together — NACLs as a coarse outer guardrail, Security Groups for granular per-instance control.

---

## Deployment Guide

### Option A — One-command deployment (CloudFormation)

```bash
# Clone the repo
git clone https://github.com/Paul-D3v/aws-networking.git
cd aws-networking

# Make scripts executable
chmod +x scripts/*.sh

# Deploy (default: us-east-1, stack name: aws-networking-lab)
./scripts/deploy.sh us-east-1 aws-networking-lab
```

### Option B — AWS Management Console

1. **VPC Wizard:** VPC → Create VPC → select "VPC and more" to auto-create subnets, IGW, and route tables.
2. **NAT Gateway:** VPC → NAT Gateways → Create → select a public subnet and allocate an EIP.
3. **Update Private Route Table:** add `0.0.0.0/0 → NAT Gateway`.
4. **Security Groups:** EC2 → Security Groups → Create, using the rules in `policies/security-groups/`.
5. **NACLs:** VPC → Network ACLs → Create, using the rules in `policies/nacl/`.

---

## Cleanup

> ⚠️ **NAT Gateways incur hourly charges.** Delete resources when done.

```bash
./scripts/teardown.sh us-east-1 aws-networking-lab
```

Or manually in the Console: delete NAT Gateway → release EIP → delete VPC.

---

## Screenshots

Screenshots of the deployed resources are located in the `screenshots/` folder:

| File | Description |
|------|-------------|
| `screenshots/vpc-overview.png` | VPC dashboard showing all resources |
| `screenshots/subnets.png` | Four subnets across two AZs |
| `screenshots/route-tables(private).png` | private (NAT GW) routes |
| `screenshots/route-tables(public).png` | Public (IGW) |
| `screenshots/nat-gateway.png` | NAT Gateway in Available state with EIP |
| `screenshots/security-groups.png` | Public and private security group rules |
| `screenshots/nacl-public.png` | Public NACL inbound/outbound rules |
| `screenshots/nacl-private.png` | Private NACL inbound/outbound rules |
| `screenshots/nat-test-output.png` | Terminal output confirming NAT GW works |
