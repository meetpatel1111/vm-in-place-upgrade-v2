# In-Place Upgrade of Azure Windows Server VM

This document describes the manual steps to perform an **in-place upgrade** of a Windows Server VM running in Microsoft Azure (to Windows Server 2016, 2019, 2022 or 2025), using the upgrade-media managed disk provided by Azure.

**Reference:** [In-place upgrade for VMs running Windows Server in Azure – Microsoft Learn](https://learn.microsoft.com/en-us/azure/virtual-machines/windows-in-place-upgrade#post-upgrade-steps) :contentReference[oaicite:0]{index=0}

---

## ✅ Prerequisites

1. The VM must use **Managed Disks** (not unmanaged). :contentReference[oaicite:1]{index=1}  
2. VM should be licensed via Volume License (default for Azure generalized images). :contentReference[oaicite:2]{index=2}  
3. Sufficient free space on system disk (as required by Windows Setup). :contentReference[oaicite:3]{index=3}  
4. It is strongly recommended to take snapshots of OS disk (and data disks) before upgrade — to allow rollback if needed. :contentReference[oaicite:4]{index=4}  
5. The upgrade-media disk must be created and attached to the VM (as per prior automation or manual steps).

---

## 🔧 Manual In-Place Upgrade Steps

1. Ensure your VM is **running** (not deallocated).  
2. Connect to the VM via **RDP** or Bastion. :contentReference[oaicite:5]{index=5}  
3. Inside the VM, open **PowerShell as Administrator**.  
4. Identify the drive letter of the attached upgrade-media disk (typically `E:` or `F:` if no other data disks). :contentReference[oaicite:6]{index=6}  
5. Change directory to the root (or folder) where `setup.exe` resides.  
6. Run the upgrade command; for example (recommended for non-interactive upgrade):

   ```powershell
   .\setup.exe /auto upgrade /dynamicupdate disable /eula accept
