# Set screen resolution script for Windows VMs
# Modify the resolution values as needed

# Define desired resolution
$Width = 1920
$Height = 794

# Set the screen resolution
Set-DisplayResolution -Width $Width -Height $Height -Force

