#!/bin/sh
set -e

if [ "${ENABLE_WITHDRAW_PROGRESS_WIDGET}" != "YES" ]; then
  echo "note: WithdrawProgressWidget disabled for ${CONFIGURATION}"
  exit 0
fi

WIDGET_APPEX="${BUILT_PRODUCTS_DIR}/WithdrawProgressWidget.appex"

if [ ! -d "${WIDGET_APPEX}" ]; then
  echo "Building WithdrawProgressWidget (${CONFIGURATION})..."
  xcodebuild \
    -project "${PROJECT_FILE_PATH}" \
    -target WithdrawProgressWidget \
    -configuration "${CONFIGURATION}" \
    -sdk "${SDK_NAME}" \
    BUILD_DIR="${BUILD_DIR}" \
    CONFIGURATION_BUILD_DIR="${CONFIGURATION_BUILD_DIR}" \
    SYMROOT="${SYMROOT}" \
    OBJROOT="${OBJROOT}" \
    ONLY_ACTIVE_ARCH="${ONLY_ACTIVE_ARCH}" \
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED}" \
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
    PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER}" \
    build
fi

if [ ! -d "${WIDGET_APPEX}" ]; then
  echo "error: WithdrawProgressWidget.appex missing at ${WIDGET_APPEX}" >&2
  exit 1
fi

PLUGINS_DIR="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/PlugIns"
mkdir -p "${PLUGINS_DIR}"
rm -rf "${PLUGINS_DIR}/WithdrawProgressWidget.appex"
ditto "${WIDGET_APPEX}" "${PLUGINS_DIR}/WithdrawProgressWidget.appex"
echo "Embedded WithdrawProgressWidget.appex"
