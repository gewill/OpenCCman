import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "duo_build", Path(__file__).resolve().parents[2] / "scripts/build-duo-validation.py")
duo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(duo)


class DuoArtifactChecks(unittest.TestCase):
    def setUp(self):
        self.info = {
            "DTSDKName": "iphonesimulator27.1", "MinimumOSVersion": "15.0",
            "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": True},
            "UILaunchScreen": {"UIColorName": "LaunchBackground"},
            "UIApplicationSupportsIndirectInputEvents": True, "UIDeviceFamily": [1, 2],
            "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        }
        self.info["UISupportedInterfaceOrientations~ipad"] = self.info["UISupportedInterfaceOrientations"]

    def test_valid_artifact_retains_deployment_floor(self):
        self.assertEqual(duo.validate_plist(self.info, "ios")["MinimumOSVersion"], "15.0")

    def test_old_sdk_and_wrong_destination_are_not_duo_builds(self):
        for sdk in ["iphonesimulator27.0", "iphoneos27.1", "", "macosx27.1"]:
            with self.subTest(sdk=sdk), self.assertRaises(ValueError):
                duo.validate_plist(dict(self.info, DTSDKName=sdk), "ios")

    def test_generated_iphone_suffix_is_a_valid_orientation_declaration(self):
        info = copy.deepcopy(self.info)
        info["UISupportedInterfaceOrientations~iphone"] = info.pop("UISupportedInterfaceOrientations")
        duo.validate_plist(info, "ios")

    def test_missing_generated_capabilities_are_rejected(self):
        for key in ["UIApplicationSceneManifest", "UILaunchScreen", "UIApplicationSupportsIndirectInputEvents",
                    "UIDeviceFamily", "UISupportedInterfaceOrientations", "UISupportedInterfaceOrientations~ipad"]:
            info = copy.deepcopy(self.info)
            del info[key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                duo.validate_plist(info, "ios")

    def test_new_sdk_does_not_authorize_a_higher_deployment_floor(self):
        for minimum in ["16.0", "27.1", "14.0"]:
            with self.subTest(minimum=minimum), self.assertRaises(ValueError):
                duo.validate_plist(dict(self.info, MinimumOSVersion=minimum), "ios")

    def test_mac_artifact_is_checked_independently(self):
        info = {"DTSDKName": "macosx27.0", "LSMinimumSystemVersion": "12.0"}
        duo.validate_plist(info, "mac", "27.0")
        with self.assertRaises(ValueError):
            duo.validate_plist(info, "mac", "26.3")
        with self.assertRaises(ValueError):
            duo.validate_plist(dict(info, LSMinimumSystemVersion="13.0"), "mac")


if __name__ == "__main__":
    unittest.main()
