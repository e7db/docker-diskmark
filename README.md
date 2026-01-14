# docker-diskmark
[![GitHub tag](https://img.shields.io/github/v/tag/e7db/docker-diskmark)](https://github.com/e7db/docker-diskmark/tags) [![codeql](https://github.com/e7db/docker-diskmark/actions/workflows/codeql.yml/badge.svg)](https://github.com/e7db/docker-diskmark/actions/workflows/codeql.yml) [![tests](https://github.com/e7db/docker-diskmark/actions/workflows/tests.yml/badge.svg)](https://github.com/e7db/docker-diskmark/actions/workflows/tests.yml) [![docker-image](https://github.com/e7db/docker-diskmark/actions/workflows/docker-image.yml/badge.svg)](https://github.com/e7db/docker-diskmark/actions/workflows/docker-image.yml)

A [fio](https://github.com/axboe/fio)-based disk benchmark [docker container](https://hub.docker.com/r/e7db/diskmark), similar to what [CrystalDiskMark](https://crystalmark.info/en/software/crystaldiskmark/) does.  

## Basic Usage

```bash
# From Docker Hub
docker pull e7db/diskmark
docker run -it --rm e7db/diskmark

# From GitHub Container Registry
docker pull ghcr.io/e7db/diskmark
docker run -it --rm ghcr.io/e7db/diskmark
```

![Docker DiskMark](https://github.com/e7db/docker-diskmark/raw/main/assets/diskmark.png?raw=true "Docker DiskMark")

## Options

All options can be configured via CLI arguments (recommended) or environment variables. CLI arguments take precedence.

The container supports multiple CLI formats: `--key value`, `--key=value`, and `-k value`.

| Short | Long | Env Var | Default | Description |
| :---: | :--- | :------ | :------ | :---------- |
| `-h` | `--help` | | | Show help message and exit |
| `-v` | `--version` | | | Show version information and exit |
| `-t` | `--target` | `TARGET` | `/disk` | Target directory for benchmark |
| `-p` | `--profile` | `PROFILE` | `auto` | Benchmark profile: `auto`, `default`, `nvme` |
| `-j` | `--job` | `JOB` | | Custom job definition (e.g., `RND4KQ32T16`). Overrides profile. |
| `-i` | `--io` | `IO` | `direct` | I/O mode: `direct` (sync), `buffered` (async) |
| `-d` | `--data` | `DATA` | `random` | Data pattern: `random`, `zero` |
| `-s` | `--size` | `SIZE` | `1G` | Test file size (e.g., `500M`, `1G`, `10G`) |
| `-w` | `--warmup` | `WARMUP=1` | `1` | Enable warmup phase |
| | `--no-warmup` | `WARMUP=0` | | Disable warmup phase |
| | `--warmup-size` | `WARMUP_SIZE` | _(profile)_ | Warmup block size (`8M` default, `64M` nvme) |
| `-r` | `--runtime` | `RUNTIME` | `5s` | Runtime per job (e.g., `500ms`, `5s`, `2m`) |
| `-l` | `--loops` | `LOOPS` | | Number of test loops |
| `-n` | `--dry-run` | `DRY_RUN=1` | `0` | Validate configuration without running |
| `-f` | `--format` | `FORMAT` | | Output format: `json`, `yaml`, `xml` |
| `-u` | `--no-update-check` | `UPDATE_CHECK=0` | `1` | Disable update check at startup |
| | `--color` | `COLOR=1` | | Force colored output |
| | `--no-color` | `COLOR=0` | | Disable colored output |
| | `--emoji` | `EMOJI=1` | | Force emoji output |
| | `--no-emoji` | `EMOJI=0` | | Disable emoji output |

## Profiles

The container contains two different test profiles:
- Default profile:
  - Sequential 1M Q8T1
  - Sequential 1M Q1T1
  - Random 4K Q32T1
  - Random 4K Q1T1
- NVMe profile:
  - Sequential 1M Q8T1
  - Sequential 128K Q32T1
  - Random 4K Q32T16
  - Random 4K Q1T1

## Examples

### Basic parameters

```bash
# 4 GB file, 2 loops, warmup, zero data pattern
docker run -it --rm e7db/diskmark --size 4G --warmup --loops 2 --data zero
docker run -it --rm e7db/diskmark -s 4G -w -l 2 -d zero

# Hybrid mode: 3 loops, each capped at 10 seconds
docker run -it --rm e7db/diskmark --loops 3 --runtime 10s

# Custom warmup block size
docker run -it --rm e7db/diskmark --warmup --warmup-size 128M
```

### Force profile

Drive detection selects the appropriate profile (`default` or `nvme`). Override if needed:
```bash
docker run -it --rm e7db/diskmark --profile nvme
```

### Custom job

Run a custom job using the format `[RND|SEQ][size][Q depth][T threads]`:
- `RND` or `SEQ` — random or sequential access
- `xxK` or `xxM` — block size (e.g., `4K`, `1M`)
- `Qyy` — queue depth
- `Tzz` — number of threads

Example: `RND4KQ32T16` = random 4K blocks, queue depth 32, 16 threads.
```bash
docker run -it --rm e7db/diskmark --job RND4KQ32T16
```

### Specific disk

By default, the benchmark uses a [Docker volume](https://docs.docker.com/storage/volumes/) at `/disk`. Mount a different path to benchmark another disk:
```bash
docker run -it --rm -v /path/to/disk:/disk e7db/diskmark
```

### Machine-readable output

Output in JSON, YAML, or XML for scripting (automatically disables colors, emojis, and update check):
```bash
docker run -it --rm e7db/diskmark --format json
docker run -it --rm e7db/diskmark --format yaml
docker run -it --rm e7db/diskmark --format xml
```

#### JSON output sample

```json
{
  "configuration": {
    "target": "/mnt",
    "drive": {
      "label": "NVMe",
      "info": "Samsung SSD 990 PRO 2TB"
    },
    "filesystem": {
      "type": "ext4",
      "partition": "/dev/nvme0n1p1",
      "size": "1.8T"
    },
    "profile": "nvme",
    "io": "direct",
    "data": "random",
    "size": "1G",
    "warmup": 1,
    "runtime": "5s"
  },
  "results": [
    {"name": "SEQ1MQ8T1", "status": "success", "read": {"bandwidth_mb": 524, "iops": 499, "latency_ms": 2.15}, "write": {"bandwidth_mb": 498, "iops": 475, "latency_ms": 1.89}},
    {"name": "SEQ1MQ1T1", "status": "success", "read": {"bandwidth_mb": 512, "iops": 488, "latency_ms": 0.52}, "write": {"bandwidth_mb": 487, "iops": 464, "latency_ms": 0.48}},
    {"name": "RND4KQ32T1", "status": "success", "read": {"bandwidth_mb": 45, "iops": 11691, "latency_ms": 2.73}, "write": {"bandwidth_mb": 42, "iops": 10839, "latency_ms": 2.95}},
    {"name": "RND4KQ1T1", "status": "success", "read": {"bandwidth_mb": 41, "iops": 10583, "latency_ms": 0.09}, "write": {"bandwidth_mb": 38, "iops": 9814, "latency_ms": 0.10}}
  ]
}
```

#### YAML output sample

```yaml
configuration:
  target: "/mnt"
  drive:
    label: "NVMe"
    info: "Samsung SSD 990 PRO 2TB"
  filesystem:
    type: "ext4"
    partition: "/dev/nvme0n1p1"
    size: "1.8T"
  profile: "nvme"
  io: "direct"
  data: "random"
  size: "1G"
  warmup: 1
  runtime: "5s"
results:
  - name: "SEQ1MQ8T1"
    status: "success"
    read:
      bandwidth_mb: 524
      iops: 499
      latency_ms: 2.15
    write:
      bandwidth_mb: 498
      iops: 475
      latency_ms: 1.89
  - name: "SEQ1MQ1T1"
    status: "success"
    read:
      bandwidth_mb: 512
      iops: 488
      latency_ms: 0.52
    write:
      bandwidth_mb: 487
      iops: 464
      latency_ms: 0.48
  - name: "RND4KQ32T1"
    status: "success"
    read:
      bandwidth_mb: 45
      iops: 11691
      latency_ms: 2.73
    write:
      bandwidth_mb: 42
      iops: 10839
      latency_ms: 2.95
  - name: "RND4KQ1T1"
    status: "success"
    read:
      bandwidth_mb: 41
      iops: 10583
      latency_ms: 0.09
    write:
      bandwidth_mb: 38
      iops: 9814
      latency_ms: 0.10
```

#### XML output sample

```xml
<?xml version="1.0" encoding="UTF-8"?>
<benchmark>
  <configuration>
    <target>/mnt</target>
    <drive label="NVMe">Samsung SSD 990 PRO 2TB</drive>
    <filesystem type="ext4" partition="/dev/nvme0n1p1" size="1.8T" />
    <profile>nvme</profile>
    <io>direct</io>
    <data>random</data>
    <size>1G</size>
    <warmup>1</warmup>
    <runtime>5s</runtime>
  </configuration>
  <results>
    <job name="SEQ1MQ8T1" status="success">
      <read bandwidth_mb="524" iops="499" latency_ms="2.15" />
      <write bandwidth_mb="498" iops="475" latency_ms="1.89" />
    </job>
    <job name="SEQ1MQ1T1" status="success">
      <read bandwidth_mb="512" iops="488" latency_ms="0.52" />
      <write bandwidth_mb="487" iops="464" latency_ms="0.48" />
    </job>
    <job name="RND4KQ32T1" status="success">
      <read bandwidth_mb="45" iops="11691" latency_ms="2.73" />
      <write bandwidth_mb="42" iops="10839" latency_ms="2.95" />
    </job>
    <job name="RND4KQ1T1" status="success">
      <read bandwidth_mb="41" iops="10583" latency_ms="0.09" />
      <write bandwidth_mb="38" iops="9814" latency_ms="0.10" />
    </job>
  </results>
</benchmark>
```
