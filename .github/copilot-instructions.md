# Copilot Instructions for docker-diskmark

## Project Overview

Docker DiskMark is a fio-based disk benchmarking tool packaged as a minimal Docker container. It provides CrystalDiskMark-like functionality for Linux systems.

**Container registries:**
- Docker Hub: `e7db/diskmark` (tags only)
- GHCR: `ghcr.io/e7db/diskmark` (all builds)

## Project Structure

```
diskmark.sh          # Main entry point (~70 lines)
lib/
├── args.sh          # CLI argument parsing + help/version
├── validate.sh      # Input validation functions
├── utils.sh         # Utility functions (color, size conversion, cleanup)
├── profiles.sh      # Profile definitions (default, nvme, custom job)
├── detect.sh        # Drive/filesystem detection
├── benchmark.sh     # fio benchmark execution + warmup + result parsing
├── output.sh        # Output formatting (human/JSON/YAML/XML)
└── update.sh        # Update check functionality
```

## Default Values

Key defaults (defined in Dockerfile ENV and scripts):
- `TARGET=/disk` - Benchmark directory
- `PROFILE=auto` - Auto-detect drive type
- `IO=direct` - Direct I/O mode
- `DATA=random` - Random data pattern
- `SIZE=1G` - Test file size
- `WARMUP=1` - Warmup enabled
- `RUNTIME=5s` - Runtime per job
- `UPDATE_CHECK=1` - Update check enabled

## Clean Code Principles

Follow these clean code principles when contributing:

### Single Responsibility
- Each function should do one thing and do it well
- Keep functions small and focused (ideally < 30 lines)
- Separate concerns: parsing, validation, execution, output

### Meaningful Names
- Use descriptive function names: `validate_size_string` not `check`
- Use consistent naming conventions (snake_case for functions/variables)
- Prefix validation functions with `validate_`
- Prefix parsing functions with `parse_`

### DRY (Don't Repeat Yourself)
- Extract common patterns into reusable functions
- Use helper functions for repeated validation logic
- Centralize error handling and output formatting

### Comments and Documentation
- Functions should be self-documenting through clear names
- Add comments only when explaining "why", not "what"
- Keep help text and documentation in sync with code

### Error Handling
- Fail fast with clear error messages
- Validate inputs early before processing
- Use consistent exit codes (0=success, 1=error)

### Code Organization
- Group related functions together
- Order: constants → helpers → validators → core logic → main
- Keep configuration separate from logic

## Shell Script Best Practices

- Use `set -e` to exit on errors
- Quote variables: `"$VAR"` not `$VAR`
- Use `[[` for conditionals (bash)
- Prefer `local` variables in functions
- Use meaningful return codes
- Avoid global state when possible

## Testing Guidelines

- All features should have corresponding tests in `.github/workflows/tests.yml`
- Test both valid and invalid inputs
- Test CLI arguments in all formats: `--key value`, `--key=value`, `-k value`
- Use dry-run mode for input validation tests
- Use minimal sizes/runtimes for actual benchmark tests

## Docker Best Practices

- Keep the container minimal (scratch-based)
- Only include necessary binaries
- Use multi-stage builds
- Set appropriate defaults via ENV
- Run as non-root user (65534:65534)

## CI/CD Workflows

- `tests.yml` - Input validation and benchmark tests
- `docker-image.yml` - Build and push to GHCR (always) and Docker Hub (tags only)
- `codeql.yml` - Security scanning

## Output Formats

The tool supports multiple output formats:
- Human-readable (default): colored, with emojis
- JSON: structured, machine-readable
- YAML: structured, human-friendly
- XML: structured, enterprise-compatible

When modifying output, ensure all formats are updated consistently.
