#!/usr/bin/env bash

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

# Build editor binary
scons platform=linuxbsd target=editor module_mono_enabled=yes 

# Build export templates
# scons platform=linuxbsd target=template_debug module_mono_enabled=yes
# scons platform=linuxbsd target=template_release module_mono_enabled=yes

# Generate glue sources
bin/godot.linuxbsd.editor.x86_64.mono --headless --generate-mono-glue modules/mono/glue
# Generate binaries
BUILD_ASSEMBLIES_ARGS=(
	./modules/mono/build_scripts/build_assemblies.py
	--godot-output-dir=./bin
	--godot-platform=linuxbsd
)

if [ -n "$LOCAL_NUGET_SOURCE" ]; then
	BUILD_ASSEMBLIES_ARGS+=(--push-nupkgs-local "$LOCAL_NUGET_SOURCE")
fi

"${BUILD_ASSEMBLIES_ARGS[@]}"