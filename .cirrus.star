load(
    "./cirrus/common.star",
    "secrets",
    "setup_1password_cli",
    "setup_credentials",
    "setup_fastlane",
)
load("cirrus", "fs", "yaml")
load(
    "github.com/cirrus-modules/helpers",
    "cache",
    "container",
    "macos_instance",
    "script",
    "task",
)

def main():
    return [
        task(
            name = "prepare",
            env = secrets(),
            instance = container(image = "ghcr.io/cirruslabs/android-sdk:34"),
            instructions = [
                setup_1password_cli(),
                setup_credentials(),
                script(
                    "install_rubocop",
                    "cd fastlane && bundle install",
                ),
                script(
                    "rubocop",
                    "cd fastlane && bundle exec rubocop",
                ),
                script(
                    "checks",
                    "./gradlew :composeApp:lint",
                    "./gradlew :composeApp:detektAndroidDebug",
                    "./gradlew :composeApp:detektMetadataMain",
                    "./gradlew :composeApp:detektMetadataIosMain",  # FIXME: requires macOS host
                    "./gradlew :composeApp:detektMetadataCommonMain",
                ),
            ],
        ),
        task(
            name = "Deploy Android app",
            env = {"CIRRUS_CLONE_TAGS": "true"} | secrets(),
            instance = container(image = "ghcr.io/cirruslabs/android-sdk:34"),
            only_if = "$CIRRUS_TAG =~ 'v.*' || $CIRRUS_BRANCH == 'master'",
            # only_if = "$CIRRUS_TAG =~ 'v.*'",
            instructions = [
                setup_1password_cli(),
                setup_credentials(),
                setup_fastlane(),
                script(
                    "fastlane_android_tst",
                    "cd fastlane",
                    "op run -- bundle exec fastlane android tst",
                ),
            ],
        ),
        task(
            name = "Deploy iOS app",
            env = {"CIRRUS_CLONE_TAGS": "true"} | secrets(),
            instance = macos_instance(
                image = "ghcr.io/cirruslabs/macos-sonoma-xcode@sha256:07bbebb2931113e187a49284f98d3834ffbe8584e9c90ab789d914b0f2df4a40",
            ),
            # only_if = "$CIRRUS_TAG =~ 'v.*' || $CIRRUS_BRANCH == 'master'",
            only_if = "$CIRRUS_TAG =~ 'v.*'",
            instructions = [
                cache("cocoapods", "~/.cocoapods"),
                setup_1password_cli(),
                setup_credentials(),
                setup_fastlane(),
                script(
                    "fastlane_ios_tst",
                    "chmod +x ./gradlew",  # workaround for "permission denied" when running gradlew
                    "cd fastlane",
                    "op run -- bundle exec fastlane ios tst",
                ),
            ],
        ),
    ]
