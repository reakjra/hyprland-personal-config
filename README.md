# hyprland-config

## Mounting Drives

first we download ntfs-3g
```sh
sudo pacman -S ntfs-3g
```
then we get all the info we need about our drives
```sh
lbslk -o NAME,SIZE,UUID
```

then we make one or more Dir for our drives
```sh
mkdir -p ~/MountedDrive
```
we mount it to check if it works
```sh
sudo mount ntfs-3g /dev/<drive name> ~/MountedDrive -o uid=$(id -u),gid=$(id -g)
```
if it works, we proceed to mount them automatically at every boot. Edit fstab
```sh
sudo nano /etc/fstab
```
and we add:
```sh
UUID=<drive ID> /home/<username>/MountedDrive ntfs-3g defaults,uid=1000,gid=1000,rw,user,exec,umask=000 0 0
```
then we check if everything works:
```sh
sudo umount ~/MountedDrive
sudo mount -a
ls -l ~/MountedDrive
```
