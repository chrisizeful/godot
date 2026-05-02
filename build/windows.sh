#!/usr/bin/env bash

set -euo pipefail

# Move to parent directory of the script
cd "$(dirname "$0")/.."

LOCAL_NUGET_SOURCE="${GODOT_NUGET_SOURCE:-}"

# Auto-detect the first enabled local filesystem NuGet source.
if [ -z "$LOCAL_NUGET_SOURCE" ]; then
	LOCAL_NUGET_SOURCE="$(dotnet nuget list source | awk '
		/^  [0-9]+\.  .*\[Enabled\]$/ {
			if (getline > 0) {
				sub(/^[[:space:]]+/, "", $0);
				if ($0 !~ /^https?:\/\//) {
					print;
					exit;
				}
			}
		}
	')"
fi

# dotnet on Windows expects a Windows-style path, not /c/... from MSYS/Git Bash.
if [ -n "$LOCAL_NUGET_SOURCE" ] && command -v cygpath >/dev/null 2>&1 && [[ "$LOCAL_NUGET_SOURCE" == /* ]]; then
	LOCAL_NUGET_SOURCE="$(cygpath -m "$LOCAL_NUGET_SOURCE")"
fi

# Build editor binary
scons platform=windows target=editor module_mono_enabled=yes d3d12=no accesskit=no

# Build export templates
# scons platform=windows target=template_debug module_mono_enabled=yes
# scons platform=windows target=template_release module_mono_enabled=yes

# Generate glue sources
bin/godot.windows.editor.x86_64.mono.exe --headless --generate-mono-glue modules/mono/glue
# Build .NET assemblies
BUILD_ASSEMBLIES_ARGS=(
	./modules/mono/build_scripts/build_assemblies.py
	--godot-output-dir
	./bin
)

if [ -n "$LOCAL_NUGET_SOURCE" ]; then
	BUILD_ASSEMBLIES_ARGS+=(--push-nupkgs-local "$LOCAL_NUGET_SOURCE")
fi

python "${BUILD_ASSEMBLIES_ARGS[@]}"