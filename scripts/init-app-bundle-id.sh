#!/bin/bash

set -euo pipefail

# Usage:
#   ./scripts/init-app-bundle-id.sh com.yourcompany.app

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NEW_APP_ID="${1:-}"

if [ -z "${NEW_APP_ID}" ]; then
	echo "Usage: $0 <bundle_id>"
	echo "Example: $0 com.icyanstudio.godansbook"
	exit 1
fi

# Safe cross-platform format (Android + Apple): lowercase reverse-domain style.
if ! echo "${NEW_APP_ID}" | grep -Eq '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$'; then
	echo "Error: invalid bundle id '${NEW_APP_ID}'"
	echo "Use lowercase reverse-domain format, e.g. com.company.app"
	exit 1
fi

replace_in_file() {
	local file_path="$1"
	local from="$2"
	local to="$3"

	if [ ! -f "${file_path}" ]; then
		return
	fi

	if ! grep -qF "${from}" "${file_path}"; then
		echo "  [skip] '${from}' not found in ${file_path}"
		return
	fi

	sed -i "s|${from}|${to}|g" "${file_path}"
	echo "  [ok]   ${file_path}"
}

# Detect the current iOS bundle ID from project.pbxproj (ignores RunnerTests suffix)
detect_current_ios_bundle_id() {
	local pbxproj="${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj"
	if [ ! -f "${pbxproj}" ]; then
		echo ""
		return
	fi
	# Find PRODUCT_BUNDLE_IDENTIFIER lines, exclude RunnerTests, take the first value
	grep 'PRODUCT_BUNDLE_IDENTIFIER' "${pbxproj}" \
		| grep -v 'RunnerTests' \
		| sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = //;s/;//;s/[[:space:]]//g' \
		| sort -u | head -n 1
}

update_main_activity_package() {
	local kotlin_root="${PROJECT_ROOT}/android/app/src/main/kotlin"

	if [ ! -d "${kotlin_root}" ]; then
		return
	fi

	local main_activity
	main_activity="$(find "${kotlin_root}" -type f -name 'MainActivity.kt' | head -n 1 || true)"

	if [ -z "${main_activity}" ]; then
		return
	fi

	local current_package
	current_package="$(grep -E '^package ' "${main_activity}" | head -n 1 | sed 's/^package[[:space:]]\+//')"

	if [ -z "${current_package}" ]; then
		return
	fi

	if [ "${current_package}" = "${NEW_APP_ID}" ]; then
		return
	fi

	local current_rel_path
	current_rel_path="${current_package//./\/}"

	local new_rel_path
	new_rel_path="${NEW_APP_ID//./\/}"

	local new_dir="${kotlin_root}/${new_rel_path}"
	mkdir -p "${new_dir}"

	local new_main_activity="${new_dir}/MainActivity.kt"

	mv "${main_activity}" "${new_main_activity}"
	sed -i "s|^package[[:space:]]\+${current_package}$|package ${NEW_APP_ID}|" "${new_main_activity}"

	local old_dir="${kotlin_root}/${current_rel_path}"
	while [ "${old_dir}" != "${kotlin_root}" ] && [ -d "${old_dir}" ] && [ -z "$(ls -A "${old_dir}")" ]; do
		rmdir "${old_dir}"
		old_dir="$(dirname "${old_dir}")"
	done
}

echo "Updating app identifier to: ${NEW_APP_ID}"

# Android
replace_in_file "${PROJECT_ROOT}/android/app/build.gradle.kts" "com.example.mobile" "${NEW_APP_ID}"

# iOS — detect whatever bundle ID is currently in the project rather than
# assuming the Flutter template default (com.example.mobile).
CURRENT_IOS_BUNDLE_ID="$(detect_current_ios_bundle_id)"
if [ -z "${CURRENT_IOS_BUNDLE_ID}" ]; then
	CURRENT_IOS_BUNDLE_ID="com.example.mobile"
fi
echo "iOS current bundle ID: ${CURRENT_IOS_BUNDLE_ID}"
replace_in_file "${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj" "${CURRENT_IOS_BUNDLE_ID}.RunnerTests" "${NEW_APP_ID}.RunnerTests"
replace_in_file "${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj" "${CURRENT_IOS_BUNDLE_ID}" "${NEW_APP_ID}"

# macOS
replace_in_file "${PROJECT_ROOT}/macos/Runner.xcodeproj/project.pbxproj" "com.example.mobile.RunnerTests" "${NEW_APP_ID}.RunnerTests"
replace_in_file "${PROJECT_ROOT}/macos/Runner/Configs/AppInfo.xcconfig" "com.example.mobile" "${NEW_APP_ID}"

# Linux desktop app id
replace_in_file "${PROJECT_ROOT}/linux/CMakeLists.txt" "com.example.mobile" "${NEW_APP_ID}"

# Android Kotlin package + folder structure
update_main_activity_package

echo "Done. Updated bundle/package identifiers to ${NEW_APP_ID}."
echo "Next: run 'flutter clean && flutter pub get' before the next build."
