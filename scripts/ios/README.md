# iOS TestFlight CI Setup

This guide explains how to set up GitHub Actions deployment to TestFlight using:

- `.github/workflows/deploy-testflight.yml`
- `scripts/ios/01_prepare-ci-secrets-from-input.sh`
- `scripts/ios/generate-testflight-secrets.sh`
- `scripts/ios/generate-ios-signing-secrets.sh`

## Enviroment
1. Github cli
2. setup fastline for ios folder

## How to use
1. Create/Download appstore.mobileprovision
2. Copy/setup vars.env
3. run `01-prepare-ci-secrets-from-input.sh`
4. run `output/apply-secrets-with-gh.sh`
