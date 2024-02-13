import platform
from subprocess import Popen, PIPE
import sys
import torch


if torch.backends.mps.is_available():  # MacOS
    device = "mps"
elif torch.cuda.is_available():  # Linux or Windows running in Docker
    device = "cuda"
else:
    device = "cpu"

dtype = torch.bfloat16
if device == "mps":
    try:
        has_bf16 = int(
            Popen(
                ["/bin/sh", "-c", "sysctl hw | grep FEAT_BF16 | awk '{print $2}'"],
                stdout=PIPE,
            )
            .stdout.read()
            .decode("ascii")
            .strip()
        )
        if not has_bf16:
            print("No bfloat16 support on M1 - falling back to float16")
            dtype = torch.float16
        else:
            print("Using bfloat16 on M2/M3")
    except:
        print("No bfloat16 support on Intel - falling back to float16")
        dtype = torch.float16

print(f"Platform: {platform.platform()} ({sys.platform} on {platform.machine()})")
if device == "cpu":
    print(
        "WARNING: No accelerator detected. Models may take a long time to run!",
        file=sys.stderr,
    )
else:
    print(f"Using {device} to accelerate model inference")
