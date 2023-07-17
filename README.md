Build an image for remote development. Packer documentation is at (https://packer.io).

For example, to build against an Amazon Linux 2 AMI execute:

```console
packer build -var-file amazon-linux2023/vars.x86_64.json amazon-ebs.json | tee packer.log
```

To enable logging with timestamps set the environment variable `PACKER_LOG`:

```console
PACKER_LOG=1 packer build [...] | tee packer.log
```

To connect to the build instance enable the debug flag to step through the build process and have
packer save a copy of the key file and print the instance's public IP address:

```console
packer build -debug -on-error=ask -var-file [...]
```

Then connect to the build instance over SSH:
```console
ssh -i <KEY_FILE>.pem <SSH_USERNAME>@<PUBLIC_IP>
```

!!! Note that AMIs are region-specific !!!

The base AMI name is stored in the vars file within the distribution directory and can be queried
from AWS Systems Manager as follows. The available architectures are `arm64` and `x86_64`.

```console
# arm64 or x86_64
ARCH=arm64

# [list of EC2 regions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)
REGION=us-east-2

# for Amazon Linux 2023 (EOL 2028-03-15)
IMAGE=al2023-ami-kernel-default-${ARCH}

# for Amazon Linux 2 (EOL 2025-06-30)
IMAGE=amzn2-ami-hvm-${ARCH}-gp2

# query AMI name
aws ssm get-parameters --region $REGION --names /aws/service/ami-amazon-linux-latest/$IMAGE --query 'Parameters[0].[Value]' --output text
```

Notes on building: the images using Guix substitutes can be built with a volume size of at least
8 GB. The images built with substitutes disabled require a 13 GB volume. The Guix binary can be
copied to the transfer directory after compilation from the Guix source with the command
 `make guix-binary.$(uname -m)-linux.tar.xz`.
