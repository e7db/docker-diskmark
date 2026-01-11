# docker-diskmark
[![GitHub tag](https://img.shields.io/github/v/tag/e7db/docker-diskmark)](https://github.com/e7db/docker-diskmark/tags) [![codeql](https://github.com/e7d/docker-diskmark/actions/workflows/codeql.yml/badge.svg)](https://github.com/e7d/docker-diskmark/actions/workflows/codeql.yml) [![tests](https://github.com/e7d/docker-diskmark/actions/workflows/tests.yml/badge.svg)](https://github.com/e7d/docker-diskmark/actions/workflows/tests.yml) [![docker-image](https://github.com/e7d/docker-diskmark/actions/workflows/docker-image.yml/badge.svg)](https://github.com/e7d/docker-diskmark/actions/workflows/docker-image.yml)

A [fio](https://github.com/axboe/fio)-based disk benchmark [docker container](https://hub.docker.com/r/e7db/diskmark), similar to what [CrystalDiskMark](https://crystalmark.info/en/software/crystaldiskmark/) does.  

## Basic Usage

```
docker pull e7db/diskmark
docker run -it --rm e7db/diskmark
```

![Docker DiskMark](https://github.com/e7d/docker-diskmark/raw/main/assets/diskmark.png?raw=true "Docker DiskMark")

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

## Advanced usage

Find below a table listing all the different parameters you can use with the container:
| Parameter            | Type        | Default  | Description |
| :-                   | :-          |:-        | :- |
| `PROFILE`            | Environment | `auto`   | The profile to apply:<br>- `auto` to try and autoselect the best one based on the used drive detection,<br>- `default`, best suited for hard disk drives,<br>- `nvme`, best suited for NVMe SSD drives. |
| `JOB`                | Environment |          | A custom job to use: details below in the [Custom job](#custom-job) section.<br>This parameter overrides the `PROFILE` parameter. |
| `IO`                 | Environment | `direct` | The drive access mode:<br>- `direct` for synchronous I/O,<br>- `buffered` for asynchronous I/O. |
| `DATA`               | Environment | `random` | The test data:<br>- `random` to use random data,<br>- `0x00` to fill with 0 (zero) values. |
| `SIZE`               | Environment | `1G`     | The size of the test file (e.g., `500M`, `1G`, `10G`). |
| `WARMUP`             | Environment | `0`      | When set to `1`, use a warmup phase, thus preparing the test file with `dd`, using either random data or zero values as set by `DATA`. |
| `WARMUP_SIZE`        | Environment |          | Warmup block size. Defaults depend on the profile:<br>- `8M` for the default profile<br>- `64M` for the NVMe profile. |
| `RUNTIME`            | Environment | `5s`     | The duration for each job (e.g., `1s`, `5s`, `2m`).<br>Used alone: time-based benchmark.<br>Used with `LOOPS`: caps each loop to this duration. |
| `LOOPS`              | Environment |          | The number of test loops to run.<br>Used alone: runs exactly N loops with no time limit.<br>Used with `RUNTIME`: runs N loops, each capped to `RUNTIME`. |
| `DRY_RUN`            | Environment | `0`      | When set to `1`, validates configuration without running the benchmark. |
| `UPDATE_CHECK`       | Environment | `1`      | When set to `0`, skips the update check at startup. |
| `FORMAT`             | Environment | _(empty)_| Output format:<br>- Empty or unset for human-readable output,<br>- `json` for JSON format,<br>- `yaml` for YAML format,<br>- `xml` for XML format.<br>Machine-readable formats disable colors, emojis, and update check. |
| `/disk`              | Volume      |          | The target path to benchmark. |

By default, a 1 GB test file is used, with a 5 seconds duration for each test, reading and writing random bytes on the disk where Docker is installed.

### With parameters

For example, you can use a 4 GB file, looping each test twice, but after a warmup phase, and writting only zeros instead of random data.  
You can achieve this using the following command:  
```
docker run -it --rm -e SIZE=4G -e WARMUP=1 -e LOOPS=2 -e DATA=0x00 e7db/diskmark
```

You can also combine `LOOPS` and `RUNTIME` for hybrid mode — run a fixed number of loops, but cap each loop's duration:
```
docker run -it --rm -e SIZE=1G -e LOOPS=3 -e RUNTIME=10s e7db/diskmark
```

Warmup block size is tunable with `WARMUP_SIZE` (e.g. `8M`, `64M`, `128M`). By default it adapts to the selected profile: `8M` for the default profile (HDD-friendly) and `64M` for the NVMe profile. You can override it explicitly if needed:  
```
docker run -it --rm -e WARMUP=1 -e WARMUP_SIZE=128M e7db/diskmark
```

### Force profile

A detection of your disk is tried, so the benchmark uses the appropriate profile, `default` or `nvme`.  
In the event that the detection fails, yielding "Unknown", or returns the wrong profile, you can force the use of either of the profiles:  
```
docker run -it --rm -e PROFILE=nvme e7db/diskmark
```

### Custom job

You can run a custom single job using the `JOB` parameter.   
The job expression must follow a specific format, such as follows: `RND4KQ32T16`.  
It is composed of 4 parts:  
- `RND` or `SEQ`, for random or sequential access
- `xxK` or `xxM`, where `xx` is the block size, and `K` or `M` is the unit (Kilobytes or Megabytes)
- `Qyy`, where `yy` is the queue depth
- `Tzz`, where `zz` is the number of threads

In the previous example `RND4KQ32T16`, the job uses **random accesses**, with a **block size of 4K**, a **queue depth of 32**, and **16 threads**.

Construct your custom chain, then run the benchmark using the following command:  
```
docker run -it --rm -e JOB=RND4KQ32T16 e7db/diskmark
```

### Specific disk

By default, the benchmark runs on the disk where Docker is installed, using a [Docker volume](https://docs.docker.com/storage/volumes/) mounted on the `/disk` path inside the container.  
To run the benchmark on a different disk, use a path belonging to that disk, and mount it as the `/disk` volume:  
```
docker run -it --rm -v /path/to/specific/disk:/disk e7db/diskmark
```

### Machine-readable output

For scripting and automation, you can output results in JSON, YAML, or XML format:
```
docker run -it --rm -e FORMAT=json e7db/diskmark
docker run -it --rm -e FORMAT=yaml e7db/diskmark
docker run -it --rm -e FORMAT=xml e7db/diskmark
```

Machine-readable formats automatically disable colors, emojis, and the update check to produce clean output.

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
