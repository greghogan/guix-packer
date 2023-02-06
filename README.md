Build an image for remote development. Packer documentation is at (https://packer.io).

For example, to build against an Amazon Linux 2 AMI execute:
$ packer build -var-file amazon-linux2/vars.x86_64.json amazon-ebs.json | tee packer.log

Or to build against an Ubuntu AMI execute:
$ packer build -var-file ubuntu/vars-latest.x86_64.json amazon-ebs.json | tee packer.log


To enable logging set the environment variable PACKER_LOG:
$ PACKER_LOG=1 packer build [...] | tee packer.log


To connect to the build instance enable the debug flag to step through the build process and have
packer save a copy of the key file and print the instance's public IP address:
$ packer build -debug -on-error=ask -var-file [...]

Then connect to the build instance over SSH:
$ ssh -i <KEY_FILE>.pem <SSH_USERNAME>@<PUBLIC_IP>

!!! Note that AMIs are region-specific !!!

The base AMI name and owners can be discovered by searching with the awscli tool. If the AMI image
ID is known (perhaps from the AWS Console) then filter by image-id. For example, for a recent
Amazon Linux 2 image:
$ aws ec2 describe-images --filters "Name=image-id,Values=ami-0323c3dd2da7fb37d"

If the AWS Marketplace, the product key can be obtained by searching for and viewing a specific
instance then clicking "Continue to Subscribe" and selecting the "productId" parameter from the
URL. For example, a recent CentOS image:
$ aws ec2 describe-images --owners aws-marketplace --filters "Name=name,Values=*d83d0782-cb94–46d7–8993-f4ce15d1a484*"

If the `jq` command is installed then the previous `describe-images` commands can be piped as
follows to parse the "OwnerID" and "Name" fields":
$ aws ec2 describe-images [...] | jq -r '.Images[] | "\(.OwnerId)\t\(.Name)"' | sort

| productID | OS |
| ----------- | ----------- |
| 3b73ef49-208f-47e1-8a6e-4ae768d8a333 | Ubuntu 18.04 LTS |
| aced0818-eef1-427a-9e04-8ba38bada306 | Ubuntu 20.04 LTS |
| 9b889f11-a864-4343-9340-1b2042b8cd6c | Ubuntu 21.04 |
